"""Original studio meshes based on manufacturer photos; no photo textures."""
import math
import bpy


def cylinder(h,n,x,y,z,r,d,m,axis='z'):
    o=h.cyl(n,x,y,z,r,d,m)
    if axis!='z':
        o.location=(x,-y,z)
        o.rotation_euler=(math.pi/2,0,0) if axis=='y' else (0,math.pi/2,0)
    for p in o.data.polygons:p.use_smooth=len(p.vertices)==4
    return o


def ring(h,n,x,y,z,r,inside,d,m,axis='z'):
    count=64;v=[];f=[]
    for zz,rr in ((d/2,r),(d/2,inside),(-d/2,r),(-d/2,inside)):
        v.extend((rr*math.cos(i*math.tau/count),rr*math.sin(i*math.tau/count),zz) for i in range(count))
    for i in range(count):
        j=(i+1)%count
        f.extend(((i,j,count+j,count+i),(i,2*count+i,2*count+j,j),(count+j,3*count+j,3*count+i,count+i),(2*count+j,2*count+i,3*count+i,3*count+j)))
    mesh=bpy.data.meshes.new(n);mesh.from_pydata(v,[],f);mesh.update()
    o=bpy.data.objects.new(n,mesh);bpy.context.scene.collection.objects.link(o);o.location=(x,-y,z)
    o.rotation_euler=(math.pi/2,0,0) if axis=='y' else (0,math.pi/2,0) if axis=='x' else (0,0,0)
    for p in mesh.polygons:p.use_smooth=True
    return h._finish(o,n,m,.2)


def prism(h,n,outline,z,d,m,r=1):
    count=len(outline);v=[(x,-y,t) for t in (z,z-d) for x,y in outline]
    f=[tuple(reversed(range(count))),tuple(range(count,2*count))]
    f.extend((i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count))
    mesh=bpy.data.meshes.new(n);mesh.from_pydata(v,[],f);mesh.update()
    o=bpy.data.objects.new(n,mesh);bpy.context.scene.collection.objects.link(o)
    return h._finish(o,n,m,r)


def screw(h,n,x,y,z,r=1.1):
    h.cyl(n+'_washer',x,y,z,r*1.3,.3,h.steel)
    h.cyl(n,x,y,z+.5,r,.7,h.steel)
    h.box(n+'_slot',x,y,r*1.1,.25,z+.9,.12,h.well,r=.04)


def plate(h,n,x,y,z,w=22,hh=10):
    h.box(n,x,y,w,hh,z,.5,h.steel,r=.3)
    for i in range(4):h.box(n+'_engraving_'+str(i),x,y-hh*.28+i*hh*.16,w*.7,.2,z+.2,.1,h.black)


def motor(h,x,y,z,d,r,m,vertical=False):
    axis='y' if vertical else 'x';cylinder(h,'cast_motor_body',x,y,z,r,d,m,axis)
    for i in range(18):
        a=i*math.tau/18
        if vertical:h.box('motor_fin_'+str(i),x+math.cos(a)*(r+2),y,1.8,d*.85,z+math.sin(a)*(r+2),3.1,m,r=.4)
        else:h.box('motor_fin_'+str(i),x,y+math.cos(a)*(r+2),d*.85,1.8,z+math.sin(a)*(r+2),3.1,m,r=.4)
    if vertical:
        cylinder(h,'motor_fan_cover',x,y-d/2-3,z,r+1,9,m,axis)
        h.box('motor_foot',x,y+d/2+4,r*2+8,7,z+3,13,m,r=.6)
    else:
        cylinder(h,'motor_fan_cover',x+d/2+3,y,z,r+1,9,m,axis)
        for xx in (x-d*.26,x+d*.26):
            h.box('motor_foot_'+str(xx),xx,y+r+7,15,8,z+4,21,m,r=.5)
            screw(h,'motor_anchor_'+str(xx),xx,y+r+7,z+5,1.5)
    plate(h,'motor_rating_plate',x,y-r*.15,z+r+1,20,8)


