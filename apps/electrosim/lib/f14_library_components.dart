import 'dart:math' as math;

import 'package:flutter/material.dart';

enum F14LibraryDevice {
  capacitor,
  inductor,
  impedance,
  auxiliaryNo,
  auxiliaryNc,
  contactorAc1,
  contactor3p,
  breaker3p,
  thermalOverload3p,
}

enum F14AuxiliaryContactSilhouette { contactorAuxiliary, relay }

abstract final class F14LibraryVisualIdentity {
  static F14AuxiliaryContactSilhouette auxiliaryContactSilhouette(
    String? variantKey,
  ) => variantKey?.startsWith('relay-') ?? false
      ? F14AuxiliaryContactSilhouette.relay
      : F14AuxiliaryContactSilhouette.contactorAuxiliary;
}

@immutable
final class F14LibraryVisualState {
  const F14LibraryVisualState({
    this.active = true,
    this.energized = false,
    this.closed = true,
    this.tripped = false,
    this.actuated = false,
    this.currentA = 0,
    this.voltageV = 0,
    this.variantKey,
  });

  final bool active;
  final bool energized;
  final bool closed;
  final bool tripped;
  final bool actuated;
  final double currentA;
  final double voltageV;
  final String? variantKey;
}

abstract final class F14LibraryGeometry {
  static Size boardSizeFor(F14LibraryDevice device) => switch (device) {
    F14LibraryDevice.capacitor => const Size(220, 110),
    F14LibraryDevice.inductor => const Size(220, 110),
    F14LibraryDevice.impedance => const Size(220, 110),
    F14LibraryDevice.auxiliaryNo => const Size(120, 170),
    F14LibraryDevice.auxiliaryNc => const Size(120, 170),
    F14LibraryDevice.contactorAc1 => const Size(110, 190),
    F14LibraryDevice.contactor3p => const Size(145, 220),
    F14LibraryDevice.breaker3p => const Size(120, 180),
    F14LibraryDevice.thermalOverload3p => const Size(145, 180),
  };
}

class F14LibraryComponentView extends StatelessWidget {
  const F14LibraryComponentView({
    super.key,
    required this.device,
    required this.size,
    this.state = const F14LibraryVisualState(),
  });

  final F14LibraryDevice device;
  final Size size;
  final F14LibraryVisualState state;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size.width,
    height: size.height,
    child: CustomPaint(
      painter: _F14LibraryPainter(device: device, state: state),
    ),
  );
}

final class _F14LibraryPainter extends CustomPainter {
  const _F14LibraryPainter({required this.device, required this.state});

  final F14LibraryDevice device;
  final F14LibraryVisualState state;

  @override
  void paint(Canvas canvas, Size size) {
    final _Painter p = _Painter(canvas, Offset.zero & size, state);
    switch (device) {
      case F14LibraryDevice.capacitor:
        p.capacitor();
        break;
      case F14LibraryDevice.inductor:
        p.inductor();
        break;
      case F14LibraryDevice.impedance:
        p.impedance();
        break;
      case F14LibraryDevice.auxiliaryNo:
        p.auxiliaryContact(normallyClosed: false);
        break;
      case F14LibraryDevice.auxiliaryNc:
        p.auxiliaryContact(normallyClosed: true);
        break;
      case F14LibraryDevice.contactorAc1:
        p.contactor(singlePhase: true);
        break;
      case F14LibraryDevice.contactor3p:
        p.contactor(singlePhase: false);
        break;
      case F14LibraryDevice.breaker3p:
        p.breaker3p();
        break;
      case F14LibraryDevice.thermalOverload3p:
        p.thermalOverload3p();
        break;
    }
  }

  @override
  bool shouldRepaint(_F14LibraryPainter oldDelegate) =>
      oldDelegate.device != device || oldDelegate.state != state;
}

final class _Painter {
  _Painter(this.canvas, this.rect, this.state);

  final Canvas canvas;
  final Rect rect;
  final F14LibraryVisualState state;

  double get w => rect.width;
  double get h => rect.height;
  double get s => rect.shortestSide;
  Offset get c => rect.center;

