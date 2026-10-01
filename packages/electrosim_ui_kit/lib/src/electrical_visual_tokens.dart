abstract final class ElectroSimElectricalVisualTokens {
  static const double terminalVisualDiameter = 16;
  static const double terminalHitTarget = 48;
  static const double selectionHaloWidth = 2;
  static const double selectionHaloOpacity = 0.20;
  static const double deviceBodyRadius = 8;
  static const double deviceCardRadius = 14;

  // UI state is never evidence of electrical state.
  static const bool selectionIsUiOnly = true;
  static const bool electricalStateRequiresEvidence = true;
  static const bool phaseOrPolarityMustUseMoreThanColor = true;
  static const bool decorationMustNotObscureTerminals = true;
}
