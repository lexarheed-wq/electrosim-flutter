# ElectroSim Flutter F12-R1

F12 introduces a pure-Dart TP orchestration layer:

- explicit TP lifecycle: draft -> published -> started -> submitted -> evaluated -> closed;
- wiring and troubleshooting modes;
- student diagnostic sheet exposed only during student troubleshooting;
- submitted/evaluated/closed TPs are read-only;
- troubleshooting repair is recalculated through TopologyEngine + SolverDC;
- generated score after submission;
- no teacherTruth in student payload;
- one active TP at a time.

Run `./validate.sh`. Expected final marker: `F12_GATE_PASS`.
