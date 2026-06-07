# ROCm Hardware Inventory 20260325-182949

## Status

- Archived
- Historical record; ROCm runtime was later reinstated 2026-06-07 (Tier A library stack active, framework lane still NO-GO) — see [`ROCM_WORKLOG_20260607-113702.md`](./ROCM_WORKLOG_20260607-113702.md)

## Summary

This file records the hardware and baseline software state captured for the March 25, 2026 ROCm retry review.

Use it as historical reference for that investigation.

## Historical details

## Machine Facts

- Host: `Think14GRyzen`
- Repo root: `/etc/nixos`
- OS: `NixOS 25.11.20260323.4590696 (Xantusia)`
- Kernel: `6.12.76`
- Current system store path: `/nix/store/lbimrj14xvy772vn1wgx5ifavj2s9gk3-nixos-system-Think14GRyzen-25.11.20260323.4590696`
- Booted system store path: `/nix/store/gfkfr8jawf2w350fpvbmw4pkiw9hp1c3-nixos-system-Think14GRyzen-25.11.20260320.812b398`

## CPU / GPU

- CPU: `AMD Ryzen 7 8845H w/ Radeon 780M Graphics`
- CPU topology: `8 cores / 16 threads`
- GPU PCI identity: `65:00.0 Advanced Micro Devices, Inc. [AMD/ATI] HawkPoint1 [1002:1900]`
- Active kernel graphics driver: `amdgpu`
- `/dev/kfd`: present
- `/dev/dri/renderD128`: present

## Memory / Storage

- OS-visible memory: `27 GiB total`, `12 GiB available` at capture time
- Swap: `40 GiB total` (`zram0` + disk swap)
- Root filesystem: `ext4`
- Boot filesystem: `vfat`
- Main system disk: `KINGSTON SNVS500G 465.8G`

## Power / CPU Policy Baseline

- `power-profiles-daemon`: enabled `linked`, active `active`
- `tlp`: `not-found`, inactive
- `lactd`: `not-found`, inactive
- `amd_pstate`: `active`
- Scaling driver: `amd-pstate-epp`
- Governor: `performance`
- EPP: `performance`

## Current ROCm / Graphics Userland State

- `rocminfo`: absent
- `rocm-smi`: absent
- `clinfo`: present, reports `Number of platforms 0`
- `vulkaninfo --summary`: present, reports `AMD Radeon 780M Graphics (RADV PHOENIX)` and `llvmpipe`
- Current kernel journal scan found no current-boot `MES failed`, `GPU reset`, `VRAM is lost`, or ring-timeout signatures in the baseline state

## Raw Artifacts

- `/var/tmp/rocm-retry-20260325-182949/system-version.txt`
- `/var/tmp/rocm-retry-20260325-182949/system-generation-targets.txt`
- `/var/tmp/rocm-retry-20260325-182949/lscpu.txt`
- `/var/tmp/rocm-retry-20260325-182949/lspci-nnk.txt`
- `/var/tmp/rocm-retry-20260325-182949/lsblk.txt`
- `/var/tmp/rocm-retry-20260325-182949/free-h.txt`
- `/var/tmp/rocm-retry-20260325-182949/lsmod-amd.txt`
- `/var/tmp/rocm-retry-20260325-182949/service-states.txt`
- `/var/tmp/rocm-retry-20260325-182949/cpufreq-state.txt`
- `/var/tmp/rocm-retry-20260325-182949/tool-presence.txt`
- `/var/tmp/rocm-retry-20260325-182949/device-nodes.txt`
- `/var/tmp/rocm-retry-20260325-182949/journal-kernel-amd-scan.txt`

## References

- [`README.md`](./README.md)
- [`ROCM_WORKLOG_20260325-182949.md`](./ROCM_WORKLOG_20260325-182949.md)
