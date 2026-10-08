#!/usr/bin/env python3
"""Conservative G12RQ three-way conflict repair: preserve engine and editing semantics."""
import re
import subprocess
import tempfile
from pathlib import Path

ROOT=Path.cwd()
PATCH=ROOT/'integration/professional-workspace/electrosim-interface-changements.patch'
MAIN=ROOT/'apps/electrosim/lib/main.dart'
SHELL=ROOT/'packages/electrosim_ui_kit/lib/src/workspace_shell.dart'
BASE='09f0459dd584c6231870387e7d5f8d8dd77b647d'
ANCHOR='class _WorkspaceTopBar extends StatelessWidget'

def rep(s, old, new):
    n=s.count(old)
    if n != 1:
        raise RuntimeError(f'expected one fragment, found {n}: {old[:90]!r}')
    return s.replace(old,new)

def supply():
    with tempfile.TemporaryDirectory() as d:
        root=Path(d)
        archive=root/'base.tar'
        with archive.open('wb') as f:
            subprocess.run(['git','archive','--format=tar',BASE],stdout=f,check=True)
        subprocess.run(['tar','xf',str(archive),'-C',str(root)],check=True)
        subprocess.run(['git','apply',str(PATCH)],cwd=root,check=True)
        return (root/'apps/electrosim/lib/main.dart').read_text(),(root/'packages/electrosim_ui_kit/lib/src/workspace_shell.dart').read_text()

def fix_topbar(t):
    t=rep(t,'    required this.onResetSimulation,\n',"""    required this.onResetSimulation,
    required this.simulationAdvancing,
    required this.onAdvanceSimulation,
    required this.onCancelAdvance,
    required this.onUndo,
    required this.onRedo,
""")
    t=rep(t,'  final VoidCallback onResetSimulation;\n',"""  final VoidCallback onResetSimulation;
  final bool simulationAdvancing;
  final ValueChanged<Duration> onAdvanceSimulation;
  final VoidCallback onCancelAdvance;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
""")
    t=rep(t,'          _modeMenu(compact),\n',"""          _modeMenu(compact),
          if (!compact)
            PopupMenuButton<Duration>(
              key: const Key('workspace-time-advance'),
              tooltip: 'Avancer le temps simulé',
              enabled: !simulationAdvancing,
              icon: const Icon(Icons.more_time_outlined),
              onSelected: onAdvanceSimulation,
              itemBuilder: (context) => const [
                PopupMenuItem<Duration>(
                  key: Key('workspace-time-plus-minute'),
                  value: Duration(minutes: 1),
                  child: Text('Avancer de +1 min'),
                ),
                PopupMenuItem<Duration>(
                  key: Key('workspace-time-plus-hour'),
                  value: Duration(hours: 1),
                  child: Text('Avancer de +1 h'),
                ),
                PopupMenuItem<Duration>(
                  key: Key('workspace-time-plus-day'),
                  value: Duration(hours: 24),
                  child: Text('Avancer de +24 h'),
                ),
              ],
            ),
""")
    t=rep(t,"            message: simulationRunning\n                ? 'Mettre la simulation en pause'\n                : 'Démarrer la simulation',","            message: simulationAdvancing\n                ? 'Annuler l’avance temporelle'\n                : simulationRunning\n                    ? 'Mettre la simulation en pause'\n                    : 'Démarrer la simulation',")
    t=rep(t,'              onPressed: onToggleSimulation,','              onPressed: simulationAdvancing ? onCancelAdvance : onToggleSimulation,')
    t=rep(t,'              icon: Icon(simulationRunning ? Icons.pause : Icons.play_arrow),',"""              icon: Icon(simulationAdvancing
                  ? Icons.stop_circle_outlined
                  : simulationRunning ? Icons.pause : Icons.play_arrow),""")
    t=rep(t,"              label: Text(simulationRunning ? 'Pause' : 'Lancer'),","              label: Text(simulationAdvancing ? 'Stop' : simulationRunning ? 'Pause' : 'Lancer'),")
    t=rep(t,"      switch (action) {\n        case _WorkspaceSecondaryAction.save:","""      switch (action) {
        case _WorkspaceSecondaryAction.undo:
          onUndo?.call();
        case _WorkspaceSecondaryAction.redo:
          onRedo?.call();
        case _WorkspaceSecondaryAction.advanceMinute:
          onAdvanceSimulation(const Duration(minutes: 1));
        case _WorkspaceSecondaryAction.advanceHour:
          onAdvanceSimulation(const Duration(hours: 1));
        case _WorkspaceSecondaryAction.advanceDay:
          onAdvanceSimulation(const Duration(hours: 24));
        case _WorkspaceSecondaryAction.save:""")
    t=rep(t,"    itemBuilder: (context) => [\n      if (onSave != null)","""    itemBuilder: (context) => [
      PopupMenuItem(
        key: const Key('workspace-undo-action'),
        value: _WorkspaceSecondaryAction.undo,
        enabled: onUndo != null,
        child: const Text('Annuler · ⌘Z / Ctrl+Z'),
      ),
      PopupMenuItem(
        key: const Key('workspace-redo-action'),
        value: _WorkspaceSecondaryAction.redo,
        enabled: onRedo != null,
        child: const Text('Rétablir · ⌘⇧Z / Ctrl+Y'),
      ),
      if (MediaQuery.sizeOf(context).width < 720 && !simulationAdvancing) ...const [
        PopupMenuItem(
          key: Key('workspace-time-plus-minute'),
          value: _WorkspaceSecondaryAction.advanceMinute,
          child: Text('Avancer de +1 min'),
        ),
        PopupMenuItem(
          key: Key('workspace-time-plus-hour'),
          value: _WorkspaceSecondaryAction.advanceHour,
          child: Text('Avancer de +1 h'),
        ),
        PopupMenuItem(
          key: Key('workspace-time-plus-day'),
          value: _WorkspaceSecondaryAction.advanceDay,
          child: Text('Avancer de +24 h'),
        ),
      ],
      if (onSave != null)""")
    t=rep(t,'enum _WorkspaceSecondaryAction { save, open, recenter, resetSimulation }','enum _WorkspaceSecondaryAction { undo, redo, save, open, recenter, resetSimulation, advanceMinute, advanceHour, advanceDay }')
    return t

