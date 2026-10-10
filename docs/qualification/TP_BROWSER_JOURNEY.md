# Classroom and TP browser qualification

The qualification uses the production student Web build in Chromium and the
production teacher widgets with a real native HTTP/WebSocket host. It runs both
troubleshooting and wiring activities. No legacy component assets are substituted.

The teacher creates a classroom, displays its QR, publishes and starts a TP,
observes the student's work, assigns 81/100, and explicitly stops the classroom.
The student follows the decoded QR URL, joins, edits the TP, opens the same URL in
a second tab of the same browser, resumes the same identity and circuit, submits,
attempts a forbidden component addition after submission, receives the grade and
sees the classroom close. The host circuit is checked unchanged after the attempt. The previous tab stops reconnecting
when the work is transferred to the new tab. The teacher management QR is decoded
and compared with the original classroom QR.

Dashboard widget regressions additionally check that Home and system Back retain
the active classroom, that its action resumes rather than creates a second
classroom, that teacher workshop preparation survives Home/resume, and that a new
classroom becomes available only after explicit termination. Diagnostic widget
regressions check the transition to submitted/read-only while the panel is open.

## Reproduction

Use Flutter 3.38.10. Install `tools/e2e/requirements.txt` and Chromium with
`python -m playwright install --with-deps chromium`. Prepare a Web runner with
`bash tools/f15_prepare_runner.sh web`, then build its app:

```sh
flutter build web --release --target lib/student_web_main.dart --no-wasm-dry-run
```

In the original repository's `apps/electrosim` directory:

```sh
flutter pub get
ELECTROSIM_STUDENT_WEB_ROOT=/absolute/runner/apps/electrosim/build/web \
  flutter test --no-pub test/tp_real_browser_journey_test.dart --reporter expanded
```

Without the Web root variable, the browser test is explicitly skipped. The G5
qualification workflow builds and executes it, uploads screenshots and transport
metadata for both modes, and records the source SHA and PNG checksums.

## Scope

QR images are decoded programmatically. The container connects to the same host
and port using loopback because its advertised LAN address is not externally
reachable; `transport.json` records both URLs. This tests real browser, native host
and WebSocket traffic, but does not certify a phone camera, Wi-Fi network or
physical Mac. Resumption requires the same browser storage and the same student
name while the teacher classroom host remains active. It does not promise recovery
across a teacher process restart or a different device.
