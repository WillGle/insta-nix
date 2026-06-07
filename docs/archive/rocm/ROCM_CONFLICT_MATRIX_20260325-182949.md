# ROCm Conflict Matrix 20260325-182949

## Status

- Archived
- Historical record; ROCm runtime was later reinstated 2026-06-07 (Tier A library stack active, framework lane still NO-GO) — see [`ROCM_WORKLOG_20260607-113702.md`](./ROCM_WORKLOG_20260607-113702.md)

## Summary

This file is the condensed risk table used during the March 25, 2026 ROCm retry review.

Read it as a historical decision record for that review.

## Historical details

| component | current_state | risk_level | why_it_conflicts_or_not | required_action | phase_where_action_applies |
| --- | --- | --- | --- | --- | --- |
| distro support | `NixOS 25.11` | high | Current official Ryzen ROCm Linux matrix lists `Ubuntu 24.04.3` only and does not list NixOS. This is an official support gap, not a packaging issue. | Treat host OS as unsupported for official ROCm retry. Do not interpret runtime detection as supported deployment. | F1 |
| APU / GPU support | `Ryzen 7 8845H` + `Radeon 780M` / PCI `1002:1900` | high | Current official Ryzen matrix lists `gfx1150/gfx1151` AI Max / AI 300 / AI 400 parts only. This Hawk Point `780M` path is not listed. | Treat hardware as unsupported / preview-risk with no official stability claim. | F1 |
| memory headroom | `27 GiB total` | high | Official Ryzen prerequisites recommend `64GB+` system memory and warn low memory may cause inference issues. Shared-memory iGPU pressure worsens this. | Do not use small-model success as evidence of production readiness. | F1 |
| historical failure evidence | 2026-03-12 framework canary caused `MES failed`, `GPU reset`, `VRAM is lost`, logout | high | Local machine-specific evidence already shows framework instability on this host. Unsupported current docs increase the risk, not reduce it. | Prefer `NO-GO` over another host-level rollout. | F1 |
| amdgpu / kfd baseline | `amdgpu` active, `/dev/kfd` present, no current hard-fail signatures | low | Kernel graphics/compute path is currently stable in the non-ROCm-userland baseline. This is necessary but not sufficient for ROCm safety. | Preserve baseline; use as control evidence only. | F0-F1 |
| power policy | `power-profiles-daemon` active; `tlp` and `lactd` absent | low | Matches the checkpoint guardrail and avoids A/B contamination from multiple power managers. | Keep unchanged. | F0-F6 |
| CPU policy | `amd_pstate=active`, `amd-pstate-epp`, governor `performance`, EPP `performance` | low | Matches the locked baseline and historical checkpoint. | Keep unchanged during any future comparison. | F0-F6 |
| current ROCm userland | `rocminfo` and `rocm-smi` absent; `clinfo` and `vulkaninfo` present | low | Host is currently clean of active ROCm runtime packages while retaining graphics diagnostics. | Good rollback baseline; no action required unless retry resumes. | F1 |
| community override lane | `HSA_OVERRIDE_GFX_VERSION=11.0.0`, `HCC_AMDGPU_TARGET=gfx1103`, `rocmOverrideGfx` exist only as community hints | high | Overrides may improve detection for unsupported GPUs but are not proof of official support or stability. Historical crash risk remains. | Do not use as justification to proceed on this host. | F1-F4 |
| current nixpkgs minimal packages | `rocmPackages.clr`, `clr.icd`, `rocminfo`, `rocm-smi` all still evaluate in current flake | medium | Packaging availability means a minimal retry is technically buildable, but it does not mitigate unsupported distro/APU risk. | Availability noted; not sufficient to clear F1. | F1 |
| privileged switch / rollback execution | `sudo -n` unavailable in current shell | medium | Controlled host reintroduction would require privileged `nixos-rebuild switch` and rollback. This session cannot perform that unattended. | Do not attempt rebuild/switch from this session. | F1-F2 |

## Pre-install Verdict

`NO-GO`

Reason:
- Official AMD ROCm Ryzen Linux support currently excludes both the host distro path and the exact APU/GPU.
- Official Ryzen prerequisites recommend materially more memory than this machine currently exposes to the OS.
- Local history already records a GPU reset/logout on this exact machine during ROCm framework canary.
- This session cannot execute a controlled privileged switch/rollback even if the support gate were acceptable.

## References

- [`README.md`](./README.md)
- [`ROCM_ATTEMPT_REPORT_20260325-182949.md`](./ROCM_ATTEMPT_REPORT_20260325-182949.md)
