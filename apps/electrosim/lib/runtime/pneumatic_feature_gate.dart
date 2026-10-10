/// Opt-in gate for the experimental pneumatic/multiphysics workspace.
///
/// The existing electrical modes and normal saved-circuit path remain
/// unchanged when this flag is disabled. Never discard pneumatic records.
const bool kElectroSimPneumaticExperimental = bool.fromEnvironment(
  'ELECTROSIM_PNEUMATICS_EXPERIMENTAL',
  defaultValue: false,
);

enum ElectroSimWorkshopFamily { electrical, pneumatic, electropneumatic }

/// Workshop families are deliberately separate from ElectricalMode.
final class PneumaticFeatureGate {
  const PneumaticFeatureGate({this.enabled = kElectroSimPneumaticExperimental});

  final bool enabled;

  /// The electrical workshop is always available.
  bool permits(ElectroSimWorkshopFamily family) =>
      family == ElectroSimWorkshopFamily.electrical || enabled;

  /// Never authorize an export that drops multiphysics data.
  bool permitsLegacySave({required bool containsMultiphysicsRecords}) =>
      !containsMultiphysicsRecords;
}
