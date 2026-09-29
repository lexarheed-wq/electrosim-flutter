String f9ModelLabel(String modelType) {
  switch (modelType) {
    case 'dc_voltage_source':
      return 'Source CC';
    case 'switch':
    case 'switch_spst':
      return 'Interrupteur';
    case 'lamp':
      return 'Lampe';
    case 'resistor':
      return 'Résistance';
    case 'breaker':
      return 'Disjoncteur';
    case 'push_button_no':
      return 'Bouton-poussoir NO';
    case 'buzzer':
      return 'Buzzer';
    case 'fuse':
      return 'Fusible';
    case 'diode':
      return 'Diode';
    case 'fan_dc':
      return 'Ventilateur CC';
    case 'motor_dc':
      return 'Moteur CC';
    case 'relay_coil':
      return 'Bobine relais';
    default:
      return modelType;
  }
}
