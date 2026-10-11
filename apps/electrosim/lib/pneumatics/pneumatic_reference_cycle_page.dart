import 'dart:async';

import 'package:electrosim_electropneumatic/electrosim_electropneumatic.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:flutter/material.dart';

import 'pneumatic_device_glyph.dart';

/// A real, bounded, directly observed 24 V / 5/2 / double-acting cylinder
/// training scenario. It is NOT an arbitrary-workshop network compiler.
/// All numbers below originate from the accepted common-clock snapshot.
class PneumaticReferenceCyclePage extends StatefulWidget {
  const PneumaticReferenceCyclePage({super.key});

  @override
  State<PneumaticReferenceCyclePage> createState() =>
      _PneumaticReferenceCyclePageState();
}

class _PneumaticReferenceCyclePageState
    extends State<PneumaticReferenceCyclePage> {
  late final PneumaticReferenceCycle _reference;
  late SelfHoldValve52Snapshot _accepted;
  final PneumaticTelemetrySeries _series = PneumaticTelemetrySeries(
    capacity: 600,
  );
  Timer? _clock;
  bool _airEnabled = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reference = PneumaticReferenceCycle.build();
    _accepted = _reference.initial();
    _series.record(_reference.read(_accepted));
  }

  @override
  void dispose() {
    _clock?.cancel();
    _clock = null;
    super.dispose();
  }

  void _advance(double dt, {bool press = false}) {
    if (_error != null) return;
    try {
      final SelfHoldValve52Snapshot next = _reference.cycle.advance(
        _accepted,
        durationS: dt,
        startPressed: press,
        airSupplyEnabled: _airEnabled,
      );
      final PneumaticCylinderTelemetry telemetry = _reference.read(next);
      setState(() {
        _accepted = next;
        _series.record(telemetry);
      });
    } on Object catch (e) {
      _stop();
      setState(() => _error = '$e');
    }
  }

  void _stop() {
    _clock?.cancel();
    _clock = null;
  }

  void _toggleRun() {
    if (_clock != null) {
      setState(_stop);
      return;
    }
    setState(() {
      _clock = Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => _advance(.01),
      );
    });
  }

  void _reset() {
    _stop();
    setState(() {
      _accepted = _reference.initial();
      _series.reset();
      _series.record(_reference.read(_accepted));
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final PneumaticCylinderTelemetry m = _reference.read(_accepted);
    final bool running = _clock != null;
    final double fraction = (m.positionM /
            _reference.cycle.cylinder.geometry.strokeM)
        .clamp(0.0, 1.0);
    final bool energized = _accepted.electrical?.relay.energized ?? false;
    final double voltageV = _accepted.electrical?.valveReading.voltageV ?? 0;
    return Scaffold(
      key: const Key('r6-live-reference-cycle'),
      appBar: AppBar(title: const Text('Cycle réel 24 V / 5/2 / B1')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text(
            'Scénario générique vérifié : commande S1, auto-maintien K1, '
            'bobine Y1, distributeur 5/2, vérin double effet et capteur B1. '
            'Calculateur DC et moteur pneumatique réels. Cet exemple ne '
            'simule pas le câblage libre de l’éditeur.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton(
                key: const Key('r6-start-s1'),
                onPressed: _error == null ? () => _advance(0, press: true) : null,
                child: const Text('Impulsion Marche S1'),
              ),
              OutlinedButton(
                key: const Key('r6-step'),
                onPressed: _error == null ? () => _advance(.005) : null,
                child: const Text('Avancer de 5 ms'),
              ),
              OutlinedButton(
                key: const Key('r6-run-toggle'),
                onPressed: _error == null ? _toggleRun : null,
                child: Text(running ? 'Pause' : 'Exécuter'),
              ),
              OutlinedButton(
                key: const Key('r6-isolate-air'),
                onPressed: () => setState(() => _airEnabled = !_airEnabled),
                child: Text(_airEnabled ? 'Fermer arrivée air' : 'Ouvrir arrivée air'),
              ),
              TextButton(
                key: const Key('r6-reset'),
                onPressed: _reset,
                child: const Text('Réinitialiser'),
              ),
            ],
          ),
          if (_error != null)
            Text('Erreur de calcul : $_error',
                key: const Key('r6-diagnostic'),
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 20,
            runSpacing: 12,
            children: <Widget>[
              _value('Temps simulé', '${m.timeS.toStringAsFixed(3)} s',
                  'r6-time'),
              _value('K1 / Y1', energized ? 'Excités' : 'Repos',
                  'r6-relay'),
              _value('Tension Y1', '${voltageV.toStringAsFixed(2)} V',
                  'r6-voltage'),
              _value('B1 fin de course',
                  _accepted.endStopActuated ? 'Actionné' : 'Non actionné',
                  'r6-endstop'),
              _value('Pression A',
                  '${m.pressureAGaugeBar.toStringAsFixed(3)} bar (rel.)',
                  'r6-pressure-a'),
              _value('Pression B',
                  '${m.pressureBGaugeBar.toStringAsFixed(3)} bar (rel.)',
                  'r6-pressure-b'),
              _value('Position',
                  '${m.positionMm.toStringAsFixed(2)} mm',
                  'r6-position'),
              _value('Vitesse',
                  '${m.velocityMPerS.toStringAsFixed(3)} m/s',
                  'r6-speed'),
              _value('Effort',
                  '${m.forceN.toStringAsFixed(2)} N',
                  'r6-force'),
              _value('Résidu de masse',
                  '${m.massResidualKg.toStringAsExponential(2)} kg',
                  'r6-mass-residual'),
              _value('Distributeur',
                  m.commutedSpool == ValveSpoolSide.coilSide
                      ? 'Bobine' : 'Ressort',
                  'r6-spool'),
            ],
          ),
          const SizedBox(height: 22),
          const Text('Schéma cinématique — tige animée uniquement par le snapshot physique'),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              const PneumaticDeviceGlyph(
                kind: PneumaticDeviceKind.valve52,
                schematic: true,
                width: 118,
                height: 50,
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 220,
                height: 70,
                child: CustomPaint(
                  key: const Key('r6-physical-rod'),
                  painter: _ReferenceCylinderPainter(fraction: fraction),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Position physique acceptée'),
          LinearProgressIndicator(
            key: const Key('r6-stroke-progress'),
            value: fraction,
            minHeight: 9,
          ),
          const SizedBox(height: 12),
          Text('Historique temporel borné : ${_series.samples.length} / 600 mesures'),
          SizedBox(
            height: 120,
            child: CustomPaint(
              key: const Key('r6-measured-history'),
              painter: _PositionHistoryPainter(
                samples: _series.samples,
                strokeM: _reference.cycle.cylinder.geometry.strokeM,
              ),
            ),
          ),
          const Text(
            'Ordonnanceur de démonstration : un pas physique de 10 ms toutes '
            'les 50 ms d’horloge murale, et non du temps réel garanti. '
            'Le rendu ne participe pas aux équations.',
          ),
        ],
      ),
    );
  }

  Widget _value(String title, String value, String key) => SizedBox(
        width: 170,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: const TextStyle(fontSize: 12)),
            Text(value, key: Key(key),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
}

class _ReferenceCylinderPainter extends CustomPainter {
  const _ReferenceCylinderPainter({required this.fraction});

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint housing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xff263846);
    canvas.drawRect(const Rect.fromLTWH(5, 12, 125, 45), housing);
    final double pistonX = 13 + 110 * fraction;
    canvas.drawLine(Offset(pistonX, 12), Offset(pistonX, 57), housing);
    canvas.drawLine(Offset(pistonX, 34), Offset(pistonX + 60, 34), housing);
    canvas.drawLine(const Offset(22, 57), const Offset(22, 67), housing);
    canvas.drawLine(const Offset(113, 57), const Offset(113, 67), housing);
  }

  @override
  bool shouldRepaint(covariant _ReferenceCylinderPainter previous) =>
      previous.fraction != fraction;
}

class _PositionHistoryPainter extends CustomPainter {
  const _PositionHistoryPainter({required this.samples, required this.strokeM});

  final List<PneumaticCylinderTelemetry> samples;
  final double strokeM;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty) return;
    final Paint pen = Paint()
      ..color = const Color(0xff145a7e)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final Path line = Path();
    final double t0 = samples.first.timeS;
    final double timeSpan =
        (samples.last.timeS - t0).clamp(.001, double.infinity);
    for (int i = 0; i < samples.length; i++) {
      final PneumaticCylinderTelemetry point = samples[i];
      final double x = size.width * (point.timeS - t0) / timeSpan;
      final double y = size.height * (1 - point.positionM / strokeM);
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }
    canvas.drawPath(line, pen);
  }

  @override
  bool shouldRepaint(covariant _PositionHistoryPainter old) =>
      !identical(old.samples, samples);
}
