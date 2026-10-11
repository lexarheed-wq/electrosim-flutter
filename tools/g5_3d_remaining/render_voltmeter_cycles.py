"""Real Cycles PREVIEW of the G5 draft voltmeter mesh, not an ElectroSim capture.

Run: blender -b --factory-startup -t 4 --python
tools/g5_3d_remaining/render_voltmeter_cycles.py -- --out build/g5-3d-voltmeter
"""
import argparse
import hashlib
import importlib
import json
import math
import sys
import time
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from instrument_voltmeter_recipe import build as voltmeter_build, KEY as VOLT_KEY, SIZE as VOLT_SIZE


class CyclesGeometry:
    def __init__(self):
        self.yellow = self.material('impact sleeve yellow', (.94, .64, .025))
        self.black = self.material('matte graphite', (.045, .052, .055))
        self.well = self.material('socket depth', (.006, .007, .008))
        self.steel = self.material('satin aluminium', (.53, .57, .61), .8)
        self.glass = self.material('neutral LCD acrylic', (.65, .77, .69), .07)
        self.terminal_gray = self.material('control rubber', (.24, .28, .30))
        self.red = self.material('insulated V jack', (.71, .027, .037))
        self.brass = self.material('socket inner metal', (.59, .41, .12), .82)

    @staticmethod
    def material(name, rgb, metallic=0):
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        node = mat.node_tree.nodes.get('Principled BSDF')
        node.inputs['Base Color'].default_value = (*rgb, 1)
        node.inputs['Roughness'].default_value = .28 if metallic else .42
        node.inputs['Metallic'].default_value = metallic
        return mat

    @staticmethod
    def _finish(obj, name, material, bevel=0):
        obj.name = name
        obj.data.materials.append(material)
        if bevel:
            modifier = obj.modifiers.new('actual moulded corner radius', 'BEVEL')
            modifier.width = bevel
            modifier.segments = 4
        return obj

    def box(self, name, x, y, width, height, z, depth, material, r=0):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x, -y, z - depth / 2))
        obj = bpy.context.object
        obj.dimensions = (width, height, depth)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        return self._finish(obj, name, material, r)

    def cyl(self, name, x, y, z, radius, depth, material):
        bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=radius, depth=depth,
                                            location=(x, -y, z - depth / 2))
        return self._finish(bpy.context.object, name, material, min(.18, depth * .12))

    @staticmethod
    def cut(obj, cutter):
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        mod = obj.modifiers.new('physical socket bore', 'BOOLEAN')
        mod.operation = 'DIFFERENCE'
        mod.object = cutter
        while obj.modifiers.find(mod.name) > 0:
            bpy.ops.object.modifier_move_up(modifier=mod.name)
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(cutter, do_unlink=True)


def raised_legend(name, value, x, y, z, size, material):
    # Genuine Blender 3D letters shared by front and 3/4 Cycles renders.
    # Never burn runtime measurement values into the LCD.
    font = bpy.data.curves.new(name, 'FONT')
    font.body = value
    font.align_x = 'CENTER'
    font.align_y = 'CENTER'
    font.size = size
    font.extrude = 0.025
    font.bevel_depth = 0.008
    obj = bpy.data.objects.new(name, font)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = (x, -y, z)
    obj.data.materials.append(material)
    return obj


def area(name, location, power, size):
    data = bpy.data.lights.new(name, 'AREA')
    data.energy = power
    data.shape = 'DISK'
    data.size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location


