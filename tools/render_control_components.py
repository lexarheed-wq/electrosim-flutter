"""Build original Cycles product views for the remaining control devices.

Reference form factors were compared with Schneider RE22 star-delta timers,
Siemens S7-1200 PLCs and Omron M18 inductive sensors. The models below are
generic, original meshes; they do not reproduce logos or copy product photos.

Run from a macOS Terminal with Blender installed:
  /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/render_control_components.py
"""

import math
import os
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
OUT = Path(os.getenv("ELECTROSIM_CONTROL_RENDER_OUTPUT", ROOT / "apps/electrosim/assets/g5_control"))
OUT.mkdir(parents=True, exist_ok=True)

INK = (0.025, 0.04, 0.047, 1)
MAT = {}


def material(name, color, metallic=0.0, roughness=0.3):
    item = bpy.data.materials.new(name)
    item.diffuse_color = color
    item.use_nodes = True
    shader = item.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    MAT[name] = item
    return item


for args in [
    ("graphite", (0.065, 0.085, 0.095, 1), 0.12, 0.28),
    ("dark", (0.018, 0.029, 0.034, 1), 0.05, 0.34),
    ("light_gray", (0.72, 0.76, 0.75, 1), 0.18, 0.29),
    ("gray", (0.36, 0.42, 0.43, 1), 0.32, 0.27),
    ("steel", (0.72, 0.78, 0.79, 1), 0.82, 0.19),
    ("brass", (0.62, 0.39, 0.12, 1), 0.75, 0.23),
    ("yellow", (0.92, 0.61, 0.06, 1), 0.04, 0.27),
    ("blue", (0.025, 0.18, 0.39, 1), 0.03, 0.25),
    ("green", (0.025, 0.68, 0.25, 1), 0.04, 0.2),
    ("red", (0.76, 0.045, 0.025, 1), 0.03, 0.21),
    ("white", (0.89, 0.91, 0.88, 1), 0.01, 0.3),
    ("glass", (0.47, 0.71, 0.76, 1), 0.2, 0.1),
]:
    material(*args)


def finish(obj, mat, bevel=0.018):
    obj.data.materials.append(MAT[mat])
    if bevel and obj.type == "MESH":
        modifier = obj.modifiers.new("moulded edge radii", "BEVEL")
        modifier.width = bevel
        modifier.segments = 3
        obj.modifiers.new("weighted product normals", "WEIGHTED_NORMAL")
    return obj


def box(name, location, dimensions, mat, bevel=0.018):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, mat, bevel)


def cylinder(name, location, radius, depth, mat, axis="Y", vertices=48):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices, radius=radius, depth=depth, location=location
    )
    obj = bpy.context.object
    obj.name = name
    if axis == "Y":
        obj.rotation_euler[0] = math.pi / 2
    elif axis == "X":
        obj.rotation_euler[1] = math.pi / 2
    elif axis == "Z":
        obj.rotation_euler[2] = 0
    return finish(obj, mat, min(0.025, depth * 0.1))


def label(value, location, size=0.10, mat="white"):
    curve = bpy.data.curves.new("technical legend", "FONT")
    curve.body = value
    curve.size = size
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    obj = bpy.data.objects.new("moulded technical marking", curve)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler[0] = math.pi / 2
    curve.materials.append(MAT[mat])
    return obj


def screw(location, radius=0.065):
    x, y, z = location
    cylinder("terminal bezel", (x, y, z), radius * 1.35, 0.075, "dark")
    cylinder("nickel terminal screw", (x, y - 0.045, z), radius, 0.025, "steel")
    box("cross-head recess horizontal", (x, y - 0.061, z), (radius * 1.05, 0.008, radius * 0.12), "dark", 0.002)
    box("cross-head recess vertical", (x, y - 0.062, z), (radius * 0.12, 0.008, radius * 1.05), "dark", 0.002)


