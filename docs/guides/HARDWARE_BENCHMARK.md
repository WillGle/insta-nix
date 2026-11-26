# Hardware benchmarks

CPU, RAM, GPU, storage, and LLM measurements. The power profile is recorded and
restored after each run; benchmarks do not change NixOS policy.

`oc-curve.sh` is the exception: it temporarily writes Curve Optimizer −1,
verifies readback, and resets before restoring the profile.

## Standard tests

| Component | Tool | Metric | Notes |
|---|---|---|---|
| CPU | `sysbench cpu` | events/s | Run 1 thread and all logical threads |
| RAM | `sysbench memory` | MiB/s | Sequential read/write; keep parameters fixed |
| GPU | `glmark2`, `vkmark` | FPS/score | OpenGL and Vulkan are separate APIs |
| Disk | `fio` | Throughput, IOPS, latency | Read-only on an existing file |
| LLM | `llama-bench` | tokens/s | `pp512/tg128`, Vulkan, Flash Attention |
| Thermal stability | `stress-ng` | Pass/fail | Do not compare bogo-ops/s |

The monitor stops a workload with `SENSOR_READ_FAIL` if a tracked sensor
disappears. An `NA` temperature is not proof of thermal protection.

## Run benchmarks

Each test runs 3 times by default. Results go to
`/var/tmp/laptop-bench/` or the `--output` directory, with raw logs,
`summary.tsv`, `telemetry.tsv`, `metadata.txt`, and `commands.txt`.

```bash
cd /etc/nixos
bash scripts/bench/cpu.sh --duration 30 --repetitions 3
bash scripts/bench/memory.sh --duration 30 --repetitions 3
bash scripts/bench/gpu.sh --repetitions 3

bash scripts/bench/llm.sh \
  --model /mnt/vault/lmstudio-models/unsloth/gemma-3-4b-it-GGUF/gemma-3-4b-it-UD-Q4_K_XL.gguf
```

### Five-stage roadmap

```bash
bash scripts/bench/roadmap.sh --quick --all

bash scripts/bench/roadmap.sh --all \
  --model /mnt/vault/lmstudio-models/unsloth/gemma-3-4b-it-GGUF/gemma-3-4b-it-UD-Q4_K_XL.gguf

bash scripts/bench/roadmap.sh --step 2 --output /tmp/laptop-roadmap-cpu
```

`--quick` uses short runs for a fast check. Stage 4 is `SKIP` without
`--model`. A test missing a measurement is `PARTIAL` with exit code 3. On
interrupt, the wrapper signals child benchmarks and waits for cleanup/profile
restore.

### Stress test

Plug in AC first. The default is 10 minutes; run 30 minutes to check thermal
limits.

```bash
bash scripts/bench/stress-long.sh --mode combined --duration 1800
bash scripts/bench/gpu.sh --long --duration 1800 --skip-vulkan
```

`stress-long.sh` compares the journal before/after to find hardware, kernel,
OOM, and GPU timeout/reset errors. If the journal cannot be read, that check is
`SKIP` with exit code 3. `gpu.sh --long` only passes when it completes the full
duration.

### Curve Optimizer −1

```bash
bash scripts/bench/oc-curve.sh
```

The script applies CO −1 to all 8 cores at the `performance` profile, runs CPU0
for 60 seconds, then 16 threads for 480 seconds. It requires the correct
hardware, AC power, CPU below 70°C, `sudo`, and an initial CO readback of 0. It
verifies/resets CO on exit. If reset cannot be verified, stop and cold reboot.

The script accepts only `--output` and `--help`; there is no `--profile`.
Do not change the Waybar profile during a run; it corrupts
`/run/native-power-profile/active`.

### Compare power profiles

```bash
bash scripts/bench/power-profiles.sh

bash scripts/bench/power-profiles.sh \
  --one-core-seconds 30 --all-core-seconds 180 --cooldown-seconds 60
```

The runner does not write RyzenAdj/CO, requires AC, stops at the hard thermal
limit, and restores the original profile. Results default to
`docs/internal/bench/power-profiles/<timestamp>-<pid>/`.

### Storage

The test needs an existing file at least `--size` bytes. Do not run it on a
block device.

```bash
nix shell nixpkgs#fio --command bash scripts/bench/storage.sh \
  --file /mnt/vault/lmstudio-models/unsloth/gemma-3-4b-it-GGUF/gemma-3-4b-it-UD-Q4_K_XL.gguf \
  --size 1G --duration 15 --repetitions 3
```

## Build workloads

- `scripts/bench/dev-build.sh` — real project builds: cold, warm, incremental,
  no-op; supports 1, 50%, and 100% threads.
- `scripts/bench/pts-developer.sh` — Phoronix Test Suite (`build-linux-kernel`,
  `build-llvm`, `build-gcc`, `programmer` set).

```bash
bash scripts/bench/dev-build.sh --help
bash scripts/bench/pts-developer.sh --help
```

Example Vite build:

```bash
bash scripts/bench/dev-build.sh \
  --project /path/to/checkout \
  --command 'taskset -c 0-$(( {threads} - 1 )) npm run build' \
  --cold-prepare 'rm -rf dist' \
  --incremental-prepare 'touch src/main.tsx' \
  --threads 1,8,16 --repetitions 3
```

PTS interactive mode needs a terminal and `script`; use `--batch` without a
terminal. A missing timing result is `TIMING_FAIL`, not PASS.

## Reference results

Measured at kernel 7.2, Mesa 26.2, GTT 22 GiB, EEVDF:

- Gemma 4B (UD-Q4_K_XL): ~781 t/s prefill, ~32 t/s decode.
- Qwen 14B (Q4_K_M): ~129 t/s prefill, ~9.5 t/s decode on `power-saver`.
- llama.cpp ~32 t/s decode; ollama-vulkan ~18 t/s.

## Temperature and limits

- AMD CPU Tjmax is `100°C`. `95–97°C` under long load is near the limit.
- Performance scripts report `PASS_THERMAL_LIMITED` and stop at `98°C`.
- Stability scripts stop at the `95°C` warning threshold.
- `PROFILE_DRIFT` only checks the profile name in
  `/run/native-power-profile/active`; it is not a RyzenAdj limit readback.

## A/B comparison

Keep these fixed:

- AC power and power profile.
- Kernel, Mesa, and tool versions.
- Model and quantization.
- Thread count, GPU, input/output tokens, and repetitions.
- Compare medians across the standard repetitions.
