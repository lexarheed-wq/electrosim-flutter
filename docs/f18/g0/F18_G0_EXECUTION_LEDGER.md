# SDD ledger — plan: docs/superpowers/plans/2026-09-30-electrosim-f18-g0-baseline-inventory.md

Execution mode: Superpowers executing-plans fallback because this harness exposes no subagent-dispatch primitive.

Pre-flight shared interfaces:
- Task 1 → Task 5: capture_baseline() and CLI are consumed by the drift/CI gate; consistent.
- Task 2 → Task 3: current Flutter inventory/modelType set is consumed by component parity validation; consistent.
- Task 2 → Task 4: current product inventory is evidence for capability parity; consistent.
- Task 3 → Task 6: component parity counts feed the final report; consistent.
- Task 4 → Task 6: capability parity counts/status feed the final report; consistent.
- Task 5 → Task 6: exact CI gate marker/run evidence feeds the final report; consistent.

Ruling: G0 branch starts from the approved spec/plan head 0a2e1eeb rather than raw main so the binding spec is reachable during execution. Product/runtime files remain identical to main@554d1568. Cost if wrong: documentation commits would need to be split into a separate PR before merge.

Ruling: introduce the G0 workflow during Task 1 instead of Task 5 solely to observe RED→GREEN remotely. The workflow is configuration-only and will be expanded at Task 5. Cost if wrong: one workflow-history cleanup/refactor, no product behavior impact.


Task 1 RED: workflow run 36718170896 failed with ModuleNotFoundError for tools.f18_g0_capture_baseline, matching the planned missing-feature failure.
Task 1 GREEN: workflow run 36718286958 passed the four baseline tests after commit 9510729.
Task 1 final verification: workflow run 36718365860 passed on head ba05ba7 after committing deterministic JSON/Markdown outputs.
Task 1: complete (commits 31f70a1..ba05ba7, tests: python3 -m unittest tools.test_f18_g0_tooling -v → PASS)


Task 2 RED: workflow run 36718517520 failed with ModuleNotFoundError for tools.f18_g0_build_parity, matching the planned missing-feature failure.
Task 2 GREEN: workflow run 36718700391 passed inventory extraction tests after commit 08e29fa.
Task 2 final verification: workflow run 36718771223 passed on head caffa983 with committed current-product inventory.
Task 2: complete (commits be0a00f..caffa983, tests: python3 -m unittest tools.test_f18_g0_tooling.F18G0ParityTests -v → PASS)


Task 3 RED-1: workflow run 36718962740 failed because validate_parity did not exist, matching the planned validator gap.
Task 3 RED-2: workflow run 36719190187 passed 10/11 tests and failed only because docs/f18/g0/F18_PRODUCT_PARITY.csv did not yet exist.
Task 3 Ruling: current support is conservative — only the 12 modelType values demonstrated by the qualified Flutter palette are marked REBUILD. Measurement entities are REPLACE via MeasurementEngine; legacy compatibility entries are RETIRE; all other unsupported/unproven families are DEFER until G5 evidence. Cost if wrong: a genuinely supported family may remain hidden one gate longer, but no unsupported component is falsely exposed.
Task 3 classification: 217 rows = 12 REBUILD, 11 REPLACE, 168 DEFER, 26 RETIRE; entity classes remain 195 palette-component, 4 socket, 18 external-appliance.
Task 3 GREEN/final verification: workflow run 36719356243 passed the complete G0 Python suite on head 2ce88da.
Task 3: complete (commits 73a3161..2ce88da, tests: python3 -m unittest tools.test_f18_g0_tooling.F18G0ParityMatrixTests -v → PASS)


Task 4 RED-1: workflow run 36719523932 failed because validate_capability_parity did not exist.
Task 4 RED-2: workflow run 36719610887 passed all validators except the committed capability matrix, which was absent.
Task 4 GREEN/final verification: workflow run 36719853724 passed with 29 capability rows: 4 PRESENT, 19 PARTIAL, 2 MISSING, 4 INTENTIONALLY_REDESIGNED.
Task 4: complete (commits aacba30..9244967, tests: python3 -m unittest tools.test_f18_g0_tooling.F18G0CapabilityParityTests -v → PASS)


Task 5 RED: workflow run 36720005670 failed because find_forbidden_g0_changes did not exist.
Task 5 GREEN-1: workflow run 36720124523 passed all Python drift-guard tests after commit 71b1ae3.
Task 5 RED-2: workflow run 36720202908 failed because check_committed_parity did not exist.
Task 5 GREEN-2: workflow run 36720328630 passed committed parity checks after commit ab62fd5.
Task 5 integration finding: workflow run 36720468625 failed before Flutter because verify_legacy_reference.py consumed audit/legacy_reference_analysis.json without first generating it.
Task 5 Ruling: run tools/analyze_legacy_reference.py immediately before tools/verify_legacy_reference.py in G0 CI; do not alter historical F0 tools. Root cause is workflow ordering, not reference corruption. Cost if wrong: G0 could generate a transient audit that masks a verifier defect, but the verifier still independently checks the frozen ZIP SHA and stored audit structure.
Task 5 final verification: workflow run 36720687139 PASS on head 5715fd244e6f70ce4d8f0764522543b4936dbbca; marker F18_G0_BASELINE_INVENTORY_GATE_PASS; Flutter suite 76/76 PASS.
Task 5 evidence artifact: id 11099130881, digest sha256:cdae5aea664ed26b66156225c9b93093d2146f70b8865d6d25f2cf9e0a6ef011.
Task 5: complete (commits 4357958..5715fd2, full G0 gate → PASS)
