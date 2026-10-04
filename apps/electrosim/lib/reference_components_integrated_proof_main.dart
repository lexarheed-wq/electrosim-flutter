import 'package:flutter/material.dart';

import 'f18_component_asset_visual.dart';

void main() {
  final double? fixedPhase = double.tryParse(
    Uri.base.queryParameters['phase'] ?? '',
  );
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: IntegratedReferenceComponentsProof(
        fixedPhase: fixedPhase,
      ),
    ),
  );
}

class IntegratedReferenceComponentsProof extends StatefulWidget {
  const IntegratedReferenceComponentsProof({
    super.key,
    this.fixedPhase,
  });

  final double? fixedPhase;

  @override
  State<IntegratedReferenceComponentsProof> createState() =>
      _IntegratedReferenceComponentsProofState();
}

class _IntegratedReferenceComponentsProofState
    extends State<IntegratedReferenceComponentsProof>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    final double? fixedPhase = widget.fixedPhase;
    if (fixedPhase == null) {
      _motion.repeat();
    } else {
      _motion.value = fixedPhase.clamp(0.0, 1.0).toDouble();
    }
  }

  double get _animationValue =>
      widget.fixedPhase?.clamp(0.0, 1.0).toDouble() ?? _motion.value;

  Widget component(
    String label,
    String modelType, {
    bool energized = false,
    bool? closed,
    bool tripped = false,
    bool pressed = false,
    double currentA = 0,
    double voltageV = 0,
    double resistanceOhm = 0,
  }) {
    final Size natural = F18ReferenceComponentMetrics.boardSizeFor(modelType);
    final double maxWidth = 230;
    final double maxHeight = 180;
    final double scale = [
      maxWidth / natural.width,
      maxHeight / natural.height,
      1.0,
    ].reduce((double a, double b) => a < b ? a : b);
    final Size display = Size(
      natural.width * scale,
      natural.height * scale,
    );
    return SizedBox(
      width: 255,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          F18ComponentAssetVisual(
            modelType: modelType,
            size: display,
            energized: energized,
            closed: closed,
            tripped: tripped,
            pressed: pressed,
            currentA: currentA,
            voltageV: voltageV,
            resistanceOhm: resistanceOhm,
            animationValue: _animationValue,
            showTerminals: true,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
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
      backgroundColor: const Color(0xFFF3F6F7),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _motion,
          builder: (BuildContext context, Widget? child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'ElectroSim — composants Dart intégrés',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF17313B),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Renderer de production • états actifs • moteur et ventilateur animés',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF52666F),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 18,
                    runSpacing: 30,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      component(
                        'Alimentation 24 V',
                        'dc_voltage_source',
                        energized: true,
                        currentA: 1.2,
                        voltageV: 24,
                      ),
                      component(
                        'Disjoncteur',
                        'breaker_dc',
                        energized: true,
                        closed: true,
                        currentA: 1.2,
                        voltageV: .04,
                      ),
                      component(
                        'Interrupteur',
                        'switch',
                        energized: true,
                        closed: true,
                        currentA: 1.2,
                      ),
                      component(
                        'Bouton NO',
                        'push_button_no',
                        energized: true,
                        pressed: true,
                        currentA: 1.2,
                      ),
                      component(
                        'Lampe',
                        'lamp',
                        energized: true,
                        currentA: .42,
                        voltageV: 24,
                      ),
                      component(
                        'Résistance',
                        'resistor',
                        energized: true,
                        currentA: .24,
                        voltageV: 24,
                        resistanceOhm: 100,
                      ),
                      component(
                        'Bouton NC',
                        'push_button_nc',
                        energized: true,
                        pressed: false,
                        currentA: .8,
                      ),
                      component(
                        'Buzzer',
                        'buzzer',
                        energized: true,
                        currentA: .5,
                        voltageV: 24,
                      ),
                      component(
                        'Fusible',
                        'fuse_dc',
                        energized: true,
                        closed: true,
                        currentA: .8,
                      ),
                      component(
                        'Diode — visuel',
                        'diode',
                        energized: false,
                        currentA: 0,
                        voltageV: .7,
                      ),
                      component(
                        'Ventilateur CC',
                        'fan_dc',
                        energized: true,
                        currentA: 2,
                        voltageV: 24,
                      ),
                      component(
                        'Moteur CC',
                        'motor_dc',
                        energized: true,
                        currentA: 3,
                        voltageV: 24,
                      ),
                      component(
                        'Bobine relais',
                        'relay_coil',
                        energized: true,
                        currentA: .2,
                        voltageV: 24,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }
}
