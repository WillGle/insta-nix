# ROCm Sub-Agent Prompt

## Status

- Archived
- Historical record; ROCm runtime was later reinstated 2026-06-07 (Tier A library stack active, framework lane still NO-GO) — see [`ROCM_WORKLOG_20260607-113702.md`](./ROCM_WORKLOG_20260607-113702.md)

## Summary

This file preserves the prompt used for a ROCm retry investigation on this machine.

Keep it as historical reference only. It reflects the assumptions, wording, and process used during that investigation.

## Historical details

Last updated: 2026-03-25

```text
You are a single execution sub-agent. Solve exactly one problem: determine whether ROCm can be safely reintroduced on this exact machine, and only proceed phase-by-phase when every safety gate passes. Do not branch into unrelated cleanup, refactors, or general optimization.

Your output must be stable, well-documented, thoughtful, and validation-first. Before every phase and before every material change, validate assumptions and write down the result. Do not ask for confirmation unless you hit a true blocker that cannot be resolved from repo state, system state, historical commits, or official/community documentation explicitly listed below.

Locked context: do not ask to reconfirm these facts
- Primary repo root: `/etc/nixos`
- Secondary repo in scope only at the final validation phase: `<cpda-repo-root>`
- Authoritative docs/evidence root: `/etc/nixos/docs`
- Relative path `../docs` from `/etc/nixos` does not exist as of 2026-03-25. Record that fact once and continue. Do not stop to ask where to store docs.
- Host target: `Think14GRyzen`
- CPU/GPU target: `AMD Ryzen 7 8845H w/ Radeon 780M Graphics` on the integrated GPU path (`amdgpu`)
- OS snapshot: `NixOS 25.11.20260323.4590696 (Xantusia)`
- Kernel snapshot: `6.12.76`
- Current CPU baseline: `amd_pstate=active`; expected scaling driver is `amd-pstate-epp`
- Current power policy baseline: `power-profiles-daemon` must remain the only active power manager
- Current OS-visible memory snapshot is about `27 GiB total` with shared-memory iGPU constraints. Treat large-model or training expectations conservatively.
- Historical incident anchor: major ROCm failure happened on 2026-03-12 during framework canary, with GPU reset, VRAM loss, and logout/session crash
- Historical retry-state commit: `154d279` dated 2026-03-13
- Historical rollback/removal commit: `40f0826` dated 2026-03-13

Mission boundaries
- Work only on ROCm retry/stability for this exact machine.
- Preserve unrelated changes in the current git worktree. Never revert unrelated files. Never use destructive git commands.
- Treat any sign of `MES failed`, `ring timeout`, `GPU reset`, `VRAM is lost`, hard kernel failure, or user-session logout as immediate `STOP NOW + rollback`.
- Do not jump straight to full framework enablement. Runtime-only, then soak/safe benchmarking, then one controlled framework canary, then CPDA validation.
- CPDA is in scope only after system/runtime stability gates pass.
- Add a quick compatibility check for competitor models actually used in CPDA. Do not run the full benchmark suite.

Official documentation policy
- Use AMD ROCm official docs as the support and install source of truth.
- Use these URLs first and cite the exact URLs you used in your report:
  - `https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/index.html`
  - `https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/prerequisites/prerequisitesryz.html`
  - `https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/prerequisites/prerequisitesrad.html`
  - `https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/compatibility/compatibilityryz/compatibility.html`
  - `https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/compatibility/compatibilityrad/native_linux/native_linux_compatibility.html`
  - `https://rocm.docs.amd.com/en/latest/compatibility/compatibility-matrix.html`
  - `https://rocm.docs.amd.com/en/latest/how-to/rocm-for-ai/system-setup/prerequisite-system-validation.html`
- For this machine, prefer the Ryzen/Radeon APU pages over the desktop Radeon native-Linux pages. Use the desktop pages only as comparative guidance. Do not treat desktop dGPU requirements as proof of support for this iGPU laptop.
- If the current official matrix does not list this exact APU/GPU or this distro path, explicitly mark that support gap. Do not silently treat unsupported or preview hardware as stable.
- Treat Radeon/Ryzen Linux support as preview-sensitive. Runtime detection success is not evidence of framework stability.
- Record that official Ryzen prerequisites currently recommend higher memory headroom than this machine's current OS-visible memory provides; do not over-interpret small-model success as production readiness.
- If official docs conflict with older local history, use official docs for support boundaries and local history for machine-specific failure evidence.

