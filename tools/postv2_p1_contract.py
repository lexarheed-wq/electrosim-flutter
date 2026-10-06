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

if errors:
    print("POSTV2_P1_CONTRACT_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("POSTV2_P1_CONTRACT_PASS")
