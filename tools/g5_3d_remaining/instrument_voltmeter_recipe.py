"""Original draft mesh for instrument-voltmeter, NOT a qualified render.

Proportions inspired by a handheld industrial multimeter. No brand labels,
approval badges or claims of manufacturer-equivalent measurement accuracy.
Only the COM and V/ohm probe sockets are drawn in this voltage-only model.
Blender render MUST remain blocked by the kit's verified=false contract gate.
"""
import math

KEY = 'instrument-voltmeter'
SIZE = (112, 152)
PHYSICAL_MM = {'height': 167.0, 'width': 84.0, 'depth': 46.0}


def build(h, job):
    if job.get('key') != KEY:
        raise ValueError('Voltmeter mesh cannot be reused as another instrument')
    w, height = job['size']
    if (w, height) != SIZE:
        raise ValueError('Re-export the current Canvas contract before changing size')

    cx, cy = w / 2, height / 2
    # Correct H/W ratio; the larger historic Canvas frame retains side gutters.
    logical_h = height - 4.0
    ratio = logical_h / PHYSICAL_MM['height']
    body_w = PHYSICAL_MM['width'] * ratio
    body_d = PHYSICAL_MM['depth'] * ratio

    h.box('body', cx, cy, body_w, logical_h, body_d, body_d,
          h.yellow, r=6.0)
    h.box('base', cx, cy, body_w - 4, logical_h - 4, body_d + 1, 8,
          h.black, r=6.0)
    cover = h.box('cover', cx, cy, body_w - 9, logical_h - 13, body_d + 4, 5,
          h.black, r=4.5)

    # Fixed LCD housing, with no baked simulated reading or fake 0 V.
    h.box('lcd_gasket', cx, 32, body_w - 18, 33, body_d + 7, 3,
          h.well, r=2.0)
    h.box('lcd_bezel', cx, 32, body_w - 21, 29, body_d + 8, 2,
          h.steel, r=1.6)
    h.box('lcd_glass', cx, 32, body_w - 25, 25, body_d + 9, 1,
          h.glass, r=1.2)

    for index, x in enumerate((cx - 21, cx - 7, cx + 7, cx + 21)):
        h.box(f'key_{index}', x, 56, 11.0, 5.3, body_d + 9, 3,
              h.yellow if index == 3 else h.terminal_gray, r=1.2)

    # Named moving parts. The selector's state and simulated numerical data
    # must be rendered separately from the immutable body artwork.
    h.cyl('selector_shaft', cx - 3, 91, body_d + 9, 21, 6, h.black)
    h.box('selector_grip', cx - 3, 91, 9, 29, body_d + 12, 3,
          h.terminal_gray, r=2)
    for index in range(11):
        angle = math.radians(180 + index * 18)
        x = cx - 3 + 26 * math.cos(angle)
        y = 91 + 26 * math.sin(angle)
        h.cyl(f'selector_detent_{index}', x, y, body_d + 8,
              0.9, 1.0, h.steel)

    # Voltage-mode leads are probe connections, not regular Component Terminals.
    # The optional A input on some reference instruments is deliberately absent.
    for index, (name, x, color) in enumerate((
            ('com', cx - 14, h.black), ('v_ohm', cx + 14, h.red))):
        y = height - 24
        # Actual Boolean socket well, with insulated annular surround.
        # Neither hole is a normal electrical TerminalId.
        plate_bore = h.cyl(f'cut_plate_{name}', x, y, body_d + 7,
                           4.5, 12.0, h.well)
        h.cut(cover, plate_bore)
        rim = h.cyl(f'terminal_housing_{name}', x, y, body_d + 6.3,
                    6.7, 3.0, color)
        ring_bore = h.cyl(f'cut_ring_{name}', x, y, body_d + 7,
                           4.1, 7.0, h.well)
        h.cut(rim, ring_bore)
        h.cyl(f'well_liner_{name}', x, y, body_d + 3.4,
              3.7, 1.5, h.well)
        h.cyl(f'contact_{index}', x, y, body_d + 3.5,
              1.3, 1.3, h.brass)
    # These positions are DRAFT artwork, not verified runtime hit regions.
