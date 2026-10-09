"""Rebuild G5's transparent housing plates with Blender (no source photograph).
Geometry uses the Dart renderer's millimetre coordinates and exact camera.
Run: blender -b --factory-startup -t 4 --python tools/render_g5_physical.py
"""
import bpy, bmesh, math, os
from mathutils import Matrix, Vector
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'apps/electrosim/assets/g5_physical')
os.makedirs(OUT, exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 64
scene.cycles.use_denoising = False
scene.render.film_transparent = True
scene.render.resolution_x = 840; scene.render.resolution_y = 1290
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.view_settings.view_transform = 'Filmic'
scene.view_settings.look = 'Medium High Contrast'
scene.view_settings.exposure = 1.8; scene.view_settings.gamma = 1
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.8,.85,.91,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .25

def material(name, rgb, metal=0, rough=.45, grain=0):
    m=bpy.data.materials.new(name); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*rgb,1)
    bs.inputs['Metallic'].default_value=metal
    bs.inputs['Roughness'].default_value=rough
    if grain:
        n=m.node_tree.nodes.new('ShaderNodeTexNoise'); n.inputs['Scale'].default_value=125
        n.inputs['Detail'].default_value=2
        bump=m.node_tree.nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.08
        bump.inputs['Distance'].default_value=grain
        m.node_tree.links.new(n.outputs['Fac'],bump.inputs['Height'])
        m.node_tree.links.new(bump.outputs['Normal'],bs.inputs['Normal'])
    return m
white=material('moulded warm ivory polyamide',(.78,.79,.75),rough=.38,grain=.03)
side=material('rear body polyamide',(.70,.72,.69),rough=.45,grain=.03)
steel=material('zinc plated steel',(.43,.48,.50),metal=.88,rough=.22)
dark=material('terminal well shadow',(.021,.026,.024),rough=.65)
graphite=material('matte graphite mechanism',(.025,.030,.031),rough=.33,grain=.035)
grey=material('test button polymer',(.36,.39,.41),rough=.32)
green=material('green silkscreen',(.015,.32,.07),rough=.58)
yellow=material('release tab polyamide',(.92,.66,.01),rough=.35,grain=.01)

def v(x,y,z): return (x,-y,z)
def finish(obj,name,mat,bevel=0):
    obj.name=name; obj.data.materials.append(mat)
    if bevel:
        mod=obj.modifiers.new('injection moulded radii','BEVEL');mod.width=bevel;mod.segments=4
        mod=obj.modifiers.new('weighted surface normals','WEIGHTED_NORMAL')
        mod.keep_sharp=True
    return obj

def box(name,x,y,w,h,z,d,mat,r=.2):
    bpy.ops.mesh.primitive_cube_add(size=1, location=v(x,y,z-d/2))
    obj=bpy.context.object;obj.dimensions=(w,h,d)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(obj,name,mat,r)

def rounded_box(name,x,y,w,h,z,d,mat,radius,bevel):
    # Actual rounded footprint; cube bevel alone clamps at half the thin depth.
    points=[]
    for cx,cy,a in [(x-w/2+radius,y-h/2+radius,math.pi),
                   (x+w/2-radius,y-h/2+radius,-math.pi/2),
                   (x+w/2-radius,y+h/2-radius,0),
                   (x-w/2+radius,y+h/2-radius,math.pi/2)]:
        for i in range(17):
            t=a+i*math.pi/32
            points.append((cx+radius*math.cos(t),cy+radius*math.sin(t)))
    n=len(points);verts=[v(xx,yy,zz) for zz in (z-d,z) for xx,yy in points]
    faces=[tuple(range(n)),tuple(range(2*n-1,n-1,-1))]
    faces.extend([(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)])
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
    ob=bpy.data.objects.new(name,me);scene.collection.objects.link(ob)
    return finish(ob,name,mat,bevel)

def cyl(name,x,y,z,r,d,mat):
    bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=r,depth=d,location=v(x,y,z-d/2))
    obj=bpy.context.object
    return finish(obj,name,mat,.07)

