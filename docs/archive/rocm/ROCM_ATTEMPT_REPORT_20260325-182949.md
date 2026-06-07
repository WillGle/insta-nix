# ROCm Attempt Report 20260325-182949

## Status

- Archived
- Historical record; ROCm runtime was later reinstated 2026-06-07 (Tier A library stack active, framework lane still NO-GO) — see [`ROCM_WORKLOG_20260607-113702.md`](./ROCM_WORKLOG_20260607-113702.md)

## Summary

This file summarizes the March 25, 2026 ROCm retry review and its final verdict.

It is kept as a historical report. It does not describe an active support path for the current host configuration.

## Historical details

## Baseline

- Attempt started: `20260325-182949`
- Host target: `Think14GRyzen`
- Repo root: `/etc/nixos`
- Raw artifact root: `/var/tmp/rocm-retry-20260325-182949`
- Current state before any ROCm change: stable `amdgpu` desktop baseline, `/dev/kfd` present, ROCm userland absent

## Rollback State

- Current system generation link: `/nix/var/nix/profiles/system -> system-420-link`
- Current system store path: `/nix/store/lbimrj14xvy772vn1wgx5ifavj2s9gk3-nixos-system-Think14GRyzen-25.11.20260323.4590696`
- Booted system store path: `/nix/store/gfkfr8jawf2w350fpvbmw4pkiw9hp1c3-nixos-system-Think14GRyzen-25.11.20260320.812b398`
- Previous visible generation: `system-419-link -> 25.11.20260320.812b398`
- Standard rollback path remains documented as `sudo nixos-rebuild switch --rollback` or previous boot generation
- `nix-env -p /nix/var/nix/profiles/system --list-generations` was not readable without privileges, so rollback evidence was captured via profile links and current/booted system symlinks instead

## Official AMD URLs Consulted

- `https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/index.html`
- `https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/prerequisites/prerequisitesryz.html`
- `https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/compatibility/compatibilityryz/native_linux/native_linux_compatibility.html`
- `https://rocm.docs.amd.com/en/latest/compatibility/compatibility-matrix.html`

## Key Official Findings

- Ryzen prerequisites require using a Ryzen APU listed in the compatibility matrix and recommend `64GB+` system memory.
- Current Ryzen ROCm Linux matrix lists `Ubuntu 24.04.3` as supported and currently lists only `gfx1150/gfx1151` Ryzen AI Max / AI 300 / AI 400 hardware.
- Current general ROCm compatibility matrix does not list NixOS among supported operating systems.

## Community / Fallback URLs Consulted

- `https://discourse.nixos.org/t/how-to-ollama-on-amd-strix-halo/74363/5`

## Community / Fallback Findings

- Community reports confirm wrapper-level override experiments such as `rocmOverrideGfx = "11.0.0"` or related override values can change detection behavior on unsupported APUs.
- These do not change AMD's official support boundary and were not used in this attempt.

## Exact Commits Inspected

- `154d279f3e58d3e1590c88aa831dbd1e4e0b1ad0`
- `40f082605e543951700ffc739c29ca6cd3c1b85a`

## Exact Config / Package Changes Attempted

- None. No system configuration change was applied.
- No ROCm package was reintroduced because the attempt halted at F1.

## Overrides / Fallback Lanes Tried

- `HSA_OVERRIDE_GFX_VERSION`: not tried
- `HCC_AMDGPU_TARGET`: not tried
- `rocmOverrideGfx`: not tried
- container fallback: not tried
- `nixos-rocm` overlay: not tried

## Phase Outcomes

- F0: PASS
- F1: FAIL
- F2: STOPPED
- F3: STOPPED
- F4: STOPPED
- F5: STOPPED
- F6: PASS

## Runtime-only Outcome

- Not attempted. The run stopped before any rebuild because F1 returned a pre-install `NO-GO`.

## Framework Canary Outcome

- Not attempted in this run.

## CPDA Quick Compatibility Outcome

- Not attempted in this run.

## Final Rollback State

- Unchanged from baseline. No rebuild or switch was executed.

## Final Verdict

`NO-GO`

## Recommended Next Action

- Keep ROCm out of the active NixOS host configuration on this machine.
- If ROCm experimentation is still required, move it to a currently supported Ubuntu ROCm lane and supported Ryzen/Radeon hardware, or treat it as an isolated non-production investigation outside the daily-driver host.

## References

- [`README.md`](./README.md)
- [`ROCM_CONFLICT_MATRIX_20260325-182949.md`](./ROCM_CONFLICT_MATRIX_20260325-182949.md)
- [`ROCM_WORKLOG_20260325-182949.md`](./ROCM_WORKLOG_20260325-182949.md)
