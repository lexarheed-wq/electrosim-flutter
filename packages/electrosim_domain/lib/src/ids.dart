import 'domain_error.dart';

abstract base class ValueId {
  ValueId(String raw) : value = _validate(raw);

  final String value;

  static String _validate(String raw) {
    if (raw.isEmpty || raw != raw.trim()) {
      throw DomainException(
        code: DomainErrorCode.invalidId,
        message:
            'Identifier must be non-empty and must not contain edge whitespace.',
        context: <String, Object?>{'value': raw},
      );
    }
    final RegExp pattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$');
    if (!pattern.hasMatch(raw)) {
      throw DomainException(
        code: DomainErrorCode.invalidId,
        message: 'Identifier contains unsupported characters.',
        context: <String, Object?>{'value': raw},
      );
    }
    return raw;
  }

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is ValueId &&
      other.value == value;

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => value;
}

final class CircuitId extends ValueId {
  CircuitId(super.value);
}

final class ComponentId extends ValueId {
  ComponentId(super.value);
}

final class SourceId extends ValueId {
  SourceId(super.value);
}

final class TerminalId extends ValueId {
  TerminalId(super.value);
}

final class ConnectionId extends ValueId {
  ConnectionId(super.value);
}