Community and fallback sources: useful, but not primary
- Community workaround discussion for iGPU overrides:
  - `https://discourse.nixos.org/t/how-to-ollama-on-amd-strix-halo/74363/5`
- NixOS Wiki references around Ollama/ROCm override behavior:
  - use only as a wrapper-level or package-level clue, not as official support proof
- Community ROCm packaging repository:
  - `https://github.com/nixos-rocm/nixos-rocm`
- Treat these as fallback references only. They can inform experiments, but they do not override official support boundaries.

Environment-variable and wrapper add-ons: evaluate carefully, never assume globally
- Community-suggested overrides for unsupported iGPU paths may include:
  - `HSA_OVERRIDE_GFX_VERSION=11.0.0`
  - `HCC_AMDGPU_TARGET=gfx1103`
- Older local ROCm canary history also used `HSA_OVERRIDE_GFX_VERSION=11.0.0` for `gfx1103`.
- These are experimental compatibility shims, not proof of official support.
- Do not set them globally during F0-F3.
- Only evaluate them in a tightly scoped shell, dev environment, or one-shot canary process after the no-override baseline is understood.
- If you use them, record:
  - where they were set
  - which exact command/process used them
  - whether behavior changed versus the no-override baseline
  - whether they improved runtime detection only, or actually improved workload stability
- `rocmOverrideGfx = "11.0.0"` is useful only for specific wrappers such as some Ollama packages. Do not confuse that wrapper-specific flag with generic system-wide ROCm validation.

Container and alternative packaging fallback policy
- If native NixOS ROCm setup becomes too ambiguous for framework testing, you may use official ROCm containers as an isolation aid only after the native host runtime state is documented.
- Container success is not proof of host stability. Host `/dev/kfd`, `/dev/dri`, kernel, `amdgpu`, and no-reset behavior still determine whether the machine is safe.
- The `nixos-rocm` repository may be inspected only if current `nixpkgs` and the historical pin from commit `154d279` both fail to provide a defensible minimal runtime path.
- Any use of Docker, containers, or community overlays must be documented as a fallback lane, not the default lane.

Mandatory local sources and read order before changing anything
1. `git -C /etc/nixos status --short`
2. `git -C /etc/nixos show --stat --summary 154d279`
3. `git -C /etc/nixos show --stat --summary 40f0826`
4. `/etc/nixos/docs/archive/rocm/ROCM_RETRY_CHECKPOINT_20260313.md`
5. `/etc/nixos/README.md`
6. `/etc/nixos/hosts/personal/think14gryzen-hardware.nix`
7. `/etc/nixos/profiles/personal/think14gryzen-system.nix`
- Do not modify configuration before reading those items in that order and recording what each one implies.

Additional CPDA sources to read only when Phase F5 begins
1. `<cpda-repo-root>/agents/START_HERE.md`
2. `<cpda-repo-root>/README.md`
3. `<cpda-repo-root>/pyproject.toml`
4. `<cpda-repo-root>/OCCPDA/models/pyod_baselines.py`
5. `<cpda-repo-root>/production_run.sh`

Historical facts you must carry forward
- Commit `154d279` added the retry toolkit and safe-lane support. It also introduced a pinned ROCm flake input and a pinned `rocm-phase4-python` environment for framework canary.
- Commit `40f0826` removed active ROCm rollout integration after GPU-reset/logout incidents, but retained the checkpoint document and generic AMD performance tooling.
- The old active ROCm package delta removed by `40f0826` was small and specific:
  - `rocmPackages.clr`
  - `rocmPackages.clr.icd`
  - `rocmPackages.rocm-smi`
  - `rocmPackages.rocminfo`
- Observability tools like `clinfo`, `vulkan-tools`, `amdgpu_top`, and `radeontop` already exist in the current config or were previously used as diagnostics. Re-add anything else only if docs or evidence require it.
- Do not restore the old framework canary environment or Torch ROCm pin during runtime-only phases.

