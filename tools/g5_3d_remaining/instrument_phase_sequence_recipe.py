"""Original phase-rotation tester based on the official Fluke 9040 photo.

Three fixed upper cord exits, tall LCD, no multimeter selector or lower jacks.
No manufacturer logo or unqualified safety certification is reproduced.
"""
import math

KEY = 'instrument-phase-sequence'
SIZE = (112, 152)


def build(h, job):
    if job.get('key') != KEY or tuple(job.get('size', ())) != SIZE:
        raise ValueError('Phase tester requires its own layout')
    h.box('phase_impact_sleeve', 56, 76, 80, 146, 32, 32, h.yellow, r=6)
    h.box('phase_front_insert', 56, 64, 66, 111, 33.7, 2, h.black, r=3)
    h.box('phase_lcd_gasket', 56, 83, 54, 67, 34.7, 1.2, h.well, r=1.5)
    h.box('phase_lcd_glass', 56, 83, 50, 63, 35.2, .5, h.glass, r=1)
    for i, x in enumerate((34, 56, 78), 1):
        relief = h.cyl(f'phase_top_strain_relief_{i}', x, 7, 15, 3.5, 12, h.black)
        relief.location = (x, -7, 15)
        relief.rotation_euler.x = math.pi / 2
        cord = h.cyl(f'phase_fixed_lead_exit_{i}', x, 1, 15, 2, 10, h.black)
        cord.location = (x, -1, 15)
        cord.rotation_euler.x = math.pi / 2
    for side, x in [('left', 20), ('right', 92)]:
        for i in range(4):
            h.box(f'phase_grip_{side}_{i}', x, 128 + i * 4, 2, 2, 32.3, .6, h.yellow, r=.3)
