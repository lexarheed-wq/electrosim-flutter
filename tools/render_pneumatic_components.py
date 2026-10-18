"""Render original Cycles assets for ElectroSim pneumatic workshop."""
import bpy, math, os
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parent.parent
OUT = Path(os.getenv('ELECTROSIM_PNEUMATIC_RENDER_OUTPUT', ROOT / 'apps/electrosim/assets/g5_pneumatic'))
OUT.mkdir(parents=True, exist_ok=True)
KINDS = ('idealSource','regulator','valve32','valve52','checkValve','restrictor',
         'singleActingCylinder','doubleActingCylinder','tee','manifold','silencer',
         'manometer','pressureSwitch','positionSensor','other')

def mat(name, color, metal=0, rough=.32):
    m=bpy.data.materials.new(name); m.use_nodes=True
    s=m.node_tree.nodes.get('Principled BSDF'); s.inputs['Base Color'].default_value=(*color,1)
    s.inputs['Metallic'].default_value=metal; s.inputs['Roughness'].default_value=rough
    return m
M={k:mat(*v) for k,v in {
 'alloy':('Satin anodized aluminium',(.43,.50,.53),.8,.24),
 'dark':('Textured graphite polymer',(.045,.06,.065),.1,.36),
 'blue':('Industrial blue polymer',(.025,.14,.30),.08,.27),
 'white':('Light polyamide',(.78,.80,.77),.04,.3),
 'brass':('Turned brass fitting',(.61,.39,.12),.84,.22),
 'steel':('Stainless steel',(.77,.81,.82),.91,.18),
 'glass':('Gauge glass',(.70,.84,.87),.2,.1),
 'yellow':('Safety yellow',(.9,.58,.03),.05,.28),
 'green':('Indicator green',(.02,.52,.17),.05,.2),
 'red':('Needle red',(.68,.025,.02),.02,.2),
}.items()}

def finish(o, key, bevel=.025):
    o.data.materials.append(M[key])
    if bevel and o.type=='MESH':
        b=o.modifiers.new('soft moulded edges','BEVEL'); b.width=bevel; b.segments=3
        o.modifiers.new('weighted normals','WEIGHTED_NORMAL')
    return o
def box(name, loc, dims, key, bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.name=name; o.dimensions=dims
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); return finish(o,key,bevel)
def cyl(name, loc, r, depth, key, axis='Y', vertices=48):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=loc); o=bpy.context.object; o.name=name
    if axis=='Y': o.rotation_euler[0]=math.pi/2
    if axis=='X': o.rotation_euler[1]=math.pi/2
    return finish(o,key,min(.025,depth*.1))
def label(text, loc, size=.1, key='dark'):
    c=bpy.data.curves.new('engraved marking','FONT'); c.body=text; c.size=size; c.align_x='CENTER'; c.align_y='CENTER'
    o=bpy.data.objects.new('front marking',c); bpy.context.collection.objects.link(o); o.location=loc; o.rotation_euler[0]=math.pi/2; c.materials.append(M[key])
def port(x,z,r=.085):
    cyl('threaded air port',(x,-.33,z),r,.12,'brass'); cyl('port bore',(x,-.402,z),r*.52,.02,'dark')
def gauge(x=0,z=0,r=.29):
    cyl('gauge bezel',(x,-.40,z),r,.12,'dark'); cyl('steel rim',(x,-.47,z),r*.86,.035,'steel')
    cyl('white gauge face',(x,-.495,z),r*.74,.02,'white'); cyl('glass lens',(x,-.51,z),r*.64,.012,'glass')
    needle=box('red gauge needle',(x+r*.1,-.525,z+r*.06),(r*.045,.008,r*.72),'red',.002); needle.rotation_euler[1]=.38

def actuator(single):
    cyl('rear end cap',(-.24,0,0),.34,.18,'dark','X'); cyl('anodized barrel',(.18,0,0),.30,.78,'alloy','X')
    cyl('front gland',(.61,0,0),.33,.16,'dark','X'); cyl('piston rod',(1.02,0,0),.09,.70,'steel','X')
    cyl('rod eye',(1.38,0,0),.17,.20,'alloy','X'); cyl('rod eye bore',(1.38,-.11,0),.07,.02,'dark')
    port(-.28,-.31); port(.48,-.31)
    if single: box('return spring cover',(-.46,.04,.01),(.11,.16,.40),'yellow')
    label('PNEUMATIC',(.18,-.31,.09),.075)

