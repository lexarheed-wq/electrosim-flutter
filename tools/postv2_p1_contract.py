#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
errors = []

def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)

canvas_root = ROOT / "packages/electrosim_canvas"
for path in canvas_root.rglob("*.dart"):
    text = path.read_text(encoding="utf-8")
    require(
        "electrosim_solver_" not in text,
        f"Canvas must not import solver code: {path.relative_to(ROOT)}",
    )
    require(
        "electrosim_diagnostics" not in text,
        f"Canvas must not own EIE/diagnostic physics: {path.relative_to(ROOT)}",
    )

wiring = (ROOT / "apps/electrosim/lib/f9_wiring_policy.dart").read_text(
    encoding="utf-8"
)
require(
    "from == to" in wiring,
    "Wiring policy must reject self-connections structurally.",
)
require(
    "borne inconnue" in wiring,
    "Wiring policy must reject unknown terminals structurally.",
)
require(
    "ces deux bornes sont déjà reliées" in wiring,
    "Wiring policy must reject exact duplicate links structurally.",
)
require(
    "Mixed explicit tags stay neutral" in wiring,
    "Wiring policy must preserve mixed phase/polarity metadata neutrally.",
)
require(
    "PhaseTag.none" in wiring,
    "Mixed explicit terminal tags must be representable as neutral wire metadata.",
)

topology = (ROOT / "packages/electrosim_topology/lib/src/topology_engine.dart").read_text(
    encoding="utf-8"
)
require(
    "DC positive/negative are local terminal polarity labels" in topology,
    "Topology must treat DC +/- as local metadata, not global phase prohibition.",
)
require(
    "_hasDirectDcSourceShortNode" in topology,
    "Topology must distinguish an actual source short from mixed DC polarity metadata.",
)

source_tests = (
    ROOT / "packages/electrosim_solver_dc/test/postv2_p1_source_associations_test.dart"
).read_text(encoding="utf-8")
receiver_tests = (
    ROOT / "packages/electrosim_solver_dc/test/postv2_p1_receiver_polarity_test.dart"
).read_text(encoding="utf-8")
invariant_tests = (
    ROOT / "packages/electrosim_solver_dc/test/postv2_p1_invariants_test.dart"
).read_text(encoding="utf-8")
pv_tests = (
    ROOT / "packages/electrosim_pv/test/postv2_p1_polarity_test.dart"
).read_text(encoding="utf-8")
eie_tests = (
    ROOT / "packages/electrosim_diagnostics/test/postv2_p1_eie_authority_test.dart"
).read_text(encoding="utf-8")
motor_visual_tests = (
    ROOT / "apps/electrosim/test/postv2_p1_motor_visual_direction_test.dart"
).read_text(encoding="utf-8")
for marker in (
    "P1-DC-SERIES-01",
    "P1-DC-SERIES-02",
    "P1-DC-SERIES-03",
    "P1-DC-OPPOSED-01",
    "P1-DC-MIDPOINT-01",
    "P1-DC-PARALLEL-01",
    "P1-DC-PARALLEL-02",
):
    require(marker in source_tests, f"Missing P1.3 source association case: {marker}")

require(
    "<String>['resistor', 'lamp']" in receiver_tests,
    "Missing P1.4 unpolarized resistor/lamp matrix.",
)
for marker in (
    "P1-RX-MOTOR-DC",
    "P1-RX-COIL-SIMPLE",
    "P1-RX-LED",
    "P1-RX-COIL-POLARIZED",
):
    require(marker in receiver_tests, f"Missing P1.4 receiver case: {marker}")

for marker in (
    "P1-PV-INVERTER",
    "P1-PV-STORAGE",
    "P1-PV-CONTROLLER",
    "P1-PV-BATTERY",
):
    require(marker in pv_tests, f"Missing P1.4 PV polarity case: {marker}")

require("P1-INV-DC" in invariant_tests, "Missing P1.5 physical invariant test")
require("P1-INV-REPRO" in invariant_tests, "Missing P1.5 reproducibility test")
require(
    "without mutating electrical state" in eie_tests,
    "Missing P1.5 EIE observational-authority test",
)
require(
    "follows signed solver current" in motor_visual_tests,
    "Motor animation must follow signed solver evidence.",
)

solver_dc = (ROOT / "packages/electrosim_solver_dc/lib/src/solver_dc.dart").read_text(
    encoding="utf-8"
)
require(
    "_normalizeIdealVoltageConstraints" in solver_dc,
    "SolverDC must normalize redundant/contradictory ideal voltage constraints.",
)
require(
    "DcDiagnosticCode.contradictoryIdealSource" in solver_dc,
    "Incompatible ideal source constraints must be diagnosed by SolverDC.",
)

if errors:
    print("POSTV2_P1_CONTRACT_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("POSTV2_P1_CONTRACT_PASS")
