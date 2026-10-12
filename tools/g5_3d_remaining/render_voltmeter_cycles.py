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
    def material(name, rgb, metallic=0, roughness=None, coat=0, anisotropic=0):
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        node = mat.node_tree.nodes.get('Principled BSDF')
        node.inputs['Base Color'].default_value = (*rgb, 1)
        node.inputs['Roughness'].default_value = roughness if roughness is not None else (.28 if metallic else .42)
        node.inputs['Metallic'].default_value = metallic
        node.inputs['Coat Weight'].default_value = coat
        node.inputs['Coat Roughness'].default_value = .2
        node.inputs['Anisotropic'].default_value = anisotropic
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

    def panel(self, name, points, material, thickness):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([(x,-y,z) for x,y,z in points],[],[tuple(range(len(points)))])
        mesh.update()
        obj = bpy.data.objects.new(name,mesh)
        bpy.context.scene.collection.objects.link(obj)
        solid = obj.modifiers.new('sheet thickness','SOLIDIFY')
        solid.thickness = thickness
        return self._finish(obj,name,material,.5)

    def tube(self, name, points, radius, material):
        """Physical cable/conduit mesh, using coordinates of the recipe."""
        curve = bpy.data.curves.new(name, 'CURVE')
        curve.dimensions = '3D'
        curve.resolution_u = 16
        curve.bevel_depth = radius
        curve.bevel_resolution = 4
        spline = curve.splines.new('BEZIER')
        spline.bezier_points.add(len(points)-1)
        for point, (x,y,z) in zip(spline.bezier_points, points):
            point.co = (x,-y,z)
            point.handle_left_type = 'AUTO'
            point.handle_right_type = 'AUTO'
        obj = bpy.data.objects.new(name,curve)
        bpy.context.scene.collection.objects.link(obj)
        obj.data.materials.append(material)
        return obj

    def domed_panel(self, name, points, material, thickness, bulge):
        """Closed pressed cover with a gently convex face for studio reflections."""
        count = len(points)
        cx = sum(p[0] for p in points)/count
        cy = sum(p[1] for p in points)/count
        z = points[0][2]
        vertices=[]
        for scale in (1,.85,.65,.4,.15):
            vertices.extend((cx+(x-cx)*scale,-(cy+(y-cy)*scale),
                             z+bulge*(1-scale*scale)) for x,y,_ in points)
        center = len(vertices)
        vertices.append((cx,-cy,z+bulge))
        rear = len(vertices)
        vertices.extend((x,-y,z-thickness) for x,y,_ in points)
        faces=[]
        for ring in range(4):
            for i in range(count):
                j=(i+1)%count
                faces.append((ring*count+i,ring*count+j,(ring+1)*count+j,(ring+1)*count+i))
        for i in range(count):
            j=(i+1)%count
            faces.append((4*count+i,4*count+j,center))
            faces.append((j,i,rear+i,rear+j))
        faces.append(tuple(reversed(range(rear,rear+count))))
        mesh=bpy.data.meshes.new(name)
        mesh.from_pydata(vertices,[],faces)
        mesh.update()
        obj=bpy.data.objects.new(name,mesh)
        bpy.context.scene.collection.objects.link(obj)
        for polygon in mesh.polygons:
            polygon.use_smooth = len(polygon.vertices) < count
        return self._finish(obj,name,material)

    def bolt(self, name, x, y, z, radius, material):
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=radius,
            depth=radius*.6, location=(x,-y,z-radius*.3))
        return self._finish(bpy.context.object,name,material,.12)

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
    return obj


def studio_softbox(name, location, power, width, height):
    obj = area(name,location,power,width)
    obj.data.shape = 'RECTANGLE'
    obj.data.size_y = height
    direction = Vector((110,-110,40))-obj.location
    obj.rotation_euler = direction.to_track_quat('-Z','Y').to_euler()


