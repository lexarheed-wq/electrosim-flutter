"""Render ONE G5 component locally, with PNG-only outputs and identity checks.

Examples:
  python tools/g5_3d_remaining/render_one.py --component instrument-ammeter
  python tools/g5_3d_remaining/render_one.py --component instrument-voltmeter

This does not merge, trigger GitHub Actions, or qualify Mac/Chromium. Rendering
requires a locally installed Blender with Cycles. Never invent fallback PNGs.
"""
import argparse
import hashlib
import json
import shutil
import struct
import subprocess
import sys
from pathlib import Path

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[1]
SUPPORTED = ('instrument-voltmeter', 'instrument-ammeter')
PNG_MAGIC = b'\x89PNG\r\n\x1a\n'
EXPECTED_SIZE = (1120, 1520)


def png_dimensions(path):
    with Path(path).open('rb') as source:
        chunk = source.read(24)
    if len(chunk) != 24 or not chunk.startswith(PNG_MAGIC) or chunk[12:16] != b'IHDR':
        raise ValueError(f'{path}: invalid PNG signature or IHDR')
    return struct.unpack('>II', chunk[16:24])


def verify_assets(folder, component):
    folder = Path(folder)
    front = folder / 'front.png'
    palette = folder / 'palette.png'
    for output in (front, palette):
        if not output.is_file():
            raise FileNotFoundError(output)
        if png_dimensions(output) != EXPECTED_SIZE:
            raise ValueError(f'{output}: expected {EXPECTED_SIZE} PNG texture')
    prov = folder / 'provenance.json'
    record = json.loads(prov.read_text())
    if record.get('key') != component:
        raise ValueError(f"wrong original model identity: {record.get('key')}")
    recipe = BASE / ('instrument_ammeter_recipe.py' if component == 'instrument-ammeter'
                      else 'instrument_voltmeter_recipe.py')
    current_sha = hashlib.sha256(recipe.read_bytes()).hexdigest()
    if record.get('sha256_recipe') != current_sha:
        raise ValueError('image provenance SHA does not match Blender recipe')
    manifest = {}
    for view in (front, palette):
        manifest[view.name] = {
            'size': list(png_dimensions(view)),
            'sha256': hashlib.sha256(view.read_bytes()).hexdigest(),
        }
    (folder / 'PNG_PROVENANCE.json').write_text(
        json.dumps({'key': component, 'verified_render': True,
                    'flutter_qualification': False, 'images': manifest},
                   ensure_ascii=False, indent=2) + '\n')
    return front, palette


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--component', required=True, choices=SUPPORTED)
    parser.add_argument('--output-root', default='build/g5_sequential')
    parser.add_argument('--blender', default=None)
    parser.add_argument('--samples', type=int, default=96)
    parser.add_argument('--verify-existing', action='store_true')
    args = parser.parse_args()
    folder = Path(args.output_root) / args.component
    if args.verify_existing:
        verify_assets(folder, args.component)
    else:
        blender = args.blender or shutil.which('blender')
        if not blender:
            print('Blender absent locally; no PNG has been fabricated.', file=sys.stderr)
            return 2
        if not 16 <= args.samples <= 256:
            parser.error('--samples must be 16..256')
        runner = BASE / 'render_voltmeter_cycles.py'
        subprocess.run([
            blender, '-b', '--factory-startup', '-t', '4', '--python', str(runner),
            '--', '--out', str(folder), '--component', args.component,
            '--samples', str(args.samples),
        ], cwd=ROOT, check=True)
        verify_assets(folder, args.component)
    print(f'Original front Cycles PNG: {folder / "front.png"}')
    print(f'Original 3/4 Cycles PNG: {folder / "palette.png"}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