def led(location, color, lit=False):
    cylinder("LED bezel", location, 0.063, 0.07, "dark")
    x, y, z = location
    cap = cylinder("status lens", (x, y - 0.043, z), 0.039, 0.025, color if lit else "gray")
    if lit:
        mat = MAT[color]
        mat.node_tree.nodes.get("Principled BSDF").inputs["Emission Color"].default_value = mat.diffuse_color
        mat.node_tree.nodes.get("Principled BSDF").inputs["Emission Strength"].default_value = 0.25
    return cap


def dial(location, radius=0.22, caption="DELAY"):
    x, y, z = location
    cylinder("rotary bezel", (x, y, z), radius * 1.12, 0.10, "steel")
    cylinder("calibrated dial", (x, y - 0.06, z), radius, 0.055, "graphite")
    for index in range(9):
        theta = math.radians(-125 + index * 31)
        px = x + math.cos(theta) * radius * 0.78
        pz = z + math.sin(theta) * radius * 0.78
        box("engraved scale mark", (px, y - 0.092, pz), (0.012, 0.009, 0.042), "white", 0.002)
    pointer = box("dial pointer", (x, y - 0.105, z + radius * 0.30), (0.025, 0.014, radius * 0.70), "yellow", 0.004)
    pointer.rotation_euler[1] = -0.28
    label(caption, (x, y - 0.11, z - radius * 1.45), 0.07, "white")


def build_timer():
    box("star delta timer enclosure", (0, 0, 0), (0.78, 0.58, 1.72), "graphite", 0.07)
    box("front bezel", (0, -0.302, 0.03), (0.65, 0.045, 1.56), "dark", 0.045)
    box("legend panel", (0, -0.331, 0.55), (0.52, 0.018, 0.40), "gray", 0.015)
    label("STAR / DELTA", (0, -0.348, 0.69), 0.085)
    label("TIME RELAY", (0, -0.348, 0.51), 0.062)
    dial((0, -0.36, 0.05), 0.20, "DELAY")
    led((-0.19, -0.365, -0.48), "green")
    led((0, -0.365, -0.48), "yellow")
    led((0.19, -0.365, -0.48), "green")
    label("U", (-0.19, -0.372, -0.61), 0.055)
    label("Y", (0, -0.372, -0.61), 0.055)
    label("Δ", (0.19, -0.372, -0.61), 0.055)
    for i, (x, z, text) in enumerate([
        (-0.22, 0.78, "A1"), (0.22, 0.78, "A2"),
        (-0.22, -0.76, "15"), (0, -0.76, "16"), (0.22, -0.76, "18"),
    ]):
        screw((x, -0.345, z), 0.052)
        label(text, (x, -0.355, z + (0.09 if z < 0 else -0.09)), 0.055, "white")


def build_plc(dc=False):
    color = "light_gray" if dc else "gray"
    box("PLC DIN rail enclosure", (0, 0, 0), (2.05, 0.62, 1.66), color, 0.075)
    box("front fascia", (0, -0.32, 0), (1.91, 0.055, 1.49), "light_gray", 0.055)
    box("communications recess", (-0.62, -0.36, 0.02), (0.42, 0.04, 0.86), "dark", 0.035)
    box("ethernet port", (-0.62, -0.39, 0.12), (0.27, 0.025, 0.20), "graphite", 0.018)
    for i in range(8):
        box("RJ45 gold contact", (-0.72 + i * 0.028, -0.407, 0.12), (0.009, 0.008, 0.085), "brass", 0.002)
    label("ETHERNET", (-0.62, -0.385, -0.12), 0.055, "white")
    box("CPU display", (0.0, -0.36, 0.18), (0.62, 0.035, 0.47), "graphite", 0.035)
    box("LCD glass", (0.0, -0.382, 0.19), (0.51, 0.018, 0.32), "glass", 0.018)
    label("PLC 24 V CC" if dc else "PLC AC3", (0.0, -0.40, -0.17), 0.105, "white")
    label("LADDER · I/O", (0.0, -0.40, -0.32), 0.060, "white")
    # Terminal bank sits in the same upper/lower arrangement as ElectroSim's
    # interactive PLC model. The Flutter layer will own state and hit targets.
    for i, x in enumerate([-0.72, -0.43, -0.14, 0.15, 0.44, 0.73]):
        screw((x, -0.40, 0.68), 0.057)
        label(["L+", "M", "I0", "I1", "I2", "I3"][i], (x, -0.408, 0.54), 0.048)
    for i, x in enumerate([-0.50, -0.17, 0.17, 0.50]):
        screw((x, -0.40, -0.66), 0.057)
        label(f"Q{i}", (x, -0.408, -0.52), 0.052)
    for i, (z, name, color) in enumerate([
        (0.27, "PWR", "green"), (0.05, "RUN", "green"), (-0.17, "ERR", "red")
    ]):
        led((0.70, -0.39, z), color)
        label(name, (0.70, -0.41, z - 0.095), 0.043, "white")


