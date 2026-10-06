#!/usr/bin/env python3
"""CORE-UNIFY structural guard.

Fails CI when known split-brain physics patterns are reintroduced in the
unified DC/runtime/property/visual path.
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

checks = [
    (
        ROOT / "packages/electrosim_solver_dc/lib/src/solver_dc.dart",
        ["switch (component.modelType)", "component.modelType =="],
        "DC solver must dispatch through canonical physics contracts, not modelType branches.",
    ),
    (
        ROOT / "apps/electrosim/lib/f9_component_visuals.dart",
        ["parameters['ratedCurrentA']", 'parameters["ratedCurrentA"]'],
        "Protection visuals must use ProtectionRating.ratedCurrentKey.",
    ),
    (
        ROOT / "apps/electrosim/lib/f18_g7_property_presenter.dart",
        ["Tension moteur", "Courant moteur", "Puissance moteur", "Alerte moteur"],
        "Generic properties must not expose component-specific motor labels.",
    ),
    (
        ROOT / "packages/electrosim_measurements/lib/src/device_state_engine.dart",
        ["'maxVoltageV'", "'maxCurrentA'", "'maxPowerW'"],
        "Device state must consume ComponentOperatingEnvelope instead of raw limit keys.",
    ),
]

errors: list[str] = []
for path, forbidden, message in checks:
    text = path.read_text(encoding="utf-8")
    for token in forbidden:
        if token in text:
            errors.append(f"{path.relative_to(ROOT)}: forbidden token {token!r}: {message}")

required = {
    ROOT / "packages/electrosim_domain/lib/src/component_physics_contract.dart": [
        "CoreComponentPhysicsContracts",
        "ComponentOperatingEnvelope",
        "missingPhysicsContracts",
    ],
    ROOT / "apps/electrosim/lib/runtime/electrosim_runtime_engine.dart": [
        "effectiveCircuit",
        "componentHealthStates",
        "connectionCurrentEvidence",
    ],
    ROOT / "packages/electrosim_controls/lib/src/electromechanical_control_engine.dart": [
        "oscillatingControlState",
        "_stateSignature",
    ],
}
for path, tokens in required.items():
    text = path.read_text(encoding="utf-8")
    for token in tokens:
        if token not in text:
            errors.append(f"{path.relative_to(ROOT)}: missing required CORE-UNIFY marker {token!r}")

if errors:
    print("CORE_UNIFY_ARCHITECTURE_GUARD_FAIL")
    print("\n".join(f"- {item}" for item in errors))
    sys.exit(1)

print("CORE_UNIFY_ARCHITECTURE_GUARD_PASS")
