"""Original industrial housings for ElectroSim; Cycles plates, no photographs.
Run blender -b --factory-startup -t 4 --python tools/render_g5_industrial.py.
Geometry JSON is exported by the Canvas-port regression test. Front projection
is exact: one design unit is one Flutter logical pixel. Palette is a true camera.
"""
import bpy, bmesh, math, json, os, subprocess
from pathlib import Path
from mathutils import Vector, Matrix
ROOT = Path(__file__).resolve().parent.parent
OUT = Path(os.environ.get('ELECTROSIM_RENDER_OUTPUT', str(ROOT / 'apps/electrosim/assets/g5_industrial')))
OUT.mkdir(parents=True, exist_ok=True)
MODELS = json.loads((ROOT / 'apps/electrosim/assets/g5_industrial/geometry.json').read_text())
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = int(os.environ.get('ELECTROSIM_RENDER_SAMPLES', '64'))
scene.cycles.use_denoising = True
scene.cycles.film_transparent_glass = True
scene.cycles.film_transparent_roughness = .1
scene.render.film_transparent = True
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = 'Filmic'
scene.view_settings.look = 'Medium High Contrast'
scene.view_settings.exposure = 1.8
scene.world.use_nodes = True
scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.82,.85,.90,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .10

# CC0 studio lighting supplies the real softbox reflections missing from a
# uniform world. This HDR is offline tooling, never an application texture.
environment = scene.world.node_tree.nodes.new('ShaderNodeTexEnvironment')
environment.image = bpy.data.images.load(str(ROOT/'tools/g5_render_environment/studio_small_09_1k.hdr'))
scene.world.node_tree.links.new(environment.outputs['Color'], scene.world.node_tree.nodes['Background'].inputs['Color'])
scene.world.node_tree.nodes['Background'].inputs[1].default_value = .55

def mat(name, color, metallic=0, rough=.4, grain=.025):
    m=bpy.data.materials.new(name); m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Metallic'].default_value=metallic;bs.inputs['Roughness'].default_value=rough
    if grain:
        n=m.node_tree.nodes.new('ShaderNodeTexNoise');n.inputs['Scale'].default_value=80
        bump=m.node_tree.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.09
        bump.inputs['Distance'].default_value=grain
        m.node_tree.links.new(n.outputs['Fac'],bump.inputs['Height'])
        m.node_tree.links.new(bump.outputs['Normal'],bs.inputs['Normal'])
    return m
white=mat('ivory moulded polyamide',(.78,.79,.75))
rear=mat('rear moulded polyamide',(.59,.62,.59))
black=mat('graphite textured polymer',(.022,.030,.035),rough=.38)
well=mat('recess darkness',(.007,.011,.014),rough=.7,grain=0)
steel=mat('zinc plated steel',(.50,.55,.57),.95,.10,.001)
blue=mat('blue cast aluminium',(.008,.065,.14),.25,.28)
chrome=mat('brushed nickel',(.6,.65,.67),.9,.22,0)
copper=mat('enamelled copper',(.52,.18,.045),.7,.28)
brass=mat('terminal brass',(.52,.35,.09),.85,.24,0)
green=mat('green legend',(.012,.32,.08),rough=.5)
yellow=mat('DIN release clip',(.96,.69,.008),rough=.35)
red=mat('stop button',(.5,.012,.016),rough=.28)
navy=mat('reset button',(.013,.11,.33),rough=.3)
glass=mat('clear soda lime glass',(.96,.98,1),rough=.075,grain=0)
glass.node_tree.nodes['Principled BSDF'].inputs['Transmission Weight'].default_value=1
glass.node_tree.nodes['Principled BSDF'].inputs['IOR'].default_value=1.46
porcelain=mat('glazed porcelain',(.84,.83,.79),rough=.16,grain=0)

amber=mat('transparent amber relay cover',(.94,.76,.40),rough=.045,grain=0)
amber.node_tree.nodes['Principled BSDF'].inputs['Transmission Weight'].default_value=1
amber.node_tree.nodes['Principled BSDF'].inputs['IOR'].default_value=1.49
terminal_gray=mat('terminal insulating polyamide',(.46,.49,.46),rough=.38)
pe_green=mat('PE insulating polyamide',(.04,.37,.08),rough=.4)

def finish(o, name, material, bevel=0):
    o.name=name;o.data.materials.append(material)
    if bevel:
        mod=o.modifiers.new('moulded edge radii','BEVEL');mod.width=bevel;mod.segments=5
        mod=o.modifiers.new('surface normals','WEIGHTED_NORMAL');mod.keep_sharp=True
    return o

def box(name,x,y,w,h,z,depth,material=white,r=1):
    bpy.ops.mesh.primitive_cube_add(size=1,location=(x,-y,z-depth/2))
    o=bpy.context.object;o.dimensions=(w,h,depth)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,material,r)

def cyl(name,x,y,z,r,depth,material=steel):
    bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=r,depth=depth,location=(x,-y,z-depth/2))
    return finish(bpy.context.object,name,material,min(.3,depth*.15))

def cut(o,tool):
    mod=o.modifiers.new('machined recess','BOOLEAN');mod.operation='DIFFERENCE';mod.object=tool
    while o.modifiers.find(mod.name)>0:
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_move_up(modifier=mod.name)
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(tool,do_unlink=True)

