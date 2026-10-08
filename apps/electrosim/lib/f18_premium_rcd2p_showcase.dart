import 'package:flutter/material.dart';
import 'reference_components/disjoncteur_3d.dart';

/// Non-simulable presentation of the exact premium two-pole RCD painter.
///
/// The CORE-UNIFY domain does not currently assert a validated 2P RCD model:
/// no terminal, contact, residual-current trip, or TEST interaction is faked.
/// This visual preview must never be routed from breaker_dc/breaker_ac1.
class F18PremiumRcd2pShowcase extends StatelessWidget {
  const F18PremiumRcd2pShowcase({super.key});

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFE9EDF1),
    child: Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 36,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: const [
              _RcdViewPanel(
                title: 'PALETTE · PERSPECTIVE 10° / −12°',
                vue: VueDisjoncteur.palette,
              ),
              _RcdViewPanel(
                title: 'PLATINE · FACE 0° / 0°',
                vue: VueDisjoncteur.platine,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _RcdViewPanel extends StatelessWidget {
  const _RcdViewPanel({required this.title, required this.vue});
  final String title;
  final VueDisjoncteur vue;

  @override
  Widget build(BuildContext context) => Container(
    width: 340,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
    decoration: BoxDecoration(
      color: const Color(0xFFF9FAFC),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFCBD5DB)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 12),
        Disjoncteur3D(
          key: Key('premium-rcd-' + vue.name),
          width: 280,
          height: 430,
          vue: vue,
          etat: EtatDisjoncteur.ouvert,
          calibreA: 16,
          sensibiliteMA: 30,
          onCommande: null,
          onTest: null,
          onBorne: null,
        ),
        const SizedBox(height: 8),
        const Text('APERÇU VISUEL · NON SIMULABLE',
            style: TextStyle(fontSize: 10, color: Color(0xFF5A6872))),
      ],
    ),
  );
}
