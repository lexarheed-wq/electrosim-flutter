"""Blender checks of real load paths and room for native terminal overlays."""
from pathlib import Path
import sys
import bpy
from mathutils import Vector
BASE=Path(__file__).resolve().parent;sys.path.insert(0,str(BASE))
from render_voltmeter_cycles import CyclesGeometry
from lot_16_26_geometry import build
from unified_geometry_contract import load_lot_contract
contract=load_lot_contract('16_26')
def bounds(n):
 o=bpy.data.objects[n];pts=[o.matrix_world@Vector(v) for v in o.bound_box]
 return [(min(p[i]for p in pts),max(p[i]for p in pts))for i in range(3)]
def contact(a,b):
 aa,bb=bounds(a),bounds(b)
 overlap=[min(aa[i][1],bb[i][1])-max(aa[i][0],bb[i][0])for i in range(3)]
 assert min(overlap)>.1,(a,b,overlap)
for k,s in contract.items():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 build(CyclesGeometry(),k,s,True);bpy.context.view_layer.update()
 if k=='external-refrigerator-dc':
  for x in (31,149):contact('insulated_cabinet','base_foot_'+str(x))
 if k in ('pv-resistive-load','load-wye-3p','load-delta-3p'):
  w,hh=s['size']
  for x in (23,w-23):
   contact('side_guard_'+str(x),'resistor_base')
   contact('side_guard_'+str(x),'grille_side_frame_'+str(x))
  for o in list(bpy.data.objects):
   if o.name.startswith('ceramic_bracket_'):
    x=int(o.name.split('_')[-1]);contact(o.name,'side_guard_'+str(23 if x==31 else w-23))
 if k=='source-ac3-alternator':
  for x in (156,265):
   contact('generator_body','cast_foot_neck_'+str(x));contact('cast_foot_neck_'+str(x),'cast_foot_'+str(x))
 # All physical contacts must lie inside their documented service envelope.
 x,y,w,hh,z=s['box']
 for px,py in s['ports']:assert x-w/2<px<x+w/2 and y-hh/2<py<y+hh/2,k
 print('STRUCTURE PASS: '+k)