def build_interlock(active_side="none"):
    box("interlock molded housing", (0, 0, 0), (1.75, 0.70, 0.66), "light_gray", 0.09)
    for x in [-0.94, 0.94]:
        box("contactor mounting ear", (x, 0.0, 0.0), (0.20, 0.77, 0.82), "steel", 0.035)
        cylinder("mounting screw", (x, -0.40, 0.0), 0.075, 0.035, "dark")
        box("screw slot", (x, -0.422, 0.0), (0.08, 0.008, 0.012), "steel", 0.002)
    box("sliding bridge track", (0, -0.37, 0), (1.14, 0.10, 0.37), "dark", 0.045)
    slider_x = -0.32 if active_side == "a" else 0.32 if active_side == "b" else 0.0
    box("safety yellow locking slider", (slider_x, -0.44, 0), (0.48, 0.055, 0.25), "yellow", 0.035)
    box("slider grip", (slider_x, -0.48, 0), (0.055, 0.018, 0.19), "graphite", 0.012)
    label("MECHANICAL INTERLOCK", (0, -0.365, 0.24), 0.065, "dark")


def build_proximity_sensor(actuated=False):
    cylinder("M18 threaded sensor barrel", (0, 0, -0.03), 0.30, 1.05, "steel", "Z")
    cylinder("sensor nose", (0, -0.02, 0.54), 0.31, 0.20, "graphite", "Z")
    cylinder("sensing face", (0, -0.02, 0.65), 0.255, 0.035, "blue", "Z")
    for z in [-0.20, -0.06]:
        cylinder("M18 brass lock nut", (0, 0, z), 0.36, 0.09, "brass", "Z", 6)
    for i in range(8):
        z = -0.45 + i * 0.045
        cylinder("thread groove", (0, 0, z), 0.301, 0.012, "dark", "Z", 48)
    led((0.24, -0.20, -0.43), "green", lit=actuated)
    cylinder("cable gland", (0, 0, -0.61), 0.19, 0.18, "dark", "Z")
    cylinder("sensor cable", (0, 0, -0.97), 0.085, 0.60, "graphite", "Z")
    label("INDUCTIVE", (0, -0.306, 0.02), 0.060, "dark")
    label("24 V DC", (0, -0.306, -0.11), 0.052, "dark")


def build_limit_switch(normally_closed=False, actuated=False):
    box("limit switch alloy head", (0, 0, -0.02), (0.91, 0.60, 0.75), "steel", 0.075)
    box("terminal cover", (0, -0.32, -0.03), (0.74, 0.055, 0.56), "graphite", 0.05)
    label("LIMIT SWITCH", (0, -0.355, 0.12), 0.072, "white")
    label("NC · 21/22" if normally_closed else "NO · 13/14", (0, -0.355, -0.08), 0.060, "yellow")
    cylinder("actuator pivot", (0, -0.39, 0.39), 0.10, 0.12, "dark")
    lever = box("roller lever arm", (0.18, -0.40, 0.60), (0.48, 0.075, 0.045), "steel", 0.018)
    lever.rotation_euler[1] = -0.26 + (0.42 if actuated else 0.0)
    roller_x = 0.42 + (0.04 if actuated else 0.0)
    roller_z = 0.67 - (0.13 if actuated else 0.0)
    cylinder("roller wheel", (roller_x, -0.42, roller_z), 0.14, 0.13, "graphite", "Y")
    cylinder("roller steel tread", (roller_x, -0.495, roller_z), 0.105, 0.035, "steel", "Y")
    for x, name in [(-0.22, "21" if normally_closed else "13"), (0.22, "22" if normally_closed else "14")]:
        screw((x, -0.39, -0.38), 0.052)
        label(name, (x, -0.405, -0.49), 0.052, "white")


