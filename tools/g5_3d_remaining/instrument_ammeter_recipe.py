"""G5 component 02: ORIGINAL current-meter enclosure, Blender Cycles.
Never use a manufacturer's image as a rendered texture.
The two plugs are ProbeConnection AMP/COM, NOT ordinary TerminalIds.
"""
import math

KEY = 'instrument-ammeter'
SIZE = (112, 152)

def build(h, job):
    if job.get('key') != KEY or tuple(job.get('size', ())) != SIZE:
        raise ValueError('Ammeter geometry contract mismatch')
    cx, cy = 56, 76
    width, height, depth = 75, 148, 41
    h.box('body', cx, cy, width, height, depth, depth,
          h.yellow, r=6)
    h.box('base', cx, cy, width - 3, height - 3, depth + .9, 7,
          h.black, r=5.0)
    cover = h.box('cover', cx, cy, width - 8, height - 12, depth + 4, 5.1,
          h.black, r=4.0)
    h.box('lcd_gasket', cx, 33, width - 17, 32, depth + 7, 2.8,
          h.well, r=2.1)
    h.box('lcd_bezel', cx, 33, width - 21, 28, depth + 8, 1.8,
          h.steel, r=1.6)
    h.box('lcd_glass', cx, 33, width - 25, 24, depth + 9, 1,
          h.glass, r=1.2)
    for i, x in enumerate((35, 49, 63, 77)):
        h.box(f'key_{i}', x, 56, 11, 5.3, depth + 9,
              3, h.yellow if i == 3 else h.terminal_gray, r=1.1)
    # The selector grip will be painted dynamically in Flutter.
    h.cyl('selector_shaft', 53, 86, depth + 9, 21, 6, h.black)
    h.box('selector_grip', 53, 86, 9, 29, depth + 12, 3,
          h.terminal_gray, r=2)
    for i in range(11):
        theta = math.radians(180 + 18 * i)
        h.cyl(f'selector_detent_{i}', 53 + 26 * math.cos(theta),
              86 + 26 * math.sin(theta), depth + 8, .9, 1, h.steel)
    # Recessed connector pair differs from V/ohm meter: fused A and COM.
    for i, (name, x, material) in enumerate((
            ('com', 42, h.black), ('current_a', 70, h.red))):
        y = 128
        drill = h.cyl(f'cut_plate_{name}', x, y, depth + 7,
                      4.7, 12, h.well)
        h.cut(cover, drill)
        surround = h.cyl(f'terminal_housing_{name}', x, y,
                         depth + 6.4, 7, 3, material)
        bore = h.cyl(f'cut_ring_{name}', x, y, depth + 7, 4.1, 7,
                     h.well)
        h.cut(surround, bore)
        h.cyl(f'well_liner_{name}', x, y, depth + 3.4, 3.6, 1.4,
              h.well)
        h.cyl(f'contact_{i}', x, y, depth + 3.5, 1.3, 1.3,
              h.brass)
    # Physically distinct front fuse cover, not a painted "A" label only.
    h.box('fuse_hatch', 53, 114, 29, 8.5, depth + 10,
          1.5, h.terminal_gray, r=1.3)
    for i, x in enumerate((42, 64)):
        h.cyl(f'fuse_fastener_{i}', x, 114, depth + 11.4,
              1.1, .7, h.steel)
    for i, x in enumerate((28, 84)):
        h.cyl(f'casing_fastener_{i}', x, 139, depth + 5.4,
              1.6, .8, h.steel)
