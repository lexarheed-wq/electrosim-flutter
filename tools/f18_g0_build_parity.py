#!/usr/bin/env python3
import re


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