def screw(x,y,r=4.3,z=27,rim_material=None):
    rim_material=rim_material or white
    # A moulded countersink with an actual crowned PZ metal head, not a disk.
    cyl('insulating recessed well',x,y,z,r*1.4,4,well)
    rings=[]
    for rr,zz in [(r*1.55,z),(r*1.35,z+1.2),(r*1.13,z+.4),(r*1.05,z-1.2)]:
        rings.extend((x+rr*math.cos(a*2*math.pi/64),-y+rr*math.sin(a*2*math.pi/64),zz) for a in range(64))
    me=bpy.data.meshes.new('moulded countersink');me.from_pydata(rings,[],[(a+k*64,(a+1)%64+k*64,(a+1)%64+(k+1)*64,a+(k+1)*64) for k in range(3) for a in range(64)]);me.update()
    ob=bpy.data.objects.new('moulded countersink',me);scene.collection.objects.link(ob);finish(ob,ob.name,rim_material)
    verts=[(x,-y,z+.6)]
    for k in range(1,13):
        radius=r*k/12;depth=z+.6-.65*(radius/r)**2
        verts.extend((x+radius*math.cos(i*2*math.pi/64),-y+radius*math.sin(i*2*math.pi/64),depth) for i in range(64))
    verts.extend((x+r*math.cos(i*2*math.pi/64),-y+r*math.sin(i*2*math.pi/64),z-1.5) for i in range(64))
    faces=[(0,1+i,1+(i+1)%64) for i in range(64)]
    for k in range(12):
        a=1+k*64;b=a+64;faces.extend((a+i,a+(i+1)%64,b+(i+1)%64,b+i) for i in range(64))
    faces.append(tuple(range(len(verts)-1,len(verts)-65,-1)))
    me=bpy.data.meshes.new('crowned screw');me.from_pydata(verts,[],faces);me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
    for poly in me.polygons:poly.use_smooth=True
    head=bpy.data.objects.new('zinc PZ head',me);scene.collection.objects.link(head);finish(head,head.name,steel,.06)
    for ww,hh in [(r*.40,r*1.65),(r*1.65,r*.40)]:
        cut(head,box('PZ drive cutter',x,y,ww,hh,z+1.2,1.6,well,.08))
    for angle in [math.pi/4,-math.pi/4]:
        tool=box('secondary PZ slot',x,y,r*.06,r*1.65,z+.75,.45,well,.01)
        tool.rotation_euler[2]=angle;cut(head,tool)
    box('dark drive floor',x,y,r*.29,r*1.4,z-.2,.15,well,.02)
    box('dark drive floor',x,y,r*1.4,r*.29,z-.2,.15,well,.02)

def round_housing(x,y,w,h,z=18,d=25,material=white,r=3):
    return box('moulded housing',x,y,w,h,z,d,material,r)

def profile(name,yz,xmin,xmax,material,bevel=.8):
    verts=[(x,-y,z) for x in (xmin,xmax) for y,z in yz];n=len(yz)
    faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
    o=bpy.data.objects.new(name,me);scene.collection.objects.link(o);return finish(o,name,material,bevel)

def lathe(name,x,z,points,material):
    """Smooth surface of revolution about the vertical product axis."""
    verts=[]; n=96
    for y,radius in points:
        verts.extend((x+radius*math.cos(2*math.pi*i/n),-y,z+radius*math.sin(2*math.pi*i/n)) for i in range(n))
    faces=[(k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i) for k in range(len(points)-1) for i in range(n)]
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    obj=bpy.data.objects.new(name,me);scene.collection.objects.link(obj);finish(obj,name,material)
    for poly in me.polygons:poly.use_smooth=True
    return obj

def wire(name,points,radius,material):
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.bevel_depth=radius;curve.bevel_resolution=3
    spline=curve.splines.new('POLY');spline.points.add(len(points)-1)
    for p,co in zip(spline.points,points):p.co=(*co,1)
    obj=bpy.data.objects.new(name,curve);scene.collection.objects.link(obj);obj.data.materials.append(material)
    return obj

