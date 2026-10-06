#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"G8 contract failed: {label}")

models = read("packages/electrosim_tp/lib/src/tp_models.dart")
engine = read("packages/electrosim_tp/lib/src/tp_engine.dart")
controller = read("apps/electrosim/lib/runtime/electrosim_tp_session_controller.dart")
dialog = read("apps/electrosim/lib/f17_tp_session_dialog.dart")
main = read("apps/electrosim/lib/main.dart")
supervision = read("apps/electrosim/lib/f17_tp_supervision_panel.dart")
lan = read("apps/electrosim/lib/runtime/electrosim_lan_sync.dart")

for state in ("draft", "published", "started", "submitted", "evaluated", "closed"):
    require(models, state, f"TpLifecycle.{state} missing")
for state in ("TpLifecycle.submitted", "TpLifecycle.evaluated", "TpLifecycle.closed"):
    require(models, state, f"{state} must participate in read-only semantics")
require(models, "role == TpRole.student", "diagnostic sheet must be student-scoped")
require(models, "definition.mode == TpMode.troubleshooting", "diagnostic sheet must be troubleshooting-only")
require(models, "lifecycle == TpLifecycle.started", "diagnostic sheet must be active-session-only")

require(engine, "session.lifecycle != TpLifecycle.started || session.readOnly", "student circuit mutation guard missing")
require(engine, "diagnosticSheetVisibleFor(TpRole.student)", "diagnostic write guard missing")
require(engine, "TpLifecycle.submitted", "submission transition missing")
require(engine, "TpLifecycle.evaluated", "evaluation transition missing")
require(engine, "TpLifecycle.closed", "close transition missing")
require(engine, "teacherScore", "teacher grading path missing")

require(controller, "createStudentReplica", "student replica path missing")
require(controller, "updateStudentCircuit", "repair/update path missing")
require(controller, "addDiagnosticEntry", "diagnostic path missing")
require(controller, "submitStudent", "student submission path missing")
require(controller, "evaluateTeacher", "teacher grading path missing")
require(controller, "closeTeacher", "teacher close path missing")
require(controller, "deleteTeacherActivity", "teacher deletion path missing")

for key in (
    "tp-create-draft",
    "tp-publish",
    "tp-teacher-start",
    "tp-student-submit",
    "tp-teacher-score",
    "tp-evaluate",
    "tp-close",
    "tp-student-readonly-message",
):
    require(dialog, key, f"TP dialog action {key} missing")
if "tp-student-start" in dialog:
    raise SystemExit("G8 contract failed: student UI must not expose an autonomous start action")

require(main, "bool get _studentTpReadOnly", "workspace read-only derivation missing")
require(main, "bool _blockStudentTpMutation()", "workspace mutation guard missing")
if main.count("_blockStudentTpMutation()") < 6:
    raise SystemExit("G8 contract failed: workspace mutation guard coverage regressed")
require(main, "TP remis : montage en lecture seule.", "read-only user feedback missing")

for needle, label in (
    ("supervision-grade-input-", "teacher supervision grade input missing"),
    ("supervision-grade-submit-", "teacher supervision grade action missing"),
    ("supervision-close-student-", "teacher supervision close action missing"),
):
    require(supervision, needle, label)

require(lan, "evaluateStudent(", "LAN teacher grading command missing")
require(lan, "closeStudent(", "LAN teacher close command missing")

print("F18_G8_TP_TEACHER_STUDENT_CONTRACT_PASS")