def screw_head(name,x,y,z,r):
    # Slightly crowned metal, not a flat icon disk: changing surface normals
    # produce the broken softbox reflections seen on real zinc-plated heads.
    verts=[v(x,y,z)]
    for k in range(1,13):
        radius=r*k/12;depth=z-.48*(radius/r)**2
        verts.extend(v(x+radius*math.cos(i*2*math.pi/64),
                       y+radius*math.sin(i*2*math.pi/64),depth) for i in range(64))
    verts.extend(v(x+r*math.cos(i*2*math.pi/64),
                   y+r*math.sin(i*2*math.pi/64),z-1.45) for i in range(64))
    faces=[(0,1+i,1+(i+1)%64) for i in range(64)]
    for k in range(12):
        a=1+k*64;b=a+64
        faces.extend((a+i,a+(i+1)%64,b+(i+1)%64,b+i) for i in range(64))
    faces.append(tuple(range(len(verts)-1,len(verts)-65,-1)))
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
    for face in me.polygons:face.use_smooth=True
    ob=bpy.data.objects.new(name,me);scene.collection.objects.link(ob)
    return finish(ob,name,steel,.055)

def cut(obj, tool):
    # Apply before bevel so the bore and drive receive real edge rounding.
    mod=obj.modifiers.new('recess','BOOLEAN');mod.operation='DIFFERENCE';mod.object=tool
    while obj.modifiers.find(mod.name)>0:
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.modifier_move_up(modifier=mod.name)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(tool,do_unlink=True)

def profile(name, yz, xmin,xmax,mat):
    verts=[v(x,y,z) for x in (xmin,xmax) for y,z in yz];n=len(yz)
    faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    ob=bpy.data.objects.new(name,me);scene.collection.objects.link(ob)
    return finish(ob,name,mat,.22)

corners=[(-42.5,-32),(-42.5,32),(-20,32),(-18.8,39),(7.5,39),(9,41),(29.5,41),(31,32),(42.5,32),(42.5,-25),(31,-25),(31,-10),(18,-10),(18,-1),(-12,-1),(-12,-10),(-28,-10),(-28,-32)]
housing=profile('closed stepped DIN housing',corners,-18,18,side)
land=[(-26,-27),(29,-27),(29,-10),(16,-10),(16,-1),(-11,-1),(-11,-10),(-26,-10)]
profile('rear raised moulding land',land,18,18.4,white)
# Cylindrical assembly holes on the true flank, facing sideways.
for y in (-30,-14,12,34):
    bore=cyl('assembly hole',0,0,0,1.35,5,dark)
    bore.rotation_euler[1]=math.pi/2;bore.location=v(17.5,y,21)
    cut(housing,bore)
for x in (-8.8,8.8):
    top=box('individual upper terminal bank',x,-30.8,17.6,23,35.4,3.4,white,.55)
    bot=box('individual lower terminal bank',x,35.2,17.6,14.2,35.4,3.4,white,.45)
    # Top wire mouth is a real opening into the polymer.
    mouth=box('wire opening tool', x,-42.1,7.1,7.2,23,17,dark,.35)
    cut(housing,mouth)
    box('wire well floor',x,-40.7,6.8,3,22.8,16,dark,.1)
for x in (-8.3,8.3):
    for y in (-31.5,35):
        # Circular well, moulded countersink, conical steel rim and PZ drive.
        cyl('dark terminal bore',x,y,35.5,4.1,3,dark)
        rings=[]
        for r,z in [(4.65,35.6),(4.25,36.85),(3.55,36.1),(3.35,35.1)]:
            rings.extend([v(x+r*math.cos(a*2*math.pi/64),y+r*math.sin(a*2*math.pi/64),z) for a in range(64)])
        me=bpy.data.meshes.new('countersink');me.from_pydata(rings,[],[(a+k*64,(a+1)%64+k*64,(a+1)%64+(k+1)*64,a+(k+1)*64) for k in range(3) for a in range(64)]);me.update()
        ob=bpy.data.objects.new('moulded countersink rim',me);scene.collection.objects.link(ob);finish(ob,ob.name,white)
        head=screw_head('PZ terminal screw',x,y,36.6,2.68)
        head.data.materials.append(dark)
        for w,h in ((1.04,4.32),(4.32,1.04)):
            tool=box('PZ slot cutter',x,y,w,h,37.0,1.15,dark,.08)
            tool.data.materials.clear();tool.data.materials.append(steel);tool.data.materials.append(dark)
            for face in tool.data.polygons:face.material_index=1
            cut(head,tool)
        for a in (math.pi/4,-math.pi/4):
            tool=box('secondary PZ cutter',x,y,.16,4.25,36.72,.40,dark,.01)
            tool.rotation_euler[2]=a;cut(head,tool)
