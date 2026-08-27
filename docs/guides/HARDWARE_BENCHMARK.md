# Hardware Benchmarking

The standard benchmark scripts are deliberately separate from the Ryzen
power-profile switcher. They record the active profile and temperatures, but do
not change power limits, CPU governors, or scheduler settings. The explicit
`oc-curve.sh` exception switches only the named managed profiles for its A/B
run and restores the profile that was active at the start.

## Standard measurements

| Area | Tool | Main value | Notes |
| --- | --- | --- | --- |
| CPU | `sysbench cpu` | events/s | Runs at one thread and all logical CPUs. |
| Memory | `sysbench memory` | MiB/s | Sequential read and write; keep the exact version and options. |
| GPU | `glmark2`, `vkmark` | FPS/score or scene FPS | OpenGL and Vulkan are separate APIs and are not interchangeable. |
| Storage | `fio` | bandwidth, IOPS, latency | Read-only against an existing regular file. |
| LLM | `llama-bench` | prompt and generation tokens/s | Uses the local guide's `pp512/tg128`, Vulkan, FA-on setup. |
| Stability | `stress-ng` | pass/fail, thermal behavior | This is a stress test, not the performance score. |

`stress-ng` is included for long-run fault and thermal detection. Its upstream
documentation explicitly warns that its throughput values are not intended as
precise benchmark results, so compare those runs by completion, temperature,
and kernel errors rather than by bogo-ops/s.

## Run the suite

The default scoring runs use three repetitions. Results go to
`/var/tmp/think14gryzen-bench/` unless `--output` is supplied. Each directory
contains the raw tool logs, `summary.tsv`, `telemetry.tsv`, `metadata.txt`, and
`commands.txt`.

```bash
cd /etc/nixos
bash scripts/bench/cpu.sh --duration 30 --repetitions 3
bash scripts/bench/memory.sh --duration 30 --repetitions 3
bash scripts/bench/gpu.sh --repetitions 3

# Use the exact GGUF and device that you want to compare.
bash scripts/bench/llm.sh \
  --model /mnt/vault/lmstudio-models/unsloth/gemma-3-4b-it-GGUF/gemma-3-4b-it-UD-Q4_K_XL.gguf
```

For the long-run check, use AC power and choose a duration appropriate for the
question. Ten minutes is the default; thirty minutes is a better thermal
screening run.

```bash
bash scripts/bench/stress-long.sh --mode combined --duration 1800
bash scripts/bench/gpu.sh --long --duration 1800 --skip-vulkan
```

To compare the managed CPU power curve, run the profile sweep on AC. It
measures one-core boost and sustained all-core frequency for `power-saver`,
`balanced`, and `performance`, then restores the profile that was active at
the start:

```bash
bash scripts/bench/oc-curve.sh
```

The local build-oriented overlay can be measured separately with
`bash scripts/bench/oc-curve.sh --profile sustained-build`. It keeps the PPD
base at `performance` while applying lower Ryzenadj power and temperature
limits. The runner uses the same profile coordinator and holds its lock during
each phase. Do not switch the Waybar power profile during a run; a
mixed-profile phase is not a valid comparison.

The storage script refuses block devices and does not create a test file. It
needs an existing file at least as large as `--size`; `fio` is optional in the
current system, so use a temporary Nix shell when it is absent:

```bash
nix shell nixpkgs#fio --command bash scripts/bench/storage.sh \
  --file /mnt/vault/lmstudio-models/unsloth/gemma-3-4b-it-GGUF/gemma-3-4b-it-UD-Q4_K_XL.gguf \
  --size 1G --duration 15 --repetitions 3
```

## Developer workloads

There are two comparison lanes for heavy programming work:

* `scripts/bench/dev-build.sh` measures a real checkout supplied by the user.
  It separates cold, warm, incremental, and no-op builds and can repeat the
  same command at one, half, and all logical CPUs. This is the most useful
  measure for the projects actually used on this machine, but it is only
  comparable across machines when the repository revision, build toolchain,
  build flags, dependency cache, and filesystem are also fixed.
* `scripts/bench/pts-developer.sh` delegates to Phoronix Test Suite profiles
  and suites. Use its `build-linux-kernel`, `build-llvm`, or `build-gcc`
  profiles for community-facing numbers, or the `programmer` suite for a
  broader workload. These profiles are much longer than the quick local
  checks and may download and compile their own sources.

Inspect the exact command and workload before starting a long run:

```bash
bash scripts/bench/dev-build.sh --help
bash scripts/bench/pts-developer.sh --help
```