def din(W,H,ports,poles):
    # Acti9 reference: stepped shoulders, closed flank, terminal cavities,
    # moulded rocker collars and two open yellow release loops.
    ymin,ymax=H*.02,H*.98
    shellwidth=W*(.48 if poles==1 else .90)
    shellleft=(W-shellwidth)/2; shellright=(W+shellwidth)/2
    yz=[(ymin,-22),(ymin,12),(H*.24,12),(H*.255,21),(H*.52,21),(H*.54,24),
        (H*.82,24),(H*.84,12),(ymax,12),(ymax,-18),(H*.82,-18),(H*.82,-4),
        (H*.65,-4),(H*.65,2),(H*.35,2),(H*.35,-4),(H*.18,-4),(H*.18,-22)]
    body=profile('closed stepped DIN shell',yz,shellleft,shellright,rear,.7)
    # Continuous shoulders avoid coplanar overlapping pole solids; shallow
    # parting lines describe the individual moulds without false black gaps.
    for y in [H*.13,H*.88]:
        bank=round_housing(W/2,y,shellwidth,H*.22,31,19,white,1.3)
        for x,py in ports:
            if abs(py-y)<H*.13:cut(bank,cyl('deep moulded terminal well tool',x,py,34,min(W,H)*.038*1.48,12,well))
    for i in range(poles):
        x=ports[i][0];pw=W*.45 if poles==1 else ports[1][0]-ports[0][0]
        for yy in [H*.025,H*.975]:
            cut(body,box('wire mouth tool',x,yy,pw*.48,H*.07,12,12,well,.5))
            round_housing(x,yy,pw*.43,H*.035,7,6,well,.5)
        for y in [H*.015,H*.985]:
            if poles>1 and i not in [0,poles-1]:continue
            for dx in [-pw*.15,pw*.15]:box('yellow clip upright',x+dx,y,pw*.10,H*.055,1,5,yellow,.35)
            box('yellow clip bridge',x,y-H*.025 if y<H*.5 else y+H*.025,pw*.4,H*.012,2,3,yellow,.3)
        if i:
            for y in [H*.13,H*.88]:box('pole mould parting line',x-pw*.5,y,.20,H*.205,31.1,.15,rear,.02)
        collar=round_housing(x,H*.66,pw*.86,H*.27,29,7,white,4)
        cut(collar,round_housing(x,H*.66,pw*.62,H*.23,31,11,well,3))
        round_housing(x,H*.66,pw*.63,H*.235,21,.5,well,3)
        for y in [H*.51,H*.84]:box('calibration recess',x,y,pw*.44,H*.008,23,.4,well,.15)
    round_housing(W/2,H*.375,shellwidth,H*.255,28,7,white,1)
    box('silkscreen green stripe',W/2,H*.28,shellwidth*.95,H*.014,28.1,.15,green,.02)
    # True lateral assembly bores and markings on the visible flank.
    for y in [H*.15,H*.36,H*.73,H*.88]:
        tool=cyl('side assembly bore',0,0,0,1.8,6,well);tool.rotation_euler[1]=math.pi/2;tool.location=(shellright,-y,7);cut(body,tool)
    for y in [H*.45,H*.48,H*.51]:box('rear ventilation land',shellright,y,.4,H*.022,3,9,rear,.1)

def controls(name,M):
    W,H=M['size'];ports=M['ports']
    if name.startswith('breaker') or name.startswith('isolator'):
        poles=len(ports)//2;pw=W*.45 if poles==1 else ports[1][0]-ports[0][0]
        for i in range(poles):
            x=ports[i][0]
            # Convex two-piece white rocker with moulded side cheeks.
            yz=[]
            for k in range(17):
                t=k/16;y=H*(.535+t*.24);z=27+7*math.sin(t*math.pi)
                yz.append((y,z))
            yz += [(H*.775,23),(H*.535,23)]
            profile('curved moulded rocker',yz,x-pw*.29,x+pw*.29,white,.65)
            box('green mechanical window',x,H*.558,pw*.54,H*.043,32,1.2,green,.2)
            for dx in [-pw*.30,pw*.30]:
                round_housing(x+dx,H*.66,pw*.055,H*.19,31,4,white,.65)
        # Linked bar with rounded ends, an actual 3D front bevel.
        width=ports[poles-1][0]-ports[0][0]+pw*.76
        round_housing(W/2,H*.76,width,H*.065,39,9,black,1.4)
        box('bar bevel highlight',W/2,H*.737,width*.96,H*.007,39.2,.4,black,.25)
    elif name=='fan':fan_rotor(W,H)
    elif name in ['button-no','button-nc']:
        color=red if name=='button-nc' else green
        cap=cyl('flat satin pushbutton face',W/2,H*.37,31,W*.278,2.7,color)
        for poly in cap.data.polygons:
            if len(poly.vertices)==4:poly.use_smooth=True
    else:return False
    return True

def fuse_holder(W,H,ports):
    # Horizontal presentation retains the existing two electrical anchors.
    body=round_housing(W/2,H/2,W*.91,H*.74,24,45,black,2)
    for x,y in ports:
        cut(body,cyl('terminal pocket tool',x,y,28,H*.084,15,well))
        for yy in [H*.16,H*.84]:
            box('wire entry mouth',x,yy,W*.075,H*.07,12,12,well,.5)
    round_housing(W*.5,H*.5,W*.55,H*.66,31,9,well,2)
    round_housing(W*.5,H*.5,W*.51,H*.60,34,12,white,2)
    for yy in [H*.25,H*.75]:
        box('carrier moulded return',W*.5,yy,W*.48,H*.025,35,3,rear,.5)
    round_housing(W*.73,H*.5,W*.035,H*.42,39,7,white,1)
    box('carrier grip inset',W*.73,H*.5,W*.016,H*.22,39.3,.5,well,.3)
    for x in [W*.21,W*.80]:cyl('carrier hinge',x,H*.5,27,H*.032,5,steel)
    for yy in [H*.16,H*.84]:box('rear mould parting line',W*.5,yy,W*.86,.7,24.2,.3,well,.1)
    box('DIN retaining foot',W*.5,H*.89,W*.24,H*.045,-10,9,rear,.5)

