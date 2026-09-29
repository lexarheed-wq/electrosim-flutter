enum DomainErrorCode {
  invalidId,
  invalidValue,
  invalidSchemaVersion,
  invalidEnumValue,
  missingField,
  duplicateId,
  invalidTerminalReference,
  invalidJsonValue,
}

final class DomainException implements Exception {
  DomainException({
    required this.code,
    required this.message,
    Map<String, Object?> context = const <String, Object?>{},
  }) : context = Map<String, Object?>.unmodifiable(context);

  final DomainErrorCode code;
  final String message;
  final Map<String, Object?> context;

  @override
  String toString() => 'DomainException(${code.name}): $message';
}

Never missingField(String field, Map<String, Object?> json) {
  throw DomainException(
    code: DomainErrorCode.missingField,
    message: 'Missing required field: $field',
    context: <String, Object?>{'field': field, 'json': json},
  );
}
