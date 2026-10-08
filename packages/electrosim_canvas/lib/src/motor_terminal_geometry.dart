import 'dart:ui';

/// Logical winding order U1,V1,W1,U2,V2,W2. The physical bottom row is
/// W2,U2,V2, allowing star/delta links inside a single open terminal box.
abstract final class SixTerminalMotorGeometry {
  static List<Offset> offsets(Size size) => [
    Offset(-size.width * .20, -size.height * .36),
    Offset(0, -size.height * .36),
    Offset(size.width * .20, -size.height * .36),
    Offset(0, -size.height * .22),
    Offset(size.width * .20, -size.height * .22),
    Offset(-size.width * .20, -size.height * .22),
  ];
}