def auxiliary(W,H,ports):
    body=round_housing(W/2,H/2,W*.74,H*.96,27,43,black,1.4)
    for x,y in ports:
        cut(body,cyl('auxiliary terminal pocket',x,y,31,W*.060,14,well))
        for xx in [W*.22,W*.78]:box('terminal entry cheek',xx,y,W*.05,H*.09,28,7,black,.5)
    box('identification band',W*.5,H*.34,W*.67,H*.047,27.2,.3,green,.1)
    box('channel legend',W*.47,H*.56,W*.44,H*.28,27.6,.4,black,.2)
    box('actuator inspection well',W*.73,H*.55,W*.085,H*.22,28.5,4,well,.5)
    for yy in [H*.42,H*.67]:box('moulded actuator edge',W*.73,yy,W*.10,H*.012,29,2,rear,.2)
    for xx in [W*.14,W*.86]:box('clip-on retaining jaw',xx,H*.72,W*.07,H*.16,1,12,black,.6)
    for xx in [W*.30,W*.70]:box('rear locating guide',xx,H*.08,W*.065,H*.09,-8,8,black,.4)

def relay_coil(W,H,ports):
    round_housing(W/2,H*.88,W*.86,H*.16,27,40,black,1.5)
    for x,y in ports:round_housing(x,y,W*.20,H*.14,33,16,black,1)
    round_housing(W/2,H*.49,W*.71,H*.75,-3,12,black,1)
    for xx in [W*.12,W*.88]:box('socket retaining latch',xx,H*.5,W*.045,H*.61,4,12,black,.5)
    lathe('steel magnetic core',W*.37,13,[(H*.18,11),(H*.68,11)],steel)
    for yy in [H*.20,H*.66]:lathe('winding bobbin flange',W*.37,13,[(yy-2,22),(yy+2,22)],black)
    winding=[]
    for i in range(961):
        t=i/960;a=t*80*math.tau
        winding.append((W*.37+19*math.cos(a),-(H*.22+H*.42*t),13+19*math.sin(a)))
    wire('continuous enamelled copper winding',winding,.85,copper)
    box('steel relay armature',W*.67,H*.40,W*.08,H*.43,19,5,steel,.4)
    box('magnetic return bridge',W*.58,H*.24,W*.23,H*.035,24,4,steel,.4)
    for yy in [H*.40,H*.57]:
        box('internal spring support',W*.66,yy,W*.12,H*.014,28,1.3,brass,.2)
        cyl('silver contact rivet',W*.68,yy,29.5,2.2,1.5,chrome)
    cover=round_housing(W*.5,H*.45,W*.74,H*.78,42,58,amber,1.3)
    cut(cover,round_housing(W*.5,H*.45,W*.74-3,H*.78-3,40.5,59,well,.8))
    for yy in [H*.08,H*.81]:box('transparent cover rim',W*.5,yy,W*.73,H*.02,43,5,amber,.5)
    box('relay identification strip',W*.5,H*.74,W*.60,H*.065,43,.3,white,.3)

def terminal_bank(W,H,ports):
    pitch=ports[1][0]-ports[0][0]
    box('insulating mounting base',W/2,H/2,W*.92,H*.94,-7,13,black,.7)
    for i in range(5):
        x=ports[i][0];material=pe_green if i==4 else terminal_gray
        yz=[(H*.03,-10),(H*.03,28),(H*.24,28),(H*.30,20),(H*.70,20),(H*.76,28),(H*.97,28),(H*.97,-10),(H*.61,-10),(H*.59,2),(H*.41,2),(H*.39,-10)]
        body=profile('independent terminal block',yz,x-pitch*.46,x+pitch*.46,material,.8)
        for xx,yy in [ports[i],ports[i+5]]:
            cut(body,cyl('terminal screw pocket',xx,yy,31,min(W,H)*.038*1.48,15,well))
            box('wire entry mouth',xx,yy+(-1 if yy<H/2 else 1)*H*.039,pitch*.64,H*.035,10,8,well,.4)
        for yy in [H*.27,H*.73]:box('moulded shoulder',x,yy,pitch*.76,H*.035,23,4,material,.4)
        box('individual number marker',x,H*.5,pitch*.80,H*.12,21.5,1.5,white,.4)
        box('empty bridge channel',x,H*.36,pitch*.56,H*.026,23,3,well,.2)
        if i==4:
            for yy in [H*.24,H*.76]:box('PE yellow moulding',x,yy,pitch*.86,H*.044,29,1.5,yellow,.3)
    for x in [ports[0][0]-pitch*.57,ports[4][0]+pitch*.57]:
        box('terminal bank end plate',x,H*.5,pitch*.15,H*.98,29,38,rear,.6)

def dc_motor(W,H,ports):
    y=H*.43;r=H*.24;left=W*.12;right=W*.82
    for x,rad,length,material,label in [(W*.47,r,right-left,black,'smooth brushed DC motor can'),(left,r*1.01,W*.035,steel,'machined front bearing shield'),(right,r*.97,W*.055,rear,'rear brush holder'),(W*.91,H*.027,W*.17,chrome,'DC motor output shaft')]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=96,radius=rad,depth=length,location=(x,-y,0))
        o=bpy.context.object;o.rotation_euler[1]=math.pi/2;finish(o,label,material,.45)
        for poly in o.data.polygons:
            if len(poly.vertices)==4:poly.use_smooth=True
    for yy in [y-r*.75,y+r*.75]:
        box('bearing mounting detail',W*.82,yy,W*.035,H*.012,12,3,steel,.3)
    box('neutral motor nameplate',W*.48,y-r*.48,W*.30,H*.085,r*.90,.5,black,.5)
    round_housing(W*.5,H*.85,W*.40,H*.16,28,14,black,1.5)
    for x,yy in ports:
        wire('insulated brush lead',[(W*.83,-(y+r*.40),-2),(W*.85,-H*.72,7),(x,-yy,18)],1.6,black)

