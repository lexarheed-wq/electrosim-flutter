import 'package:flutter/foundation.dart';

import 'workspace_shell.dart' show ElectroSimWorkspacePanel;

enum ElectroSimWorkspaceLayoutClass { compact, medium, expanded }

ElectroSimWorkspaceLayoutClass classifyWorkspaceWidth(double width) {
  if (width < 720) return ElectroSimWorkspaceLayoutClass.compact;
  if (width < 1200) return ElectroSimWorkspaceLayoutClass.medium;
  return ElectroSimWorkspaceLayoutClass.expanded;
}

/// Presentation preferences only; circuit geometry is never stored here.
class WorkspaceLayoutController extends ChangeNotifier {
  double _paletteWidth = 264;
  double _contextWidth = 304;
  bool _paletteVisible = true;
  bool _contextVisible = true;

  double get paletteWidth => _paletteWidth;
  double get contextWidth => _contextWidth;
  bool get paletteVisible => _paletteVisible;
  bool get contextVisible => _contextVisible;

  void setPaletteWidth(double value) {
    if (!value.isFinite) return;
    final next = value.clamp(220.0, 360.0).toDouble();
    if (next == _paletteWidth) return;
    _paletteWidth = next;
    notifyListeners();
  }

  void setContextWidth(double value) {
    if (!value.isFinite) return;
    final next = value.clamp(280.0, 440.0).toDouble();
    if (next == _contextWidth) return;
    _contextWidth = next;
    notifyListeners();
  }

  void setPanelVisible(ElectroSimWorkspacePanel panel, bool visible) {
    switch (panel) {
      case ElectroSimWorkspacePanel.palette:
        if (_paletteVisible == visible) return;
        _paletteVisible = visible;
      case ElectroSimWorkspacePanel.context:
        if (_contextVisible == visible) return;
        _contextVisible = visible;
      case ElectroSimWorkspacePanel.top:
      case ElectroSimWorkspacePanel.status:
        return;
    }
    notifyListeners();
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'paletteWidth': _paletteWidth,
    'contextWidth': _contextWidth,
    'paletteVisible': _paletteVisible,
    'contextVisible': _contextVisible,
  };

  void restore(Map<String, Object?> json) {
    final before = toJson();
    final valid = json['version'] == 1;
    double width(String key, double fallback, double min, double max) {
      final raw = valid ? json[key] : null;
      return raw is num && raw.isFinite
          ? raw.toDouble().clamp(min, max).toDouble()
          : fallback;
    }

    bool visible(String key) =>
        valid && json[key] is bool ? json[key]! as bool : true;
    _paletteWidth = width('paletteWidth', 264, 220, 360);
    _contextWidth = width('contextWidth', 304, 280, 440);
    _paletteVisible = visible('paletteVisible');
    _contextVisible = visible('contextVisible');
    if (!mapEquals(before, toJson())) notifyListeners();
  }
}
