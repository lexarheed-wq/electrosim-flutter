import 'multiphysics_project.dart';
import 'pneumatic_workshop_state.dart';
import 'project_history.dart';

/// Real editor transactions on a single canonical dual-view project.
final class PneumaticWorkshopSession {
  PneumaticWorkshopSession(
    MultiphysicsProject initial, {
    int historyCapacity = 100,
  }) : _history = ProjectHistory<MultiphysicsProject>(
         initial,
         capacity: historyCapacity,
       );

  final ProjectHistory<MultiphysicsProject> _history;
  PneumaticWorkshopView _view = PneumaticWorkshopView.physical;
  String? _selection;

  PneumaticWorkshopState get state => PneumaticWorkshopState(
    project: _history.current,
    view: _view,
    selectedPhysicalId: _selection,
  );
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;

  void switchView(PneumaticWorkshopView view) {
    _view = view;
  }

  void select(String? id) {
    _selection = state.select(id).selectedPhysicalId;
  }

  /// Rejected editor mutations cannot partially overwrite accepted history.
  void apply(PneumaticWorkshopState Function(PneumaticWorkshopState) change) {
    final PneumaticWorkshopState next = change(state);
    if (next.project.toJsonString() != _history.current.toJsonString()) {
      _history.accept(next.project);
    }
    _view = next.view;
    _selection = next.selectedPhysicalId;
    _sanitizeSelection();
  }

  void undo() {
    _history.undo();
    _sanitizeSelection();
  }

  void redo() {
    _history.redo();
    _sanitizeSelection();
  }

  void _sanitizeSelection() {
    final String? id = _selection;
    if (id != null &&
        !_history.current.devices.any((PhysicalDeviceRecord d) => d.id == id)) {
      _selection = null;
    }
  }
}