def setup_camera(view):
    scene = bpy.context.scene
    bpy.ops.object.camera_add(location=(3.8, -6.4, 2.8))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, 0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 2.8
    if view == "front":
        camera.location = (0, -8, 0.15)
        camera.rotation_euler = (Vector((0, 0, 0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
        camera.data.ortho_scale = 2.5
    scene.camera = camera


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def render(kind, view, builder, output_kind=None):
    clear_scene()
    builder()
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = int(os.getenv("ELECTROSIM_RENDER_SAMPLES", "40"))
    scene.cycles.use_denoising = os.getenv("ELECTROSIM_RENDER_DENOISE", "1") != "0"
    portrait = kind in {"timer-star-delta", "sensor-proximity", "limit-switch-no", "limit-switch-nc"}
    scene.render.resolution_x = 700 if portrait else 900
    scene.render.resolution_y = 900 if portrait else 700
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "AgX"
    for name, location, power, size in [
        ("key", (4, -5, 6), 950, 4),
        ("fill", (-4, -4, 2), 650, 4),
        ("rim", (2, 4, 5), 1100, 3),
    ]:
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.name = name
        light.data.energy = power
        light.data.shape = "DISK"
        light.data.size = size
        light.rotation_euler = (Vector((0, 0, 0)) - light.location).to_track_quat("-Z", "Y").to_euler()
    setup_camera(view)
    scene.render.filepath = str(OUT / f"{output_kind or kind}-{view}.png")
    bpy.ops.render.render(write_still=True)


COMPONENTS = {
    "timer-star-delta": build_timer,
    "plc-ac3": lambda: build_plc(False),
    "plc-dc": lambda: build_plc(True),
    "mechanical-interlock-ac3": build_interlock,
    "sensor-proximity": build_proximity_sensor,
    "limit-switch-no": lambda: build_limit_switch(False),
    "limit-switch-nc": lambda: build_limit_switch(True),
}

requested = os.getenv("ELECTROSIM_CONTROL_KINDS")
kinds = requested.split(",") if requested else list(COMPONENTS)
unknown = set(kinds) - set(COMPONENTS)
if unknown:
    raise ValueError(f"Unknown control models: {sorted(unknown)}")

for kind in kinds:
    print(f"Rendering {kind}: palette and front", flush=True)
    render(kind, "palette", COMPONENTS[kind])
    render(kind, "front", COMPONENTS[kind])

STATE_VARIANTS = {
    "sensor-proximity": lambda: build_proximity_sensor(actuated=True),
    "limit-switch-no": lambda: build_limit_switch(False, actuated=True),
    "limit-switch-nc": lambda: build_limit_switch(True, actuated=True),
}
for kind, builder in STATE_VARIANTS.items():
    if kind in kinds:
        print(f"Rendering {kind} actuated state: palette and front", flush=True)
        render(kind, "palette", builder, output_kind=f"{kind}-actuated")
        render(kind, "front", builder, output_kind=f"{kind}-actuated")

for side in ("a", "b"):
    if "mechanical-interlock-ac3" in kinds:
        print(f"Rendering mechanical interlock side {side.upper()}: palette and front", flush=True)
        builder = lambda side=side: build_interlock(active_side=side)
        render("mechanical-interlock-ac3", "palette", builder, output_kind=f"mechanical-interlock-ac3-active-{side}")
        render("mechanical-interlock-ac3", "front", builder, output_kind=f"mechanical-interlock-ac3-active-{side}")
