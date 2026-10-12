"""Original meshes of the last eleven devices and three energy-meter views.
Manufacturer images are references only, never redistributed as textures.
"""
import math
import bpy
from lot_06_15_geometry import cylinder, ring, prism, screw, plate, terminals


def label(h,name,text,x,y,z,size=3,material=None):
    curve=bpy.data.curves.new(name,'FONT');curve.body=text;curve.size=size
    curve.align_x='CENTER';curve.align_y='CENTER';curve.extrude=.01
    obj=bpy.data.objects.new(name,curve);bpy.context.scene.collection.objects.link(obj)
    obj.location=(x,-y,z);curve.materials.append(material or h.black)
    return obj


def wire(h,name,points,r,material):
    obj=h.tube(name,points,r,material)
    for p in obj.data.splines[0].bezier_points:
        p.handle_left_type='VECTOR';p.handle_right_type='VECTOR'
    return obj


def block(h,s,labels=None,always=False):
    """Electrical ports are clamps only where a real enclosed clamp is used."""
    x,y,w,hh,z=s['box']
    if not s['open'] and not always:return
    h.box('service_access_well',x,y,w,hh,z-2,4,h.well,r=1)
    if labels is None:
        labels=['L1','L2','L3','N'] if len(s['ports'])==4 else ['L1','L2','L3'] if len(s['ports'])==3 else ['L','N']
    for i,(px,py) in enumerate(s['ports']):
        if s['key'] in ('external-tv','external-refrigerator-dc','impedance'):
            # IEC contacts / DC blades / laboratory banana sockets: no screws.
            if s['key']=='impedance':
                ring(h,'banana_insulator_'+str(i),px,py,z+1,4.5,2.2,3,h.red if i==0 else h.black)
                ring(h,'banana_contact_'+str(i),px,py,z+2,2.2,1.3,2,h.brass)
            else:
                h.box('connector_contact_'+str(i),px,py,2.1,4.2,z+1,2,h.brass,r=.2)
        else:
            h.box('terminal_insulation_'+str(i),px,py,8,9,z+1,3,h.terminal_gray,r=.5)
            screw(h,'terminal_screw_'+str(i),px,py,z+2,1.7)
        label(h,'port_label_'+str(i),labels[i],px,py-7,z+2,2.5)


def refrigerator(h,s,dc=False):
    metal=h.material('brushed door stainless',(.61,.64,.66),.87,roughness=.32,anisotropic=0)
    dark=h.material('refrigerator graphite trim',(.025,.03,.034),roughness=.32)
    if dc:
        h.box('insulated_cabinet',90,116,152,198,48,76,dark,r=2)
        h.box('door_seal',90,113,143,187,50,2,h.black,r=1.5)
        h.box('stainless_door',90,116,137,179,54,4,metal,r=2)
        h.box('upper_latch_bezel',90,31,126,13,57,5,dark,r=2)
        h.box('handle_recess',90,34,56,6,58,1,h.well,r=1)
        for x in (24,156):h.box('integral_mount_flange_'+str(x),x,119,6,206,49,4,dark,r=.6)
        for x in (24,156):
            for y in (23,210):screw(h,f'mount_{x}_{y}',x,y,51,1.3)
        for x in range(31,153,6):h.box('compressor_vent_'+str(x),x,212,3,10,50,1,dark,r=.5)
        for x in (31,149):h.box('base_foot_'+str(x),x,217,14,6,29,38,dark,r=1)
        if s['open']:block(h,s,['+','−'])
        return
    h.box('insulated_body',100,159,174,280,56,80,h.terminal_gray,r=2.5)
    h.box('door_gasket',100,156,170,278,59,2,dark,r=1)
    for x in (57,143):
        h.box('upper_door_'+str(x),x,113,82,188,64,5,metal,r=2)
        hx=86 if x==57 else 114
        h.tube('door_handle_'+str(x),[(hx,57,66),(hx,63,73),(hx,178,73),(hx,184,66)],2.3,metal)
    h.box('lower_drawer',100,250,169,84,64,5,metal,r=2)
    h.tube('freezer_handle',[(34,218,65),(40,218,73),(160,218,73),(166,218,65)],2.3,metal)
    h.box('kickplate',100,298,168,8,51,4,dark,r=.5)
    for x in (29,171):h.box('adjustable_foot_'+str(x),x,303,10,9,38,40,dark,r=1)
    # Front maintenance is a cutaway projection of the rear connection area.
    # It is not an invented permanently visible front terminal enclosure.
    if s['open']:block(h,s,['L','N','PE'])


