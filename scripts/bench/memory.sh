#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$SCRIPT_DIR/common.sh"

BENCH_THERMAL_MODE="${BENCH_THERMAL_MODE:-record}"
duration=30
repetitions=3
output=''

usage() {
  cat <<'EOF'
Usage: memory.sh [options]

Run sysbench sequential memory read/write tests at one thread and all logical CPUs.

Options:
  --duration SEC       seconds per run (default: 30)
  --repetitions N      runs per operation/thread count (default: 3)
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
bench_need_command sysbench
bench_need_command nproc

bench_init_run memory "$output"
bench_record_tool_version sysbench
bench_record_metadata benchmark 'sysbench memory'
bench_record_metadata duration_seconds "$duration"
bench_record_metadata repetitions "$repetitions"
bench_record_metadata block_size 1M
bench_record_metadata access_mode sequential
bench_record_metadata total_size time_based

max_threads="$(nproc)"
thread_counts=(1)
[ "$max_threads" -gt 1 ] && thread_counts+=("$max_threads")
for operation in write read; do
  for threads in "${thread_counts[@]}"; do
    for rep in $(seq 1 "$repetitions"); do
      bench_run_monitored \
        "memory-${operation}-${threads}t-r${rep}" \
        sysbench memory \
          "--threads=$threads" \
          --memory-block-size=1M \
          --memory-total-size=0 \
          "--memory-oper=$operation" \
          --memory-access-mode=seq \
          --memory-scope=global \
          "--time=$duration" \
          run
    done
  done
done

bench_finish