  Paint get outline => Paint()
    ..color = const Color(0xFF61717B)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(.7, s * .007)
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  Paint gradient(Rect target, List<Color> colors) => Paint()
    ..style = PaintingStyle.fill
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    ).createShader(target);

  void housing(
    Rect body, {
    List<Color> colors = const <Color>[Color(0xFFF9FBFC), Color(0xFFD5DEE4)],
    double radius = 8,
  }) {
    final RRect rr = RRect.fromRectAndRadius(body, Radius.circular(radius));
    canvas.drawRRect(
      rr.shift(Offset(0, math.max(1.5, h * .018))),
      Paint()..color = const Color(0x26000000),
    );
    canvas.drawRRect(rr, gradient(body, colors));
    canvas.drawRRect(rr, outline);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        body.deflate(1.5),
        Radius.circular(math.max(1, radius - 1)),
      ),
      Paint()
        ..color = const Color(0xA0FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
  }

  void terminal(Offset p, {String? label}) {
    final double r = math.max(3.0, s * .032);
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.35, -.35),
          colors: <Color>[
            Color(0xFFF7FAFA),
            Color(0xFF9CA9B0),
            Color(0xFF52616B),
          ],
        ).createShader(Rect.fromCircle(center: p, radius: r)),
    );
    canvas.drawCircle(p, r, outline);
    canvas.drawLine(
      Offset(p.dx - r * .55, p.dy),
      Offset(p.dx + r * .55, p.dy),
      Paint()
        ..color = const Color(0xFF5A4321)
        ..strokeWidth = math.max(.8, r * .2),
    );
    if (label != null) {
      text(
        label,
        p.translate(0, p.dy < c.dy ? r + 8 : -(r + 8)),
        size: math.max(6, s * .052),
      );
    }
  }

  void text(
    String value,
    Offset center, {
    double? size,
    Color color = const Color(0xFF22313D),
    FontWeight weight = FontWeight.w700,
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Roboto',
          color: color,
          fontSize: size ?? math.max(7, h * .07),
          fontWeight: weight,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  void lead(Offset a, Offset b) {
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = const Color(0xFF6D7B84)
        ..strokeWidth = math.max(2, s * .028)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      a.translate(0, -math.max(.6, s * .008)),
      b.translate(0, -math.max(.6, s * .008)),
      Paint()
        ..color = const Color(0xFFD9E1E5)
        ..strokeWidth = math.max(.8, s * .01)
        ..strokeCap = StrokeCap.round,
    );
  }

  void capacitor() {
    final Offset left = Offset(rect.left + w * .22, c.dy);
    final Offset right = Offset(rect.right - w * .22, c.dy);
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .38,
      height: h * .56,
    );
    lead(left, Offset(body.left, c.dy));
    lead(Offset(body.right, c.dy), right);
    terminal(left);
    terminal(right);
    housing(
      body,
      colors: const <Color>[Color(0xFFFFDF62), Color(0xFFD5A72A)],
      radius: h * .08,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        body.left + body.width * .12,
        body.top,
        body.width * .08,
        body.height,
      ),
      Paint()..color = const Color(0xFF8D6A16),
    );
    text('C', c.translate(0, -h * .04), size: h * .18);
    text(
      'µF',
      c.translate(0, h * .15),
      size: h * .085,
      color: const Color(0xFF5B4614),
    );
  }

  void inductor() {
    final Offset left = Offset(rect.left + w * .22, c.dy);
    final Offset right = Offset(rect.right - w * .22, c.dy);
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .42,
      height: h * .58,
    );
    lead(left, Offset(body.left, c.dy));
    lead(Offset(body.right, c.dy), right);
    terminal(left);
    terminal(right);
    housing(
      body,
      colors: const <Color>[Color(0xFF55636B), Color(0xFF222D33)],
      radius: h * .13,
    );
    for (var i = 0; i < 7; i++) {
      final double x = body.left + body.width * (.14 + i * .12);
      canvas.drawLine(
        Offset(x, body.top + body.height * .15),
        Offset(x, body.bottom - body.height * .15),
        Paint()
          ..color = const Color(0xFFE58B3E)
          ..strokeWidth = math.max(2, s * .025)
          ..strokeCap = StrokeCap.round,
      );
    }
    text('L', c, size: h * .16, color: Colors.white);
  }

  void impedance() {
    final Offset left = Offset(rect.left + w * .22, c.dy);
    final Offset right = Offset(rect.right - w * .22, c.dy);
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .42,
      height: h * .58,
    );
    lead(left, Offset(body.left, c.dy));
    lead(Offset(body.right, c.dy), right);
    terminal(left);
    terminal(right);
    housing(
      body,
      colors: const <Color>[Color(0xFFE7EBEE), Color(0xFF909DA6)],
      radius: h * .05,
    );
    text('Z', c.translate(0, -h * .04), size: h * .18);
    text(
      'R + jX',
      c.translate(0, h * .14),
      size: h * .07,
      color: const Color(0xFF45545E),
    );
  }

  void auxiliaryContact({required bool normallyClosed}) {
    final bool relayContact =
        F14LibraryVisualIdentity.auxiliaryContactSilhouette(state.variantKey) ==
        F14AuxiliaryContactSilhouette.relay;
    final Rect body = Rect.fromCenter(
      center: c,
      width: relayContact ? w * .72 : w * .62,
      height: relayContact ? h * .60 : h * .68,
    );
    housing(
      body,
      colors: relayContact
          ? const <Color>[Color(0xFFE6F0F5), Color(0xFF9FB6C2)]
          : const <Color>[Color(0xFFF9FBFC), Color(0xFFD5DEE4)],
      radius: relayContact ? h * .055 : h * .035,
    );

    if (relayContact) {
      final Rect cover = body.deflate(math.max(5, s * .055));
      canvas.drawRRect(
        RRect.fromRectAndRadius(cover, Radius.circular(h * .035)),
        Paint()..color = const Color(0x557BC3DA),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(cover, Radius.circular(h * .035)),
        Paint()
          ..color = const Color(0xFF4F7786)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, s * .012),
      );
    }

    final Offset top = Offset(c.dx, rect.top + h * .12);
    final Offset bottom = Offset(c.dx, rect.bottom - h * .12);
    terminal(top, label: normallyClosed ? '21' : '13');
    terminal(bottom, label: normallyClosed ? '22' : '14');
    lead(top.translate(0, h * .04), Offset(c.dx, body.top + body.height * .22));
    lead(
      Offset(c.dx, body.bottom - body.height * .22),
      bottom.translate(0, -h * .04),
    );

    final bool closed = normallyClosed ? !state.actuated : state.actuated;
    final Offset fixed = Offset(c.dx, c.dy + h * .12);
    final Offset pivot = Offset(c.dx - w * .13, c.dy - h * .08);
    canvas.drawCircle(
      pivot,
      s * .025,
      Paint()..color = const Color(0xFF33434D),
    );
    canvas.drawCircle(
      fixed,
      s * .025,
      Paint()..color = const Color(0xFF33434D),
    );
    canvas.drawLine(
      pivot,
      closed ? fixed : Offset(fixed.dx + w * .12, fixed.dy - h * .09),
      Paint()
        ..color = const Color(0xFF33434D)
        ..strokeWidth = math.max(2, s * .025)
        ..strokeCap = StrokeCap.round,
    );
    text(
      relayContact
          ? (normallyClosed ? 'RELAIS NC' : 'RELAIS NO')
          : (normallyClosed ? 'AUX NC' : 'AUX NO'),
      Offset(c.dx, body.top + h * .09),
      size: relayContact ? h * .052 : h * .060,
    );
  }

  void contactor({required bool singlePhase}) {
    final body = Rect.fromCenter(center: c, width: w * .92, height: h * .94);
    housing(
      body,
      colors: const [Color(0xFFF8F8F3), Color(0xFFD5D8D3), Color(0xFFB7BDB8)],
      radius: h * .022,
    );
    // Insulating terminal decks encompass the actual contact points.
    for (final y in [rect.top + h * .035, rect.bottom - h * .145]) {
      final deck = Rect.fromLTWH(
        body.left + w * .025,
        y,
        body.width - w * .05,
        h * .11,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(deck, Radius.circular(h * .012)),
        gradient(deck, const [Color(0xFF3C464B), Color(0xFF172229)]),
      );
    }
    final face = Rect.fromLTWH(
      body.left + w * .08,
      rect.top + h * .24,
      body.width - w * .16,
      h * .43,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(face, Radius.circular(h * .022)),
      gradient(face, const [Color(0xFFFCFDF7), Color(0xFFDFE2DA)]),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(face, Radius.circular(h * .022)),
      Paint()
        ..color = const Color(0xFF9FA9A1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7,
    );
    text(
      'CONTACTEUR',
      Offset(c.dx, face.top + h * .07),
      size: h * .045,
      color: const Color(0xFF35735B),
    );
    final window = Rect.fromCenter(
      center: Offset(c.dx, c.dy - h * .02),
      width: w * .42,
      height: h * .11,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(window, Radius.circular(h * .008)),
      gradient(window, const [Color(0xFF0E171E), Color(0xFF34424D)]),
    );
    for (var i = 0; i < (singlePhase ? 1 : 3); i++) {
      final x = singlePhase
          ? window.center.dx
          : window.left + window.width * (.23 + i * .27);
      final movingBar = Rect.fromCenter(
        center: Offset(
          x,
          window.center.dy + (state.actuated ? h * .012 : -h * .012),
        ),
        width: w * .06,
        height: h * .075,
      );
      canvas.drawRect(
        movingBar,
        gradient(movingBar, const [Color(0xFFB8C3CA), Color(0xFF697A87)]),
      );
    }
    text(
      singlePhase ? '1 PÔLE' : '3 PÔLES',
      Offset(c.dx, face.bottom - h * .035),
      size: h * .045,
    );
    // Keep the established electrical terminal order and exact anchor fractions.
    final xs = singlePhase
        ? [c.dx - w * .1224]
        : [c.dx - w * .2016, c.dx, c.dx + w * .2016];
    for (var i = 0; i < xs.length; i++) {
      terminal(
        Offset(xs[i], rect.top + h * .08),
        label: singlePhase ? '1L1' : ['1L1', '3L2', '5L3'][i],
      );
      terminal(
        Offset(xs[i], rect.bottom - h * .08),
        label: singlePhase ? '2T1' : ['2T1', '4T2', '6T3'][i],
      );
    }
    terminal(Offset(rect.left + w * .08, c.dy + h * .08), label: 'A1');
    terminal(Offset(rect.right - w * .08, c.dy + h * .08), label: 'A2');
    // Mechanical state flag, not a simulated pilot lamp.
    final flag = Rect.fromLTWH(
      c.dx - w * .07,
      rect.top + h * .72,
      w * .14,
      h * .045,
    );
    canvas.drawRect(
      flag,
      Paint()
        ..color = state.actuated
            ? const Color(0xFF3B8058)
            : const Color(0xFF66716D),
    );
  }

  void breaker3p() {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .86,
      height: h * .94,
    );
    housing(body, radius: h * .03);
    final List<double> xs = <double>[c.dx - w * .2016, c.dx, c.dx + w * .2016];
    for (var i = 0; i < 3; i++) {
      final Offset top = Offset(xs[i], rect.top + h * .08);
      final Offset bottom = Offset(xs[i], rect.bottom - h * .08);
      terminal(top, label: <String>['1L1', '3L2', '5L3'][i]);
      terminal(bottom, label: <String>['2T1', '4T2', '6T3'][i]);
      final Rect slot = Rect.fromCenter(
        center: Offset(xs[i], c.dy),
        width: body.width * .16,
        height: body.height * .42,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(slot, Radius.circular(h * .025)),
        Paint()..color = const Color(0xFFB4BDC2),
      );
      final double y = state.tripped
          ? slot.center.dy
          : (state.closed
                ? slot.top + slot.height * .34
                : slot.bottom - slot.height * .34);
      final Rect lever = Rect.fromCenter(
        center: Offset(xs[i], y),
        width: slot.width * .72,
        height: slot.height * .24,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(lever, Radius.circular(h * .02)),
        gradient(lever, const <Color>[Color(0xFF515E67), Color(0xFF172027)]),
      );
    }
    final badge = Rect.fromLTWH(
      body.left + w * .06,
      rect.top + h * .21,
      body.width - w * .12,
      h * .015,
    );
    canvas.drawRect(badge, Paint()..color = const Color(0xFF5A7380));
    text('3 PÔLES', Offset(c.dx, rect.top + h * .255), size: h * .052);
    final Color indicator = state.tripped
        ? const Color(0xFFD64545)
        : (state.closed ? const Color(0xFF3AA964) : const Color(0xFF9AA7AE));
    canvas.drawCircle(
      Offset(c.dx, rect.top + h * .75),
      h * .025,
      Paint()..color = indicator,
    );
  }

  void thermalOverload3p() {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .88,
      height: h * .94,
    );
    housing(
      body,
      colors: const <Color>[Color(0xFFF3F1EA), Color(0xFFC8C4B7)],
      radius: h * .035,
    );
    final face = Rect.fromLTWH(
      body.left + w * .055,
      rect.top + h * .15,
      body.width - w * .11,
      h * .59,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(face, Radius.circular(h * .018)),
      gradient(face, const [Color(0xFFF9F8F1), Color(0xFFDEDED1)]),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(face, Radius.circular(h * .018)),
      Paint()
        ..color = const Color(0xFFAAAFA4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6,
    );

    final List<double> xs = <double>[c.dx - w * .2072, c.dx, c.dx + w * .2072];
    for (var i = 0; i < 3; i++) {
      terminal(
        Offset(xs[i], rect.top + h * .08),
        label: <String>['1L1', '3L2', '5L3'][i],
      );
      terminal(
        Offset(xs[i], rect.bottom - h * .08),
        label: <String>['2T1', '4T2', '6T3'][i],
      );
    }

    final Offset dial = Offset(
      c.dx - body.width * .20,
      body.top + body.height * .22,
    );
    canvas.drawCircle(dial, h * .075, Paint()..color = const Color(0xFF28353D));
    canvas.drawArc(
      Rect.fromCircle(center: dial, radius: h * .055),
      -math.pi * .75,
      math.pi * 1.5,
      false,
      Paint()
        ..color = const Color(0xFFE7EEF1)
        ..strokeWidth = math.max(1.2, s * .012)
        ..style = PaintingStyle.stroke,
    );
    for (var i = 0; i < 7; i++) {
      final angle = -math.pi * .75 + i * math.pi * 1.5 / 6;
      final delta = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        dial + delta * h * .085,
        dial + delta * h * .095,
        Paint()
          ..color = const Color(0xFF56625A)
          ..strokeWidth = .8,
      );
    }
    canvas.drawLine(
      dial,
      dial + Offset(h * .034, -h * .039),
      Paint()
        ..color = const Color(0xFFF5F8F3)
        ..strokeWidth = 1.7,
    );
    for (final entry in [
      ('STOP', .21, const Color(0xFFAA302C), const Color(0xFFE37669)),
      ('RESET', .31, const Color(0xFF1D5785), const Color(0xFF6AA8C9)),
    ]) {
      final button = Rect.fromCenter(
        center: Offset(c.dx + body.width * .21, rect.top + h * entry.$2),
        width: w * .25,
        height: h * .075,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          button.shift(Offset(0, h * .008)),
          Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF3D4240),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(button, Radius.circular(2)),
        gradient(button, [entry.$4, entry.$3]),
      );
      text(entry.$1, button.center, size: h * .035, color: Colors.white);
    }
    text('3 PÔLES', Offset(c.dx, rect.top + h * .59), size: h * .052);
    text(
      state.tripped ? 'TRIP' : 'THERMIQUE',
      Offset(c.dx, body.top + body.height * .38),
      size: h * .075,
      color: state.tripped ? const Color(0xFFB42318) : const Color(0xFF34454F),
    );
  }
}
