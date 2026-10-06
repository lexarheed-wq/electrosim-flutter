#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"G10B contract failed: {label}")

main = read("apps/electrosim/lib/main.dart")
pages = read("apps/electrosim/lib/f18_product_library_pages.dart")
tests = read("apps/electrosim/test/f18_g10b_library_ui_test.dart")

require(main, "F18SchemaLibraryPage(", "schema library page is not wired")
require(main, "F18FaultLibraryPage(", "fault library page is not wired")
require(main, "initialCircuit: schema.circuit", "schema CircuitState is not loaded")
require(main, "initialCircuit: scenario.faultyCircuit", "fault CircuitState is not loaded")
require(main, "buildV2ProductLibrary()", "V2 product catalog is not used by UI")

for old in (
    "Les schémas sains seront gérés dans la bibliothèque de conception F18.",
    "Les circuits défectueux autonomes seront gérés dans la bibliothèque de maintenance F18.",
):
    if old in main:
        raise SystemExit("G10B contract failed: product library placeholder remains")

require(pages, "schema-library-search", "schema search missing")
require(pages, "fault-library-search", "fault search missing")
require(pages, "library-filter-", "mode filters missing")
require(pages, "Ouvrir dans le simulateur", "schema launch action missing")
require(
    pages,
    "Lancer la recherche de dérangement",
    "fault launch action missing",
)
require(tests, "teacher truth private", "privacy regression test missing")
require(tests, "loads the selected CircuitState", "schema load test missing")

if "teacherTruth" in pages:
    raise SystemExit("G10B contract failed: teacherTruth exposed to library UI")

print("F18_G10B_LIBRARY_UI_CONTRACT_PASS")
