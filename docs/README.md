# Documentation Index

Tracked documentation lives in this directory tree. Local-only operational notes should stay under `docs/internal/`, which is intentionally git-ignored.

## Active Guides

- [`guides/INSTALL.md`](./guides/INSTALL.md): install NixOS from an existing Linux distro with the local UEFI installer.
- [`guides/HOST_ONBOARDING.md`](./guides/HOST_ONBOARDING.md): use this when adding a new host or checking where host files belong.
- [`guides/HARDWARE_BENCHMARK.md`](./guides/HARDWARE_BENCHMARK.md): repeatable CPU, memory, GPU, storage, LLM, developer-build, and long-run stability measurements.

## Specialized Guides

- [`FLATPAK.md`](./FLATPAK.md): Flatpak and non-nixpkgs package inventory for manual reinstall.
- [`guides/LOCAL_LLM.md`](./guides/LOCAL_LLM.md): use this when running local LLM tools on `laptop`.
- Screen Time usage, design, and research. [Screen Time docs](https://github.com/WillGle/screen-time-rofi#readme)
- [`ATOMIC_NOTE_USAGE.md`](./ATOMIC_NOTE_USAGE.md): use this for the Waybar task queue and `atomic-note` commands.
- [`YAZI_USAGE.md`](./YAZI_USAGE.md): use this for Yazi keybindings and file-manager integrations.

## Archived Material

- [`archive/REMOTE_MIGRATION.md`](./archive/REMOTE_MIGRATION.md): legacy remote migration note kept for historical reference.
- [`archive/rocm/README.md`](./archive/rocm/README.md): ROCm status + investigation archive — Tier A trimmed to diagnostics + OpenCL on 2026-08-25 (HIP libraries removed, nothing used them); framework lane NO-GO, training is cloud-only.