def terminals(h,s):
    x,y,w,hh,z=s['box'];k=s.get('terminal_scale',1)
    rgb=(.85,.86,.83) if s['key'] in ('external-air-conditioner','external-freezer') else (.025,.03,.035) if s['key']=='external-computer' else (.16,.19,.20)
    m=h.material('service enclosure',rgb,roughness=.3,coat=.3)
    if s['key']=='external-iron' and not s['open']:return
    h.box('physical_terminal_enclosure',x,y,w,hh,z-2,13,m,r=1.2)
    h.box('terminal_cover_gasket',x,y,w-1,hh-1,z-1,.7,h.well,r=1)
    if s['open']:
        h.box('terminal_insulating_board',x,y,w-7,hh-6,z,.8,h.black,r=.7)
        for i,(px,py) in enumerate(s['ports']):
            pe=s['kind']!='dc' and i==len(s['ports'])-1
            if s['kind']=='ac3' and not pe:
                h.cyl('winding_insulator_'+str(i),px,py,z+1,3.1*k,1.4,h.terminal_gray)
                h.cyl('winding_stud_'+str(i),px,py,z+2,1.3*k,2,h.brass)
                h.bolt('winding_nut_'+str(i),px,py,z+3,2.1*k,h.brass)
            else:
                clamp=h.material('PE green clamp' if pe else 'clamp insulation',(.16,.42,.18) if pe else (.72,.73,.66))
                h.box('terminal_clamp_'+str(i),px,py,7*k,8*k,z+2,3,clamp,r=.35)
                screw(h,'clamp_screw_'+str(i),px,py,z+2.7,1.5*k)
    else:
        h.box('closed_terminal_cover',x,y,w-2,hh-2,z+1,2,m,r=1.1)
        for dx in (-w*.38,w*.38):
            for dy in (-hh*.33,hh*.33):screw(h,'cover_screw_'+str(dx)+'_'+str(dy),x+dx,y+dy,z+1.5,.8)
    h.box('terminal_cable_gland',x+w/2+1,y+hh*.22,5,8,z-5,8,h.black,r=1.4)
    for i in range(4):h.box('gland_rib_'+str(i),x+w/2+1,y+hh*.22-2.7+i*1.7,5.5,.5,z-1,.5,h.black,r=.1)


def air(h,s):
    m=h.material('warm moulded ABS',(.85,.86,.83),roughness=.22,coat=.38)
    h.box('rear_mount_chassis',160,74,280,87,24,27,h.terminal_gray,r=7)
    h.box('split_unit_shell',160,69,286,90,52,41,m,r=10)
    outline=[]
    for i in range(96):
        a=i*math.tau/96
        outline.append((160+142*math.copysign(abs(math.cos(a))**.16,math.cos(a)),65+35*math.copysign(abs(math.sin(a))**.16,math.sin(a)),54))
    h.domed_panel('curved_front_panel',outline,m,2,5)
    h.box('outlet_dark_cavity',159,106,258,13,51,4,h.well,r=3)
    for y in (102,106,110):h.box('outlet_louvre_'+str(y),156,y,247,2.5,54,3,m,r=.7)
    for x in range(48,280,14):h.box('direction_fin_'+str(x),x,106,.8,10,51,3,m,r=.2)
    for i in range(3):h.box('status_window_'+str(i),276+i*5,88,2.5,1.3,56,.2,h.terminal_gray,r=.4)
    for x in range(37,289,8):h.box('upper_intake_slot_'+str(x),x,27,4,1,43,1,h.black,r=.3)
    terminals(h,s)


def compressor(h,s):
    m=h.material('graphite powder coat',(.18,.22,.235),roughness=.3,coat=.3)
    blue=h.material('cyan enamel',(.015,.38,.56),roughness=.25,coat=.4)
    h.box('insulated_cabinet',119,110,183,177,58,82,m,r=1.5)
    h.box('bolted_top_panel',119,21,185,3,59,83,m,r=.5)
    h.box('door_gasket',139,110,120,174,59,1,h.black,r=.5)
    h.box('removable_door',139,110,118,172,60,1.3,m,r=.6)
    h.box('cyan_strip',91,110,9,172,62,.7,blue,r=.2)
    h.box('operator_panel',53,76,43,95,63,2,h.black,r=4)
    for x,y in ((40,34),(68,34),(39,119),(68,119),(194,36),(194,189)):screw(h,f'fastener_{x}_{y}',x,y,64,1.6)
    h.cyl('gauge_bezel',55,79,64,8.5,2,h.steel)
    h.cyl('gauge_dial',55,79,65,7.2,1,h.material('gauge ivory',(.86,.87,.81)))
    for i in range(13):
        a=math.pi*.8+i*math.pi*1.4/12
        h.tube('gauge_tick_'+str(i),[(55+5.5*math.cos(a),79+5.5*math.sin(a),65.2),(55+6.5*math.cos(a),79+6.5*math.sin(a),65.2)],.18,h.black)
    h.tube('gauge_zero_pointer',[(55,79,65.4),(51,82,65.4)],.3,h.black)
    h.cyl('stop_yellow_bezel',49,103,65,5.2,1,h.yellow)
    h.cyl('red_mushroom_stop',49,103,69,3.6,4,h.red)
    h.box('isolator_bezel',47,54,5,10,65,2,h.terminal_gray,r=.7)
    h.box('isolator_toggle',47,53,2.2,6,67,2,h.steel,r=.4)
    for x in (41,49,57,65):h.cyl('indicator_'+str(x),x,43,64,1.1,.3,h.terminal_gray)
    for x in range(109,188,3):h.box('roof_air_slot_'+str(x),x,27,1.2,6,61,.2,h.black,r=.2)
    for x in (48,187):h.box('rubber_foot_'+str(x),x,204,10,10,30,30,h.black,r=2)
    plate(h,'machine_nameplate',145,52,62,38,12);terminals(h,s)


