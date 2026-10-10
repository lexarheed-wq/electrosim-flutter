/// Opt-in gate for the experimental pneumatic/multiphysics workspace.
///
/// The existing electrical modes and the normal saved-circuit path remain
/// unchanged when this flag is disabled. Only use this flag to *select an
/// implementation*; never use it to drop pneumatic records from a mixed file.
/// A caller that cannot preserve a multiphysics document must reject saving it.
const bool kElectroSimPneumaticExperimental =
    bool.fromEnvironment('ELECTROSIM_PNEUMATICS_EXPERIMENTAL', defaultValue: false);

enum ElectroSimWorkshopFamily {
  electrical,
  pneumatic,
  electropneumatic,
}

/// Workshop families are intentionally separate from ElectricalMode.
final class PneumaticFeatureGate {
  const PneumaticFeatureGate({this.enabled = kElectroSimPneumaticExperimental});

  final bool enabled;

  /// The legacy electrical workspace is always available. Hidden pneumatic
  /// modes cannot accidentally be selected by the production UI.
  bool permits(ElectroSimWorkshopFamily family) =>
      family == ElectroSimWorkshopFamily.electrical || enabled;

  /// A legacy-save operation must reject *all* mixed records, regardless of
  /// whether the feature is enabled at save time.
  bool permitsLegacySave({required bool containsMultiphysicsRecords}) =>
      !containsMultiphysicsRecords;
}
