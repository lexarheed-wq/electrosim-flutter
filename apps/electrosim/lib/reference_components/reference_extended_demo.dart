import 'package:flutter/material.dart';

import 'reference_widgets_extended.dart';

void main() => runApp(
  const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ExtendedReferenceComponentsProof(),
  ),
);

class ExtendedReferenceComponentsProof extends StatelessWidget {
  const ExtendedReferenceComponentsProof({super.key});

  Widget item(
    String label,
    ExtendedReferenceDevice device,
    ExtendedReferenceVisualState state,
  ) {
    final Size size = ExtendedReferenceGeometry.displaySizeFor(device);
    return SizedBox(
      width: size.width + 36,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ExtendedReferenceComponentView(device: device, state: state),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF24343B),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(34, 26, 34, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'ElectroSim — 8 composants suivants',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF17313B),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Même méthode Dart/vectorielle que les cinq composants de référence validés',
                style: TextStyle(fontSize: 15, color: Color(0xFF52666F)),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 34,
                    runSpacing: 38,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      item(
                        'Résistance',
                        ExtendedReferenceDevice.resistor,
                        const ExtendedReferenceVisualState(
                          resistanceOhm: 100,
                          currentA: .18,
                        ),
                      ),
                      item(
                        'Bouton-poussoir NC',
                        ExtendedReferenceDevice.pushButtonNc,
                        const ExtendedReferenceVisualState(pressed: false),
                      ),
                      item(
                        'Buzzer 24 V',
                        ExtendedReferenceDevice.buzzer,
                        const ExtendedReferenceVisualState(
                          active: true,
                          voltageV: 24,
                        ),
                      ),
                      item(
                        'Fusible cartouche',
                        ExtendedReferenceDevice.fuse,
                        const ExtendedReferenceVisualState(
                          blown: false,
                          currentA: .8,
                        ),
                      ),
                      item(
                        'Diode silicium',
                        ExtendedReferenceDevice.diode,
                        const ExtendedReferenceVisualState(
                          forwardBiased: true,
                          voltageV: .72,
                        ),
                      ),
                      item(
                        'Ventilateur CC',
                        ExtendedReferenceDevice.fan,
                        const ExtendedReferenceVisualState(
                          speedFraction: .72,
                          voltageV: 18,
                        ),
                      ),
                      item(
                        'Moteur CC',
                        ExtendedReferenceDevice.motor,
                        const ExtendedReferenceVisualState(
                          speedRpm: 1850,
                          voltageV: 24,
                        ),
                      ),
                      item(
                        'Bobine de relais 24 V',
                        ExtendedReferenceDevice.relayCoil,
                        const ExtendedReferenceVisualState(
                          energized: true,
                          voltageV: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
