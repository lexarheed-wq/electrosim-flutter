#!/usr/bin/env python3
"""Adapt *existing behavioral tests* to intentional permanent professional shell.

Only selector activation changes; all physical/electrical assertions stay intact.
"""
from pathlib import Path
from textwrap import dedent

ROOT = Path.cwd()

def edit(rel, changes):
    path = ROOT / rel
    source = path.read_text()
    for old, new, count in changes:
        seen = source.count(old)
        if seen != count:
            raise RuntimeError(f"{rel}: expected {count} occurrences, saw {seen}: {old[:120]!r}")
        source = source.replace(old, new)
    path.write_text(source)

edit("apps/electrosim/test/sim_r1_board_instrument_ui_test.dart", [
    ("    // F18 workspace auto-hides its palette: open it through its real edge.\n    await tester.tap(find.byKey(const Key('electrosim-palette-edge')));\n    await tester.pumpAndSettle();\n",
     "    // Desktop palette is docked and visible by default in the professional shell.\n    expect(find.byKey(const Key('palette-search-field')), findsOneWidget);\n", 1),
    ("    await tester.tap(find.byKey(const Key('electrosim-palette-edge')));\n    await tester.pumpAndSettle();\n",
     "    // Do not close the default-visible professional palette.\n    expect(find.byKey(const Key('palette-search-field')), findsOneWidget);\n", 1),
])
edit("apps/electrosim/test/g12rq_postaudit_time_and_ui_test.dart", [
    (dedent("""\
      for (final (Key activator, Key pin) in <(Key, Key)>[
        (electroSimContextEdgeKey, electroSimContextPinKey),
        (electroSimTopEdgeKey, electroSimTopPinKey),
      ]) {
        tester.widget<GestureDetector>(find.byKey(activator)).onTap!();
        await tester.pumpAndSettle();
        tester.widget<IconButton>(find.byKey(pin)).onPressed!();
        await tester.pumpAndSettle();
      }
"""),
     "      // Professional shell permanently displays its top bar and docked inspector.\n      await tester.pumpAndSettle();\n      expect(find.byKey(electroSimContextRegionKey), findsOneWidget);\n", 1),
    ("    tester.widget<GestureDetector>(find.byKey(electroSimTopEdgeKey)).onTap!();\n    await tester.pumpAndSettle();\n",
     "    // Permanent top command bar: no edge gesture is needed.\n    await tester.pumpAndSettle();\n", 1),
    ("    tester\n        .widget<GestureDetector>(find.byKey(electroSimPaletteEdgeKey))\n        .onTap!();\n",
     "    await tester.tap(find.byKey(electroSimPaletteEdgeKey));\n", 1),
    ("    tester\n        .widget<GestureDetector>(find.byKey(electroSimContextEdgeKey))\n        .onTap!();\n",
     "    await tester.tap(find.byKey(electroSimContextEdgeKey));\n", 1),
])
edit("apps/electrosim/test/audit_workspace_undo_redo_test.dart", [
    ("    tester\n        .widget<GestureDetector>(find.byKey(electroSimPaletteEdgeKey))\n        .onTap!();\n    await tester.pumpAndSettle();\n",
     "    // Professional desktop palette is already visible, do not toggle it closed.\n    expect(find.byKey(electroSimPaletteRegionKey), findsOneWidget);\n", 1),
    ("    tester.widget<GestureDetector>(find.byKey(electroSimTopEdgeKey)).onTap!();\n    await tester.pumpAndSettle();\n",
     "    // The top command bar is permanent.\n    await tester.pumpAndSettle();\n", 1),
])
print("PROFESSIONAL_WORKSPACE_LEGACY_TEST_SELECTORS_UPDATED")
