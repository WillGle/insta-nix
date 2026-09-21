# Native power-profile benchmark storage

`scripts/bench/power-profiles.sh` writes one timestamped run directory here by
default. It benchmarks the current `native-power-profile` presets with the same
one-core and all-core `stress-ng` workload, records CPU/APU telemetry, and
restores the profile active before the run.

Each run contains a summary, telemetry, metadata, exact commands, and one
subdirectory per profile with its logs. Existing run directories are never
overwritten. The benchmark does not write RyzenAdj or Curve Optimizer settings.
