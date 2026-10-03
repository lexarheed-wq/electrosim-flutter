# ElectroSim V1 parity — M13-R2 technical baseline

## Status

The V1 parity programme starts from the qualified M13-R2 technical baseline.

- Baseline commit: `9a7fde0d7be8ed4f90e805dc9acb736fe2b35f91`
- Immutable reference branch: `m13-r2-baseline`
- Working branch: `v1-parity`
- Original qualification workflow: `M13-R2 final convergence candidate` — PASS on the baseline commit

## Scope of the freeze

During V1 parity work, the electrical/solver core is frozen. These roots must stay byte-identical to M13-R2 unless the user explicitly decides to unlock and rebaseline the core:

- `packages/electrosim_domain`
- `packages/electrosim_topology`
- `packages/electrosim_solver_dc`
- `packages/electrosim_solver_ac`
- `packages/electrosim_measurements`
- `packages/electrosim_protection`
- `packages/electrosim_controls`
- `packages/electrosim_energy`
- `packages/electrosim_pv`
- `packages/electrosim_diagnostics`
- `packages/electrosim_storage`

Navigation, application orchestration, UI, canvas/presentation, TP/scenario integration and platform configuration may evolve during parity work without silently changing the validated electrical core.

## Enforced guard

`reference/v1_parity_m13r2_core_manifest.json` records the baseline Git blob IDs.

`.github/workflows/v1-parity-baseline-guard.yml` verifies on every push to `v1-parity` and every pull request targeting it that:

1. `m13-r2-baseline` still points to the exact M13-R2 commit.
2. The working history still descends from M13-R2.
3. No file under a frozen root differs from M13-R2.

Changing this baseline is a rebaseline operation and requires an explicit user decision.

## Point-1 acceptance criteria

Point 1 is valid only if:

1. `m13-r2-baseline` points to the exact M13-R2 commit.
2. `v1-parity` descends from that same commit.
3. The M13-R2 qualification workflow is successful on that commit.
4. The baseline guard passes.
5. The point-1 setup changes only governance/reference files and no application behaviour.
