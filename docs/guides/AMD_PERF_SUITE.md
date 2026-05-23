# AMD Performance Suite

## Purpose

This guide explains how to use `scripts/amd-perf-suite.sh`.

This tooling is optional. It is not required for normal host builds or remote installs.

## When to use

Use this guide when you want repeatable CPU, GPU, or CPDA performance checks on `think14gryzen`.

## Prerequisites

- The repo is available at `/etc/nixos`.
- The script exists at `scripts/amd-perf-suite.sh`.
- Optional: `sudo` if you want kernel log checks or baseline storage under `/var/lib`.
- Optional: `<cpda-repo-root>` if you want CPDA tests.

## Steps

1. Run the default command.

   ```bash
   ./scripts/amd-perf-suite.sh
   ```

2. Use a simple custom run when needed.

   Balanced profile, three rounds:

   ```bash
   ./scripts/amd-perf-suite.sh --profile balanced --rounds 3
   ```

   Include the kernel log check:

   ```bash
   sudo ./scripts/amd-perf-suite.sh --with-kernel-log
   ```

3. Capture a baseline if you want later comparisons.

   ```bash
   BASE="/var/lib/amd-perf-suite/baselines/safe-r5-$(date +%Y%m%d-%H%M%S)"
   sudo mkdir -p /var/lib/amd-perf-suite/baselines
   sudo env "HOME=$HOME" "USER=$USER" "PATH=$PATH" ./scripts/amd-perf-suite.sh \
     --root "$BASE" \
     --profile safe \
     --rounds 5 \
     --cpda-cli-repeats 5 \
     --cpda-cli-cooldown-sec 2 \
     --cpda-thread-count 16 \
     --secondary-kpi-mode both \
     --with-kernel-log \
     --cpda-dir <cpda-repo-root>
   ```

4. Promote the baseline manually if you want a stable comparison target.

   ```bash
   sudo ln -sfn "$BASE" /var/lib/amd-perf-suite/baselines/current-safe
   ```

5. Run a comparison against that baseline.

   ```bash
   sudo env "HOME=$HOME" "USER=$USER" "PATH=$PATH" ./scripts/amd-perf-suite.sh \
     --profile safe \
     --rounds 5 \
     --cpda-cli-repeats 5 \
     --cpda-cli-cooldown-sec 2 \
     --cpda-thread-count 16 \
     --secondary-kpi-mode both \
     --with-kernel-log \
     --compare /var/lib/amd-perf-suite/baselines/current-safe \
     --cpda-dir <cpda-repo-root>
   ```

Plain-English notes:

- A `baseline` is a previous run saved for later comparison.
- `--compare <root>` tells the script which saved run to compare against.
- Without `--compare`, any result that depends on a baseline is marked `WARN`.
- `--cpda-cli-repeats` repeats the CPDA command to reduce noise.
- `--cpda-thread-count` keeps BLAS and OMP thread counts fixed for more stable results.
- `KPI` in this script means the summary result used to mark a performance comparison as pass, fail, or warn.

## Verification

Check that the script runs and writes output to the expected result directory.

If you used `--compare`, confirm the comparison points to the intended baseline path.

## Related docs

- [`LOCAL_LLM.md`](./LOCAL_LLM.md)
- [`../README.md`](../README.md)
