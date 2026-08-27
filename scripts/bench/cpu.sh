#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$SCRIPT_DIR/common.sh"

BENCH_THERMAL_MODE="${BENCH_THERMAL_MODE:-record}"
duration=30
repetitions=3
prime=20000
output=''

usage() {
  cat <<'EOF'
Usage: cpu.sh [options]

Run the standard sysbench CPU test at one thread and all logical CPUs.

Options:
  --duration SEC       seconds per run (default: 30)
  --repetitions N      runs per thread count (default: 3)
  --prime N            sysbench CPU prime limit (default: 20000)
  --output DIR         write this run to DIR
  -h, --help           show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --duration)
      [ "$#" -ge 2 ] || bench_die "--duration needs a value"
      duration="$2"
      shift 2
      ;;
    --repetitions)
      [ "$#" -ge 2 ] || bench_die "--repetitions needs a value"
      repetitions="$2"
      shift 2
      ;;
    --prime)
      [ "$#" -ge 2 ] || bench_die "--prime needs a value"
      prime="$2"
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

bench_positive_integer duration "$duration"
bench_positive_integer repetitions "$repetitions"
bench_positive_integer prime "$prime"
bench_need_command sysbench
bench_need_command nproc

bench_init_run cpu "$output"
bench_record_tool_version sysbench
bench_record_metadata benchmark 'sysbench cpu'
bench_record_metadata duration_seconds "$duration"
bench_record_metadata repetitions "$repetitions"
bench_record_metadata cpu_max_prime "$prime"

max_threads="$(nproc)"
thread_counts=(1)
[ "$max_threads" -gt 1 ] && thread_counts+=("$max_threads")
for threads in "${thread_counts[@]}"; do
  for rep in $(seq 1 "$repetitions"); do
    bench_run_monitored \
      "cpu-${threads}t-r${rep}" \
      sysbench cpu \
        "--threads=$threads" \
        "--time=$duration" \
        "--cpu-max-prime=$prime" \
        run
  done
done

bench_finish
