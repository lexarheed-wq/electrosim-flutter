"""Original generic physical housings for the ten source/PV catalogue entries.
Commercial photos guide construction only; no photo textures or vendor claims.
"""
import math
import bpy
SOURCE_PV_MODELS = {'switch-toggle','source-dc-voltage','source-dc-current','source-ac-voltage','source-ac-current','solar-panel','controller-mppt','controller-pwm','solar-battery','solar-inverter'}

def build_source_pv(name, M, a):
    W,H=M['size'];ports=M['ports'];cx,cy=W/2,H/2
    box,cyl,cut,mat,wire=[a[k] for k in ['box','cyl','cut','mat','wire']]
    black,steel,chrome,well,white,brass=[a[k] for k in ['black','steel','chrome','well','white','brass']]
    blue=mat('solar blue textured housing',(.004,.085,.19),rough=.43,grain=.008)
    def terminal(x,y,positive=False,z=29):
        box('terminal insulation',x,y,min(W,H)*.12,min(W,H)*.13,z,12,black,1.3)
        cyl('terminal nickel washer',x,y,z+1,min(W,H)*.055,2,chrome)
    def banana_socket(x,y,positive=False):
        # Real hollow binding post. The electrical anchor is the socket centre,
        # not a PZ screw drawn over an output jack.
        insulator=a['red'] if positive else black
        cyl('binding post panel seat',x,y,32,W*.064,2,black)
        cap=cyl('ribbed binding post insulator',x,y,38,W*.050,6,insulator)
        cut(cap,cyl('binding post axial bore',x,y,40,W*.024,11,well))
        contact=cyl('banana socket nickel lip',x,y,38.6,W*.030,2,chrome)
        cut(contact,cyl('banana socket opening',x,y,40,W*.021,7,well))
        cyl('banana socket dark interior',x,y,32.2,W*.020,1,well)
        for i in range(18):
            theta=2*math.pi*i/18
            rib=cyl('binding post knurl',x+W*.047*math.cos(theta),y+W*.047*math.sin(theta),37,.55,4,insulator)
    def vents(x,y,count,step,width,height,z=30):
        for i in range(count):box('deep ventilation aperture',x+i*step,y,width,height,z,.8,well,.4)
    def knob(x,y,r,z=36):
        cyl('recessed knob ring',x,y,z-6,r*1.13,2,chrome)
        ob=cyl('ribbed control knob',x,y,z,r,8,white)
        for i in range(24):
            theta=2*math.pi*i/24
            cyl('knob grip rib',x+r*.94*math.cos(theta),y+r*.94*math.sin(theta),z-1,.55,6,white)
        box('encoder index',x,y-r*.60,1.0,r*.40,z+.15,.3,well,.1)
    if name=='switch-toggle':
        box('phenolic SPST body',cx,cy,W*.55,H*.64,14,34,black,3)
        box('metal retaining bracket',cx,cy,W*.63,H*.31,20,5,steel,1.4)
        cyl('threaded mounting bushing',cx,cy,29,W*.115,12,chrome)
        for z in [20,22,24,26]:cyl('mounting thread crest',cx,cy,z,W*.122,.7,steel)
        bpy.ops.mesh.primitive_cylinder_add(vertices=6,radius=W*.19,depth=4,location=(cx,-cy,24))
        a['finish'](bpy.context.object,'hexagonal mounting nut',chrome,.45)
        for x,y in ports:
            terminal(x,y)
            wire('SPST terminal lug',[(x,-y,25),(cx,-cy,8)],1.1,brass)
    elif name.startswith('source-'):
        ac='-ac-' in name
        box('instrument folded steel case',cx,cy,W*.87,H*.91,20,49,steel,3)
        box('moulded instrument front bezel',cx,cy,W*.84,H*.89,30,11,white,2)
        box('dark dual numeric display recess',cx,H*.35,W*.67,H*.32,31,2,well,2)
        box('display acrylic lens',cx,H*.35,W*.64,H*.29,31.3,.3,black,.8)
        for x in [W*.28,W*.72]:knob(x,H*.62,W*.075)
        vents(W*.18,H*.78,9,W*.077,W*.025,H*.055,30.3)
        for x in [W*.10,W*.90]:
            box('rear equipment foot',x,H*.94,W*.10,H*.025,2,11,black,1)
        for i,(x,y) in enumerate(ports):
            banana_socket(x,y,positive=i==0)
    elif name=='solar-panel':
        box('extruded aluminium PV frame',cx,H*.43,W*.88,H*.79,15,16,chrome,1.5)
        box('laminated PV backsheet',cx,H*.43,W*.84,H*.75,15.3,1,white,.2)
        cell=mat('photovoltaic silicon blue',(.009,.025,.073),metallic=.36,rough=.18,grain=.002)
        for row in range(5):
            for col in range(8):
                x=W*.115+col*W*.11;y=H*.115+row*H*.14
                box('silicon photovoltaic cell',x,y,W*.102,H*.131,16.1,.45,cell,.65)
                for finger in range(8):box('fine silver cell finger',x-W*.046+finger*W*.013,y,.12,H*.122,16.3,.04,chrome,.01)
                for yy in [y-H*.033,y+H*.033]:box('cell busbar',x,yy,W*.097,.23,16.4,.05,chrome,.01)
        # Serviceable junction box on the BACK, with four contacts and bypass
        # diodes; only the two outer contacts are electrical output ports.
        from mathutils import Matrix, Vector
        before=set(bpy.context.scene.objects)
        enclosure=box('rear IP junction enclosure',cx,H*.32,W*.37,H*.43,26,16,black,3)
        cut(enclosure,box('open rear junction cavity',cx,H*.32,W*.32,H*.37,27,12,well,1.8))
        for i in range(4):
            x=W*(.38+.08*i)
            box('rear tinned copper junction contact',x,H*.33,W*.045,H*.19,19,1,chrome,.3)
            a['screw'](x,H*.33,2.2,20,chrome)
            if i in [0,3]: a['screw'](x,H*.39,2.1,20,chrome)
        for i in range(3):
            x=W*(.42+.08*i)
            bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=H*.0125,depth=W*.042,location=(x,-H*.29,20),rotation=(0,math.pi/2,0))
            a['finish'](bpy.context.object,'rear axial bypass diode',black,.25)
            bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=H*.0127,depth=W*.004,location=(x+W*.016,-H*.29,20),rotation=(0,math.pi/2,0))
            a['finish'](bpy.context.object,'bypass cathode identification band',chrome,.05)
            for xx in [x-W*.03,x+W*.03]:
                box('bypass diode lead',xx,H*.29,W*.019,.5,19.5,.5,chrome,.1)
        for x in [W*.33,W*.67]:
            for y in [H*.14,H*.50]:a['screw'](x,y,1.6,26,brass)
        # Use the SAME x as the cable exits: earlier gland decorations were
        # offset from the cable by .05 W and did not physically meet it.
        for x,_ in ports:
            bpy.ops.mesh.primitive_cylinder_add(vertices=6,radius=W*.025,depth=H*.055,location=(x,-H*.54,22),rotation=(math.pi/2,0,0))
            gland=a['finish'](bpy.context.object,'junction cable gland hex nut',black,.5)
            bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=1.5,depth=H*.070,location=(x,-H*.54,22),rotation=(math.pi/2,0,0))
            cut(gland,bpy.context.object)
        rear_transform=Matrix.Translation(Vector((cx,0,8))) @ Matrix.Rotation(math.pi,4,'Y') @ Matrix.Translation(Vector((-cx,0,0)))
        for ob in set(bpy.context.scene.objects)-before:ob.matrix_world=rear_transform @ ob.matrix_world
        box('PV rear insulating laminate',cx,H*.43,W*.84,H*.75,-.7,.4,white,.2)
        for x,y in ports:
            wire('PV junction output cable',[(x,-H*.54,-14),(x,-H*.82,-2),(x,-y,4)],1.4,black)
            box('MC4 output connector body',x,y,W*.035,H*.065,7,8,black,1.5)
            for yy in [y-H*.027,y,y+H*.027]:
                box('MC4 connector retaining collar',x,yy,W*.044,H*.009,7.3,8.6,black,.3)
    elif name in ['controller-mppt','controller-pwm','solar-inverter']:
        pwm=name=='controller-pwm';inverter=name=='solar-inverter'
        box('finned aluminium rear heat spreader',cx,cy,W*.91,H*(.86 if inverter else .72),1,23,black,2)
        for i in range(15):box('extruded heat sink fin',W*.07+i*W*.061,cy,W*.018,H*(.89 if inverter else .72),0,26,black,.3)
        body=box('moulded solar electronics case',cx,H*(.50 if inverter else .55),W*.90,H*(.76 if inverter else .80),31,32,blue,5)
        if not inverter:
            # Four-way connector is recessed INTO the lower housing, rather
            # than suspended beneath it. Each cable entry is a real cavity.
            cut(body,box('lower connector bank opening',cx,H*.875,W*.59,H*.135,34,14,well,1.6))
        for x in [W*.13,W*.87]:box('raised side moulding',x,cy,W*.08,H*(.70 if inverter else .60),32,7,blue,3)
        if pwm:
            box('PWM LCD bezel',cx,H*.35,W*.39,H*.22,32.1,2,well,2)
            lcd=mat('unpowered LCD polarizer',(.17,.22,.13),rough=.3,grain=0)
            box('PWM LCD glass',cx,H*.35,W*.35,H*.18,32.4,.3,lcd,.6)
            for x in [W*.35,W*.5,W*.65]:cyl('PWM navigation button',x,H*.51,35,W*.035,3,a['yellow'])
        elif inverter:
            vents(W*.25,H*.65,9,W*.062,W*.017,H*.045,32)
            for x in [W*.23,W*.77]:
                for y in [H*.09,H*.91]:
                    lug=box('inverter mounting ear',x,y,W*.11,H*.08,4,5,blue,1)
                    cut(lug,cyl('mounting ear bore',x,y,7,W*.020,9,well))
        else:
            for x in [W*.39,W*.50,W*.61]:cyl('status light unlit lens',x,H*.64,32.8,W*.017,.8,well)
            box('label mounting land',cx,H*.33,W*.51,H*.13,31.1,.2,blue,.5)
        for x,y in ports:
            bank=box('recessed terminal insulation',x,y,W*.125,H*.105,29,10,white,.9)
            cut(bank,box('clamping contact cavity',x,y,W*.079,H*.067,30,8,well,.8))
            box('dark terminal cavity floor',x,y,W*.080,H*.069,21,1,well,.4)
            box('tinned clamping plate',x,y+H*.020,W*.063,H*.018,23,1,chrome,.2)
            a['screw'](x,y,min(W,H)*.021,26,white)
    elif name=='solar-battery':
        box('sealed battery moulded container',cx,H*.48,W*.88,H*.76,25,57,white,4)
        box('battery lid seam',cx,H*.14,W*.89,H*.09,27,57,well,1.5)
        box('black sealed battery top lid',cx,H*.12,W*.89,H*.10,30,56,black,2)
        for i in range(6):cyl('sealed cell vent moulding',W*.18+i*W*.127,H*.115,30.6,W*.025,.5,black)
        box('battery generic label land',cx,H*.45,W*.67,H*.41,25.2,.4,white,1)
        for i,(x,y) in enumerate(ports):
            box('battery top terminal polarity moulding',x,y,W*.095,H*.07,31,4,a['red'] if i==0 else black,.7)
            # Direct top-lid terminal, without classroom extension leads.
            # Bent Faston blade, thin nickel-plated strip with retention hole.
            # The socket centre remains the existing top-lid electrical anchor.
            box('battery terminal blade foot',x,y+H*.030,W*.058,H*.025,33,4,chrome,.25)
            blade=box('battery Faston blade',x,y,W*.065,H*.080,35,1.1,chrome,.20)
            cut(blade,cyl('Faston retention hole',x,y,36,W*.008,3,well))
            box('dark battery blade backing',x,y,W*.036,H*.040,32.5,.7,black,.3)