def tv(h,s):
    dark=h.material('screen moulded graphite',(.014,.018,.021),roughness=.23,coat=.25)
    metal=h.material('TV satin stand',(.23,.25,.27),.85,roughness=.27)
    glass=h.material('inactive OLED glass',(.003,.009,.016),roughness=.12,coat=.8)
    h.box('slim_display_body',180,105,332,188,23,9,dark,r=1.5)
    h.box('rear_electronics_cover',180,145,201,106,14,21,dark,r=3)
    h.box('screen_glass',180,104,324,180,24,.6,glass,r=.7)
    h.box('lower_bezel',180,197,328,3,25,1,dark,r=.5)
    h.box('stand_neck',180,205,100,24,7,17,metal,r=1)
    prism(h,'pedestal',[(112,215),(248,215),(257,231),(103,231)],25,43,metal,1)
    h.cyl('standby_lens',180,199,25,.8,.3,h.terminal_gray)
    for x in range(93,265,5):h.box('rear_vent_'+str(x),x,175,2,13,-6,.7,h.black,r=.2)
    for x in (140,220):
        for y in (130,164):screw(h,f'vesa_{x}_{y}',x,y,-8,1)
    if s['open']:block(h,s,['L','N'])


def fan_blades(h,x,y,z,r,n,mat):
    for i in range(n):
        a=i*math.tau/n
        points=[]
        for rr,theta,depth in ((r*.22,-.12,0),(r*.9,-.35,-5),(r,.12,2),(r*.4,.40,5)):
            points.append((x+rr*math.cos(a+theta),y+rr*math.sin(a+theta),z+depth))
        h.panel('impeller_blade_'+str(i),points,mat,1.2)
    h.cyl('impeller_hub',x,y,z+9,r*.23,13,h.black)
    h.cyl('hub_cap',x,y,z+10,r*.17,1,mat)


def fan(h,s,three=False):
    metal=h.material('fan satin aluminium',(.59,.64,.67),.86,roughness=.24)
    dark=h.material('fan enamel graphite',(.035,.047,.055),roughness=.26,coat=.3)
    if three:
        x,y,r=140,148,108
        ring(h,'duct_shell',x,y,22,r+6,r,83,metal)
        for zz in (-20,66):
            ring(h,'mount_flange_'+str(zz),x,y,zz,r+14,r-1,3,metal)
            for i in range(12):
                a=i*math.tau/12;screw(h,f'flange_{zz}_{i}',x+(r+9)*math.cos(a),y+(r+9)*math.sin(a),zz+2,1.7)
        # Motor and radial brackets remain behind the rotor.
        cylinder(h,'enclosed_motor',x,y,10,29,45,h.material('motor blue',(.025,.13,.25),roughness=.3))
        for i in range(4):
            a=i*math.tau/4
            wire(h,'motor_bracket_'+str(i),[(x+22*math.cos(a),y+22*math.sin(a),-7),(x+r*math.cos(a),y+r*math.sin(a),-7)],3,metal)
        fan_blades(h,x,y,39,101,7,metal)
        h.box('terminal_box_mount',140,40,25,31,72,22,metal,r=1)
        terminals(h,s)
    else:
        x,y,r=100,94,72
        ring(h,'circular_cage_rim',x,y,48,r,r-3,56,dark)
        fan_blades(h,x,y,39,64,3,metal)
        # Steel safety cage, actual round wires and radial ribs.
        for rr in (18,28,38,48,58,67):ring(h,'guard_ring_'+str(rr),x,y,66,rr,rr-.6,.9,metal)
        for i in range(24):
            a=i*math.tau/24
            wire(h,'guard_spoke_'+str(i),[(x+12*math.cos(a),y+12*math.sin(a),67),(x+71*math.cos(a),y+71*math.sin(a),64)],.55,metal)
        h.cyl('guard_center_badge',x,y,69,12,2,dark)
        for xx in (23,177):
            wire(h,'tilt_stand_'+str(xx),[(xx,87,22),(xx,193,22),(xx,215,42),(100,221,42)],3,dark)
            h.cyl('tilt_pivot_'+str(xx),xx,94,37,4,6,h.steel)
        h.box('integral_floor_base',100,220,169,9,36,40,dark,r=2)
        for xx in (27,173):h.box('rubber_pad_'+str(xx),xx,225,15,5,35,32,h.black,r=1)
        if s['open']:block(h,s,['L','N','PE'])


