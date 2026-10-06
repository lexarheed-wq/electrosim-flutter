#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"G9 contract failed: {label}")

models = read("packages/electrosim_diagnostics/lib/src/diagnostic_models.dart")
engine = read("packages/electrosim_diagnostics/lib/src/diagnostic_engine.dart")
runtime = read("apps/electrosim/lib/runtime/electrosim_runtime_engine.dart")
panels = read("apps/electrosim/lib/f9_context_panels.dart")

require(engine, "DiagnosticReport analyzePv(", "PV DiagnosticEngine adapter missing")
require(engine, "PvSolverDiagnostic", "PV solver evidence type missing")
require(engine, "_fromPvSolver", "PV diagnostic mapping missing")
require(runtime, "diagnosticEngine.analyzePv(", "PV runtime must route through DiagnosticEngine")
if "_noDcDiagnostics" in runtime:
    raise SystemExit("G9 contract failed: legacy fabricated empty PV diagnostic report remains")

for code in (
    "pvMissingArray",
    "pvMissingInverter",
    "pvDcInputDisconnected",
    "pvAcOutputDisconnected",
    "pvInputVoltageOutOfRange",
    "pvInverterFaulted",
    "pvControllerFaulted",
    "pvBatteryEmpty",
    "pvBatteryFull",
):
    require(models, code, f"EIE PV advice code {code} missing")
    require(engine, f"EieAdviceCode.{code}", f"PV mapping for {code} missing")

require(panels, "bool get showEie => role == F9UserRole.teacher;", "EIE must be teacher-only")
require(panels, "if (widget.showEie)", "teacher EIE visibility guard missing")
require(panels, "initiallyExpanded: false", "technical evidence must be collapsed by default")
require(panels, "Détails techniques", "technical evidence disclosure missing")

if "coach" in panels.lower():
    raise SystemExit("G9 contract failed: student coach vocabulary reintroduced in context panel")

print("F18_G9_EIE_INTERNAL_GATE_CONTRACT_PASS")
