#!/usr/bin/env python3
"""Guard against accidental changes to the 26 pending G5 visual contracts.

Run: python3 tools/g5_remaining_3d_contract_guard.py
This checks catalogue identity ONLY; it does not qualify rendered 3D artwork,
probe behaviour, electrical results or actual physical connector positions.
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / 'apps/electrosim/lib/f9_component_palette.dart'
DEFAULT_MANIFEST = ROOT / 'tools/g5_remaining_3d_contracts.json'


def catalogue_entries(source):
    """Extract top-level Dart palette entries rather than nested constructors."""
    blocks = re.findall(r'(?ms)^  F9PaletteDefinition\((.*?)^  \),', source)
    result = {}
    for block in blocks:
        match = re.search(r"\bkeyName:\s*'([^']+)'", block)
        if match:
            key = match.group(1)
            if key in result:
                raise ValueError(f'duplicate palette key: {key}')
            result[key] = block
    return result


def quoted_field(block, name):
    match = re.search(rf"\b{re.escape(name)}:\s*'([^']+)'", block)
    return match.group(1) if match else None


def terminal_labels(block):
    match = re.search(r'\bterminalLabels:\s*<String>\s*\[([^]]*)\]', block)
    if not match:
        raise ValueError('unreadable terminalLabels declaration')
    return re.findall(r"'([^']+)'", match.group(1))


def validate(source, manifest):
    errors = []
    entries = catalogue_entries(source)
    items = manifest['items']
    keys = [item['key'] for item in items]
    if len(keys) != 26 or len(set(keys)) != 26:
        errors.append('manifest must contain 26 distinct keys')
    routes = {}
    for item in items:
        key = item['key']
        block = entries.get(key)
        if block is None:
            errors.append(f'{key}: absent from F9 palette')
            continue
        model = quoted_field(block, 'modelType')
        visual = quoted_field(block, 'visualModelType') or model
        variant = quoted_field(block, 'visualVariant')
        kind = re.search(r'\bkind:\s*F9PaletteElementKind\.(\w+)', block)
        actual = {
            'electrical_model': model, 'visual_model': visual,
            'variant': variant, 'kind': kind.group(1) if kind else None
        }
        for field, value in actual.items():
            if value != item[field]:
                errors.append(f'{key}: {field} expected {item[field]!r}, found {value!r}')
        try:
            terminals = terminal_labels(block)
        except ValueError as exc:
            errors.append(f'{key}: {exc}')
            continue
        if terminals != item['terminals']:
            errors.append(f'{key}: terminal labels/order changed: {terminals!r}')
        if item['probe_based'] != (item['kind'] == 'instrument'):
            errors.append(f'{key}: inconsistent probe contract')
        if item['probe_based'] and terminals:
            errors.append(f'{key}: instrument requires probes, not component TerminalIds')
        # The AC and DC pumps deliberately share the old visual 'pump' key.
        # Include electrical_model to distinguish future 3D replacements.
        route = (visual, model, variant)
        if route in routes and routes[route] != key:
            errors.append(f'{key}: duplicate visual route {route!r} (also {routes[route]})')
        routes[route] = key
    return errors


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=DEFAULT_SOURCE)
    parser.add_argument('--manifest', type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args(argv)
    try:
        source = args.source.read_text(encoding='utf-8')
        manifest = json.loads(args.manifest.read_text(encoding='utf-8'))
        errors = validate(source, manifest)
    except (OSError, ValueError, KeyError, TypeError) as exc:
        errors = [str(exc)]
    if args.json:
        print(json.dumps({'pass': not errors, 'checked': 26, 'errors': errors},
                         ensure_ascii=False, indent=2))
    elif errors:
        print('G5 3D CONTRACT GUARD FAIL:\n' + '\n'.join('- ' + s for s in errors))
    else:
        print('G5 3D CONTRACT GUARD PASS: 26 catalogue identities preserved;'
              ' renders/physics still unqualified')
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
