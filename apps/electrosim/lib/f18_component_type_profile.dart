/// Shared, presentation-neutral model classification. A component has one
/// canonical modelType; palette and board must not carry independent keyword
/// dictionaries that drift when new components are added.
final class F18ComponentTypeProfile {
  F18ComponentTypeProfile(String modelType)
      : type = modelType.toLowerCase();

  final String type;

  bool _has(List<String> terms) => terms.any(type.contains);

  bool get pvArchetype => _has(const <String>[
    'pv', 'solar', 'irradiance', 'battery_storage', 'regulator',
  ]);
  bool get pvHardware => type.startsWith('pv_');
  bool get converter => _has(const <String>[
    'inverter', 'converter', 'rectifier', 'transformer', 'dc_dc', 'ac_dc',
  ]);
  bool get measurementArchetype => _has(const <String>[
    'meter', 'voltmeter', 'ammeter', 'multimeter', 'oscilloscope',
    'sensor', 'probe',
  ]);
  bool get measurementHardware =>
      type.startsWith('physical_') || _has(const <String>[
        'voltmeter', 'ammeter',
      ]);
  bool get protective => _has(const <String>[
    'breaker', 'fuse', 'rcd', 'protection', 'disjoncteur', 'fusible',
  ]);
  bool get protectiveHardware => _has(const <String>[
    'breaker', 'fuse', 'isolator', 'thermal_overload', 'terminal_block',
  ]);
  bool get controls => _has(const <String>[
    'switch', 'push_button', 'relay', 'contactor', 'contacteur',
    'interrupteur', 'bouton', 'coil', 'bobine',
  ]);
  bool get switchingHardware => _has(const <String>[
    'contactor', 'relay', 'switch', 'push_button',
  ]);
  bool get motor => _has(const <String>[
    'motor', 'fan', 'pump', 'moteur', 'ventilateur', 'pompe',
  ]);
  bool get rotatingHardware => _has(const <String>[
    'motor', 'fan', 'generator',
  ]);
  bool get load => _has(const <String>[
    'lamp', 'resistor', 'heater', 'buzzer', 'diode', 'load',
    'lampe', 'résistance', 'resistance', 'chauffage',
  ]);
  bool get boxedHardware => _has(const <String>[
    'source', 'battery', 'controller', 'inverter', 'appliance',
    'sensor', 'actuator',
  ]);
}
