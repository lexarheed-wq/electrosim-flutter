"""Read the unified app manifest as the source of geometry for G5 models."""

import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "apps/electrosim/assets/g5_industrial/geometry.unified.json"
CONTRACT_ROOT = Path(__file__).resolve().parent
LOT_CONTRACTS = {
    "06_15": CONTRACT_ROOT / "lot_06_15_contract.json",
    "16_26": CONTRACT_ROOT / "lot_16_26_contract.json",
    "sockets": CONTRACT_ROOT / "lot_sockets_contract.json",
}
GEOMETRY_FIELDS = {
    "visual",
    "variant",
    "size",
    "board",
    "ports",
    "box",
}
SIDECAR_FIELDS = {"kind", "terminal_z", "terminal_scale"}
NATIVE_FIELDS = (
    "type",
    "variant",
    "size",
    "board_size",
    "ports",
    "service_box",
    "three_phase",
)


def load_manifest(path=MANIFEST_PATH):
    """Load a supported manifest and reject incomplete document structure."""
    document = json.loads(Path(path).read_text())
    if (
        not isinstance(document, dict)
        or isinstance(document.get("schema_version"), bool)
        or document.get("schema_version") != 1
    ):
        version = document.get("schema_version") if isinstance(document, dict) else None
        raise ValueError(f"Unsupported unified geometry schema version: {version}")
    components = document.get("components")
    if not isinstance(components, dict):
        raise ValueError("Unified geometry manifest must contain a components map")
    return document


def _finite_number(value, description):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"{description} must be a number")
    if not math.isfinite(value):
        raise ValueError(f"{description} must be finite")
    return value


def _pair(value, description):
    if not isinstance(value, list) or len(value) != 2:
        raise ValueError(f"{description} must contain exactly two numbers")
    return tuple(
        _finite_number(item, f"{description}[{index}]")
        for index, item in enumerate(value)
    )


def _points(value, description):
    if not isinstance(value, list):
        raise ValueError(f"{description} must be a list of x/y points")
    points = []
    for index, point in enumerate(value):
        x, y = _pair(point, f"{description}[{index}]")
        points.append((x, y))
    return points


def _component(document, key):
    components = document.get("components")
    if not isinstance(components, dict):
        raise ValueError("Unified geometry manifest must contain a components map")
    component = components.get(key)
    if not isinstance(component, dict) or component.get("status") != "complete":
        raise ValueError(f"Manifest has no complete geometry for {key}")
    return component


def _native_spec(component, key):
    if not isinstance(component, dict):
        raise ValueError(f"{key} geometry must be a map")
    missing = [field for field in NATIVE_FIELDS if field not in component]
    if missing:
        raise ValueError(f"{key} is missing native geometry fields: {missing}")
    width, height = _pair(component["size"], f"{key}.size")
    for index, dimension in enumerate((width, height)):
        if dimension <= 0:
            raise ValueError(f"{key}.size[{index}] must be positive")
    board_width, board_height = _pair(component["board_size"], f"{key}.board_size")
    for index, dimension in enumerate((board_width, board_height)):
        if dimension <= 0:
            raise ValueError(f"{key}.board_size[{index}] must be positive")
    if not isinstance(component["ports"], list) or not component["ports"]:
        raise ValueError(f"{key}.ports must contain at least one point")
    for index, (x, y) in enumerate(_points(component["ports"], f"{key}.ports")):
        if x < 0 or y < 0 or x > width or y > height:
            raise ValueError(f"{key}.ports[{index}] lies outside the component")
    box = component["service_box"]
    if not isinstance(box, list) or len(box) != 4:
        raise ValueError(f"{key}.service_box must contain x, y, width and height")
    x, y, box_width, box_height = tuple(
        _finite_number(value, f"{key}.service_box[{index}]")
        for index, value in enumerate(box)
    )
    if x < 0 or y < 0:
        raise ValueError(f"{key}.service_box origin cannot be negative")
    if box_width <= 0 or box_height <= 0:
        raise ValueError(f"{key}.service_box dimensions must be positive")
    if x + box_width > width or y + box_height > height:
        raise ValueError(f"{key}.service_box lies outside the component frame")
    if not isinstance(component["type"], str) or not component["type"]:
        raise ValueError(f"{key}.type must be a non-empty string")
    if not isinstance(component["variant"], str) or not component["variant"]:
        raise ValueError(f"{key}.variant must be a non-empty string")
    if not isinstance(component["three_phase"], bool):
        raise ValueError(f"{key}.three_phase must be boolean")
    return {field: component[field] for field in NATIVE_FIELDS}


