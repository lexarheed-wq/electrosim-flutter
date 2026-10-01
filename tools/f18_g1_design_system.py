#!/usr/bin/env python3
import argparse, json, pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MAPPING = ROOT / "docs/f18/g1/F18_G1_TOKEN_MAPPING.json"

REQUIRED_COMPONENTS = 24
REQUIRED_ARCHETYPES = 8
REQUIRED_REFERENCES = {
    "Reference/Home/Desktop": (1440, 900),
    "Reference/Workspace/Desktop": (1440, 900),
    "Reference/Workspace/Compact": (390, 844),
    "Reference/Troubleshooting/Student": (820, 1180),
}
PROTECTED_PREFIXES = (
    "apps/electrosim/lib/",
    "packages/electrosim_domain/",
    "packages/electrosim_topology/",
    "packages/electrosim_solver_dc/",
    "packages/electrosim_solver_ac/",
    "packages/electrosim_pv/",
    "packages/electrosim_energy/",
    "packages/electrosim_measurements/",
    "packages/electrosim_diagnostics/",
    "packages/electrosim_tp/",
    "packages/electrosim_storage/",
)

def load_mapping(root: pathlib.Path = ROOT):
    return json.loads((root / "docs/f18/g1/F18_G1_TOKEN_MAPPING.json").read_text())

def validate_mapping(mapping):
    errors = []
    if mapping.get("schemaVersion") != 1: errors.append("schemaVersion")
    if mapping.get("source", {}).get("kind") != "magicpath": errors.append("source.kind")
    if not mapping.get("approval", {}).get("humanVisualApproved"): errors.append("approval")
    if len(mapping.get("components", {}).get("fundamental", [])) != REQUIRED_COMPONENTS: errors.append("components")
    if len(mapping.get("electrical", {}).get("archetypes", [])) != REQUIRED_ARCHETYPES: errors.append("archetypes")
    refs = mapping.get("references", [])
    if len(refs) != 4: errors.append("references.count")
    for ref in refs:
        expected = REQUIRED_REFERENCES.get(ref.get("name"))
        if expected is None or (ref.get("width"), ref.get("height")) != expected:
            errors.append("reference:" + str(ref.get("name")))
        if not ref.get("componentId") or not ref.get("revisionId"):
            errors.append("reference-id:" + str(ref.get("name")))
    ui = mapping.get("tokens", {}).get("uiColors", {})
    for key in ("primary","onPrimary","background","surface","outline","textPrimary","textSecondary","focus"):
        if not ui.get(key): errors.append("uiColor:" + key)
    if mapping.get("tokens", {}).get("geometry", {}).get("minimumTouchTarget", 0) < 48:
        errors.append("minimumTouchTarget")
    if len(mapping.get("tokens", {}).get("typography", {})) != 16:
        errors.append("typography")
    if not any(x.get("id") == "platform-font-family" and x.get("reason") for x in mapping.get("exceptions", [])):
        errors.append("platform-font-family")
    return errors

def _linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def contrast_ratio(foreground_hex, background_hex):
    def lum(value):
        value = value.lstrip("#")
        r,g,b = (int(value[i:i+2],16) for i in (0,2,4))
        return 0.2126*_linear(r)+0.7152*_linear(g)+0.0722*_linear(b)
    a,b = lum(foreground_hex), lum(background_hex)
    hi,lo = max(a,b), min(a,b)
    return (hi+0.05)/(lo+0.05)

def find_forbidden_g1_changes(paths):
    return sorted(p for p in paths if p.startswith(PROTECTED_PREFIXES))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--base-sha")
    args = parser.parse_args()
    mapping = load_mapping()
    errors = validate_mapping(mapping)
    ui = mapping["tokens"]["uiColors"]
    checks = [
        ("textPrimary/surface", ui["textPrimary"], ui["surface"], 4.5),
        ("onPrimary/primary", ui["onPrimary"], ui["primary"], 4.5),
        ("textSecondary/surface", ui["textSecondary"], ui["surface"], 4.5),
    ]
    for name,fg,bg,minimum in checks:
        ratio = contrast_ratio(fg,bg)
        if ratio < minimum: errors.append(f"contrast:{name}:{ratio:.2f}")
    if args.base_sha:
        completed = subprocess.run(
            ["git", "diff", "--name-only", f"{args.base_sha}...HEAD"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
        changed = [line for line in completed.stdout.splitlines() if line]
        forbidden = find_forbidden_g1_changes(changed)
        if forbidden:
            errors.extend("forbidden-change:" + path for path in forbidden)
    if errors:
        print("F18_G1_TOKEN_MAPPING_FAIL")
        for error in errors: print(error)
        return 1
    print("F18_G1_TOKEN_MAPPING_PASS")
    print("source=magicpath components=24 archetypes=8 references=4 typography=16")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