def main():
    current=MAIN.read_text()
    assert current.count('<<<<<<< ours') == 4
    ui_main,ui_shell=supply()
    prefix=current[:current.index(ANCHOR)]
    pat=re.compile(r'(?m)^<<<<<<< ours\n(.*?)^=======\n(.*?)^>>>>>>> theirs\n',re.S)
    for _ in range(3):
        m=pat.search(prefix)
        if m is None: raise RuntimeError('expected earlier merge conflict')
        prefix=prefix[:m.start()]+m.group(1)+prefix[m.end():]
    assert '<<<<<<<' not in prefix
    tail=fix_topbar(ui_main[ui_main.index(ANCHOR):])
    result=prefix+tail
    for proof in ('workspace-time-plus-hour','workspace-time-plus-day','onUndo:','onRedo:','_finishElementRoute','_simulation.advanceBy'):
        if proof not in result: raise RuntimeError('lost G12RQ contract: '+proof)
    MAIN.write_text(result)
    SHELL.write_text(ui_shell)
    # Preserve behavior while satisfying the repository's strict lint gate.
    shelltest=ROOT/'packages/electrosim_ui_kit/test/professional_workspace_shell_test.dart'
    t=shelltest.read_text()
    t=rep(t,
          '        if (element.widget.key == electroSimContextRegionKey)\n          insideClosingPanel = true;',
          '        if (element.widget.key == electroSimContextRegionKey) {\n          insideClosingPanel = true;\n        }')
    shelltest.write_text(t)
    uitest=ROOT/'apps/electrosim/test/workspace_layout_preferences_ui_test.dart'
    q=uitest.read_text()
    q=rep(q,
          '          if (editFirst)\n            await Future<void>.delayed(const Duration(milliseconds: 30));',
          '          if (editFirst) {\n            await Future<void>.delayed(const Duration(milliseconds: 30));\n          }')
    uitest.write_text(q)
    assert '<<<<<<<' not in MAIN.read_text()+SHELL.read_text()
    print('PROFESSIONAL_WORKSPACE_CONFLICTS_RESOLVED')
if __name__ == '__main__':
    main()
