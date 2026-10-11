"""Original enclosed jaw crusher silhouette from current Retsch BB300 photo.

Service presentation exposes the motor's six winding studs separately from
machine feed. No exposed rollers, imaginary rotation or manufacturer branding.
"""
KEY = 'external-crusher'
SIZE = (240, 220)
TEXTURE_SCALE = 4
PORTS = ((97,174),(107,174),(117,174),(107,187),(117,187),(97,187))
EARTH_PORT = (130, 187)


def build(h, job):
    if job.get('key') != KEY or tuple(job.get('size', ())) != SIZE:
        raise ValueError('Crusher has a distinct body and terminal contract')
    grey = h.material('painted machine frame', (.16,.19,.21))
    ivory = h.material('powder coated hopper', (.79,.80,.77))
    satin = h.material('satin frame hardware', (.48,.52,.54), .75)
    h.box('crusher_pedestal', 109,177,116,49,31,62,grey,r=1.2)
    h.box('crusher_floor_base',109,205,136,9,45,85,grey,r=1)
    for x in (60,158):
        h.box('crusher_anchor_foot_'+str(x),x,209,22,5,49,7,satin,r=.5)
        h.cyl('anchor_bolt_'+str(x),x,209,51,2.2,2,satin)
    h.box('crusher_enclosed_chamber',103,111,91,75,57,72,grey,r=1.3)
    # Truncated hopper: open top, tapered side panels, no painted flat trapezoid.
    for side, coords in enumerate([
        [(53,13,12),(166,13,12),(140,56,25),(79,56,25)],
        [(53,13,66),(166,13,66),(140,56,49),(79,56,49)],
        [(53,13,12),(53,13,66),(79,56,49),(79,56,25)],
        [(166,13,12),(166,13,66),(140,56,49),(140,56,25)],
    ]):
        h.panel('hopper_panel_'+str(side),coords,ivory,1.1)
    h.box('hopper_dark_interior',109,31,76,24,33,1.5,h.well,r=.5)
    h.box('hopper_throat',109,67,57,31,50,48,ivory,r=1)
    # Belt transmission remains inside its safety housing.
    # Sample a closed cubic outline, not a visibly faceted seven-sided slab.
    segments = [
        ((145,73),(164,62),(179,74),(181,94)),
        ((181,94),(186,119),(200,157),(185,165)),
        ((185,165),(174,172),(153,139),(144,123)),
        ((144,123),(135,107),(132,82),(145,73)),
    ]
    outline = []
    for a,b,c,d in segments:
        for step in range(20):
            t = step / 20
            u = 1-t
            outline.append((u**3*a[0]+3*u*u*t*b[0]+3*u*t*t*c[0]+t**3*d[0],
                            u**3*a[1]+3*u*u*t*b[1]+3*u*t*t*c[1]+t**3*d[1],71))
    h.panel('closed_lateral_belt_guard',outline,ivory,22)
    h.box('front_service_plate',95,111,69,65,59,2,grey,r=.8)
    for x in (64,127):
        for y in (84,138): h.cyl(f'chamber_fastener_{x}_{y}',x,y,60.3,1.4,.8,satin)
    h.cyl('adjustment_shaft',86,126,63,5,5,grey)
    h.cyl('adjustment_handwheel',86,126,66,10,2,h.black)
    h.cut(h.cyl('handwheel_open_rim',86,126,69,11,2,satin),
          h.cyl('handwheel_rim_bore',86,126,72,8.6,8,h.well))
    for angle in (0,60,120):
        import math
        spoke = h.box('handwheel_spoke_'+str(angle),86,126,19,1.5,68,1.5,satin,r=.3)
        if hasattr(spoke, 'rotation_euler'):
            spoke.rotation_euler.z = math.radians(angle)
    h.box('machine_control_pod',126,105,15,24,67,8,ivory,r=1.5)
    h.cyl('control_stop_button',126,100,68,3,2,h.red)
    h.cyl('control_status_lens',126,111,68,2,1,h.black)
    # Accessible lower-side motor box for star/delta exercise; not six mains sockets.
    h.box('service_motor_box',113,180.5,54,39,71,23,ivory,r=2)
    h.box('service_terminal_board',113,180,45,25,72,2,h.black,r=1)
    h.cyl('protective_earth_insulator',*EARTH_PORT,73.5,3.5,1.4,h.terminal_gray)
    h.cyl('protective_earth_stud',*EARTH_PORT,75,2.4,1.2,satin)
    for i,(x,y) in enumerate(PORTS):
        h.cyl(f'winding_stud_insulator_{i}',x,y,73.5,3.5,1.4,h.terminal_gray)
        h.cyl(f'winding_stud_{i}',x,y,75,1.5,2.8,h.brass)
        h.cyl(f'winding_nut_{i}',x,y,74.8,2.4,1.2,satin)
        h.cut(h.box(f'winding_nut_ring_{i}',x,y,5,5,75,1.2,satin,r=.6),h.cyl(f'winding_nut_bore_{i}',x,y,77,1.15,6,h.well))
    for y in (160,171,183,195):
        for x in (56,162):h.cyl(f'pedestal_fastener_{x}_{y}',x,y,32,1.2,1,satin)
