import 'package:electrosim/f14_library_components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'relay and contactor auxiliary contacts keep distinct visual identities',
    () {
      expect(
        F14LibraryVisualIdentity.auxiliaryContactSilhouette('relay-no'),
        F14AuxiliaryContactSilhouette.relay,
      );
      expect(
        F14LibraryVisualIdentity.auxiliaryContactSilhouette('relay-nc'),
        F14AuxiliaryContactSilhouette.relay,
      );
      expect(
        F14LibraryVisualIdentity.auxiliaryContactSilhouette(null),
        F14AuxiliaryContactSilhouette.contactorAuxiliary,
      );
    },
  );
}