def resistor_bank(h,s,branches=1):
    metal=h.material('galvanized load enclosure',(.55,.59,.61),.88,roughness=.27,anisotropic=.4)
    ceramic=h.material('ceramic support',(.83,.79,.64),roughness=.43)
    w,hh=s['size'];cx=w/2
    h.box('resistor_base',cx,hh-25,w-34,6,26,67,metal,r=.7)
    for x in (25,w-25):h.box('mounting_lug_'+str(x),x,hh-22,19,9,29,25,metal,r=.6);screw(h,'base_anchor_'+str(x),x,hh-22,31,1.8)
    for i in range(branches):
        yy=42+i*(88/max(1,branches-1)) if branches>1 else 64
        cylinder(h,'ceramic_element_'+str(i),cx,yy,17,9,w-66,ceramic,'x')
        coil=[]
        for j in range(660):
            a=j*math.tau/12
            coil.append((34+(w-68)*j/659,yy+10*math.cos(a),17+10*math.sin(a)))
        h.tube('resistance_winding_'+str(i),coil,.5,h.steel)
        for xx in (31,w-31):
            h.box(f'ceramic_bracket_{i}_{xx}',xx,yy,18,29,27,39,metal,r=.5)
    for x in (23,w-23):
        h.box('side_guard_'+str(x),x,hh/2-2,2,hh-48,48,62,metal,r=.5)
        h.box('grille_side_frame_'+str(x),x,hh/2-13,3,hh-73,51,5,metal,r=.5)
    for yy in (24,hh-52):h.box('grille_frame_'+str(yy),cx,yy,w-44,3,51,5,metal,r=.5)
    # Ventilated grille above the hot elements; no glowing fake temperature.
    for x in range(30,w-26,7):h.box('vent_guard_'+str(x),x,hh/2-13,.65,hh-73,50,.7,metal,r=.15)
    for y in range(25,hh-46,9):h.box('guard_crossbar_'+str(y),cx,y,w-44,.65,50,.7,metal,r=.15)
    h.box('electrical_connection_compartment',s['box'][0],s['box'][1],s['box'][2]+8,s['box'][3]+6,s['box'][4]-2,17,metal,r=.8)
    if not s['open']:h.box('connection_lid',s['box'][0],s['box'][1],s['box'][2]+6,s['box'][3]+4,s['box'][4],1,metal,r=.7)
    block(h,s)
    for x in (s['box'][0]-s['box'][2]*.4,s['box'][0]+s['box'][2]*.4):screw(h,'lid_fastener_'+str(x),x,s['box'][1]+s['box'][3]*.4,s['box'][4]+1,1)
    label(h,'hot_surface_warning','!',31,35,52,8,h.yellow)
    if branches==3:label(h,'coupling_mark','Y' if s['key']=='load-wye-3p' else 'Δ',cx,hh-56,52,9)


def grid(h,s):
    white=h.material('painted electrical cabinet',(.74,.77,.78),roughness=.25,coat=.25)
    dark=h.material('insulated cabinet trim',(.04,.06,.075),roughness=.33)
    h.box('distribution_cabinet',100,138,167,245,54,57,white,r=2)
    h.box('door_seal',100,130,155,218,56,1,dark,r=.8)
    h.box('cabinet_door',100,130,152,214,58,2,white,r=1)
    h.box('viewing_window_bezel',100,79,112,63,60,2,dark,r=1.5)
    h.box('inspection_glass',100,79,103,55,61,.6,h.material('smoked glass',(.04,.08,.1),roughness=.13,coat=.7),r=1)
    for x in (67,88,109,130):
        h.box('visible_switch_pole_'+str(x),x,81,17,40,62,2,h.terminal_gray,r=.8)
        h.box('pole_handle_'+str(x),x,88,10,12,63,1,h.black,r=.7)
    h.box('door_lock',163,146,5,19,61,4,h.steel,r=1)
    for y in (44,204):h.box('door_hinge_'+str(y),22,y,6,19,59,3,h.steel,r=.7)
    h.box('lower_terminal_cover',100,236,135,40,60,4,white,r=.8)
    for x in (42,158):screw(h,'cover_screw_'+str(x),x,249,62,1.3)
    block(h,s)
    label(h,'voltage_warning','400 V',100,144,60,6)
    label(h,'electrical_danger','⚡',100,172,60,14,h.yellow)


def alternator(h,s):
    green=h.material('alternator green enamel',(.15,.29,.24),roughness=.26,coat=.35)
    alloy=h.material('alternator machined flange',(.50,.55,.56),.88,roughness=.25)
    cylinder(h,'generator_body',209,146,25,69,203,green,'x')
    cylinder(h,'coupling_bellhousing',102,146,25,87,30,green,'x')
    cylinder(h,'drive_flange',84,146,25,87,8,alloy,'x')
    cylinder(h,'coupling_recess',79,146,25,70,2,h.black,'x')
    cylinder(h,'drive_shaft',62,146,25,13,40,h.steel,'x')
    for i in range(8):
        a=i*math.tau/8
        cylinder(h,'flange_bolt_'+str(i),78,146+77*math.cos(a),25+77*math.sin(a),2.5,4,h.steel,'x')
    for xx in (109,295):
        for yy in range(109,182,5):h.box(f'vent_{xx}_{yy}',xx,yy,13,2,84,.7,h.black,r=.5)
    for xx in (156,265):
        h.box('cast_foot_neck_'+str(xx),xx,217,20,21,45,40,green,r=1)
        h.box('cast_foot_'+str(xx),xx,231,38,10,52,56,green,r=.8)
        screw(h,'mount_bolt_'+str(xx),xx,231,54,2.5)
    h.box('top_terminal_housing',242,65,113,49,79,54,green,r=3)
    for xx in (194,290):
        for yy in (45,83):screw(h,f'hood_{xx}_{yy}',xx,yy,81,1.6)
    block(h,s)
    ring(h,'lifting_eye',155,72,30,7,4,4,alloy)
    plate(h,'rating_plate',221,145,96,45,17)