# Separate moulded nameplate and shell return under the two handles.
box('front identification plate',0,-6,35,28,40,6,white,.65)
box('top identification shoulder',0,-19.3,35.4,1.5,39.6,3.4,white,.24)
box('printed green stripe',-6.7,-15,18.6,1.3,40.10,.10,green,.02)
for x in (-8.3,8.3):
    box('calibration moulding',x,6.5,9.5,2.4,40.4,.6,white,.15)
    box('calibration window',x,6.5,5.3,1,40.6,.2,dark,.04)
    surround=rounded_box('rocker surround',x,19.3,14.7,23.5,43.0,3.0,white,6.2,.6)
    aperture=rounded_box('rocker aperture cutter',x,19.1,10.5,18.8,44.0,4.0,dark,4.1,0)
    cut(surround,aperture)
    rounded_box('rocker cavity floor',x,19.1,10.5,18.8,41.1,.2,dark,4.1,.05)
box('bottom shell return',0,31,15,1.7,39.4,.6,white,.15)
for x in (-8.3,8.3):
    for dx in (-2.4,2.4):box('yellow release upright',x+dx,-44.7,1.8,5.7,25,5,yellow,.28)
    box('yellow release bridge',x,-46.95,6.85,1.8,25.9,3.1,yellow,.3)
    box('yellow release foot',x,-43.2,3.1,2.9,35.7,2,yellow,.3)
box('lower release tab',-12,43.5,7,2.2,-22,9,yellow,.35)

def area(name,location,power,size):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
    ob=bpy.data.objects.new(name,data);scene.collection.objects.link(ob);ob.location=location
    ob.rotation_euler=(Vector((0,0,15))-ob.location).to_track_quat('-Z','Y').to_euler()
# Metre-scale lighting (geometry is millimetres here) scales flux accordingly.
area('large soft key',(-90,125,180),70000,125)
area('cool soft fill',(100,15,100),15000,100)
area('edge light',(20,-80,50),10000,90)
cam_data=bpy.data.cameras.new('G5 projector');cam=bpy.data.objects.new('G5 projector',cam_data);scene.collection.objects.link(cam);scene.camera=cam
cam_data.sensor_fit='HORIZONTAL';cam_data.sensor_width=32;cam_data.clip_end=2000

def camera(yaw,pitch):
    cy,sy=math.cos(math.radians(yaw)),math.sin(math.radians(yaw));cp,sp=math.cos(math.radians(pitch)),math.sin(math.radians(pitch))
    right=Vector((cy,0,sy));up=Vector((-sp*sy,cp,sp*cy));back=Vector((-cp*sy,-sp,cp*cy))
    cam.rotation_euler=Matrix((right,up,back)).transposed().to_euler();cam.location=back*500
    def raw(x,y,z):
        xx=x*cy+z*sy;zz=-x*sy+z*cy;yy=y*cp-zz*sp;zv=y*sp+zz*cp
        k=500/(500-zv);return xx*k,yy*k
    bounds=[raw(x,y,z) for x in (-18.5,18.5) for y in (-43,43) for z in (-34,56)]+[raw(-15,-46,-28),raw(0,-46,-10)]
    minx,maxx=min(q[0] for q in bounds),max(q[0] for q in bounds);miny,maxy=min(q[1] for q in bounds),max(q[1] for q in bounds)
    scale=min((280-16)/(maxx-minx),(430-16)/(maxy-miny))
    ox=(280-(maxx-minx)*scale)/2-minx*scale;oy=(430-(maxy-miny)*scale)/2-miny*scale
    cam_data.lens=500*scale*32/280
    cam_data.shift_x=(140-ox)/280;cam_data.shift_y=(oy-215)/280

for name,yaw,pitch in [('palette',-14,-12),('platine',0,0)]:
    camera(yaw,pitch);scene.render.filepath=os.path.join(OUT,'housing-'+name+'.png')
    bpy.ops.render.render(write_still=True)
if os.environ.get('ELECTROSIM_SAVE_BLEND'):
    bpy.ops.wm.save_as_mainfile(filepath=os.environ['ELECTROSIM_SAVE_BLEND'])
