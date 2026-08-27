#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$SCRIPT_DIR/common.sh"

BENCH_THERMAL_MODE="${BENCH_THERMAL_MODE:-record}"
repetitions=3
duration=600
long_run=0
skip_vulkan=0
output=''

usage() {
  cat <<'EOF'
Usage: gpu.sh [options]

Run glmark2 off-screen and, when available, the default vkmark scene suite.

Options:
  --repetitions N      runs per graphics benchmark (default: 3)
  --long               loop glmark2 for --duration instead of scoring scenes
  --duration SEC       long-run duration (default: 600)
  --skip-vulkan        do not run vkmark
  --output DIR         write this run to DIR
  -h, --help           show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repetitions)
      [ "$#" -ge 2 ] || bench_die "--repetitions needs a value"
      repetitions="$2"
      shift 2
      ;;
    --long)
      long_run=1
      shift
      ;;
    --duration)
      [ "$#" -ge 2 ] || bench_die "--duration needs a value"
      duration="$2"
      shift 2
      ;;
    --skip-vulkan)
      skip_vulkan=1
      shift
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

bench_positive_integer repetitions "$repetitions"
bench_positive_integer duration "$duration"
bench_need_command glmark2
bench_need_command timeout
[ "$long_run" -eq 0 ] || bench_require_ac

bench_init_run gpu "$output"
bench_record_tool_version glmark2
bench_record_metadata benchmark 'glmark2 off-screen; vkmark default scenes'
bench_record_metadata repetitions "$repetitions"
bench_record_metadata long_run "$long_run"
bench_record_metadata duration_seconds "$duration"

if [ "$long_run" -eq 1 ]; then
  BENCH_ALLOWED_EXIT_CODES='124 143'
  bench_run_monitored \
    glmark2-long \
    timeout --signal=TERM --kill-after=10s "${duration}s" glmark2 --off-screen --run-forever
  unset BENCH_ALLOWED_EXIT_CODES
else
  for rep in $(seq 1 "$repetitions"); do
    bench_run_monitored "glmark2-r${rep}" glmark2 --off-screen
  done
fi

if [ "$skip_vulkan" -eq 1 ]; then
  bench_record_skip vkmark 'disabled with --skip-vulkan' 0
elif command -v vkmark >/dev/null 2>&1; then
  bench_record_metadata vkmark_path "$(command -v vkmark)"
  bench_record_metadata vkmark_version 'vkmark does not expose a version option'
  for rep in $(seq 1 "$repetitions"); do
    bench_run_monitored "vkmark-r${rep}" vkmark
  done
else
  bench_record_skip vkmark 'vkmark is not installed'
fi

bench_finish