def main():
    argv = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', required=True)
    parser.add_argument('--component', choices=['instrument-voltmeter', 'instrument-ammeter'], default='instrument-voltmeter')
    parser.add_argument('--samples', type=int, default=64)
    opts = parser.parse_args(argv)
    assert 16 <= opts.samples <= 256
    recipe_name = 'instrument_ammeter_recipe' if opts.component == 'instrument-ammeter' else 'instrument_voltmeter_recipe'
    recipe_module = importlib.import_module(recipe_name)
    build = recipe_module.build
    KEY = recipe_module.KEY
    SIZE = recipe_module.SIZE
    out = Path(opts.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = opts.samples
    # Ubuntu apt Blender builds can be compiled without OpenImageDenoiser.
    scene.cycles.use_denoising = False
    for layer in scene.view_layers:
        if hasattr(layer, 'cycles'):
            layer.cycles.use_denoising = False
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.resolution_percentage = 100
    # Render at four times the previous texture dimensions. Logical canvas
    # and solver contracts stay unchanged: 1120x1520 texture on 112x152 box.
    scene.render.resolution_x = round(SIZE[0] * 10)
    scene.render.resolution_y = round(SIZE[1] * 10)
    scene.world.color = (.36, .40, .45)

    h = CyclesGeometry()
    build(h, {'kind': 'draft_preview', 'key': KEY, 'size': SIZE})
    body_d = SIZE[1] - 4.0
    body_d *= 46.0 / 167.0
    # Permanent *function* labels; dynamic mode/range/reading remain Flutter.
    for name, value, x, size, material in (
            ('function-hold', 'HOLD', 35, 2.45, h.steel),
            ('function-range', 'RANGE', 49, 2.30, h.steel),
            ('function-select', 'SELECT', 63, 2.12, h.steel),
            ('function-light', 'LIGHT', 77, 2.45, h.black)):
        raised_legend(name, value, x, 56.0, body_d + 9.12, size, material)
    raised_legend('socket-com-label', 'COM', 42, 116.0, body_d + 9.1,
                  3.6, h.steel)
    raised_legend('socket-voltage-label', 'A' if KEY == 'instrument-ammeter' else 'V/Ohm',
                  70, 116.0, body_d + 9.1, 3.4, h.steel)
    # Small moulded reference rivets and tactile relief, not extra terminals.
    for i, x in enumerate((28, 84)):
        h.cyl(f'casing-fastener-{i}', x, 137, body_d + 5.0,
              1.6, 0.8, h.steel)
    for i in range(5):
        h.box(f'grip-rib-{i}', 53, 80 + i * 5.0,
              6.2, 0.9, body_d + 15.6, 0.8, h.steel, r=0.35)
    area('diffused studio left', (-70, 60, 190), 100000, 150)
    area('diffused studio right', (190, -60, 170), 75000, 100)
    area('soft rim reflection', (48, -130, 120), 45000, 130)

    data = bpy.data.cameras.new('orthographic geometry camera')
    data.type = 'ORTHO'
    data.clip_end = 2000
    cam = bpy.data.objects.new('orthographic geometry camera', data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    t0 = time.monotonic()
    w, height = SIZE
    for view, yaw, pitch, scale in (('front', 0, 0, 1),
                                    ('palette', -24, -16, .78)):
        # Front selector grip is a real moving UI part. Keep it OUT of the
        # baked front PNG; show it fixed only in the static 3/4 palette image.
        selector = bpy.data.objects.get('selector_grip')
        if selector is None:
            raise RuntimeError('Missing selector_grip 3D object')
        selector.hide_render = view == 'front'
        cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
        cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
        right = Vector((cy, 0, sy))
        up = Vector((-sp * sy, cp, sp * cy))
        back = Vector((-cp * sy, -sp, cp * cy))
        cam.rotation_euler = Matrix((right, up, back)).transposed().to_euler()
        cam.location = Vector((w / 2, -height / 2, 0)) + back * 600
        data.ortho_scale = max(w, height) / scale
        scene.render.filepath = str(out / (view + '.png'))
        bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(out / 'draft.blend'))
    recipe = Path(__file__).with_name(recipe_name + '.py')
    (out / 'provenance.json').write_text(json.dumps({
        'key': KEY, 'blender_version': bpy.app.version_string,
        'sha256_recipe': hashlib.sha256(recipe.read_bytes()).hexdigest(),
        'sha256_render_runner': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'seconds': round(time.monotonic() - t0, 2),
        'is_product_capture': False, 'integrated_in_flutter': False,
        'qualification': 'draft_preview_only'}, indent=2) + '\n')


if __name__ == '__main__':
    main()
