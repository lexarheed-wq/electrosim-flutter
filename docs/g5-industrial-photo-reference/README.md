# Industrial rendering from product photo references

This iteration replaces the generic housings with original Blender/Cycles meshes. Product photographs were downloaded for visual study and are kept outside the repository. The distributed PNGs are renders of our own meshes, not those photographs.

## Reference observations

| Family | Downloaded reference | Geometry used |
| --- | --- | --- |
| Single-pole breaker | [Acti9 A9F74116](https://t03391.vtexassets.com/arquivos/ids/200002/A9F74116.jpg?v=638773788768500000) | Narrow pole, stepped casing, recessed terminal wells |
| Three-pole breaker | [Acti9 A9F74316](https://www.elec-fournitures.com/938-large_default/a9f74316-schneider-ic60n-disjoncteur-triphase-16a-3p-courbe-c-6-10ka-bornes-a-vis-acti9-ic60.jpg) | Curved white rockers, linked dark bridge, green mechanical windows, yellow DIN clips |
| Contactor | [TeSys LC1D18](https://assets.cef.co.uk/images/pdg/tele_lc1d18v7-c/original/tele_lc1d18v7-c.jpg) | Stacked shoulders, graphite power terminal banks, white label land and operating window |
| Thermal overload | [LRD16](https://mm.digikey.com/Volume0/opasdata/d220001/medias/images/5753/MFG_LRD16.jpg) | Compact graphite case, setting dial, blue reset and red stop |
| Green pushbutton | [Harmony XB4BA31](https://assets.cef.co.uk/images/pdg/tele_xb4ba31/original/tele_xb4ba31.jpg) | Satin flat face, chrome bezel, cast mounting collar and fixing ears |
| Red pushbutton | [Harmony XB4BA42](https://eegsa.com.mx/cdn/shop/files/bf34f826ab1311db75630b55895b5a16.jpg?v=1720317944) | Red satin face with the same mounting construction |
| Three-phase motor | [WEG W22](https://static.weg.net/medias/images/h73/hb6/MKT_WMO_EU_IMAGE_3PHASE_W22_RAL5009_TEFC_160A200_B3D_IE3_1200Wx1200H.jpg) | Radial cooling fins, bolted end shields, ventilated rear hood, keyed shaft, drilled feet and compact open side terminal box with M6 brass nuts |

These are generic ElectroSim components, not manufacturer-validated digital twins. Shapes are adapted to the existing simulation terminal contract: the LRD-like model retains six power ports; the contactor retains its established coil ports. Additional real-product auxiliary contacts are not invented in the simulation. The live replacement is limited to the 12 shapes in these industrial families. Other catalogue entries retain their existing native drawings; their generic experimental plates are not enabled. This avoids replacing unmatched components with less faithful drawings.

## Lighting and scale correction

The clear A60 reference was downloaded from [Bailey 24 V](https://www.lampco.co.uk/cdn/shop/products/G27024060_b6600ac4-d122-485c-828c-060ff7f1e0dd.jpg?v=1595506847), with a separate [Philips dimension sheet](https://www.docs.signify.com/assets/Leaflet/Philips_PROF/FP/en_AA/920021020517_EU.en_AA.PROF.FP.pdf): Ø60×107.5 mm. [Lightspares porcelain holder photographs](https://www.lightspares.co.uk/products/e27-porcelain-ceramic-batten-fixed-mount-e27-lampholder) show cylindrical ceramic, slotted mounting ears and two brass terminal blocks underneath. These informed the original pear-shaped glass, visible tungsten filament, E27 helical base and integrated holder terminal pockets. No LED electronics are substituted for the existing incandescent electrical model. Live filament intensity keeps the existing squared normalized-voltage behavior; the commercial product's power is not imposed on the simulation.

The comprehensive [catalogue comparison](catalogue-comparison.md) distinguishes all 74 entries, downloaded photos, concrete dimensions and unresolved references. `photo-downloads.json` documents actual downloads, without bundling commercial photographs.

## Runtime

- One front camera preserves all Canvas coordinates. A second orthographic camera at 24° yaw / 16° pitch produces the palette perspective.
- Static PBR geometry is rendered once offline. Flutter decodes and caches the shared images once at startup; adding components does not allocate another texture copy or start a real-time 3D renderer. Global animation phase changes do not repaint stationary breakers/contactors/buttons; the energized motor retains its live animation.
- Breaker rockers and pushbutton caps have separate physically rendered transparent layers. The rocker has OFF, ON and trip poses rendered with a physical pivot rotation; Dart interpolates those layers from the existing state parameters; ON/OFF/trip flags, coil state, display measurements and rotating shaft marks remain live.
- A model is enabled only after both cameras and its required control layers have loaded. Missing or corrupt images retain that model's existing native drawing.
- Electrical models and terminal IDs are preserved. The motor uses a shared Canvas/native side-box geometry; its approximate industrial envelope is 750×430 board units, compared with a 120×180 three-pole breaker. This is a coherent visual scale, not a manufacturer-specific dimensional certificate. The A60 lamp with holder is 130×260. Initial placement accounts for different envelopes. Legacy saved motor/lamp sizes are migrated while positions/rotations remain; old paths are invalidated and rerouted. Existing DIN rails remain enabled for eligible components.

## Reproduction

Use official Blender 4.5 LTS with Cycles/OpenImageDenoise and Python/Pillow available. The CC0 studio HDR used for metal reflections is included in `tools/g5_render_environment/` and is not bundled into Flutter:

```sh
blender -b --factory-startup -t 4 --python tools/render_g5_industrial.py
cd apps/electrosim
flutter pub get
flutter test test/g5_industrial_physical_assets_test.dart test/g5_industrial_rendering_test.dart test/g5_industrial_asset_fallback_test.dart
flutter test tool/capture_g5_industrial_test.dart
```

`geometry.json` is checked against the current Canvas terminal contract by the asset test. `controls.json` stores exact crop coordinates for the original rendered control layers. Captures in `build/g5-industrial-proof/` come from production Flutter widgets, including the real workspace palette, inspector and DIN rail. They are not generated mockups.

Visual acceptance remains distinct from functional test success. No assertion of photographic identity or of performance at 400 components is made by these tests.

## Genuine Flutter evidence

- [Six-terminal motor in the actual palette and board](proof/electrosim-motor_3p_6t.png)
- [A60 bulb and porcelain holder in the actual palette and board](proof/electrosim-lamp.png)
- [Mixed board: motor, DIN-mounted breaker and lamp at their relative scale](proof/electrosim-echelle-moteur-protection-lampe.png)
- [Industrial production widgets, perspective and front, page 1](proof/industriels-perspective-face-1.png)
- [Industrial production widgets, perspective and front, page 2](proof/industriels-perspective-face-2.png)

The workspace captures exercise actual production widgets with fixture circuits; they demonstrate appearance and placement, not live electrical measurements. All 74 catalogue appearances are also captured in seven review sheets by the capture tool and exported by the qualification workflow. The comparison report records remaining schematic families explicitly.

## Qualification on G5 df53f7b (including PR 58)

The full app suite passed **408 tests**, the Canvas suite passed **89 tests**, and app analysis reported no issues. Both architecture guards passed. The capture tool passed four tests, producing the workspace proofs, two industrial sheets and all seven catalogue sheets. These are functional and visual regression checks, not a benchmark for 400 components.

The download manifest records **55 usable photos and one manufacturer PDF**, three HTTP 403 responses and one rejected placeholder. Individual voltage/current markings and model variants remain subject to the caveats in the comparison report.

Legacy dense boards can require manual spacing after the larger motor/lamp footprint migration: user placements are intentionally retained, and wire routes are recalculated. The initial placement of new boards uses the actual envelopes and is checked for overlap.