Execution protocol that applies to every phase
- Maintain one timestamped working log from start to finish:
  - `TS="$(date +%Y%m%d-%H%M%S)"`
  - `WORKLOG="/etc/nixos/docs/archive/rocm/ROCM_WORKLOG_${TS}.md"`
  - `HW_DOC="/etc/nixos/docs/archive/rocm/ROCM_HARDWARE_INVENTORY_${TS}.md"`
  - `MATRIX_DOC="/etc/nixos/docs/archive/rocm/ROCM_CONFLICT_MATRIX_${TS}.md"`
  - `REPORT_DOC="/etc/nixos/docs/archive/rocm/ROCM_ATTEMPT_REPORT_${TS}.md"`
  - `RAW_ROOT="/var/tmp/rocm-retry-${TS}"`
- Create the docs files immediately and append to them during the run. Do not wait until the end to write evidence.
- Before each phase, write a section with:
  - `Preconditions`
  - `Commands to run`
  - `Expected output / pass criteria`
  - `Stop conditions`
  - `Rollback path`
  - `Artifacts to save`
- After each phase, write `PASS`, `FAIL`, or `STOPPED`, with exact evidence paths and the decisive reason.
- If a phase fails, stop advancing. Record the failure, execute rollback if needed, and produce a final verdict without moving to later phases.

Required deliverables
- A timestamped working log with time, phase, commands, and findings
- A hardware inventory file under `/etc/nixos/docs`
- A conflict matrix file under `/etc/nixos/docs`
- A ROCm attempt report under `/etc/nixos/docs`
- Final verdict must be exactly one of:
  - `NO-GO`
  - `SAFE-RUNTIME-ONLY`
  - `GO-WITH-CANARY-EVIDENCE`

Phase F0 - Freeze and baseline capture
Goal
- Freeze the current machine state, hardware facts, rollback position, and current ROCm absence/presence before any modification.

Required actions
- Confirm `/etc/nixos/docs` exists.
- Check and record that `/etc/nixos/../docs` is absent.
- Capture:
  - `git status --short`
  - active generation / rollback options
  - `nixos-version`
  - `uname -r`
  - `lscpu`
  - `lspci -nnk` for GPU/audio/AMD devices
  - `lsblk`
  - `free -h`
  - `lsmod | rg 'amdgpu|kfd|amd'`
  - `systemctl is-enabled` and `systemctl is-active` for `power-profiles-daemon`, `tlp`, `lactd`
  - current values for `amd_pstate`, governor, and EPP if available
  - presence/absence of `rocminfo`, `rocm-smi`, `clinfo`, `vulkaninfo`
- Save a concise hardware fact sheet to `HW_DOC`.
- Save the current rollback options and generation identifiers to `REPORT_DOC`.

Pass criteria
- Hardware and baseline state are fully captured.
- Current power-manager baseline is clear.
- Current rollback route is documented before any ROCm work starts.

Stop conditions
- Missing rollback path
- Unclear host identity
- Current system is already in a partially broken ROCm state you cannot explain from the repo/system evidence

Phase F1 - Conflict audit before install
Goal
- Determine whether the current machine state has package, service, driver, or policy conflicts that make ROCm retry unsafe before any install/rebuild happens.

Required actions
- Audit configuration and runtime for conflicts involving:
  - `amdgpu`
  - Mesa/Vulkan stack
  - `amd_pstate`
  - `power-profiles-daemon`
  - `tlp`
  - `lactd`
  - ROCm runtime packages
  - AMD observability tools
  - CPU/GPU tuning utilities that can distort A/B comparisons
  - low-memory pressure due to iGPU shared RAM
- Explicitly record whether NixOS is covered by the current AMD install/support docs for this target. If not, record that as a support-risk row in the matrix.
- Compare the exact GPU/APU against the current official compatibility pages. If the hardware is not explicitly listed, record it as unsupported/preview-risk.
- Explicitly evaluate whether the community override lane is worth a later canary test:
  - `HSA_OVERRIDE_GFX_VERSION=11.0.0`
  - `HCC_AMDGPU_TARGET=gfx1103`
- Do not enable those overrides in F1. Only decide whether they deserve a later controlled experiment.
- Build `MATRIX_DOC` with columns:
  - `component`
  - `current_state`
  - `risk_level`
  - `why_it_conflicts_or_not`
  - `required_action`
  - `phase_where_action_applies`
- End the phase with a crisp pre-install verdict: `GO` or `NO-GO`.

Pass criteria
- Every meaningful AMD/CPU/power/runtime conflict has an explicit row and action.
- There is a documented reason why retry may continue despite preview/unsupported risk, or the run is halted as `NO-GO`.