def axial_fan(W,H,ports):
    cy=H*.44
    frame=round_housing(W/2,cy,W*.90,H*.84,24,31,rear,4)
    cut(frame,cyl('open axial airflow aperture',W/2,cy,31,W*.36,65,well))
    for xx in [W*.12,W*.88]:
        for yy in [cy-H*.34,cy+H*.34]:
            pad=round_housing(xx,yy,W*.13,H*.13,25,32,black,2)
            cut(pad,cyl('fan mounting through hole',xx,yy,30,W*.026,55,well))
    # Rear support stays fixed behind the rotor on the intake view.
    for angle in [math.pi/4,3*math.pi/4]:
        bar=box('fixed motor support',W/2,cy,W*.70,H*.035,-2,5,rear,.5)
        bar.rotation_euler[2]=angle
    round_housing(W*.5,H*.89,W*.34,H*.15,28,12,black,1.5)
    wire('two-wire fan lead',[(W*.84,-(cy+H*.32),3),(W*.84,-H*.88,3),(ports[1][0],-ports[1][1],18)],1.4,black)

def fan_rotor(W,H):
    cx,cy=W/2,H*.44
    for k in range(9):
        vertices=[];steps=14
        for i in range(steps+1):
            t=i/steps;radius=W*(.10+.25*t)
            sweep=k*math.tau/9+.48*t
            for side in [0,1]:
                a=sweep+side*(.41-.08*t)
                vertices.append((cx+radius*math.cos(a),-cy+radius*math.sin(a),12+side*5-3*t))
        faces=[(2*i,2*i+1,2*i+3,2*i+2) for i in range(steps)]
        me=bpy.data.meshes.new('twisted curved fan blade');me.from_pydata(vertices,[],faces);me.update()
        ob=bpy.data.objects.new('twisted curved fan blade',me);scene.collection.objects.link(ob);finish(ob,ob.name,black,.3)
        solid=ob.modifiers.new('blade thickness','SOLIDIFY');solid.thickness=1.2
        for poly in me.polygons:poly.use_smooth=True
    cyl('satin rotor hub',cx,cy,24,W*.105,14,black)
    cyl('hub bearing cap',cx,cy,24.3,W*.028,.4,steel)

def sounder(W,H,ports):
    cx,cy=W/2,H*.42;r=W*.29
    body=cyl('cylindrical acoustic case',cx,cy,37,r,48,black)
    for poly in body.data.polygons:
        if len(poly.vertices)==4:poly.use_smooth=True
    cut(body,cyl('central acoustic opening',cx,cy,41,W*.035,18,well))
    cyl('dark acoustic cavity',cx,cy,24,W*.031,1,well)
    for yy in [cy-r*.8,cy+r*.8]:box('case parting seam',cx,yy,W*.25,.5,37.1,.2,well,.1)
    round_housing(W/2,H*.83,W*.41,H*.16,28,12,black,1)
    for x,yy in ports:
        wire('sounder solder lead',[(x,-(cy+r*.60),-5),(x,-yy,20)],1.5,steel)

