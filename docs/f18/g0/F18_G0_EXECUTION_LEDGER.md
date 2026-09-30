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
