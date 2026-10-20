"""Sequential real Cycles renders of the authorized ten-component lot.
blender -b --factory-startup -t 4 --python-exit-code 1 --python THIS -- --out build/g5_lot_06_15
"""
import argparse,hashlib,json,math,sys,time
from pathlib import Path
import bpy
from mathutils import Vector,Matrix
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_voltmeter_cycles import CyclesGeometry
from lot_06_15_geometry import build
from unified_geometry_contract import MANIFEST_PATH, load_lot_contract
BASE=Path(__file__).resolve().parent

def light(scene,name,loc,target,power,w,hh):
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='RECTANGLE';data.size=w;data.size_y=hh
    o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);o.location=loc
    o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()

def main():
    a=argparse.ArgumentParser();a.add_argument('--out',required=True);a.add_argument('--only');a.add_argument('--samples',type=int,default=32);a.add_argument('--lot',default='06_15',choices=['06_15','16_26','sockets']);opts=a.parse_args(sys.argv[sys.argv.index('--')+1:])
    assert 16<=opts.samples<=256
    contract_file=BASE/f'lot_{opts.lot}_contract.json'
    geometry_file=BASE/f'lot_{opts.lot}_geometry.py'
    contract=load_lot_contract(opts.lot)
    manifest_sha=hashlib.sha256(MANIFEST_PATH.read_bytes()).hexdigest()
    builder=build
    if opts.lot=='16_26':
        from lot_16_26_geometry import build as builder
    if opts.lot=='sockets':
        from lot_sockets_geometry import build as builder
    geometry_sha=hashlib.sha256(geometry_file.read_bytes()).hexdigest()
    for key,s in contract.items():
        if opts.only and key not in opts.only.split(','):continue
        folder=Path(opts.out)/key;folder.mkdir(parents=True,exist_ok=True);start=time.monotonic();records={}
        views=[('front',False),('palette',False),('service',True)]
        moving_fan=opts.lot=='16_26' and key in ('external-fan-ac1','external-fan-3p')
        if moving_fan:views.extend([('rotor',False),('guard',False)])
        if moving_fan and key=='external-fan-3p':views.append(('guard-service',True))
        for view,service in views:
            bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
            # Reset orphaned datablocks between components to bound memory.
            for collection in (bpy.data.meshes,bpy.data.curves,bpy.data.materials,bpy.data.cameras,bpy.data.lights):
                for block in list(collection):
                    if block.users==0:collection.remove(block)
            scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=opts.samples;scene.cycles.use_denoising=True;scene.cycles.denoiser='OPENIMAGEDENOISE'
            scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.resolution_percentage=100
            w,hh=s['size'];scene.render.resolution_x=w*4;scene.render.resolution_y=hh*4
            scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast';scene.view_settings.exposure=.15
            scene.world.use_nodes=True;nodes=scene.world.node_tree.nodes;bg=nodes.get('Background')
            env=nodes.get('lot HDR') or nodes.new('ShaderNodeTexEnvironment');env.name='lot HDR';env.image=bpy.data.images.load(str(BASE.parent/'g5_render_environment/studio_small_09_1k.hdr'),check_existing=True)
            scene.world.node_tree.links.new(env.outputs['Color'],bg.inputs['Color']);bg.inputs['Strength'].default_value=.42
            h=CyclesGeometry();builder(h,key,s,service)
            if opts.lot=='16_26':
                # Explicit brushing direction avoids the star-shaped tangent
                # singularity in the centre of broad flat stainless panels.
                for mat in bpy.data.materials:
                    if mat.use_nodes:
                        node=mat.node_tree.nodes.get('Principled BSDF')
                        if node and node.inputs['Anisotropic'].default_value>0:
                            node.inputs['Tangent'].default_value=(0,1,0)
            if moving_fan and view!='palette':
                for obj in bpy.data.objects:
                    rotor=obj.name.startswith('impeller_') or obj.name=='hub_cap'
                    guard=(obj.name.startswith('guard_') or obj.name=='circular_cage_rim') if key=='external-fan-ac1' else not(rotor or obj.name=='enclosed_motor' or obj.name.startswith('motor_bracket_'))
                    obj.hide_render=rotor if view in ('front','service') else not rotor if view=='rotor' else not guard
            for o in bpy.data.objects:
                if o.type=='MESH':
                    for mod in o.modifiers:
                        if mod.type=='BEVEL':mod.segments=5;mod.harden_normals=True
                    mod=o.modifiers.new('weighted machining normals','WEIGHTED_NORMAL');mod.keep_sharp=True
            target=(w/2,-hh/2,25);unit=max(w,hh)/240;energy=unit*unit
            light(scene,'large key',(-w*.15,-hh*.15,280*unit),target,90000*energy,100*unit,180*unit)
            light(scene,'reflection strip',(w*1.15,-hh*.7,180*unit),target,65000*energy,25*unit,200*unit)
            light(scene,'top rim',(w*.5,-hh*1.3,120*unit),target,65000*energy,160*unit,40*unit)
            light(scene,'front fill',(w*.5,hh*.15,220*unit),target,25000*energy,150*unit,100*unit)
            data=bpy.data.cameras.new('front aligned physical camera');data.type='ORTHO';data.clip_end=3000
            cam=bpy.data.objects.new('front aligned physical camera',data);scene.collection.objects.link(cam);scene.camera=cam
            yaw,pitch=(-24,-16) if view=='palette' else (0,0)
            cy,sy=math.cos(math.radians(yaw)),math.sin(math.radians(yaw));cp,sp=math.cos(math.radians(pitch)),math.sin(math.radians(pitch))
            right=Vector((cy,0,sy));up=Vector((-sp*sy,cp,sp*cy));back=Vector((-cp*sy,-sp,cp*cy))
            cam.rotation_euler=Matrix((right,up,back)).transposed().to_euler();cam.location=Vector((w/2,-hh/2,0))+back*1000
            data.ortho_scale=max(w,hh)*(1.18 if view=='palette' else 1)
            scene.render.filepath=str(folder/(view+'.png'));bpy.ops.render.render(write_still=True)
            records[view+'.png']={'sha256':hashlib.sha256((folder/(view+'.png')).read_bytes()).hexdigest(),'size':[w*4,hh*4]}
        (folder/'provenance.json').write_text(json.dumps({'key':key,'images':records,'samples':opts.samples,'blender':bpy.app.version_string,'seconds':round(time.monotonic()-start,2),'render_metadata_sha256':hashlib.sha256(contract_file.read_bytes()).hexdigest(),'manifest_sha256':manifest_sha,'geometry_sha256':geometry_sha,'actual_flutter_capture':False},indent=2)+'\n')
        print('COMPLETED '+key,flush=True)
if __name__=='__main__':main()
