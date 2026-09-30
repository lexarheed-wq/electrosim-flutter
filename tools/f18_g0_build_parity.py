#!/usr/bin/env python3
import argparse
import csv
import pathlib
import re
import sys


_FIELD_PATTERNS = {
    "keyName": re.compile(r"\bkeyName:\s*'([^']+)'"),
    "title": re.compile(r"\btitle:\s*'([^']+)'"),
    "category": re.compile(r"\bcategory:\s*'([^']+)'"),
    "modelType": re.compile(r"\bmodelType:\s*'([^']+)'"),
}


def extract_palette_definitions(dart_source: str) -> list[dict[str, str]]:
    blocks = re.findall(
        r"F9PaletteDefinition\(\s*(.*?)\n\s*\),",
        dart_source,
        flags=re.DOTALL,
    )
    items: list[dict[str, str]] = []
    seen_keys: set[str] = set()
    for block in blocks:
        item: dict[str, str] = {}
        for field, pattern in _FIELD_PATTERNS.items():
            match = pattern.search(block)
            if not match:
                raise ValueError(f"palette definition missing {field}")
            item[field] = match.group(1)

        key = item["keyName"]
        if key in seen_keys:
            raise ValueError(f"duplicate palette key: {key}")
        seen_keys.add(key)
        items.append(item)

    if not items:
        raise ValueError("no F9PaletteDefinition entries found")
    return items


def extract_catalog_counts(dart_source: str) -> dict[str, int]:
    examples = set(re.findall(r"ExampleId\('([^']+)'\)", dart_source))
    faults = set(re.findall(r"FaultScenarioId\('([^']+)'\)", dart_source))
    return {
        "examples": len(examples),
        "faultScenarios": len(faults),
    }


CURRENT_FLUTTER_MODEL_TYPES = frozenset({
    "dc_voltage_source",
    "switch",
    "lamp",
    "resistor",
    "breaker",
    "push_button_no",
    "buzzer",
    "fuse",
    "diode",
    "fan_dc",
    "motor_dc",
    "relay_coil",
})
ALLOWED_DISPOSITIONS = frozenset({"REBUILD", "REPLACE", "DEFER", "RETIRE"})
REQUIRED_PARITY_FIELDS = (
    "legacy_id",
    "label",
    "entity_class",
    "legacy_category",
    "legacy_modes",
    "flutter_model_type",
    "disposition",
    "reason",
    "target_gate",
    "visual_family",
)


def validate_parity(rows: list[dict[str, str]]) -> list[str]:
    errors: list[str] = []
    seen: set[str] = set()
    for index, row in enumerate(rows, start=2):
        missing = [field for field in REQUIRED_PARITY_FIELDS if field not in row]
        if missing:
            errors.append(f"row {index}: missing fields {','.join(missing)}")
            continue

        legacy_id = row["legacy_id"].strip()
        if not legacy_id:
            errors.append(f"row {index}: legacy_id is empty")
        elif legacy_id in seen:
            errors.append(f"row {index}: duplicate legacy_id {legacy_id}")
        else:
            seen.add(legacy_id)

        disposition = row["disposition"].strip()
        if disposition not in ALLOWED_DISPOSITIONS:
            errors.append(
                f"row {index}: invalid disposition {disposition or '<empty>'}"
            )

        for field in ("reason", "target_gate", "visual_family"):
            if not row[field].strip():
                errors.append(f"row {index}: {field} is empty")

        model_type = row["flutter_model_type"].strip()
        if model_type and model_type not in CURRENT_FLUTTER_MODEL_TYPES:
            planned_rebuild = (
                disposition == "REBUILD"
                and row["target_gate"].strip() in {"G4", "G5"}
            )
            if not planned_rebuild:
                errors.append(
                    f"row {index}: unknown flutter_model_type {model_type}"
                )
    return errors