The local lane uses `hyperfine` when available for repeated timing and falls
back to a `date`/`awk` wall-clock measurement; the selected timing method is
recorded in metadata. Retain the output directory with the commit, tool
versions, thread count, and cache state. A cold build means the project's
build output is absent or isolated; it does not mean dropping the whole
operating-system page cache. Do not compare a cold result from one filesystem
with a warm result from another.

Example for a disposable checkout with a Vite build:

```bash
bash scripts/bench/dev-build.sh \
  --project /path/to/checkout \
  --command 'taskset -c 0-$(( {threads} - 1 )) npm run build' \
  --cold-prepare 'rm -rf dist' \
  --incremental-prepare 'touch src/main.tsx' \
  --threads 1,8,16 --repetitions 3
```

Adjust the output and prepare commands to the project; run them only in a
disposable or isolated checkout. For public comparison, keep the exact PTS
profile version and configuration fixed because profile revisions can change
the workload.

## Existing local reference points

The internal June 7 report measured the same machine with llama.cpp b9309 and
the older stack: Gemma 4B Q4_K_M reached `550/31.95 t/s` (pp512/tg128) in
power-saver and `545/31.6 t/s` in performance; Qwen 14B reached `129/9.46
t/s` in power-saver. The current three-repetition run on the UD Gemma file
records `780.91/32.10 t/s` with the newer stack. The prefill numbers are not a
like-for-like quantization comparison, while decode is close; keep model,
quantization, llama.cpp build, Mesa, and kernel fixed before calling a change
a regression or improvement. The same report measured standalone llama.cpp at
about `32 t/s` decode versus about `18 t/s` for the then-current
ollama-vulkan, so those are separate engine baselines rather than CPU scores.

## Interpreting old versus new results

The May 5 standalone APU runs used the then-current `54/54/54 W` limits and
were interrupted by `signal_interrupt`. They are useful telemetry evidence,
but not completed long-run passes and do not directly validate the later
`56/72/67 W` experiment or the current `48/64/60 W` wrapper. The new scripts
therefore preserve raw output and distinguish a score from a stress pass.

The archived `20260505-150210` run records `4.74 GHz` as its peak single
thread reading, while its first sample reported `4.41 GHz` average and
`70.61 GHz` summed across logical CPUs; later samples settled around
`3.74 GHz` average under max stress. The other interrupted runs recorded
`4.86 GHz` and `4.99 GHz` single-thread peaks. Thus the remembered `4.72 GHz`
figure belongs to the instantaneous/peak-clock class, not a sustained all-core
clock, unless another raw run is found.

AMD lists a `100°C` Tjmax for the [Ryzen 7 8845H/HS
family](https://www.amd.com/zh-cn/products/processors/laptop/ryzen/8000-series/amd-ryzen-7-8845h.html).
A measured `95–97°C` during a sustained run is therefore near the vendor
limit and must be reported as thermal behavior, not treated as evidence that
the benchmark is healthy. Performance scripts now record this as
`PASS_THERMAL_LIMITED` and keep a hard abort at `98°C`; the stability script
still aborts at the conservative `95°C` warning threshold. If a deliberate
near-Tjmax characterization is needed, set an explicit policy such as
`BENCH_CPU_LIMIT_MILLIC=98000` for that one run, stay present, and stop if
temperature, clock, or system behavior becomes abnormal.

For a valid A/B comparison, keep these fixed: AC power, active power profile,
kernel/Mesa/benchmark versions, model and quantization, thread count, GPU
device, prompt/generation token counts, and repetitions. Compare the median of
the repeated standard scores; do not compare `stress-ng` bogo-ops/s to the old
APU controller's bogo-ops/s.

## Upstream references

- [`sysbench`](https://github.com/akopytov/sysbench)
- [`stress-ng`](https://github.com/ColinIanKing/stress-ng)
- [`fio`](https://github.com/axboe/fio)
- [`glmark2`](https://github.com/glmark2/glmark2)
- [`vkmark`](https://github.com/vkmark/vkmark)
- [`llama.cpp`](https://github.com/ggml-org/llama.cpp)
- [`hyperfine`](https://github.com/sharkdp/hyperfine)
- [`Phoronix Test Suite`](https://github.com/phoronix-test-suite/phoronix-test-suite)
- [`OpenBenchmarking developer profiles`](https://openbenchmarking.org/tests/pts)
- [`DevBench`](https://github.com/DamianEdwards/DevBench)
