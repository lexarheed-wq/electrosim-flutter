import 'dart:ui';

/// Side-mounted open terminal box on a horizontal IEC-frame motor.
/// Logical winding order U1,V1,W1,U2,V2,W2 remains unchanged; physical
/// bottom row W2,U2,V2 lets existing star/delta links keep their meaning.
abstract final class SixTerminalMotorGeometry {
  /// Approximate IEC100-sized envelope, expressed in the same board scale
  /// as an 85 mm high DIN breaker (~160 logical pixels).
  static const boardSize = Size(750, 430);
  static Rect bodyRect(Size size) => Rect.fromLTWH(
    size.width * .11,
    size.height * .14,
    size.width * .73,
    size.height * .68,
  );
  static Rect terminalBoxRect(Size size) => Rect.fromLTWH(
    size.width * .225,
    size.height * .34,
    size.width * .23,
    size.height * .28,
  );
  static List<Offset> offsets(Size size) => [
    Offset(-size.width * .23, -size.height * .08),
    Offset(-size.width * .16, -size.height * .08),
    Offset(-size.width * .09, -size.height * .08),
    Offset(-size.width * .16, size.height * .04),
    Offset(-size.width * .09, size.height * .04),
    Offset(-size.width * .23, size.height * .04),
  ];
}