ALLOWED_CAPABILITY_STATES = frozenset({
    "PRESENT",
    "PARTIAL",
    "MISSING",
    "INTENTIONALLY_REDESIGNED",
})
REQUIRED_CAPABILITY_FIELDS = (
    "capability",
    "legacy_evidence",
    "flutter_evidence",
    "current_state",
    "target_gate",
    "acceptance",
)


def validate_capability_parity(rows: list[dict[str, str]]) -> list[str]:
    errors: list[str] = []
    seen: set[str] = set()
    for index, row in enumerate(rows, start=2):
        missing = [field for field in REQUIRED_CAPABILITY_FIELDS if field not in row]
        if missing:
            errors.append(f"row {index}: missing fields {','.join(missing)}")
            continue

        capability = row["capability"].strip()
        if not capability:
            errors.append(f"row {index}: capability is empty")
        elif capability in seen:
            errors.append(f"row {index}: duplicate capability {capability}")
        else:
            seen.add(capability)

        state = row["current_state"].strip()
        if state not in ALLOWED_CAPABILITY_STATES:
            errors.append(f"row {index}: invalid current_state {state or '<empty>'}")

        for field in ("legacy_evidence", "flutter_evidence", "target_gate", "acceptance"):
            if not row[field].strip():
                errors.append(f"row {index}: {field} is empty")
    return errors


REQUIRED_PRODUCT_CAPABILITIES = frozenset({
    "Accueil",
    "Session",
    "Centre de maintenance",
    "Centre de conception",
    "Palette composants",
    "Canvas",
    "Câblage interactif",
    "Mesures",
    "Énergie",
    "EIE / diagnostic",
    "Sauvegardes locales",
    "TP câblage",
    "Recherche de dérangement",
    "Supervision professeur",
    "Responsive/mobile",
    "LAN professeur/élève",
})


def _read_csv(path: pathlib.Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def check_committed_parity(root: pathlib.Path) -> list[str]:
    errors: list[str] = []

    product_path = root / "docs" / "f18" / "g0" / "F18_PRODUCT_PARITY.csv"
    capability_path = root / "docs" / "f18" / "g0" / "F18_CAPABILITY_PARITY.csv"
    try:
        product_rows = _read_csv(product_path)
    except Exception as exc:
        errors.append(f"product parity unreadable: {exc}")
        product_rows = []
    try:
        capability_rows = _read_csv(capability_path)
    except Exception as exc:
        errors.append(f"capability parity unreadable: {exc}")
        capability_rows = []

    errors.extend(validate_parity(product_rows))
    errors.extend(validate_capability_parity(capability_rows))

    if len(product_rows) != 217:
        errors.append(f"product parity row count must be 217, got {len(product_rows)}")

    expected_classes = {
        "palette-component": 195,
        "socket": 4,
        "external-appliance": 18,
    }
    for entity_class, expected in expected_classes.items():
        actual = sum(row.get("entity_class") == entity_class for row in product_rows)
        if actual != expected:
            errors.append(
                f"entity_class {entity_class} count must be {expected}, got {actual}"
            )

    capabilities = {row.get("capability", "") for row in capability_rows}
    missing_capabilities = sorted(REQUIRED_PRODUCT_CAPABILITIES - capabilities)
    if missing_capabilities:
        errors.append(
            "missing required capabilities: " + ", ".join(missing_capabilities)
        )
    if len(capability_rows) < 22:
        errors.append(
            f"capability parity must contain at least 22 rows, got {len(capability_rows)}"
        )

    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    if not args.check:
        parser.error("--check is required; generation is intentionally explicit")

    root = pathlib.Path(__file__).resolve().parents[1]
    errors = check_committed_parity(root)
    if errors:
        for error in errors:
            print(f"F18_G0_PRODUCT_PARITY_ERROR {error}", file=sys.stderr)
        return 1
    print("F18_G0_PRODUCT_PARITY_PASS rows=217")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
