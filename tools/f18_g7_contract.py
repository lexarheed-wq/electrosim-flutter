#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
checks = []


def require(path: str, needle: str, label: str) -> None:
    text = (ROOT / path).read_text(encoding='utf-8')
    checks.append((label, needle in text))


def forbid(path: str, needle: str, label: str) -> None:
    text = (ROOT / path).read_text(encoding='utf-8')
    checks.append((label, needle not in text))


require(
    'apps/electrosim/lib/runtime/electrosim_runtime_engine.dart',
    'ComponentOperatingState? componentOperatingState',
    'runtime exposes DeviceStateEngine operating state',
)
for method, label in (
    ('deviceStateEngine.evaluateAc1', 'AC1 state routes through DeviceStateEngine'),
    ('deviceStateEngine.evaluateAc3', 'AC3 state routes through DeviceStateEngine'),
    ('deviceStateEngine.evaluatePv', 'PV state routes through DeviceStateEngine'),
):
    require(
        'apps/electrosim/lib/runtime/electrosim_runtime_engine.dart',
        method,
        label,
    )
require(
    'packages/electrosim_measurements/lib/electrosim_measurements.dart',
    "export 'src/device_state_domain_extensions.dart';",
    'domain adapters are exported by measurement package',
)
for method, label in (
    ('ComponentOperatingState evaluateAc1', 'DeviceStateEngine supports AC1'),
    ('ComponentOperatingState evaluateAc3', 'DeviceStateEngine supports AC3'),
    ('ComponentOperatingState evaluatePv', 'DeviceStateEngine supports PV'),
):
    require(
        'packages/electrosim_measurements/lib/src/device_state_domain_extensions.dart',
        method,
        label,
    )
require(
    'apps/electrosim/lib/f9_context_panels.dart',
    'F18G7PropertyPresenter.describe',
    'properties are routed through the G7 presenter',
)
require(
    'apps/electrosim/lib/f9_context_panels.dart',
    "title: const Text('Preuves moteur')",
    'properties expose solver evidence',
)
forbid(
    'apps/electrosim/lib/f9_context_panels.dart',
    '_PropertyLine(label: entry.key',
    'raw parameter keys are not rendered directly',
)
require(
    'apps/electrosim/lib/f18_g7_property_presenter.dart',
    'The presenter does not calculate substitute electrical values',
    'presenter documents no-fabrication policy',
)
for literal in ('24.000', '230.000', '1.000 A', '5.000 A'):
    forbid(
        'apps/electrosim/lib/f18_g7_property_presenter.dart',
        literal,
        f'presenter contains no hard-coded runtime reading {literal}',
    )
require(
    'apps/electrosim/test/f17_measurement_ui_test.dart',
    'UI does not fabricate readings when the solver cannot resolve a model',
    'existing no-fabrication measurement regression remains present',
)
require(
    'apps/electrosim/test/f18_g7_instruments_properties_test.dart',
    'unsolved circuits never manufacture operating quantities',
    'G7 adds unsolved/no-fabrication state regression',
)

failed = [label for label, ok in checks if not ok]
for label, ok in checks:
    print(('PASS' if ok else 'FAIL') + ': ' + label)

if failed:
    print('F18_G7_INSTRUMENTS_PROPERTIES_CONTRACT_FAIL', file=sys.stderr)
    raise SystemExit(1)

print('F18_G7_INSTRUMENTS_PROPERTIES_CONTRACT_PASS')
