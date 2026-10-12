"""Generic type-E AC receptacle and keyed two-pole DC connector.
Keep every saved contact coordinate; supply clamps are a maintenance projection.
No voltage/current rating, certification or fictitious screws on mating contacts.
"""
from lot_06_15_geometry import ring, screw

def build(h,key,s,service=False):
    white=h.material('socket moulded ivory',(.82,.83,.79),roughness=.3,coat=.12)
    inner=h.material('socket recessed satin',(.57,.60,.57),roughness=.42)
    steel=h.material('socket protective earth brass nickel',(.65,.68,.67),metallic=.88,roughness=.23)
    h.box('wall mounting base',60,60,100,104,8,14,h.black,r=5)
    h.box('moulded faceplate',60,60,100,104,18,10,white,r=7)
    ac=key=='power_socket_ac'
    if ac:
        h.cyl('recess black shadow',60,70,20,30,3,h.well)
        ring(h,'socket rim',60,70,22,32,29,10,white)
        h.cyl('receptacle bottom',60,70,20.3,28.8,1,inner)
        for x in (38.4,81.6):
            h.cyl('female contact recess '+str(x),x,78,21,5.3,.8,h.well)
            ring(h,'female socket sleeve '+str(x),x,78,21.2,4.2,3.1,1,steel)
        h.cyl('protective earth pin',60,54,30,3,10,steel)
        inputs=[31.2,60,88.8]
    else:
        h.box('keyed DC recess',60,87,52,30,20,3,h.black,r=4)
        h.box('polarisation key',60,74.5,8,5,22,2,white,r=.3)
        for x in (45.6,74.4):
            h.box('female insulated pocket '+str(x),x,90,9,10,22,.8,h.well,r=1)
            h.box('female copper contact '+str(x),x,90,3,6,22.3,.5,h.brass,r=.3)
        inputs=[45.6,74.4]
    # The supply entry row already belongs to the author's stable canvas.
    # Expose it as a maintenance view, rather than inventing another connector.
    for x in inputs:
        h.box('rear terminal housing '+str(x),x,12,12,9,22,4,h.black,r=1)
        screw(h,'wire clamp '+str(x),x,12,23,2.7)
    for x in (18,102): screw(h,'mounting screw '+str(x),x,106,19,1.5)
