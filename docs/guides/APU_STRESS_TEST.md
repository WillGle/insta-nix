# APU Stress Test

## Purpose

This guide explains how to use `apu-stress-test` on `Laptop`.

The command is separate from `scripts/amd-perf-suite.sh`. Use `apu-stress-test` when you want a host-local CPU/GPU stress run with live telemetry and CSV export.

## Prerequisites

- The repo is available at `/etc/nixos`.
- You are on `Laptop`.
- A graphical session is active for any run that includes GPU stress.
- You applied the updated host config so the command exists in `~/.local/bin`.

## Install

Apply the host configuration:

```bash
sudo nixos-rebuild switch --flake path:/etc/nixos#Laptop
```

## Default run

The default run uses sequential CPU then GPU stress for 15 minutes, samples once per second, and writes results under `~/.local/state/apu-stress-test/runs/`.

```bash
apu-stress-test
```

## Useful examples

Quick CPU-only smoke run without changing power settings:

```bash
apu-stress-test --mode cpu --duration-minutes 1 --performance-mode off
```

Quick GPU-only smoke run:

```bash
apu-stress-test --mode gpu --duration-minutes 1 --performance-mode off
```

Custom sequential split with extra limits:

```bash
apu-stress-test \
  --mode sequential \
  --duration-minutes 10 \
  --cpu-seconds 240 \
  --gpu-seconds 360 \
  --max-input-w 45 \
  --min-cpu-ghz 2.8
```

## Output

Each run creates a timestamped directory with:

- `samples.csv`: raw time-series samples for load, temperatures, watts, and clocks
- `cpu_threads.csv`: per-sample clock values for every logical CPU thread, grouped by `core_id`
- `events.csv`: phase transitions, limit trips, and restore events
- `summary.csv`: one summary row for the run
- `run.log`: plain log output from the controller and stress commands

## Notes

- `--performance-mode auto` tries to switch to `powerprofilesctl performance` for the run and then restore the previous profile.
- `--performance-mode auto` also tries `sudo -n /run/current-system/sw/bin/ryzenadj-profile performance` when that wrapper is available without a password.
- Default enforced limits are CPU `94C` and GPU `88C`.
- Power and clock limits are opt-in flags.
- `summary.csv` now records the peak combined logical-thread clock (`peak_total_cpu_ghz`) and the peak single-thread clock (`peak_single_thread_ghz`) seen during the run.