def impedance(h,s):
    metal=h.material('impedance instrument case',(.37,.42,.46),.84,roughness=.26)
    h.box('laboratory_case',90,62,151,99,36,37,metal,r=2)
    h.box('front_panel',90,65,143,88,39,2,h.terminal_gray,r=1)
    h.box('marking_panel',90,50,105,40,40,.5,h.material('cream engraved panel',(.82,.83,.77)),r=.6)
    label(h,'impedance_symbol','Z',90,48,41,15)
    label(h,'impedance_formula','R + jX',90,68,41,5)
    for xx in (21,159):
        for yy in (22,104):screw(h,f'panel_{xx}_{yy}',xx,yy,41,1.1)
    # Banana sockets on the front panel, not screw studs or decorative legs.
    block(h,s,['1','2'],always=True)
    for xx in range(40,148,5):h.box('upper_cooling_slot_'+str(xx),xx,14,2,3,29,.8,h.black,r=.2)
    for xx in (26,154):h.box('integral_rubber_foot_'+str(xx),xx,113,13,5,25,28,h.black,r=.8)


def meter(h,s):
    w,hh=s['size'];x=w/2
    ivory=h.material('meter moulded ivory',(.81,.83,.80),roughness=.23,coat=.3)
    dark=h.material('meter smoked bezel',(.028,.05,.06),roughness=.19,coat=.45)
    h.box('DIN_back_shell',x,90,w-10,168,18,37,ivory,r=1)
    h.box('DIN_front_shell',x,90,w-8,120,33,15,ivory,r=1.5)
    h.box('LCD_bezel',x,75,w-19,48,35,2,dark,r=1)
    h.box('LCD_glass',x,75,w-25,39,36,.5,h.material('inactive LCD glass',(.22,.34,.29),roughness=.16,coat=.4),r=.5)
    # Values are drawn by Flutter as crisp text from real energy registers.
    for px,py in s['ports']:
        h.cyl(f'recess_{px}_{py}',px,py,24,5,2,h.well)
        screw(h,f'clamp_{px}_{py}',px,py,25,2.4)
    for yy in (23,157):
        if not s['open']:
            h.box('transparent_terminal_shield_'+str(yy),x,yy,w-12,19,29,2,h.material('terminal cover tint',(.51,.56,.56),roughness=.16,coat=.6),r=.5)
        for xx in (7,w-7):screw(h,f'seal_{xx}_{yy}',xx,yy,31,1)
    h.cyl('navigation_button',x,114,36,4,2,dark)
    h.cyl('pulse_LED',x,105,35,1.4,.5,h.red)
    label(h,'meter_unit','kWh',x,137,35,5)
    label(h,'meter_voltage','3 × 230/400 V' if w>100 else '230 V',x,47,35,3)
    for i,(px,py) in enumerate(s['ports']):
        poles=len(s['ports'])//2
        name=(['L1','L2','L3','N'] if poles==4 else ['L','N'])[i%poles]
        label(h,'meter_port_'+str(i),name,px,py+(10 if py<90 else -10),33,3)
    h.box('DIN_locking_clip',x,174,w*.55,6,-8,8,h.yellow,r=.5)

BUILDERS={'external-refrigerator':refrigerator,'external-refrigerator-dc':lambda h,s:refrigerator(h,s,True),'external-tv':tv,'external-fan-ac1':fan,'external-fan-3p':lambda h,s:fan(h,s,True),'pv-resistive-load':resistor_bank,'source-ac3-grid':grid,'source-ac3-alternator':alternator,'load-wye-3p':lambda h,s:resistor_bank(h,s,3),'load-delta-3p':lambda h,s:resistor_bank(h,s,3),'impedance':impedance,'energy-meter-ac1':meter,'energy-meter-ac3':meter,'energy-meter-pv':meter}
def build(h,key,spec,service_open=False):BUILDERS[key](h,dict(spec,open=service_open,key=key))