def freezer(h,s):
    m=h.material('white stove enamel',(.86,.87,.84),roughness=.25,coat=.45)
    h.box('insulated_chest',160,121,273,135,64,92,m,r=2.5)
    h.box('lid_seal',160,53,276,3,65,94,h.terminal_gray,r=1)
    h.box('chest_lid',160,44,280,14,69,98,m,r=3)
    for x in (58,261):h.box('lid_hinge_'+str(x),x,49,9,15,-16,8,h.steel,r=.8)
    h.box('handle_recess',156,64,36,12,66,3,h.terminal_gray,r=2)
    h.tube('lid_handle',[(140,65,67),(140,62,73),(171,62,73),(171,65,67)],2,m)
    h.box('control_bezel',267,139,30,14,65,1,h.terminal_gray,r=1.5)
    h.box('control_glass',263,139,20,10,66,.5,h.black,r=.7)
    for y in (136,142):h.box('display_button_'+str(y),280,y,3,3,66,.7,m,r=.6)
    for x in range(225,288,4):h.box('compressor_vent_'+str(x),x,115,1.3,20,65,.5,h.terminal_gray,r=.4)
    h.cyl('drain_cap',47,174,66,3.5,2,m)
    for x in (47,274):h.box('foot_'+str(x),x,191,13,7,37,38,h.black,r=1.5)
    terminals(h,s)


def conveyor(h,s):
    alloy=h.material('anodized aluminium extrusion',(.58,.62,.64),.88,roughness=.24,anisotropic=.5)
    belt=h.material('polyurethane belt',(.76,.79,.75),roughness=.48)
    h.box('belt_deck',175,67,307,12,22,83,belt,r=5)
    for x in (22,328):cylinder(h,'end_drum_'+str(x),x,67,2,7,86,h.steel)
    for z in (-22,44):
        h.box('side_rail_'+str(z),175,85,314,20,z,4,alloy,r=.7)
        for yy in (81,89):h.box(f'extrusion_channel_{z}_{yy}',175,yy,294,1,z+.3,.8,h.terminal_gray,r=.2)
        h.box('belt_guide_'+str(z),175,59,302,7,z,3,alloy,r=.5)
    for x in (57,262):
        h.box('leg_'+str(x),x,153,13,112,25,13,alloy,r=.6)
        h.box('stand_slot_'+str(x),x,153,2,94,26,.5,h.terminal_gray,r=.3)
        h.box('floor_foot_'+str(x),x,211,31,6,34,40,h.black,r=1.2)
        screw(h,'stand_bolt_'+str(x),x,112,28,2)
    h.box('cross_brace',159,175,205,8,25,8,alloy,r=.4)
    for x in (31,52,298,319):
        h.box('bearing_plate_'+str(x),x,85,16,23,47,2,h.black,r=2)
        screw(h,'bearing_bolt_'+str(x),x,84,49,1.8)
    h.box('enclosed_gearbox',307,110,30,28,50,26,h.material('gearbox grey',(.35,.39,.41),.5),r=3)
    motor(h,293,163,37,42,21,h.material('drive blue',(.025,.13,.25),roughness=.26,coat=.3),True)
    terminals(h,s)