def native_catalogue_specs(document=None):
    """Return the manifest rows that use the synchronous native catalogue."""
    document = load_manifest() if document is None else document
    if not isinstance(document, dict) or not isinstance(document.get("components"), dict):
        raise ValueError("Unified geometry manifest must contain a components map")
    specs = {}
    for key, component in document["components"].items():
        if not isinstance(component, dict):
            raise ValueError(f"{key} geometry must be a map")
        if "board_size" not in component:
            continue
        if key in specs:
            raise ValueError(f"Duplicate native geometry key: {key}")
        _component(document, key)
        specs[key] = _native_spec(component, key)
    if len(specs) != 26:
        raise ValueError(f"Expected 26 native geometry rows, found {len(specs)}")
    return specs


def load_lot_contract(lot, manifest=None):
    """Merge render-only Blender settings with authoritative manifest geometry."""
    if lot not in LOT_CONTRACTS:
        raise ValueError(f"Unknown Blender geometry lot: {lot}")
    manifest = load_manifest() if manifest is None else manifest
    source = json.loads(LOT_CONTRACTS[lot].read_text())
    if not isinstance(source, dict):
        raise ValueError(f"Blender sidecar for {lot} must be a map")
    merged = {}
    for key, metadata in source.items():
        if not isinstance(metadata, dict):
            raise ValueError(f"Blender render metadata for {key} must be a map")
        duplicate_fields = GEOMETRY_FIELDS.intersection(metadata)
        if duplicate_fields:
            raise ValueError(
                f"{key} duplicates manifest geometry in Blender metadata: "
                f"{sorted(duplicate_fields)}"
            )
        unknown_fields = set(metadata).difference(SIDECAR_FIELDS)
        if unknown_fields:
            raise ValueError(f"{key} has unknown Blender metadata: {sorted(unknown_fields)}")
        if "kind" not in metadata or "terminal_z" not in metadata:
            raise ValueError(f"{key} must define render kind and terminal_z")
        if not isinstance(metadata["kind"], str) or not metadata["kind"]:
            raise ValueError(f"{key}.kind must be a non-empty string")
        component = _component(manifest, key)
        spec = _native_spec(component, key)
        x, y, width, height = spec["service_box"]
        terminal_z = _finite_number(metadata["terminal_z"], f"{key}.terminal_z")
        job = {
            "visual": spec["type"],
            "variant": spec["variant"],
            "size": spec["size"],
            "board": spec["board_size"],
            "ports": spec["ports"],
            "box": [x + width / 2, y + height / 2, width, height, terminal_z],
            "kind": metadata["kind"],
        }
        if "terminal_scale" in metadata:
            terminal_scale = _finite_number(
                metadata["terminal_scale"], f"{key}.terminal_scale"
            )
            if terminal_scale <= 0:
                raise ValueError(f"{key}.terminal_scale must be positive")
            job["terminal_scale"] = terminal_scale
        merged[key] = job
    return merged


def load_crusher_geometry(manifest=None):
    """Read the specialized crusher's terminal contract without inventing fields."""
    manifest = load_manifest() if manifest is None else manifest
    crusher = _component(manifest, "external-crusher")
    for field in ("size", "ports", "ports_7t_extra"):
        if field not in crusher:
            raise ValueError(f"external-crusher is missing {field}")
    width, height = _pair(crusher["size"], "external-crusher.size")
    for index, dimension in enumerate((width, height)):
        if dimension <= 0:
            raise ValueError(f"external-crusher.size[{index}] must be positive")
    ports = _points(crusher["ports"], "external-crusher.ports")
    extra_ports = _points(crusher["ports_7t_extra"], "external-crusher.ports_7t_extra")
    if not ports:
        raise ValueError("external-crusher.ports must contain at least one point")
    if not extra_ports:
        raise ValueError("external-crusher.ports_7t_extra must contain its PE point")
    for index, (x, y) in enumerate(ports + extra_ports):
        if not (0 <= x <= width and 0 <= y <= height):
            raise ValueError(f"external-crusher port {index} is outside its frame")
    return {
        "size": crusher["size"],
        "ports": crusher["ports"],
        "ports_7t_extra": crusher["ports_7t_extra"],
    }