Stop conditions
- Multiple active power managers
- Unsupported hardware/distro risk with no acceptable mitigation
- Existing driver/runtime state already shows hard-failure signatures

Phase F2 - Minimal ROCm runtime only
Goal
- Reintroduce the smallest viable ROCm runtime surface first, without framework all-in enablement.

Default implementation rules
- Start from the current config, not from the old full rollout stack.
- Restore only the minimal ROCm package set first unless official docs force another dependency:
  - `rocmPackages.clr`
  - `rocmPackages.clr.icd`
  - `rocmPackages.rocminfo`
  - `rocmPackages.rocm-smi`
- Do not restore the old `rocm-phase4-python` flake package in this phase.
- Do not add Torch ROCm, TensorFlow ROCm, or any framework-specific wheel/environment in this phase.
- Only if current nixpkgs cannot provide the required minimal runtime in a reproducible way, inspect the old pinned ROCm input from commit `154d279` and justify any pin reintroduction explicitly.
- Do not use `nixos-rocm`, Docker, or wrapper-specific `rocmOverrideGfx` as the first move in this phase.

Validation after rebuild
- Run and record:
  - `rocminfo`
  - `clinfo`
  - `vulkaninfo --summary`
  - `rocm-smi` if available
  - journal and kernel scans for `amdgpu`, `kfd`, `gpu`, `ring timeout`, `reset`, `VRAM`
  - current module state for `amdgpu` and any ROCm-related kernel/runtime pieces
- Record whether runtime detection is clean, partial, or failed.

Pass criteria
- System rebuild succeeds.
- Runtime tools can execute without triggering hard kernel signatures.
- No logout/session crash.

Stop conditions
- Build failure you cannot resolve from docs and repo evidence
- Any hard-fail kernel signature
- Any user-session instability

Rollback path
- `sudo nixos-rebuild switch --rollback`
- If boot path is impacted, use the previous generation from the boot menu and document it

Phase F3 - Soak and safe benchmark lane
Goal
- Prove the runtime can survive safe, non-framework validation before touching framework canary.

Required actions
- Run safe-lane validation only. Prefer existing generic tooling such as `/etc/nixos/scripts/amd-perf-suite.sh` where appropriate.
- Keep framework canary disabled in this phase.
- Run at least two clean safe-lane passes before considering promotion to F4.
- Compare against the preserved safe baseline/evidence referenced by the checkpoint document when possible.

Pass criteria
- Two consecutive safe-lane runs finish without hard kernel failures, logout, or suspicious reset signatures.
- Performance and runtime behavior are documented relative to the existing safe baseline.

Stop conditions
- Any hard-fail kernel signature
- Unexplained instability, hangs, or soft-to-hard escalation trend

Phase F4 - One-shot framework canary
Goal
- Run exactly one controlled framework canary only after F2 and F3 pass cleanly.

Required actions
- Start with the cleanest no-override canary path that is still defensible.
- Monitor kernel logs in parallel.
- Keep rollback ready before launching the canary.
- If the canary is impossible to start on this iGPU without a compatibility shim, you may run exactly one scoped comparison using:
  - `HSA_OVERRIDE_GFX_VERSION=11.0.0`
  - optionally `HCC_AMDGPU_TARGET=gfx1103`
- Never make those overrides global in system config during this phase unless a later decision explicitly requires it and you have already documented process-local evidence first.
- If reintroducing a historical Torch ROCm environment becomes necessary here, justify it from commit `154d279`, official docs, and the conflict matrix, and keep the change scoped to canary validation.
- If native user-space canary remains too ambiguous, you may add one containerized framework observation as a fallback diagnostic, but it cannot replace the host verdict.

Pass criteria
- Canary completes without GPU reset, logout, or hard kernel fault.

Stop conditions
- Any single recurrence of the 2026-03-12 signature family:
  - `MES failed`
  - `GPU reset begin`
  - `VRAM is lost`
  - ring timeout
  - compositor/session crash or forced logout
- One recurrence is enough to stop and classify the machine as `NO-GO` for framework lane.

Phase F5 - CPDA validation and quick competitor compatibility
Goal
- Verify that ROCm retry does not break the actual CPDA workloads and competitor models currently used in practice, without running the full suite.

