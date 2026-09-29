from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
main=(root/'apps/electrosim/lib/main.dart').read_text(encoding='utf-8')
test=(root/'apps/electrosim/test/f9_shell_test.dart').read_text(encoding='utf-8')
checks={
 'total-count-formula':'final int elementCount = circuit.components.length + circuit.sources.length;' in main,
 'expanded-label-uses-elements':"'$elementCount élément${elementCount == 1 ? '' : 's'} · '" in main,
 'compact-label-uses-elements':"'$elementCount élém. · ${circuit.sources.length} src.'" in main,
 'initial-regression-expectation':"contains('3 éléments · 1 source')" in test,
 'after-add-regression-expectation':"contains('4 éléments · 1 source')" in test,
}
failed=[k for k,v in checks.items() if not v]
if failed:
 print('F9_STATUS_BAR_STATIC_FAIL: '+','.join(failed)); sys.exit(1)
print(f'F9_STATUS_BAR_STATIC_PASS ({sum(checks.values())}/{len(checks)})')
