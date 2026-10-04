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
    case 'capacitor':
      return 'Condensateur';
    case 'inductor':
      return 'Inductance';
    case 'impedance':
      return 'Impédance';
    case 'breaker_ac1':
      return 'Disjoncteur AC 1φ';
    case 'fuse_ac1':
      return 'Fusible AC 1φ';
    case 'contactor_aux_no':
      return 'Contact auxiliaire NO';
    case 'contactor_aux_nc':
      return 'Contact auxiliaire NC';
    case 'contactor_ac1':
      return 'Contacteur AC 1φ';
    case 'contactor_3p':
      return 'Contacteur 3P';
    case 'breaker_3p':
      return 'Disjoncteur 3P';
    case 'thermal_overload_3p':
      return 'Relais thermique 3P';
    default:
      return modelType;
  }
}
