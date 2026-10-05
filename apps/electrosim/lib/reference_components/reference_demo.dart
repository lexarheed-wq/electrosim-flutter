import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'reference_models.dart';
import 'reference_widgets.dart';

// Optional standalone entry point. Keep ElectroSim's main.dart when integrating.
void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorSchemeSeed: const Color(0xFF16785E),
      useMaterial3: true,
    ),
    home: const ReferenceComponentsDemo(),
  ),
);

class ReferenceComponentsDemo extends StatefulWidget {
  const ReferenceComponentsDemo({super.key});
  @override
  State<ReferenceComponentsDemo> createState() => _DemoState();
}

class _DemoState extends State<ReferenceComponentsDemo>
    with WidgetsBindingObserver {
  ReferenceSeriesCircuit circuit = ReferenceSeriesCircuit();
  final FocusNode buttonFocus = FocusNode();
  Timer? timer;
  bool running = false;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void pause() {
    timer?.cancel();
    timer = null;
    circuit.button.release();
    if (mounted) setState(() => running = false);
  }

  void start() {
    if (running) return;
    setState(() {
      running = true;
      error = null;
    });
    // Simulated time is explicit. It can run slower than real time under load.
    timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      try {
        circuit.advance(const Duration(milliseconds: 50));
        setState(() {});
      } catch (failure) {
        pause();
        setState(() => error = failure.toString());
      }
    });
  }

  void setPressed(bool pressed) {
    if (!mounted) return;
    setState(() {
      if (pressed && running) {
        circuit.button.press();
      } else {
        circuit.button.release();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) pause();
  }

  Widget deviceCard(
    String label,
    ReferenceDevice device,
    ReferenceVisualState state, {
    VoidCallback? onTap,
  }) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReferenceComponentView(device: device, state: state),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final output = circuit.reading;
    return Scaffold(
      appBar: AppBar(title: const Text('ElectroSim • composants de référence')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Circuit série 24 V : alimentation → disjoncteur → '
              'interrupteur → bouton NO → lampe → retour.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: running ? pause : start,
                  icon: Icon(running ? Icons.pause : Icons.play_arrow),
                  label: Text(running ? 'Pause' : 'Démarrer'),
                ),
                OutlinedButton(
                  onPressed: () {
                    pause();
                    setState(() {
                      circuit = ReferenceSeriesCircuit();
                      error = null;
                    });
                  },
                  child: const Text('Réinitialiser'),
                ),
                Text(
                  'Temps simulé : '
                  '${(circuit.simulatedTime.inMilliseconds / 1000).toStringAsFixed(2)} s',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                deviceCard(
                  'Alimentation • toucher pour activer/couper',
                  ReferenceDevice.supply,
                  ReferenceVisualState(
                    voltageV: output.voltageV,
                    currentA: output.currentA,
                    supplyMode: output.mode,
                  ),
                  onTap: () => setState(
                    () => circuit.supply.enabled = !circuit.supply.enabled,
                  ),
                ),
                deviceCard(
                  circuit.breaker.tripped
                      ? 'Déclenché • toucher pour réarmer après refroidissement'
                      : 'Disjoncteur • toucher pour ouvrir/fermer',
                  ReferenceDevice.breaker,
                  ReferenceVisualState(
                    closed: circuit.breaker.conducting,
                    tripped: circuit.breaker.tripped,
                    ratedCurrentA: circuit.breaker.ratedCurrentA,
                  ),
                  onTap: () => setState(() {
                    if (circuit.breaker.tripped) {
                      if (!circuit.breaker.rearm()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Disjoncteur encore chaud : laisser la simulation avancer.',
                            ),
                          ),
                        );
                      }
                    } else {
                      circuit.breaker.closed = !circuit.breaker.closed;
                    }
                  }),
                ),
                deviceCard(
                  'Interrupteur • toucher pour basculer',
                  ReferenceDevice.toggle,
                  ReferenceVisualState(closed: circuit.toggle.closed),
                  onTap: () => setState(
                    () => circuit.toggle.closed = !circuit.toggle.closed,
                  ),
                ),
                Focus(
                  focusNode: buttonFocus,
                  onFocusChange: (focused) {
                    if (!focused) setPressed(false);
                  },
                  onKeyEvent: (_, event) {
                    if (event.logicalKey != LogicalKeyboardKey.space &&
                        event.logicalKey != LogicalKeyboardKey.enter) {
                      return KeyEventResult.ignored;
                    }
                    if (event is KeyDownEvent) setPressed(true);
                    if (event is KeyUpEvent) setPressed(false);
                    return KeyEventResult.handled;
                  },
                  child: Listener(
                    onPointerDown: (_) {
                      buttonFocus.requestFocus();
                      setPressed(true);
                    },
                    onPointerUp: (_) => setPressed(false),
                    onPointerCancel: (_) => setPressed(false),
                    child: Semantics(
                      button: true,
                      child: deviceCard(
                        'Maintenir appuyé • clavier : Espace/Entrée',
                        ReferenceDevice.button,
                        ReferenceVisualState(pressed: circuit.button.pressed),
                      ),
                    ),
                  ),
                ),
                deviceCard(
                  'Lampe à filament • température et lumière calculées',
                  ReferenceDevice.lamp,
                  ReferenceVisualState(
                    brightness: circuit.lamp.brightness,
                    temperatureK: circuit.lamp.temperatureK,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Filament : ${circuit.lamp.temperatureK.toStringAsFixed(0)} K   '
              'Résistance : ${circuit.lamp.resistanceOhm.toStringAsFixed(2)} Ω   '
              'Exposition thermique : ${(circuit.breaker.exposure * 100).toStringAsFixed(0)} %',
            ),
            const SizedBox(height: 8),
            Text('Consigne : ${circuit.supply.voltageV.toStringAsFixed(1)} V'),
            Slider(
              value: circuit.supply.voltageV,
              min: 1,
              max: 24,
              onChanged: (value) =>
                  setState(() => circuit.supply.voltageV = value),
            ),
            Text(
              'Limite : ${circuit.supply.currentLimitA.toStringAsFixed(2)} A',
            ),
            Slider(
              value: circuit.supply.currentLimitA,
              min: .1,
              max: 5,
              onChanged: (value) =>
                  setState(() => circuit.supply.currentLimitA = value),
            ),
            Text(
              'Calibre : ${circuit.breaker.ratedCurrentA.toStringAsFixed(2)} A',
            ),
            Slider(
              value: circuit.breaker.ratedCurrentA,
              min: .1,
              max: 2,
              onChanged: (value) =>
                  setState(() => circuit.breaker.ratedCurrentA = value),
            ),
            const Text(
              'Pour provoquer un déclenchement : calibre 0,10 A, '
              'simulation démarrée, interrupteur fermé et bouton maintenu. '
              'Les modèles sont génériques et pédagogiques, sans certification constructeur.',
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    circuit.button.release();
    WidgetsBinding.instance.removeObserver(this);
    buttonFocus.dispose();
    super.dispose();
  }
}