def build(name,M):
    W,H=M['size'];ports=M['ports'];cx,cy=W/2,H/2
    if name=='motor-dc':dc_motor(W,H,ports)
    elif name=='fan':axial_fan(W,H,ports)
    elif name=='buzzer':sounder(W,H,ports)
    elif name=='fuse-holder':fuse_holder(W,H,ports)
    elif name in ['auxiliary-no','auxiliary-nc']:auxiliary(W,H,ports)
    elif name=='coil':relay_coil(W,H,ports)
    elif name=='terminal5':terminal_bank(W,H,ports)
    elif name.startswith('breaker') or name.startswith('isolator'):
        poles=len(ports)//2;din(W,H,ports,poles)
    elif name.startswith('contactor') or name=='overload':
        overload=name=='overload'
        round_housing(cx,cy,W*.90,H*.93,15,42,black,2)
        for y in [H*.08,H*.92]:
            bank=round_housing(cx,y,W*.90,H*.15,36,26,black,1.2)
            for x,py in ports:
                if abs(py-y)<H*.11:cut(bank,cyl('power terminal pocket tool',x,py,39,min(W,H)*.038*1.48,12,well))
        if overload:
            # LRD reference: compact front, setting dial, separate STOP/RESET.
            round_housing(cx,H*.49,W*.88,H*.68,29,16,black,2)
            box('overload green identification band',cx,H*.205,W*.84,H*.065,29.2,.3,green,.1)
            for x,y in ports[:3]:
                cyl('copper power adapter post',x,y,20,W*.021,14,copper)
            round_housing(W*.35,H*.51,W*.40,H*.36,29.5,.8,black,1)
            cyl('setting dial shoulder',W*.34,H*.58,32,H*.088,4,black)
            cyl('setting dial face',W*.34,H*.58,33,H*.069,1.3,rear)
            round_housing(W*.78,H*.37,W*.115,H*.065,33,6,navy,1)
            round_housing(W*.78,H*.67,W*.115,H*.085,33,7,red,1.2)
            for y in [H*.46,H*.54]:round_housing(W*.58,y,W*.07,H*.025,31,4,rear,.25)
        else:
            # LC1D18 reference: stacked terminal shoulders, label land,
            # black contact inspection window and lower operating recess.
            round_housing(cx,H*.50,W*.89,H*.70,28,13,white,1.4)
            for y in [H*.225,H*.77]:round_housing(cx,y,W*.89,H*.16,30,4,white,1)
            round_housing(cx,H*.38,W*.92,H*.16,32,5,white,1)
            box('green identification band',cx,H*.345,W*.78,H*.012,32.1,.2,green,.06)
            window=round_housing(cx,H*.52,W*.43,H*.10,32.2,.6,well,.8)
            round_housing(cx,H*.66,W*.42,H*.11,30,2,white,.8)
            for i in [-1,1]:
                # Clear-cover style return edges catch the softbox light.
                box('front cover edge',cx+i*W*.43,H*.58,W*.02,H*.34,32,4,white,.4)
                for y in [H*.52,H*.70]:box('cover retaining latch',cx+i*W*.45,y,W*.035,H*.04,29,8,rear,.3)
        for i in [-1,1]:
            for y in [H*.28,H*.4,H*.56,H*.70]:box('flank moulding recess',cx+i*W*.46,y,W*.018,H*.035,7,12,rear,.3)
    elif name in ['button-no','button-nc','toggle']:
        round_housing(cx,H*.74,W*.70,H*.39,13,30,black,3)
        round_housing(cx,H*.76,W*.58,H*.27,19,8,white,1.5)
        if name=='toggle':
            round_housing(cx,H*.47,W*.68,H*.46,21,12,black,5)
            round_housing(cx,H*.47,W*.39,H*.40,24,4,well,3)
            for x,y in ports:round_housing(x,y,W*.26,H*.11,20,5,white,1)
        else:
            cyl('button rear collar',cx,H*.37,17,W*.40,17,black)
            # Harmony reference: irregular zinc casting and fixing ears.
            collar=cyl('cast zinc mounting collar',cx,H*.37,20,W*.35,15,steel)
            cut(collar,cyl('cast collar central bore',cx,H*.37,23,W*.28,21,well))
            for side in [-1,1]:
                ear=box('zinc fixing ear',cx+side*W*.34,H*.45,W*.15,H*.12,16,14,steel,.7)
                cut(ear,cyl('ear mounting bore',cx+side*W*.34,H*.45,19,W*.022,22,well))
                box('rear contact retaining clip',cx+side*W*.27,H*.70,W*.085,H*.11,14,5,black,.6)
            bezel=cyl('nickel button bezel',cx,H*.37,32,W*.36,8,chrome)
            cut(bezel,cyl('bezel bore',cx,H*.37,35,W*.292,14,well))
            cyl('button cavity',cx,H*.37,25,W*.29,1,well)
    elif name=='lamp':
        # A60 incandescent envelope: rounded crown, shoulders and a narrow
        # neck. Reference dimensions Ø60 x 107.5 mm, not a spherical LED globe.
        points=[(.025,0),(.035,.12),(.065,.23),(.11,.32),(.17,.39),(.24,.42),(.32,.425),(.40,.405),(.47,.35),(.53,.27),(.58,.21),(.63,.19),(.66,.18)]
        bulb=lathe('A60 clear pear glass envelope',cx,24,[(H*y,W*r) for y,r in points],glass)
        sub=bulb.modifiers.new('continuous blown glass curvature','SUBSURF');sub.levels=2
        solid=bulb.modifiers.new('thin glass wall','SOLIDIFY');solid.thickness=.5
        # Visible glass stem and classic tungsten coil with two supports.
        stem=lathe('glass stem',cx,24,[(H*.63,8),(H*.58,5),(H*.40,3),(H*.39,0)],glass)
        for side in [-1,1]:
            wire('filament support',[(cx+side*6,-H*.62,28),(cx+side*21,-H*.32,28)],.45,chrome)
        filament=[]
        for i in range(300):
            t=i/299;filament.append((cx-21+42*t,-H*(.32+.035*math.sin(t*math.pi))+math.sin(t*math.pi*70)*.7,28+math.cos(t*math.pi*70)*.7))
        wire('coiled tungsten incandescent filament',filament,.17,black)
        lathe('E27 nickel screw base',cx,24,[(H*.65,23),(H*.71,23),(H*.73,21)],chrome)
        turns=[]
        for i in range(400):
            t=i/399;angle=t*math.pi*10
            turns.append((cx+23.8*math.cos(angle),-H*(.652+t*.065),24+23.8*math.sin(angle)))
        wire('E27 helical screw thread',turns,1.15,chrome)
        # Glazed cylindrical batten holder, mounting ears, two integrated
        # terminal pockets. Underneath terminals are exposed for training.
        lathe('porcelain batten holder',cx,17,[(H*.71,27),(H*.73,33),(H*.77,37),(H*.88,39),(H*.94,42),(H*.95,0)],porcelain)
        for side in [-1,1]:
            ear=round_housing(cx+side*W*.37,H*.925,W*.19,H*.055,31,19,porcelain,4)
            cut(ear,round_housing(cx+side*W*.38,H*.925,W*.035,H*.018,35,25,well,1))
        for xx,yy in ports:
            round_housing(xx,yy,W*.17,H*.072,55,4,porcelain,2)
            round_housing(xx,yy,W*.11,H*.043,55.5,1.5,well,1)
            cyl('brass lamp terminal',xx,yy,56,5.5,2,brass)
            screw(xx,yy,3.9,57,porcelain)
    elif name=='motor3':
        if name=='motor3':
            left,right,y,r=W*.11,W*.84,H*.48,H*.34
        else:
            left,right,y,r=W*.09,W*.83,H*.43,H*.29
            round_housing(cx,H*.84,W*.43,H*.18,22,15,white,2)
        # Real cast cylindrical motor whose axis lies along X.
        bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=r,depth=right-left,location=((left+right)/2,-y,0))
        o=bpy.context.object;o.rotation_euler[1]=math.pi/2;finish(o,'motor cast cylindrical body',blue,1.5)
        for poly in o.data.polygons:
            if len(poly.vertices)==4:poly.use_smooth=True
        # WEG W22 reference: deep cast cooling fins distributed radially,
        # bolted bearing shield, rear ventilated hood and ribbed feet.
        for k in range(28):
            angle=2*math.pi*k/28
            rr=r+2
            o=box('cast radial cooling fin',(left+right)/2,y+rr*math.cos(angle),right-left-W*.08,1.1,rr*math.sin(angle)+2,4.2,blue,.25)
            o.rotation_euler[0]=angle-math.pi/2
        for x in [left,right]:
            bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=r*1.07,depth=W*.058,location=(x,-y,0))
            o=bpy.context.object;o.rotation_euler[1]=math.pi/2;finish(o,'cast bearing end shield',blue,.7)
            for poly in o.data.polygons:
                if len(poly.vertices)==4:poly.use_smooth=True
            for k in range(8):
                angle=k*math.pi/4
                yy=y+r*.76*math.cos(angle);zz=r*.76*math.sin(angle)
                bpy.ops.mesh.primitive_cylinder_add(vertices=6,radius=W*.014,depth=W*.024,location=(x+W*.04,-yy,zz))
                o=bpy.context.object;o.rotation_euler[1]=math.pi/2;finish(o,'hex bearing shield bolt',steel,.12)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=24,location=(left-W*.015,-y,0))
        o=bpy.context.object;o.scale=(W*.06,r*1.08,r*1.08);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        finish(o,'rear convex ventilation hood',blue)
        for poly in o.data.polygons:poly.use_smooth=True
        for k in range(9):
            box('fan hood ventilation slot',left-W*.04,y+r*(-.72+k*.18),W*.032,H*.009,r*.85,1.2,well,.25)
        bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=H*.035,depth=W*.13,location=(right+W*.07,-y,0))
        o=bpy.context.object;o.rotation_euler[1]=math.pi/2;finish(o,'machined steel shaft',chrome,.3)
        box('shaft keyway',right+W*.07,y,W*.085,H*.009,H*.036,.7,well,.15)
        for x in [W*.30,W*.70]:
            foot=round_housing(x,y+r,W*.21,H*.085,10,20,blue,.7)
            cut(foot,cyl('foot mounting bore tool',x,y+r,12,W*.022,24,well))
            for dx in [-W*.045,W*.045]:
                profile('triangular cast foot web',[(y+r,5),(y+r*.50,2),(y+r,15)],x+dx-W*.014,x+dx+W*.014,blue,.35)
        if name=='motor3':
            # W22 B3 side-mounted open terminal box. Its 23% body-envelope
            # width is deliberately distinct from the much larger stator.
            bx,by=W*.34,H*.48
            base=round_housing(bx,by,W*.23,H*.28,r+32,45,blue,4)
            cut(base,round_housing(bx,by,W*.19,H*.215,r+38,21,well,2))
            rim=round_housing(bx,by,W*.215,H*.255,r+35,7,blue,2)
            cut(rim,round_housing(bx,by,W*.19,H*.215,r+38,13,well,2))
            round_housing(bx,by,W*.19,H*.215,r+24,2,black,1)
            for xx in [W*.24,W*.44]:
                for yy in [H*.355,H*.605]:screw(xx,yy,3.2,r+35,blue)
            # Brass M6 studs, washers and hex nuts: winding terminals are
            # not the giant insulating PZ countersinks of a circuit breaker.
            for xx,yy in ports:
                cyl('brass terminal washer',xx,yy,r+34,8.5,1.5,brass)
                bpy.ops.mesh.primitive_cylinder_add(vertices=6,radius=7.2,depth=5,location=(xx,-yy,r+36.5))
                nut=finish(bpy.context.object,'M6 brass terminal nut',brass,.3)
                cut(nut,cyl('thread opening',xx,yy,r+41,2.7,8,well))
                cyl('dark stud thread',xx,yy,r+34,2.5,1,well)
            # The identification plate remains on the curved stator flank.
            box('riveted aluminium nameplate',W*.61,H*.25,W*.13,H*.10,r*.77,1.5,chrome,1)
            for xx in [W*.55,W*.67]:screw(xx,H*.25,1.7,r*.78,chrome)
    elif name=='supply':
        round_housing(cx,cy,W*.89,H*.91,21,38,black,3)
        round_housing(cx,H*.36,W*.76,H*.44,24,3,chrome,2)
        round_housing(cx,H*.36,W*.68,H*.35,24.4,.5,well,1)
        for x in [W*.12,W*.88]:
            for y in [H*.095,H*.90]:screw(x,y,2.2,23)
        for i in range(6):box('housing ventilation',W*.15+i*W*.055,H*.63,W*.026,H*.04,22,.6,well,.3)
    for j,(x,y) in enumerate(ports):
        if name in ['motor3','lamp']:continue
        dark_rim=name.startswith('contactor') or name in ['overload','coil','fuse-holder','auxiliary-no','auxiliary-nc','motor-dc','fan','buzzer']
        rim=(pe_green if j%5==4 else terminal_gray) if name=='terminal5' else black if dark_rim else white
        screw(x,y,min(W,H)*.038,34 if dark_rim else 29,rim)

