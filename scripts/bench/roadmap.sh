#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: roadmap.sh [options]

Run the five-stage performance roadmap without changing persistent NixOS
configuration. Stage 1 temporarily switches native power profiles and restores
the profile selected before the run.

Stages:
  1  native power-profile comparison
  2  CPU and memory throughput
  3  Vulkan/GPU throughput
  4  llama.cpp Vulkan throughput (requires --model)
  5  sustained thermal/stability run

Options:
  --step N             run one stage (1-5); default is all stages
  --all                run all stages
  --model PATH         GGUF model for stage 4
  --output DIR         output directory; default is /tmp/think14gryzen-roadmap-...
  --quick              use short representative runs
  -h, --help           show this help
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 2
}

step='all'
model=''
output=''
quick=0
active_pid=''

cleanup() {
  if [ -n "$active_pid" ]; then
    # Signal the child shell so its trap can stop the workload and restore power.
    kill -TERM "$active_pid" 2>/dev/null || true
    wait "$active_pid" 2>/dev/null || true
    active_pid=''
  fi
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

while [ "$#" -gt 0 ]; do
  case "$1" in
    --step)
      [ "$#" -ge 2 ] || die '--step needs a value'
      step="$2"
      shift 2
      ;;
    --all)
      step='all'
      shift
      ;;
    --model)
      [ "$#" -ge 2 ] || die '--model needs a path'
      model="$2"
      shift 2
      ;;
    --output)
      [ "$#" -ge 2 ] || die '--output needs a directory'
      output="$2"
      shift 2
      ;;
    --quick)
      quick=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

case "$step" in
  all|1|2|3|4|5) ;;
  *) die "step must be all or an integer from 1 to 5: $step" ;;
esac

if [ -n "$model" ] && [ ! -r "$model" ]; then
  die "model is not readable: $model"
fi

if [ -z "$output" ]; then
  output="/tmp/think14gryzen-roadmap-$(date -u +%Y%m%dT%H%M%SZ)-$$"
fi
[ ! -e "$output/summary.tsv" ] || die "output already contains a benchmark: $output"
mkdir -p -- "$output" || die "cannot create output directory: $output"

summary="$output/summary.tsv"
metadata="$output/metadata.txt"
commands="$output/commands.txt"
printf 'stage\tworkload\tstatus\texit_code\tlog\n' >"$summary"
: >"$commands"

record_metadata() {
  {
    printf 'started_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'host=%s\n' "$(hostname)"
    printf 'kernel='; uname -srvm
    printf 'git_revision='
    git -C "$SCRIPT_DIR/../.." rev-parse --short HEAD 2>/dev/null || printf 'unknown\n'
    printf 'cpu_model='
    awk -F: '/^model name[[:space:]]*:/ && !found { sub(/^[[:space:]]*/, "", $2); print $2; found = 1 } END { if (!found) print "unknown" }' /proc/cpuinfo
    printf 'cpu_threads='; nproc 2>/dev/null || printf 'unknown\n'
    printf 'memory_total_kib='
    awk '/^MemTotal:/ { print $2; found = 1 } END { if (!found) print "unknown" }' /proc/meminfo
    printf 'power_profile='
    if [ -r /run/native-power-profile/active ]; then cat /run/native-power-profile/active; else printf 'unknown\n'; fi
    printf 'scaling_governor='
    if [ -r /sys/devices/system/cpu/cpufreq/policy0/scaling_governor ]; then cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor; else printf 'unknown\n'; fi
    printf 'quick=%s\n' "$quick"
    printf 'model=%s\n' "${model:-none}"
    if command -v lspci >/dev/null 2>&1; then
      printf 'gpu='; lspci | awk '/VGA|3D controller|Display controller/'
    fi
  } >"$metadata"
}

record_metadata

run_workload() {
  local stage="$1"
  local workload="$2"
  local script="$3"
  shift 3
  local log="$output/${stage}-${workload}.log"
  local code=0
  local status=PASS
  local child_summary="$output/${stage}-${workload}/summary.tsv"

  printf '%s %q' "$workload" "$script" >>"$commands"
  printf ' %q' "$@" >>"$commands"
  printf '\n' >>"$commands"
  bash "$SCRIPT_DIR/$script" "$@" >"$log" 2>&1 &
  active_pid=$!
  wait "$active_pid" || code=$?
  active_pid=''
  case "$code" in
    130|143) exit "$code" ;;
  esac
  if [ "$code" -eq 3 ]; then
    status=PARTIAL
  elif [ "$code" -ne 0 ]; then
    status=FAIL
  elif [ ! -s "$child_summary" ]; then
    status=FAIL
    code=1
  else
    status="$(awk -F '\t' '
      NR > 1 {
        for (i = 1; i <= NF; i++) {
          if ($i == "PASS_THERMAL_LIMITED" || $i == "PASS_THERMAL_WARNING") warning = $i
          if ($i == "SKIP") skipped = 1
        }
      }
      END { if (skipped) print "PARTIAL"; else if (warning != "") print warning; else print "PASS" }
    ' "$child_summary")"
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$stage" "$workload" "$status" "$code" "$log" >>"$summary"
  return 0
}

run_stage() {
  local requested="$1"
  [ "$step" = all ] || [ "$step" = "$requested" ] || return 0

  case "$requested" in
    1)
      if [ "$quick" -eq 1 ]; then
        run_workload 1 power-profiles power-profiles.sh \
          --profiles performance,sustained-build,balanced \
          --one-core-seconds 15 --all-core-seconds 45 --cooldown-seconds 10 \
          --output "$output/1-power-profiles"
      else
        run_workload 1 power-profiles power-profiles.sh \
          --output "$output/1-power-profiles"
      fi
      ;;
    2)
      if [ "$quick" -eq 1 ]; then
        run_workload 2 cpu cpu.sh --duration 10 --repetitions 1 --output "$output/2-cpu"
        run_workload 2 memory memory.sh --duration 10 --repetitions 1 --output "$output/2-memory"
      else
        run_workload 2 cpu cpu.sh --output "$output/2-cpu"
        run_workload 2 memory memory.sh --output "$output/2-memory"
      fi
      ;;
    3)
      if [ "$quick" -eq 1 ]; then
        run_workload 3 gpu gpu.sh --repetitions 1 --output "$output/3-gpu"
      else
        run_workload 3 gpu gpu.sh --output "$output/3-gpu"
      fi
      ;;
    4)
      if [ -z "$model" ]; then
        printf '4\tllm\tSKIP\t0\tmodel not supplied; use --model PATH\n' >>"$summary"
      elif [ "$quick" -eq 1 ]; then
        run_workload 4 llm llm.sh --model "$model" --repetitions 1 --output "$output/4-llm"
      else
        run_workload 4 llm llm.sh --model "$model" --output "$output/4-llm"
      fi
      ;;
    5)
      if [ "$quick" -eq 1 ]; then
        run_workload 5 stress stress-long.sh --mode combined --duration 60 --output "$output/5-stress"
      else
        run_workload 5 stress stress-long.sh --mode combined --output "$output/5-stress"
      fi
      ;;
  esac
}

run_stage 1
run_stage 2
run_stage 3
run_stage 4
run_stage 5

printf 'output=%s\n' "$output"
cat "$summary"

awk -F '\t' '
  NR > 1 && $3 == "FAIL" { failed = 1 }
  NR > 1 && $3 == "PARTIAL" { partial = 1 }
  END { if (failed) exit 1; if (partial) exit 3; exit 0 }
' "$summary"
