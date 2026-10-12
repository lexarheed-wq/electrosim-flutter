import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter_test/flutter_test.dart';
const lastLotKeys = [
 'external-refrigerator', 'external-refrigerator-dc', 'external-tv',
 'external-fan-ac1', 'external-fan-3p', 'pv-resistive-load',
 'source-ac3-grid', 'source-ac3-alternator', 'load-wye-3p',
 'load-delta-3p', 'impedance',
];
void main() {
 for(final key in lastLotKeys) {
  test('$key has an independent native port contract', () {
   final s=NativeApplianceGeometry.catalogue[key];
   expect(s,isNotNull,reason:'Missing native geometry for $key');
   expect(s!.ports.toSet().length,s.ports.length);
   for(final p in s.ports) {
    expect(s.serviceBox.contains(p),isTrue,reason:'Port outside service area');
   }
  });
 }
}
