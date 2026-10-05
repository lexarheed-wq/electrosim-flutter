import 'dart:math' as math;

final class AcComplex {
  const AcComplex(this.real, this.imaginary);

  const AcComplex.real(double value) : real = value, imaginary = 0.0;

  factory AcComplex.polar(double magnitude, double angleRadians) => AcComplex(
    magnitude * math.cos(angleRadians),
    magnitude * math.sin(angleRadians),
  );

  final double real;
  final double imaginary;

  static const AcComplex zero = AcComplex(0.0, 0.0);
  static const AcComplex one = AcComplex(1.0, 0.0);

  bool get isFinite => real.isFinite && imaginary.isFinite;
  double get magnitude => math.sqrt((real * real) + (imaginary * imaginary));
  double get angleRadians => math.atan2(imaginary, real);
  double get angleDegrees => angleRadians * 180.0 / math.pi;
  AcComplex get conjugate => AcComplex(real, -imaginary);

  AcComplex operator +(AcComplex other) =>
      AcComplex(real + other.real, imaginary + other.imaginary);
  AcComplex operator -(AcComplex other) =>
      AcComplex(real - other.real, imaginary - other.imaginary);
  AcComplex operator -() => AcComplex(-real, -imaginary);
  AcComplex operator *(AcComplex other) => AcComplex(
    (real * other.real) - (imaginary * other.imaginary),
    (real * other.imaginary) + (imaginary * other.real),
  );
  AcComplex operator /(AcComplex other) {
    final double denominator =
        (other.real * other.real) + (other.imaginary * other.imaginary);
    if (denominator == 0.0) {
      throw StateError('Complex division by zero.');
    }
    return AcComplex(
      ((real * other.real) + (imaginary * other.imaginary)) / denominator,
      ((imaginary * other.real) - (real * other.imaginary)) / denominator,
    );
  }

  AcComplex scale(double factor) =>
      AcComplex(real * factor, imaginary * factor);

  @override
  bool operator ==(Object other) =>
      other is AcComplex && other.real == real && other.imaginary == imaginary;

  @override
  int get hashCode => Object.hash(real, imaginary);

  @override
  String toString() => 'AcComplex($real, $imaginary)';
}