def area(name,loc,power,size):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.size=size;data.shape='DISK'
    o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);o.location=loc
    o.rotation_euler=(Vector((W/2,-H/2,10))-o.location).to_track_quat('-Z','Y').to_euler()

selected=os.environ.get('ELECTROSIM_INDUSTRIAL_MODELS','').split(',')
for name,M in MODELS.items():
    if selected!=[''] and name not in selected:continue
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    W,H=M['size'];build(name,M)
    body_objects=[o for o in scene.objects if o.type in ['MESH','CURVE']]
    has_controls=controls(name,M)
    control_objects=[o for o in scene.objects if o.type=='MESH' and o not in body_objects]
    area('large soft key',(W/2-160,-H/2+200,320),180000,170)
    area('cool fill',(W/2+200,-H/2+10,200),18000,140)
    area('edge softbox',(W/2,-H/2-150,130),30000,140)
    data=bpy.data.cameras.new('industrial product camera');data.type='ORTHO';data.clip_end=2000
    cam=bpy.data.objects.new('industrial product camera',data);scene.collection.objects.link(cam);scene.camera=cam
    factor=1.5 if name=='motor3' else 2.5
    scene.render.resolution_x=round(W*factor);scene.render.resolution_y=round(H*factor)
    for view,yaw,pitch,scale in [('front',0,0,1),('palette',-24,-16,.78)]:
        cy,sy=math.cos(math.radians(yaw)),math.sin(math.radians(yaw))
        cp,sp=math.cos(math.radians(pitch)),math.sin(math.radians(pitch))
        right=Vector((cy,0,sy));up=Vector((-sp*sy,cp,sp*cy));back=Vector((-cp*sy,-sp,cp*cy))
        center=Vector((W/2,-H/2,0))
        cam.rotation_euler=Matrix((right,up,back)).transposed().to_euler();cam.location=center+back*600
        data.ortho_scale=max(W,H)/scale
        # Blender's AUTO sensor fit uses the longest rendered dimension.
        for o in body_objects:o.hide_render=False
        for o in control_objects:o.hide_render=True
        if not os.environ.get('ELECTROSIM_CONTROLS_ONLY'):
            scene.render.filepath=str(OUT/f'{name}-{view}.png')
            bpy.ops.render.render(write_still=True)
        if has_controls:
            for o in body_objects:o.hide_render=True
            for o in control_objects:o.hide_render=False
            temporary=ROOT/'apps/electrosim/build/g5-controls';temporary.mkdir(parents=True,exist_ok=True)
            source=temporary/f'{name}-{view}.png';target=OUT/f'{name}-controls-{view}.png'
            originals={o:o.matrix_world.copy() for o in control_objects}
            poses=[('',0)]
            if name.startswith('breaker') or name.startswith('isolator'):poses += [('-on',-40),('-trip',-20)]
            for pose,angle in poses:
                pivot=Vector((W/2,-H*.655,26))
                transform=Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(angle),4,'X') @ Matrix.Translation(-pivot)
                for o in control_objects:o.matrix_world=transform @ originals[o]
                source=temporary/f'{name}{pose}-{view}.png';target=OUT/f'{name}-controls{pose}-{view}.png'
                scene.render.filepath=str(source);bpy.ops.render.render(write_still=True)
                # Lossless crop of our own rendered layer, not any reference photo.
                code='from PIL import Image; import json,sys; im=Image.open(sys.argv[1]); b=im.getbbox(); im.crop(b).save(sys.argv[2]); print(json.dumps(list(b)))'
                result=subprocess.run(['python3','-c',code,str(source),str(target)],capture_output=True,text=True,check=True)
                bounds=json.loads(result.stdout);factor=scene.render.resolution_x/W
                metadata_path=OUT/'controls.json'
                metadata=json.loads(metadata_path.read_text()) if metadata_path.exists() else {}
                metadata[f'{name}{pose}-{view}']=[bounds[0]/factor,bounds[1]/factor,(bounds[2]-bounds[0])/factor,(bounds[3]-bounds[1])/factor]
                metadata_path.write_text(json.dumps(metadata,indent=2))
            for o in control_objects:o.matrix_world=originals[o]