def main():
    argv = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', required=True)
    parser.add_argument('--component', choices=['instrument-voltmeter', 'instrument-ammeter', 'instrument-frequency', 'instrument-phase-sequence', 'external-crusher'], default='instrument-voltmeter')
    parser.add_argument('--samples', type=int, default=64)
    parser.add_argument('--denoise', action='store_true')
    parser.add_argument('--service-open', action='store_true')
    opts = parser.parse_args(argv)
    assert 16 <= opts.samples <= 256
    recipe_name = opts.component.replace('-', '_') + '_recipe'
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
    scene.cycles.use_denoising = opts.denoise
    if opts.denoise:
        scene.cycles.denoiser = 'OPENIMAGEDENOISE'
    for layer in scene.view_layers:
        if hasattr(layer, 'cycles'):
            layer.cycles.use_denoising = opts.denoise
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.resolution_percentage = 100
    # Render at four times the previous texture dimensions. Logical canvas
    # and solver contracts stay unchanged: 1120x1520 texture on 112x152 box.
    scene.render.resolution_x = round(SIZE[0] * getattr(recipe_module,'TEXTURE_SCALE',10))
    scene.render.resolution_y = round(SIZE[1] * getattr(recipe_module,'TEXTURE_SCALE',10))
    scene.world.color = (.36, .40, .45)

    h = CyclesGeometry()
    build(h, {'kind': 'draft_preview', 'key': KEY, 'size': SIZE,
              'service_open': opts.service_open})
    body_d = SIZE[1] - 4.0
    body_d *= 46.0 / 167.0
    if KEY == 'external-crusher':
        scene.view_settings.exposure = .25
        scene.world.use_nodes = True
        env = scene.world.node_tree.nodes.new('ShaderNodeTexEnvironment')
        env.image = bpy.data.images.load(str(Path(__file__).resolve().parents[1] / 'g5_render_environment/studio_small_09_1k.hdr'))
        background = scene.world.node_tree.nodes.get('Background')
        scene.world.node_tree.links.new(env.outputs['Color'],background.inputs['Color'])
        background.inputs['Strength'].default_value = .55
        for obj in bpy.data.objects:
            if obj.type == 'MESH':
                for modifier in obj.modifiers:
                    if modifier.type == 'BEVEL':
                        modifier.segments = 8
                        modifier.harden_normals = True
                normal = obj.modifiers.new('machined edge normals', 'WEIGHTED_NORMAL')
                normal.keep_sharp = True
        raised_legend('gap_scale_units', 'mm', 103, 130, 63, 2.2, h.black)
        for i in range(11):
            x = 88+i*2.5
            h.box('gap_scale_tick_'+str(i),x,134, .22, 2.5 if i%5==0 else 1.5,
                  63, .12, h.black)
    elif KEY == 'instrument-phase-sequence':
        scene.view_settings.look = 'AgX - Medium High Contrast'
        scene.view_settings.exposure = .65
        for obj in bpy.data.objects:
            if obj.type != 'MESH':
                continue
            for modifier in obj.modifiers:
                if modifier.type == 'BEVEL':
                    modifier.segments = 12
                    modifier.harden_normals = True
            normal = obj.modifiers.new('moulded surface normals', 'WEIGHTED_NORMAL')
            normal.keep_sharp = True
        for i, x in enumerate((34, 56, 78), 1):
            raised_legend(f'phase_input_{i}', f'L{i}', x, 24, 34, 5, h.steel)
        raised_legend('phase_function_title', 'PHASE ROTATION', 56, 41, 34, 3.6, h.steel)
    elif KEY == 'instrument-frequency':
        raised_legend('frequency_title', 'FREQUENCY', 56, 15, 37.2, 3.5, h.steel)
        raised_legend('frequency_units', 'Hz', 56, 62, 37.2, 7, h.steel)
        for name, x in [('HOLD', 35), ('ON/OFF', 56), ('LIGHT', 77)]:
            raised_legend('frequency_button_' + name, name, x, 78, 41.2, 2.4, h.steel)
        raised_legend('frequency_common', 'COM', 42, 116, 37.2, 3.5, h.steel)
        raised_legend('frequency_input', 'V/Hz', 70, 116, 37.2, 3.5, h.steel)
    else:
        # Permanent *function* labels; dynamic mode/range/reading remain Flutter.
        for name, value, x, size, material in (
                ('function-hold', 'HOLD', 35, 2.45, h.steel),
                ('function-range', 'RANGE', 49, 2.30, h.steel),
                ('function-select', 'SELECT', 63, 2.12, h.steel),
                ('function-light', 'LIGHT', 77, 2.45, h.black)):
            raised_legend(name, value, x, 56.0, body_d + 9.12, size, material)
        # On the ammeter, the physical fuse hatch covers y=110..118.
        # Move jack legends BELOW the bores so COM is not hidden behind the hatch.
        # The voltmeter has no hatch and preserves the original y=116 legends.
        jack_legend_y = 143.0 if KEY == 'instrument-ammeter' else 116.0
        raised_legend('socket-com-label', 'COM', 42, jack_legend_y,
                      body_d + 9.1, 3.6, h.steel)
        raised_legend(
            'socket-input-label',
            'A' if KEY == 'instrument-ammeter' else 'V/Ohm',
            70, jack_legend_y, body_d + 9.1, 3.4, h.steel)
        if KEY == 'instrument-ammeter':
            # Fuse rating is editable at runtime. Never bake a fixed "10 A"
            # certification/rating into the image: Flutter will print the
            # instrument's *actual* fuseRatingA on the lower hatch line.
            raised_legend('fuse-panel-legend', 'FUSE',
                          53, 112.0, body_d + 11.2, 2.7, h.steel)
        # The tactile moulding belongs to the lateral holster, NOT to the dial.
        for i, x in enumerate((28, 84)):
            h.cyl(f'casing-fastener-{i}', x, 137, body_d + 5.0,
                  1.6, 0.8, h.steel)
        for side, x in (('left', 22), ('right', 90)):
            for i in range(5):
                h.box(
                    f'holster-grip-{side}-{i}', x, 76 + i * 6.5,
                    2.0, 4.2, body_d + 7.0, 0.9, h.yellow, r=0.35)
    if KEY == 'external-crusher':
        studio_softbox('large key softbox',(-45,-45,230),110000,70,150)
        studio_softbox('vertical reflection strip',(230,-125,170),65000,25,170)
        studio_softbox('upper rim softbox',(115,-260,145),90000,100,40)
        studio_softbox('front fill softbox',(110,10,200),25000,130,100)
    else:
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
        if selector is None and KEY not in ('instrument-frequency', 'instrument-phase-sequence', 'external-crusher'):
            raise RuntimeError('Missing selector_grip 3D object')
        if selector is not None:
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
        'samples': opts.samples, 'denoised': opts.denoise,
        'service_open': opts.service_open,
        'sha256_recipe': hashlib.sha256(recipe.read_bytes()).hexdigest(),
        'sha256_render_runner': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'seconds': round(time.monotonic() - t0, 2),
        'is_product_capture': False, 'integrated_in_flutter': False,
        'qualification': 'draft_preview_only'}, indent=2) + '\n')


if __name__ == '__main__':
    main()
