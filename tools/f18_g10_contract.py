#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"G10 contract failed: {label}")

examples = read("packages/electrosim_scenarios/lib/src/v2_product_examples.dart")
faults = read("packages/electrosim_scenarios/lib/src/v2_product_faults.dart")
catalog = read("packages/electrosim_scenarios/lib/src/v2_product_catalog.dart")
exports = read("packages/electrosim_scenarios/lib/electrosim_scenarios.dart")
policy = read("packages/electrosim_scenarios/REBUILD_POLICY.md")
fixtures = [
    read("packages/electrosim_scenarios/lib/src/f10_examples.dart"),
    read("packages/electrosim_scenarios/lib/src/f11_fault_scenarios.dart"),
    read("packages/electrosim_scenarios/lib/src/f16_catalog.dart"),
]

for text, label in (
    (examples, "product schemas"),
    (faults, "product faults"),
):
    require(text, "'origin': 'v2-native'", f"{label} must declare V2-native origin")
    require(text, "'library': 'v2-product'", f"{label} must declare product library")

require(examples, "'libraryKind': 'healthy-schema'", "healthy schema marker missing")
require(faults, "'libraryKind': 'fault-scenario'", "fault scenario marker missing")
require(faults, "'autonomousFaultScenario': true", "autonomous fault marker missing")
require(catalog, "buildV2ProductExampleRepository()", "product catalog must use V2 schemas")
require(catalog, "buildV2ProductFaultRepository()", "product catalog must use V2 faults")
require(catalog, "bool get allNativeV2", "native V2 catalog invariant missing")

for forbidden in (
    "f10_examples",
    "f11_fault_scenarios",
    "f16_catalog",
    "buildF10",
    "buildF11",
    "buildF16",
    "reference/",
    "legacy",
):
    if forbidden.lower() in catalog.lower():
        raise SystemExit(f"G10 contract failed: product catalog references forbidden source {forbidden}")
    if forbidden.lower() in examples.lower():
        raise SystemExit(f"G10 contract failed: product schemas reference forbidden source {forbidden}")
    if forbidden.lower() in faults.lower():
        raise SystemExit(f"G10 contract failed: product faults reference forbidden source {forbidden}")

for forbidden in ("exampleid", "example_id", "examplecircuit"):
    if forbidden in faults.lower():
        raise SystemExit(f"G10 contract failed: fault library contains forbidden linkage {forbidden}")

if "v2_product_examples.dart" in faults:
    raise SystemExit("G10 contract failed: fault library must not import healthy product schemas")

for fixture in fixtures:
    require(
        fixture,
        "BOOTSTRAP_FIXTURE_ONLY",
        "baseline fixture lost its non-production marker",
    )

require(policy, "Aucun schéma V1 n'est importé ou converti.", "V1 schema ban missing")
require(policy, "Aucun scénario final ne dépend d'un exemple sain existant.", "fault independence policy missing")
require(exports, "v2_product_catalog.dart", "V2 product catalog export missing")

print("F18_G10_V2_PURE_LIBRARIES_CONTRACT_PASS")
