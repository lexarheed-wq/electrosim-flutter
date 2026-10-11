"""Original jaw crusher mesh, compared with BB300 manufacturer detail photos.

Normal presentation is enclosed. The optional service view exposes six winding
studs and PE; their location is pedagogical, not manufacturer-certified.
"""
import math

KEY = 'external-crusher'
SIZE = (240, 220)
TEXTURE_SCALE = 6
PORTS = ((97,174),(107,174),(117,174),(107,187),(117,187),(97,187))
EARTH_PORT = (130,187)


def build(h, job):
    if job.get('key') != KEY or tuple(job.get('size', ())) != SIZE:
        raise ValueError('Crusher has a distinct body and terminal contract')
    grey = h.material('graphite powder coated frame', (.085,.105,.112),roughness=.3,coat=.25)
    ivory = h.material('ivory powder coated sheet metal', (.79,.80,.77),roughness=.25,coat=.4)
    satin = h.material('machined steel', (.48,.52,.54), .95,roughness=.2,anisotropic=.35)
    dark = h.material('panel gasket', (.012,.016,.018))
    # Folded sheet metal pedestal, removable collector and bolted floor feet.
    h.box('crusher_pedestal',109,177,116,49,31,62,grey,r=.8)
    h.box('crusher_floor_base',109,205,136,9,45,85,grey,r=.6)
    h.box('collector_panel_gasket',109,176,108,41,32,1,dark,r=.5)
    h.box('removable_collector_panel',109,176,106,39,33,1,grey,r=.5)
    for x in (60,158):
        h.box('crusher_anchor_foot_'+str(x),x,209,22,5,49,7,satin,r=.5)
        h.cyl('anchor_washer_'+str(x),x,209,50,3,.6,satin)
        h.bolt('anchor_bolt_'+str(x),x,209,51,2.2,satin)
    # Jaw chamber has a narrow access door, seams, lifting brackets and latch.
    h.box('crusher_enclosed_chamber',103,111,91,75,57,72,grey,r=.7)
    h.box('front_door_gasket',81,111,44,72,58,1,dark,r=.3)
    h.box('front_access_door',81,111,42,70,59,1,grey,r=.3)
    for y in (80,93,106,119,132,144):
        for x in (62,100):
            h.cyl(f'door_washer_{x}_{y}',x,y,59.5,1.3,.3,satin)
            h.bolt(f'door_bolt_{x}_{y}',x,y,60,1,satin)
    for x in (71,105):
        h.tube('lifting_bracket_'+str(x),[(x,80,58),(x,73,61),(x+7,73,61),(x+7,80,58)],1.2,h.black)
    h.box('toggle_latch_base',107,90,4,11,61,2,satin,r=.3)
    h.box('toggle_latch_handle',107,89,2.2,8,63,2,h.red,r=.4)
    # Open hopper: folded lips, corner seams, tapered throat and mounting flange.
    hopper = [
        [(53,13,12),(166,13,12),(140,56,25),(79,56,25)],
        [(53,13,66),(166,13,66),(140,56,49),(79,56,49)],
        [(53,13,12),(53,13,66),(79,56,49),(79,56,25)],
        [(166,13,12),(166,13,66),(140,56,49),(140,56,25)],
    ]
    for side,coords in enumerate(hopper):
        h.panel('hopper_panel_'+str(side),coords,ivory,.8)
    for i,(a,b) in enumerate([
        ((53,13,12),(166,13,12)),((53,13,66),(166,13,66)),
        ((53,13,12),(53,13,66)),((166,13,12),(166,13,66)),
    ]):
        h.tube('hopper_folded_lip_'+str(i),[a,b],.65,ivory)
    # Inner baffle is below the opening, not a black rectangle floating inside it.
    h.panel('hopper_inner_baffle',[(83,43,28),(136,43,28),(136,48,43),(83,48,43)],dark,.6)
    h.box('hopper_throat',109,67,57,31,50,48,ivory,r=.5)
    h.box('hopper_mounting_flange',109,80,64,2.5,55,55,ivory,r=.4)
    for x in (81,137):
        h.bolt('hopper_flange_bolt_'+str(x),x,80,56,1.4,satin)
    # Two-piece enclosed belt cover. A narrow dark seam reveals its actual depth.
    segments = [
        ((145,73),(164,62),(179,74),(181,94)),
        ((181,94),(186,119),(200,157),(185,165)),
        ((185,165),(174,172),(153,139),(144,123)),
        ((144,123),(135,107),(132,82),(145,73)),
    ]
    outline = []
    for a,b,c,d in segments:
        for step in range(20):
            t=step/20; u=1-t
            outline.append((u**3*a[0]+3*u*u*t*b[0]+3*u*t*t*c[0]+t**3*d[0],
                            u**3*a[1]+3*u*u*t*b[1]+3*u*t*t*c[1]+t**3*d[1],71))
    # Screen Y is inverted by the mesh adapter. Reverse winding so Solidify
    # extrudes behind the front face, not towards the camera leaving an air gap.
    outline.reverse()
    h.panel('belt_guard_gasket',[(x,y,49) for x,y,z in outline],dark,1)
    h.domed_panel('closed_lateral_belt_guard',outline,ivory,21,6)
    for x,y in ((150,75),(185,156)):
        h.box(f'guard_retaining_tab_{x}',x,y,6,4,72,2,ivory,r=.3)
        h.bolt(f'guard_retaining_bolt_{x}',x,y,73,1.1,satin)
    # Manufacturer close-up: threaded spindle, SOLID handwheel and locking lever.
    h.cyl('adjustment_shaft_housing',79,130,69,6.2,11,grey)
    h.cyl('adjustment_threaded_spindle',79,130,87,2.7,18,satin)
    # Actual helical wire geometry makes threads visible in the palette view.
    helix=[]
    for step in range(321):
        a=step*math.tau/20
        helix.append((79+2.9*math.cos(a),130+2.9*math.sin(a),69+step*18/320))
    h.tube('adjustment_spindle_thread',helix,.33,satin)
    h.cyl('solid_adjustment_handwheel',79,130,90,8,3,h.black)
    h.cyl('handwheel_satin_edge',79,130,90.4,8.1,.5,satin)
    h.cyl('handwheel_face',79,130,91,7.2,.6,grey)
    h.cyl('handwheel_center',79,130,92,1.8,1,h.black)
    h.tube('handwheel_crank',[(74,127,91),(69,123,94)],1.1,satin)
    h.cyl('handwheel_crank_grip',69,123,99,2.2,6,h.black)
    h.tube('gap_locking_lever',[(83,131,70),(95,143,71)],1.5,satin)
    h.cyl('gap_locking_grip',95,143,74,3.1,4,h.black)
    # Calibrated slit scale, service fasteners and end covers.
    h.box('gap_scale_plate',104,131,33,12,62,1,satin,r=.3)
    h.box('gap_scale_slit',104,130,21,2,62.5,.5,h.well,r=.6)
    h.box('gap_scale_pointer',101,130,1.1,3,63,.5,grey)
    for x in (89,119): h.bolt('scale_bolt_'+str(x),x,127,63,1,satin)
    for x,y in ((119,142),(129,145),(134,135)):
        h.bolt(f'chamber_service_bolt_{x}_{y}',x,y,60,2.1,satin)
    # Front rotary isolator, stop control, glands and the two visible conduits.
    h.box('machine_control_pod',117,108,13,27,65,8,ivory,r=.7)
    h.cyl('rotary_isolator_bezel',117,106,67,4.3,2,h.black)
    h.box('rotary_isolator_handle',117,106,6.4,1.8,69,2,h.black,r=.4)
    h.cyl('stop_button_bezel',117,98,66,2.2,1,satin)
    h.cyl('control_stop_button',117,98,68,1.7,2,h.red)
    h.box('control_lower_gland',117,123,4,4,66,3,ivory,r=.5)
    h.tube('black_control_conduit',[(117,125,66),(116,145,64),(127,151,58),(132,150,48)],1.1,h.black)
    h.tube('grey_interlock_conduit',[(123,90,55),(130,112,57),(128,137,60),(121,145,61)],.9,satin)
    for y in (128,140):
        h.box('conduit_clip_'+str(y),116,y,3.7,1.6,66,1.5,grey,r=.3)
    # Rear drive housing stays behind the chamber, visible in perspective only.
    h.cyl('rear_motor_body',130,132,-16,17,29,grey)
    for i in range(10):
        h.cyl('rear_motor_cooling_fin_'+str(i),130,132,-18-i*2.2,18, .8,grey)
    h.cyl('rear_motor_fan_cover',130,132,-46,18,5,grey)
    # Closed service enclosure by default. Exposed winding studs are maintenance
    # only, and not asserted to reproduce the manufacturer's actual locations.
    h.box('service_motor_box',113,180.5,54,39,45,18,grey,r=.7)
    if job.get('service_open',False):
        h.box('service_terminal_board',113,180,45,25,46,2,h.black,r=1)
        h.cyl('protective_earth_insulator',*EARTH_PORT,47.5,3.5,1.4,h.terminal_gray)
        h.bolt('protective_earth_stud',*EARTH_PORT,49,2.4,satin)
        for i,(x,y) in enumerate(PORTS):
            h.cyl(f'winding_stud_insulator_{i}',x,y,47.5,3.5,1.4,h.terminal_gray)
            h.cyl(f'winding_stud_{i}',x,y,49,1.5,2.8,h.brass)
            h.bolt(f'winding_nut_{i}',x,y,49,2.4,satin)
    else:
        h.box('service_cover_gasket',113,180.5,53,38,46,.7,dark,r=.5)
        h.box('closed_service_cover',113,180.5,52,37,47,1,grey,r=.5)
        for x in (90,136):
            for y in (165,196):h.bolt(f'service_cover_bolt_{x}_{y}',x,y,48,1.1,satin)
        h.box('fixed_power_gland',140,185,5,8,39,9,h.black,r=1.4)
    for y in (160,171,183,195):
        for x in (56,162):h.bolt(f'pedestal_fastener_{x}_{y}',x,y,34,1.1,satin)
