#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$SCRIPT_DIR/common.sh"

BENCH_THERMAL_MODE="${BENCH_THERMAL_MODE:-abort}"
mode=combined
duration=600
vm_workers=1
vm_bytes=35%
output=''

usage() {
  cat <<'EOF'
Usage: stress-long.sh [options]

Run a thermal/stability workload. The stress-ng metrics are diagnostic only;
use cpu.sh and memory.sh for performance scores.

Options:
  --mode MODE          cpu, memory, or combined (default: combined)
  --duration SEC       run time (default: 600)
  --vm-workers N       stress-ng VM workers (default: 1)
  --vm-bytes VALUE     memory per VM worker, e.g. 35% (default: 35%)
  --output DIR         write this run to DIR
  -h, --help           show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode)
      [ "$#" -ge 2 ] || bench_die "--mode needs a value"
      mode="$2"
      shift 2
      ;;
    --duration)
      [ "$#" -ge 2 ] || bench_die "--duration needs a value"
      duration="$2"
      shift 2
      ;;
    --vm-workers)
      [ "$#" -ge 2 ] || bench_die "--vm-workers needs a value"
      vm_workers="$2"
      shift 2
      ;;
    --vm-bytes)
      [ "$#" -ge 2 ] || bench_die "--vm-bytes needs a value"
      vm_bytes="$2"
      shift 2
      ;;
    --output)
      [ "$#" -ge 2 ] || bench_die "--output needs a directory"
      output="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      bench_die "unknown option: $1"
      ;;
  esac
done

case "$mode" in
  cpu|memory|combined) ;;
  *) bench_die "--mode must be cpu, memory, or combined" ;;
esac
bench_positive_integer duration "$duration"
bench_positive_integer vm_workers "$vm_workers"
bench_need_command stress-ng
bench_need_command nproc
bench_require_ac

bench_init_run "stress-$mode" "$output"
bench_record_tool_version stress-ng
bench_record_metadata benchmark stress-ng
bench_record_metadata mode "$mode"
bench_record_metadata duration_seconds "$duration"
bench_record_metadata vm_workers "$vm_workers"
bench_record_metadata vm_bytes "$vm_bytes"
bench_record_metadata cpu_method matrixprod

stress_args=(stress-ng --timeout "${duration}s" --metrics-brief --thermalstat 2 --verify --oom-avoid)
case "$mode" in
  cpu)
    stress_args+=(--cpu "$(nproc)" --cpu-method matrixprod)
    ;;
  memory)
    stress_args+=(--vm "$vm_workers" --vm-bytes "$vm_bytes" --vm-method all)
    ;;
  combined)
    stress_args+=(
      --cpu "$(nproc)"
      --cpu-method matrixprod
      --vm "$vm_workers"
      --vm-bytes "$vm_bytes"
      --vm-method all
    )
    ;;
esac

bench_run_monitored "stress-ng-$mode" "${stress_args[@]}"
bench_finish