Read and respect these CPDA facts
- Stable default benchmark model set is:
  - `cpda`
  - `ocsvm`
  - `iforest`
  - `lof`
  - `knn`
- Production benchmark history also includes deep competitors:
  - `autoencoder`
  - `deepsvdd`
- CPDA currently pins:
  - `torch==2.9.1+cpu`
  - `torchvision==0.24.1+cpu`
  - `torchaudio==2.9.1+cpu`
  - `tensorflow-cpu==2.15.0`
- `autoencoder` in `pyod_baselines.py` is explicitly forced to `device="cpu"` for stability.
- `deepsvdd` remains a deep baseline and must be treated as backend-sensitive.

Required actions
- Only enter this phase if F2-F4 passed well enough to justify app-level checking.
- Work on a CPDA canary branch if any repo edits become necessary.
- Do not run the full CPDA suite.
- Run a quick smoke benchmark on a canonical small dataset, using the CPDA quick path around `OCCPDA/datasets/Classical/38_thyroid.npz` unless a better repo-local smoke dataset is clearly documented.
- First quick compatibility set:
  - `cpda ocsvm iforest lof knn`
- Then deep-risk quick set:
  - `autoencoder deepsvdd`
- The purpose is not to prove full scientific performance. The purpose is to detect backend breakage, forced device switching, import/runtime errors, obvious correctness failures, or instability introduced by ROCm retry.
- Explicitly verify that the stable default models still run as expected and that deep competitors do not unexpectedly auto-select a broken GPU path.
- If a model is intentionally CPU-pinned, treat an unexpected GPU takeover as a failure.
- Record whether current ROCm work is actually useful for CPDA, neutral for CPDA, or harmful to CPDA.

Pass criteria
- Stable default model set can run a quick smoke path without backend/device regressions.
- Deep competitor quick checks do not trigger hard failure or incorrect device selection.
- No CPDA runtime path regresses because of ROCm retry.

Stop conditions
- Import failure, device-selection regression, hard runtime failure, or correctness anomaly in the quick checks
- Any signal that ROCm retry breaks the stable CPU-pinned baseline workflow

Phase F6 - Final report and verdict
Goal
- Close the loop with a decision-complete report that another engineer can audit without replaying your entire session.

Required report content
- Machine facts and baseline
- Exact official AMD URLs consulted
- Exact community or fallback URLs consulted, if any
- Exact commit(s) inspected or reused
- Exact config/package changes attempted
- Whether `HSA_OVERRIDE_GFX_VERSION`, `HCC_AMDGPU_TARGET`, `rocmOverrideGfx`, container fallback, or `nixos-rocm` were tried, and with what effect
- Phase-by-phase PASS/FAIL evidence
- Conflict matrix summary
- Runtime-only outcome
- Framework canary outcome
- CPDA quick compatibility outcome:
  - stable set `cpda/ocsvm/iforest/lof/knn`
  - deep competitors `autoencoder/deepsvdd`
- Final rollback state
- Recommended next action

Verdict rules
- `NO-GO`
  - Any hard kernel failure
  - Any recurrence of the known GPU reset/logout signature family
  - Unsupported/preview situation with unacceptable operational risk
  - CPDA stable path or quick competitor checks regress
- `SAFE-RUNTIME-ONLY`
  - Runtime-only phases are acceptable, but framework or app-level risk remains too high
  - Use this when ROCm runtime can exist for diagnostics/safe benchmarking but not for trusted framework rollout
- `GO-WITH-CANARY-EVIDENCE`
  - Only if runtime, safe lane, one framework canary, and CPDA quick compatibility all pass with evidence and no hard-fail signatures

Non-negotiable behavioral rules
- Be explicit, not optimistic.
- Prefer `NO-GO` over wishful interpretation.
- Runtime detect PASS does not equal framework stability PASS.
- Preview support does not equal production readiness.
- Do not leave evidence unwritten.
- Do not ask follow-up questions for facts already available in the repo, system, commits, or listed docs.
```

## Maintenance note

- Re-check the official AMD compatibility matrix before reusing this prompt on a different ROCm release.
- If the host kernel, NixOS version, available system memory, or CPDA backend pins change, update the locked context section before delegating.

## References

- [`README.md`](./README.md)
- [`ROCM_RETRY_CHECKPOINT_20260313.md`](./ROCM_RETRY_CHECKPOINT_20260313.md)
