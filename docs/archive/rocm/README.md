# ROCm — Current Status + Investigation Archive

## Current status (2026-08-22)

**Final verdict (Conclusion v3 in `ROCM_WORKLOG_20260822-022110.md`): local
PyTorch/Unsloth training on gfx1103 is STOCHASTIC — functionally correct when
it runs, but the same 4B QLoRA config went 1 PASS (100 steps / 19.6 min
clean) vs 4 instant MES hangs across fresh boots, reset states, power
profiles, and identical scripts. No variable predicts survival. NOT usable
for real training; matches AMD/Unsloth excluding gfx1103 from their support
matrices.**

What the campaign established:
- ROCm 7.2 wheels + `HSA_OVERRIDE_GFX_VERSION=11.0.2` (mandatory — no-spoof
  segfaults) compute *correctly* when they survive: real gradients, decreasing
  loss, saved adapters, ~4 TFLOPS fp16 matmul. Fine for short throwaway
  experiments at ~80% instant-fail odds per attempt.
- Higher-intensity lanes (MLP-LoRA targets, AOTriton experimental attention)
  failed 3/3 — read as higher crash probability, not distinct root causes.
- A MES hang now costs ~5 s (MODE2 reset, session survives, kernel 6.12.93;
  7 resets across the campaign, 0 logouts) — cheap to retry, impossible to
  trust.
- **Vulkan inference (`llm-run`) was unaffected throughout** — the stable
  lane stays stable.
- The experiment stack was TORN DOWN 2026-08-22 by user decision (stochastic
  training rejected even for experiments; ~25 GiB reclaimed). Recreate recipe
  remains in the worklog if ever wanted on supported hardware.
- DaVinci Resolve removed from the box (2026-08-22) → the old "protect the
  shared OpenCL ICD" constraint is obsolete.
- **Real fine-tuning = cloud GPU (Unsloth QLoRA) → export GGUF → serve
  locally via `llm-run`.**

## Previous status (2026-06-07)

ROCm partially active on `think14gryzen` (Radeon 780M / gfx1103):

- **Runtime / library stack (Tier A): ACTIVE.** The full `rocmPackages` userspace (clr, clr.icd,
  rocminfo, rocm-smi, rocm-runtime, rocblas, hipblas, hipblaslt, rocsolver, rocsparse, hipsparse,
  rocfft, hipfft, rocrand, hiprand, rocprim, rocthrust, hipcub, miopen, amdsmi, rocm-bandwidth-test)
  is installed via the host config. It is cache-served (no local compilation) and **library-only**,
  so it dispatches no GPU kernels and cannot trigger the historical GPU-reset/logout. `clr`/`clr.icd`
  also feed DaVinci Resolve's OpenCL on the same 780M.
- **Framework / compute lane (PyTorch-ROCm, ollama-rocm, llama.cpp-HIP): NO-GO for LLM; stability-gated for ML.**
  gfx1103 is not an officially supported ROCm target and previously caused MES failure → GPU reset → logout.
  - **LLM inference does NOT use ROCm.** It runs on **Vulkan** via `llm-run` (llama.cpp). Measured 2026-06-07:
    ROCm-LLM is both **~2.5-3x slower AND crash-prone** on gfx1103 — it loses on every axis. The optimal LLM
    path is `llm-pull`/`llm-fit`/`llm-run` (see [`../../guides/LOCAL_LLM.md`](../../guides/LOCAL_LLM.md) and the
    local note `docs/internal/LLM_BENCHMARK_20260607.md`).
  - **ROCm's actual role here = ML / HIP compute** (PyTorch/TF/JAX training) — the *only* GPU path for that on
    AMD. On gfx1103 it is crash-prone, so it is **stability-gated**: run it isolated (Ubuntu-ROCm container /
    scoped devshell) + checkpointed, or in the cloud. See the local note `docs/internal/ML_GPU_COMPUTE_20260607.md`.

See [`ROCM_WORKLOG_20260607-113702.md`](./ROCM_WORKLOG_20260607-113702.md) for the full 2026-06-07
reinstatement (diagnosis, evidence, config, safety gates, switch + verification). The dated files
below are **historical investigation records** from the earlier 2026-03 campaign, when ROCm had been
rolled back — read them as context, not as the current state.

## Files in this directory

- `ROCM_WORKLOG_20260822-022110.md`: **current** worklog — Unsloth QLoRA canary,
  MES-hang trigger isolation (MLP-LoRA + AOTriton), safe-envelope definition.
- `ROCM_WORKLOG_20260607-113702.md`: the 2026-06-07 Tier A install
  (cache/broken-flag/gfx1103 findings, decision, config, verification).
- `ROCM_RETRY_CHECKPOINT_20260313.md`: Vietnamese checkpoint recording the March 13, 2026 rollback
  rationale and retry rules.
- `ROCM_SUBAGENT_PROMPT.md`: preserved agent prompt used for the later ROCm retry investigation.
- `ROCM_WORKLOG_20260325-182949.md`: timestamped worklog for the March 25, 2026 retry review.
- `ROCM_ATTEMPT_REPORT_20260325-182949.md`: summary report and verdict for that review (NO-GO).
- `ROCM_CONFLICT_MATRIX_20260325-182949.md`: condensed risk table / pre-install verdict for that review.
- `ROCM_HARDWARE_INVENTORY_20260325-182949.md`: hardware and baseline state for that review.

## Key facts to carry forward

- Runtime-detect PASS (`rocminfo`/`clinfo`) ≠ framework-stable PASS.
- gfx1103 is absent from the default `clr.gpuTargets` and from the torch-rocm
  wheels; any ROCm *compute* needs `HSA_OVERRIDE_GFX_VERSION=11.0.2` (11.0.0
  as fallback). Crash-prone only on the two isolated kernel paths above —
  stable inside the attention-only envelope.
- Do NOT set `nixpkgs.config.rocmSupport` globally (de-substitutes the cache).
  A global `HSA_OVERRIDE` no longer breaks anything (DaVinci gone) but
  per-process scoping stays the cleaner habit.
- The full rocmPackages stack is `meta.broken=false` and **cache-served** on the 25.11 pin; overriding
  `localGpuTargets`/`rocmSupport` de-substitutes it and forces multi-hour local builds (hipblaslt OOMs).

## References

- [`../../README.md`](../../README.md)
- [`../../guides/LOCAL_LLM.md`](../../guides/LOCAL_LLM.md)
