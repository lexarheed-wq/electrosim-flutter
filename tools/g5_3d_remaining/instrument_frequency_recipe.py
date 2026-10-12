"""Component 03: dedicated frequency instrument, not a relabelled ammeter.

Handheld shielded banana sockets at the established probe coordinates. Neutral
industrial design inspired by the downloaded Fluke handheld family reference;
no brand, safety certification or fabricated readings are included in artwork.
"""
KEY = 'instrument-frequency'
SIZE = (112, 152)
BODY_DEPTH = 35.0


def build(h, job):
    if job.get('key') != KEY or tuple(job.get('size', ())) != SIZE:
        raise ValueError('Frequency mesh requires its own 112x152 contract')
    sleeve = h.material('blue impact sleeve', (.045, .20, .37))
    h.box('frequency_body', 56, 76, 80, 148, 35, 35, sleeve, r=6)
    cover = h.box('frequency_front_cover', 56, 76, 71, 137, 37, 3,
                  h.black, r=4)
    h.box('frequency_lcd_gasket', 56, 38, 66, 37, 39, 2, h.well, r=2)
    h.box('frequency_lcd_bezel', 56, 38, 63, 34, 41, 2, h.steel, r=1.5)
    h.box('frequency_lcd_glass', 56, 38, 60, 31, 42, .8, h.glass, r=1)
    for name, x, material in [('hold', 35, h.terminal_gray),
                             ('power', 56, sleeve), ('light', 77, h.yellow)]:
        h.box(f'frequency_key_{name}', x, 78, 15, 8, 41, 4, material, r=1.5)
    for x in (26, 86):
        for y in (91, 98, 105):
            h.box('moulded_grip_rib', x, y, 2.5, 4, 38.5, 1,
                  sleeve, r=.5)
    for name, x, material in [('com', 42, h.black), ('hz', 70, h.red)]:
        h.cut(cover, h.cyl(f'frequency_cover_bore_{name}', x, 128, 42, 4.5, 12, h.well))
        rim = h.cyl(f'frequency_socket_{name}', x, 128, 40, 6.7, 3, material)
        h.cut(rim, h.cyl(f'frequency_socket_bore_{name}', x, 128, 44, 4.1, 10, h.well))
        h.cyl(f'frequency_liner_{name}', x, 128, 36, 3.7, 1.5, h.well)
        h.cyl(f'frequency_contact_{name}', x, 128, 36.3, 1.3, .5, h.brass)