def build(kind):
    if kind=='idealSource':
        box('compressed air source',(0,0,0),(.85,.56,.85),'blue'); box('front panel',(0,-.30,.03),(.66,.025,.47),'dark')
        gauge(0,.18,.18); cyl('outlet',(0,-.36,-.28),.10,.13,'brass'); cyl('status LED',(.24,-.34,-.13),.05,.04,'green'); label('AIR SUPPLY',(0,-.323,-.20),.075,'white')
    elif kind=='regulator':
        box('regulator head',(0,0,.25),(.86,.52,.53),'alloy'); cyl('knob collar',(0,0,.61),.24,.18,'dark','Z'); cyl('pressure knob',(0,0,.77),.20,.18,'blue','Z')
        cyl('filter bowl collar',(0,0,-.06),.27,.11,'dark','Z'); cyl('transparent filter bowl',(0,0,-.31),.22,.43,'glass','Z'); cyl('drain',(0,0,-.56),.10,.10,'dark','Z')
        port(-.34,.10); port(.34,.10); gauge(.47,.52,.19)
    elif kind in ('valve32','valve52'):
        n=3 if kind=='valve32' else 5; box('directional valve manifold',(0,0,0),(1.42,.54,.58),'alloy')
        for i in range(n): port(-.48+i*.24,-.24,.065)
        for x in (-.86,.86): box('solenoid end cap',(x,0,0),(.28,.61,.61),'dark')
        cyl('manual override',(-.86,-.34,.02),.09,.13,'yellow'); box('spool position window',(0,-.29,.12),(.56,.02,.13),'blue'); label(f'{n} PORT',(0,-.30,.25),.09,'white')
    elif kind=='checkValve':
        cyl('inline check valve', (0,0,0),.27,.82,'brass','X',6)
        for x in (-.50,.50): cyl('hex connection',(x,0,0),.19,.18,'alloy','X',6)
        box('flow arrow',(0,-.28,.09),(.38,.018,.06),'blue',.01)
    elif kind=='restrictor':
        cyl('flow control body',(0,0,0),.25,.75,'brass','X',6); cyl('adjuster base',(0,0,.25),.17,.18,'dark','Z'); cyl('flow knob',(0,0,.42),.15,.18,'blue','Z')
        for x in (-.45,.45): cyl('threaded union',(x,0,0),.15,.18,'alloy','X',6)
    elif kind in ('singleActingCylinder','doubleActingCylinder'): actuator(kind=='singleActingCylinder')
    elif kind=='tee':
        cyl('tee horizontal',(0,0,0),.105,.83,'brass','X'); cyl('tee branch',(0,0,.28),.105,.50,'brass','Z')
        for loc,axis in (((-.48,0,0),'X'),((.48,0,0),'X'),((0,0,.55),'Z')): cyl('compression nut',loc,.15,.16,'alloy',axis,6)
    elif kind=='manifold':
        box('distribution manifold',(0,0,0),(1.65,.48,.42),'blue')
        for x in (-.62,-.21,.21,.62): port(x,-.23); cyl('outlet union',(x,.21,-.03),.085,.25,'brass')
        box('DIN mounting foot',(0,.03,-.29),(1.2,.58,.14),'alloy'); label('DISTRIBUTION',(0,-.25,.05),.09,'white')
    elif kind=='silencer':
        cyl('sintered bronze silencer',(0,0,0),.24,.70,'brass','X')
        for x in (-.44,.44): cyl('threaded neck',(x,0,0),.15,.18,'alloy','X',6)
        for i in range(8):
            a=2*math.pi*i/8; cyl('porous surface hole',(0,.243*math.cos(a),.243*math.sin(a)),.018,.012,'dark','X',12)
    elif kind=='manometer':
        gauge(0,.08,.35); box('gauge lower case',(0,0,-.34),(.24,.25,.22),'dark'); port(0,-.46); label('bar',(0,-.52,-.14),.10)
    elif kind=='pressureSwitch':
        box('pressure sensor housing',(0,0,0),(.72,.48,.62),'dark'); box('display',(0,-.255,.08),(.41,.025,.22),'blue',.01); box('digits',(0,-.273,.08),(.24,.008,.05),'green',.004)
        cyl('setpoint screw',(.22,-.29,-.16),.06,.03,'brass'); port(0,-.34); cyl('M12 plug',(.23,.20,.20),.10,.25,'steel','Z')
    elif kind=='positionSensor':
        box('cylinder position sensor',(0,0,0),(.68,.32,.34),'dark'); box('yellow label',(0,-.17,.02),(.44,.018,.14),'yellow',.01)
        cyl('status indicator',(.20,-.19,.02),.035,.02,'green'); box('sensor cable',(0,.22,-.12),(.13,.30,.10),'dark'); box('mounting clip',(0,.12,-.25),(.48,.12,.12),'alloy')
    else:
        box('pneumatic accessory',(0,0,0),(.70,.48,.62),'white'); port(-.25,-.31); port(.25,-.31); label('PNEUMATIC',(0,-.25,.05),.09)

def setup():
    s=bpy.context.scene; s.render.engine='CYCLES'; s.cycles.samples=int(os.getenv('ELECTROSIM_RENDER_SAMPLES','32')); s.cycles.use_denoising=True
    s.render.resolution_x=600; s.render.resolution_y=440; s.render.resolution_percentage=80; s.render.film_transparent=True
    s.render.image_settings.file_format='PNG'; s.render.image_settings.color_mode='RGBA'; s.view_settings.view_transform='AgX'
    for name,loc,power,size in [('key',(4,-5,6),900,5),('fill',(-4,-4,2),600,4),('rim',(2,4,5),1100,3)]:
        bpy.ops.object.light_add(type='AREA',location=loc); l=bpy.context.object; l.name=name; l.data.energy=power; l.data.shape='DISK'; l.data.size=size; l.rotation_euler=(Vector((0,0,0))-l.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add(location=(4,-7,3)); c=bpy.context.object; c.rotation_euler=(Vector((0,0,0))-c.location).to_track_quat('-Z','Y').to_euler(); c.data.type='ORTHO'; c.data.ortho_scale=3.5; s.camera=c

def render(kind,view):
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    build(kind); setup(); s=bpy.context.scene
    if view=='front':
        c=s.camera; c.location=(0,-8,1.1); c.rotation_euler=(Vector((0,0,0))-c.location).to_track_quat('-Z','Y').to_euler(); c.data.ortho_scale=3.1
    s.render.filepath=str(OUT/f'{kind}-{view}.png'); bpy.ops.render.render(write_still=True)

requested=os.getenv('ELECTROSIM_PNEUMATIC_KINDS'); kinds=requested.split(',') if requested else KINDS
if set(kinds)-set(KINDS): raise ValueError(f'Unknown kinds: {set(kinds)-set(KINDS)}')
for kind in kinds:
    print(f'Rendering {kind}: palette and front',flush=True); render(kind,'palette'); render(kind,'front')
