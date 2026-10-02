import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:test/test.dart';

void main() {
  group('ReceiverNominalRating', () {
    test('round-trips only canonical receiver keys', () {
      final ReceiverNominalRating rating = ReceiverNominalRating(
        voltageV: 230,
        currentA: 2.5,
        powerW: 575,
      );
      final Map<String, Object?> parameters = rating.toParameters();

      expect(parameters, <String, Object?>{
        'receiverNominalVoltageV': 230.0,
        'receiverNominalCurrentA': 2.5,
        'receiverNominalPowerW': 575.0,
      });
      expect(ReceiverNominalRating.tryFromParameters(parameters), rating);
      expect(parameters.containsKey('ratedCurrent'), isFalse);
      expect(parameters.containsKey('Imax'), isFalse);
    });

    test('missing receiver keys means no receiver rating', () {
      expect(
        ReceiverNominalRating.tryFromParameters(
          const <String, Object?>{'resistanceOhm': 12},
        ),
        isNull,
      );
    });

    test('rejects invalid receiver nominal values', () {
      expect(
        () => ReceiverNominalRating(currentA: 0),
        throwsA(isA<DomainException>()),
      );
      expect(
        () => ReceiverNominalRating.tryFromParameters(
          const <String, Object?>{'receiverNominalCurrentA': '2.5'},
        ),
        throwsA(isA<DomainException>()),
      );
    });
  });

  group('ProtectionRating', () {
    test('uses a protection-specific calibre key', () {
      final ProtectionRating rating = ProtectionRating(ratedCurrentA: 10);
      expect(
        rating.toParameters(),
        <String, Object?>{'protectionRatedCurrentA': 10.0},
      );
      expect(ProtectionRating.tryFromParameters(rating.toParameters()), rating);
    });

    test('receiver nominal current and protection calibre are independent', () {
      final Map<String, Object?> receiver = ReceiverNominalRating(
        currentA: 2,
      ).toParameters();
      final Map<String, Object?> protection = ProtectionRating(
        ratedCurrentA: 10,
      ).toParameters();

      expect(receiver['receiverNominalCurrentA'], 2.0);
      expect(receiver.containsKey('protectionRatedCurrentA'), isFalse);
      expect(protection['protectionRatedCurrentA'], 10.0);
      expect(protection.containsKey('receiverNominalCurrentA'), isFalse);
    });

    test('rejects invalid protection calibre', () {
      expect(
        () => ProtectionRating(ratedCurrentA: double.infinity),
        throwsA(isA<DomainException>()),
      );
    });
  });
}