def iron(h,s):
    dark=h.material('graphite moulding',(.025,.035,.038),roughness=.23,coat=.4)
    teal=h.material('teal reservoir',(.005,.34,.37),roughness=.19,coat=.5)
    steel=h.material('ceramic soleplate',(.55,.59,.61),.8,roughness=.18)
    prism(h,'soleplate',[(23,149),(37,147),(209,146),(221,148),(215,154),(37,157)],45,9,steel,2)
    prism(h,'dark_base',[(26,147),(38,127),(72,112),(173,106),(207,115),(221,144),(215,151),(36,152)],62,36,dark,4)
    h.domed_panel('water_tank',[(x,y,64) for x,y in [(45,125),(74,101),(171,90),(201,109),(214,139),(52,143)]],teal,28,4)
    h.tube('open_arch_handle',[(48,125,49),(63,78,48),(89,44,47),(145,38,46),(183,58,46),(207,105,45),(212,140,44)],7,dark)
    h.tube('teal_handle_trim',[(49,124,56),(65,79,55),(91,45,54),(145,40,53),(181,60,53),(204,105,52),(210,137,51)],1.5,teal)
    h.box('steam_trigger',106,43,19,11,57,8,h.terminal_gray,r=3)
    h.box('spray_button',82,59,10,13,57,8,dark,r=2)
    h.cyl('thermostat_dial',124,106,67,13,3,dark)
    h.box('dial_grip',124,106,15,3,70,3,h.terminal_gray,r=1)
    for i in range(9):
        a=i*math.tau/12;h.cyl('dial_mark_'+str(i),124+16*math.cos(a),106+16*math.sin(a),67,.4,.2,h.steel)
    h.cyl('spray_nozzle',45,123,67,2,3,h.steel)
    h.box('status_lens',168,91,5,3,66,1,h.terminal_gray,r=1)
    h.tube('cord_strain_relief',[(205,80,36),(208,63,35),(211,56,35)],3,dark)
    for y in range(58,75,3):h.box('strain_relief_rib_'+str(y),209,y,7,1,37,3,dark,r=.5)
    for x in range(47,203,6):h.cyl('soleplate_steam_hole_'+str(x),x,152,67,.7,.3,h.well)
    terminals(h,s)


def computer(h,s):
    m=h.material('PC graphite polycarbonate',(.023,.029,.035),roughness=.28,coat=.2)
    h.box('monitor_rear',139,95,247,144,31,15,m,r=3)
    h.box('front_bezel',139,95,246,143,34,3,m,r=2)
    glass=h.material('dark display glass',(.003,.008,.016),roughness=.16,coat=.6)
    h.box('inactive_display',139,92,232,126,35,1,glass,r=.5)
    h.box('lower_chin',139,163,240,6,35,2,m,r=.8)
    h.box('webcam',139,20,44,7,32,10,m,r=2)
    h.cyl('lens_ring',139,20,34,2,1,h.steel);h.cyl('lens',139,20,35,1.3,.4,glass)
    h.box('privacy_slider',148,20,9,2,34,1,h.terminal_gray,r=.5)
    h.box('height_adjustable_stand',139,185,31,65,17,14,m,r=2)
    h.box('stand_spine',139,185,16,62,19,7,h.terminal_gray,r=1)
    h.box('monitor_base',139,218,125,5,37,58,m,r=2)
    h.box('red_accent',139,214,94,1,34,1,h.red,r=.3)
    h.cyl('power_key',251,162,36,1.7,.6,h.terminal_gray)
    for x in range(31,243,7):h.box('bottom_vent_'+str(x),x,167,3,1,22,4,h.black,r=.3)
    h.tube('supply_cable',[(236,155,20),(239,172,18),(229,185,19)],1.3,h.black)
    terminals(h,s)


def pump(h,s,single=False):
    m=h.material('blue cast enamel',(.04,.16,.31),roughness=.25,coat=.45)
    cx,cy=(65,112) if single else (72,119);r=48 if single else 56
    cylinder(h,'volute',cx,cy,36,r,38,m)
    cylinder(h,'volute_front_cover',cx,cy,57,r-3,3,m)
    ring(h,'suction_threaded_socket',cx-8,cy,66,15,11,12,h.steel)
    ring(h,'discharge_socket',cx+8,cy-r-9,32,14,10,24,h.steel,'y')
    h.tube('lower_cast_rib',[(cx-r*.65,cy+18,60),(cx-4,cy+31,61),(cx+r*.55,cy+26,60)],1.4,m)
    h.tube('upper_cast_rib',[(cx-r*.55,cy-21,60),(cx-6,cy-32,61),(cx+r*.6,cy-18,60)],1.4,m)
    for i in range(6):
        a=i*math.tau/6;screw(h,'volute_bolt_'+str(i),cx+(r-7)*math.cos(a),cy+(r-7)*math.sin(a),60,1.8)
    h.bolt('drain_plug',cx-9,cy+r-10,61,3,h.brass)
    h.box('volute_foot',cx,cy+r+5,r*1.4,7,40,44,m,r=.6)
    motor(h,173 if single else 204,112 if single else 119,19,101 if single else 117,30 if single else 34,m)
    if single:h.box('capacitor_housing',175,66,56,29,37,25,m,r=5)
    terminals(h,s)


