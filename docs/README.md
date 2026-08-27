# Documentation Index

Tracked documentation lives in this directory tree. Local-only operational notes should stay under `docs/internal/`, which is intentionally git-ignored.

## Active Guides

- [`guides/HOST_ONBOARDING.md`](./guides/HOST_ONBOARDING.md): use this when adding a new host or checking where host files belong.
- [`guides/HARDWARE_BENCHMARK.md`](./guides/HARDWARE_BENCHMARK.md): repeatable CPU, memory, GPU, storage, LLM, developer-build, and long-run stability measurements.
- [`guides/PLANK_REMOTE_INSTALL.md`](./guides/PLANK_REMOTE_INSTALL.md): use this when installing `plank` on a remote machine.

## Specialized Guides

- [`guides/LOCAL_LLM.md`](./guides/LOCAL_LLM.md): use this when running local LLM tools on `think14gryzen`.
- [`ROFI_UTILITIES.md`](./ROFI_UTILITIES.md): use this for Study Timer and Screen Time dashboard documentation.

## Archived Material

- [`archive/REMOTE_MIGRATION.md`](./archive/REMOTE_MIGRATION.md): legacy remote migration note kept for historical reference.
- [`archive/rocm/README.md`](./archive/rocm/README.md): ROCm status + investigation archive — Tier A trimmed to diagnostics + OpenCL on 2026-08-25 (HIP libraries removed, nothing used them); framework lane NO-GO, training is cloud-only.
