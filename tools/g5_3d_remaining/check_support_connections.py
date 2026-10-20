"""Blender geometry check: positive-volume contact along structural load paths.

Run with Blender --background --python-exit-code 1 --python THIS.
Checks actual object bounds, not screenshots or source-text patterns. Bounding
boxes certify these box-to-box welds; curved casing contact also needs review.
"""
from pathlib import Path
import sys
import bpy
from mathutils import Vector

BASE = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE))
from lot_06_15_geometry import build
from render_voltmeter_cycles import CyclesGeometry
from unified_geometry_contract import load_lot_contract

contract = load_lot_contract('06_15')

def bounds(name):
    obj = bpy.data.objects[name]
    points = [obj.matrix_world @ Vector(p) for p in obj.bound_box]
    return [(min(p[i] for p in points), max(p[i] for p in points)) for i in range(3)]

def contact(a, b):
    aa, bb = bounds(a), bounds(b)
    overlap = [min(aa[i][1], bb[i][1]) - max(aa[i][0], bb[i][0]) for i in range(3)]
    assert min(overlap) > .1, (a, b, overlap)

for key in ('external-mixer', 'external-pump-3p', 'external-pump-ac1', 'external-solar-pump'):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    build(CyclesGeometry(), key, contract[key])
    bpy.context.view_layer.update()
    if key == 'external-mixer':
        contact('lifting_mast', 'mast_welded_socket')
        contact('mast_welded_socket', 'mast_baseplate')
        contact('mast_baseplate', 'rear_chassis_crossmember')
        for x in (20, 180):
            leg = 'forward_chassis_leg_' + str(x)
            contact('rear_chassis_crossmember', leg)
            for z in (-12, 46):
                tag = str(x) + '_' + str(z)
                contact(leg, 'castor_mount_plate_' + tag)
                contact('castor_mount_plate_' + tag, 'castor_swivel_stem_' + tag)
                contact('castor_swivel_stem_' + tag, 'castor_fork_bridge_' + tag)
                for dx in (-4, 4):
                    contact('castor_fork_bridge_' + tag, 'castor_fork_' + tag + '_' + str(dx))
                    contact('castor_fork_' + tag + '_' + str(dx), 'castor_axle_' + tag)
                contact('castor_axle_' + tag, 'castor_wheel_' + tag)
        # Vessel clearance: working head does not rest on either floor leg.
        head = bounds('high_shear_workhead')
        for x in (20, 180):
            leg = bounds('forward_chassis_leg_' + str(x))
            assert head[0][0] > leg[0][1] or head[0][1] < leg[0][0]
    elif key == 'external-solar-pump':
        for x in (49, 119):
            contact('pump_base', 'integral_base_lug_' + str(x))
            contact('integral_base_lug_' + str(x), 'floor_foot_' + str(x))
    else:
        contact('volute', 'volute_cast_pedestal')
        contact('volute_cast_pedestal', 'volute_foot')
        for obj in bpy.data.objects:
            if obj.name.startswith('motor_pedestal_'):
                contact('cast_motor_body', obj.name)
                contact(obj.name, obj.name.replace('pedestal', 'foot'))
                # Pump and motor share one anchoring plane; feet must not hang
                # higher than the volute base on an otherwise rigid assembly.
                foot = bounds(obj.name.replace('pedestal', 'foot'))
                assert abs(foot[1][0] - bounds('volute_foot')[1][0]) < .1
    print('STRUCTURAL CONTACT PASS: ' + key)