def solar(h,s):
    dark=h.material('EC drive dark enamel',(.04,.055,.06),roughness=.28,coat=.3)
    steel=h.material('brushed stainless jacket',(.61,.64,.65),.95,roughness=.22,anisotropic=.6)
    motor(h,84,69,28,75,25,dark,True)
    ring(h,'motor_adapter_flange',84,115,28,31,18,7,steel,'y')
    cylinder(h,'stainless_multistage_housing',84,183,28,29,127,steel,'y')
    for y in (137,170,202,232):ring(h,'jacket_joint_'+str(y),84,y,28,29.3,28,1,h.steel,'y')
    for x in (60,108):h.tube('tie_rod_'+str(x),[(x,126,49),(x,246,49)],1.2,h.steel)
    h.box('pump_base',84,257,92,21,48,52,dark,r=3)
    ring(h,'water_inlet',51,249,57,12,8,13,steel);ring(h,'water_outlet',118,249,57,12,8,13,steel)
    for x in (49,119):
        h.box('floor_foot_'+str(x),x,275,22,6,46,40,dark,r=.6)
        screw(h,'anchor_'+str(x),x,274,48,2)
    plate(h,'rating_plate',84,186,58,23,24);terminals(h,s)


def mixer(h,s):
    m=h.material('blue mixer enamel',(.035,.22,.36),roughness=.26,coat=.4)
    steel=h.material('sanitary stainless',(.55,.60,.62),.95,roughness=.17,anisotropic=.35)
    for x in (47,152):
        h.box('chassis_foot_'+str(x),x,279,76,7,35,48,m,r=.7)
        for xx in (x-29,x+29):
            cylinder(h,'castor_'+str(xx),xx,287,34,5,7,h.black)
            h.box('castor_yoke_'+str(xx),xx,283,9,5,36,9,steel,r=.4)
    h.box('lifting_mast',155,140,13,256,12,17,m,r=.5)
    h.box('mast_guide_channel',155,140,3,237,22,1,h.black,r=.2)
    h.box('carriage',147,92,24,34,25,16,m,r=.6)
    h.box('motor_support_arm',116,45,77,8,25,16,m,r=.5)
    h.panel('triangular_gusset',[(148,46,26),(99,46,26),(148,72,26)],m,2)
    motor(h,83,85,26,57,23,m,True)
    h.box('support_plate',83,123,79,6,31,52,m,r=.6)
    for x in (57,109):
        h.tube('sanitary_rod_'+str(x),[(x,128,35),(x,254,35)],1.5,steel)
        h.bolt('rod_nut_'+str(x),x,129,37,2,steel)
    h.tube('drive_shaft',[(83,128,35),(83,257,35)],1.6,steel)
    cylinder(h,'high_shear_workhead',83,262,35,14,19,steel,'y')
    for i in range(9):h.box('workhead_port_'+str(i),72+i*2.7,264,1.3,8,48,.3,h.black,r=.3)
    ring(h,'workhead_ring',83,273,35,14,10,2,steel,'y')
    h.tube('safety_lifting_handle',[(63,54,37),(63,36,38),(83,33,38),(103,36,38),(103,54,37)],1.5,steel)
    h.box('lift_casing',162,197,23,48,30,23,m,r=3)
    h.tube('lift_handle',[(168,177,34),(185,174,34)],1.4,steel)
    h.box('lift_grip',183,174,12,4,36,6,h.black,r=1.5)
    for y in (56,89,145,246):screw(h,'mast_bolt_'+str(y),155,y,24,1.8)
    terminals(h,s)

BUILDERS={'external-air-conditioner':air,'external-compressor':compressor,'external-freezer':freezer,'external-conveyor':conveyor,'external-iron':iron,'external-mixer':mixer,'external-computer':computer,'external-pump-3p':pump,'external-pump-ac1':lambda h,s:pump(h,s,True),'external-solar-pump':solar}

def build(h,key,spec,service_open=False):BUILDERS[key](h,dict(spec,open=service_open,key=key))
