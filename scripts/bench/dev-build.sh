#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$SCRIPT_DIR/common.sh"

BENCH_THERMAL_MODE="${BENCH_THERMAL_MODE:-record}"
project=''
build_command=''
cold_prepare=''
incremental_prepare=''
thread_option=''
repetitions=3
output=''

usage() {
  cat <<'EOF'
Usage: dev-build.sh --project DIR --command COMMAND [options]

Measure a real project build at several logical-CPU counts. COMMAND and each
prepare command run from DIR through bash and may contain the {threads}
placeholder. The project tree is never cleaned automatically.

Options:
  --project DIR             source checkout to benchmark (required)
  --command COMMAND        build command; must contain {threads} (required)
  --cold-prepare COMMAND   prepare a cold build before every cold run
  --incremental-prepare C  make the explicit incremental change before runs
  --threads LIST            comma-separated counts (default: 1,half,all)
  --repetitions N           runs per phase and thread count (default: 3)
  --output DIR              write this run to DIR
  -h, --help                show this help

Phases:
  cold         --cold-prepare is supplied; output/build directories must be
               isolated by that command, for example `rm -rf build`.
  warm         build command after a successful cold/pre-existing build.
  incremental  --incremental-prepare is supplied; the prepare command is
               responsible for changing only the intended source input.
  noop         build command again without a prepare command.

This harness does not drop the OS page cache, run git clean, or modify a source
tree by itself. It uses hyperfine for one-shot timing when both hyperfine and
jq are installed; otherwise it measures elapsed wall time with date and awk.
Keep the output directory, toolchain, checkout revision, build flags, and
cache state with the result.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project)
      [ "$#" -ge 2 ] || bench_die '--project needs a directory'
      project="$2"
      shift 2
      ;;
    --command)
      [ "$#" -ge 2 ] || bench_die '--command needs a value'
      build_command="$2"
      shift 2
      ;;
    --cold-prepare)
      [ "$#" -ge 2 ] || bench_die '--cold-prepare needs a value'
      cold_prepare="$2"
      shift 2
      ;;
    --incremental-prepare)
      [ "$#" -ge 2 ] || bench_die '--incremental-prepare needs a value'
      incremental_prepare="$2"
      shift 2
      ;;
    --threads)
      [ "$#" -ge 2 ] || bench_die '--threads needs a comma-separated list'
      thread_option="$2"
      shift 2
      ;;
    --repetitions)
      [ "$#" -ge 2 ] || bench_die '--repetitions needs a value'
      repetitions="$2"
      shift 2
      ;;
    --output)
      [ "$#" -ge 2 ] || bench_die '--output needs a directory'
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

[ -n "$project" ] || bench_die '--project is required'
[ -n "$build_command" ] || bench_die '--command is required'
[[ "$build_command" == *'{threads}'* ]] || \
  bench_die '--command must contain the {threads} placeholder'
bench_positive_integer repetitions "$repetitions"
bench_need_command nproc
bench_need_command bash
bench_need_command git
bench_need_command date
bench_need_command awk

[ -d "$project" ] || bench_die "project is not a directory: $project"
project="$(cd -- "$project" && pwd -P)" || bench_die "cannot enter project: $project"

declare -a thread_counts
if [ -n "$thread_option" ]; then
  IFS=',' read -r -a thread_counts <<<"$thread_option"
  [ "${#thread_counts[@]}" -gt 0 ] || bench_die '--threads cannot be empty'
  for threads in "${thread_counts[@]}"; do
    bench_positive_integer threads "$threads"
  done
else
  max_threads="$(nproc)"
  half_threads=$(( (max_threads + 1) / 2 ))
  thread_counts=(1)
  [ "$half_threads" -eq 1 ] || thread_counts+=("$half_threads")
  [ "$max_threads" -eq 1 ] || thread_counts+=("$max_threads")
fi

bench_init_run dev-build "$output"
bench_record_metadata benchmark 'developer build workload'
bench_record_metadata project "$project"
bench_record_metadata build_command "${build_command//$'\n'/ }"
bench_record_metadata cold_prepare "${cold_prepare//$'\n'/ }"
bench_record_metadata incremental_prepare "${incremental_prepare//$'\n'/ }"
bench_record_metadata thread_counts "$(IFS=,; printf '%s' "${thread_counts[*]}")"
bench_record_metadata repetitions "$repetitions"

if git_root="$(git -C "$project" rev-parse --show-toplevel 2>/dev/null)"; then
  bench_record_metadata git_root "$git_root"
  bench_record_metadata git_head "$(git -C "$project" rev-parse HEAD 2>/dev/null || printf unknown)"
  bench_record_metadata git_status "$(git -C "$project" status --short 2>/dev/null | tr '\n' ';')"
else
  bench_record_metadata git_root 'not-a-git-checkout'
fi

if command -v hyperfine >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  timing_tool=hyperfine
  bench_record_tool_version hyperfine
else
  timing_tool=time
  bench_record_metadata timing_note 'hyperfine+jq unavailable; using date+awk wall-clock timing'
fi
bench_record_metadata timing_tool "$timing_tool"

printf 'stage\tthreads\trepetition\tseconds\tstatus\tworkload\n' >"$RUN_DIR/developer.tsv"

dev_replace_threads() {
  local value="$1"
  local threads="$2"

  printf '%s' "${value//\{threads\}/$threads}"
}

dev_status_for() {
  local workload="$1"

  awk -F '\t' -v workload="$workload" \
    '$1 == workload { status = $2 } END { print status }' "$RUN_SUMMARY"
}

dev_record_result() {
  local stage="$1"
  local threads="$2"
  local repetition="$3"
  local seconds="$4"
  local status="$5"
  local workload="$6"

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$stage" "$threads" "$repetition" "$seconds" "$status" "$workload" \
    >>"$RUN_DIR/developer.tsv"
}

dev_run_prepare() {
  local workload="$1"
  local command_value="$2"
  local threads="$3"
  local command_expanded

  command_expanded="$(dev_replace_threads "$command_value" "$threads")"
  bench_run_monitored "$workload" bash -lc \
    'cd -- "$1" && bash -lc "$2"' _ "$project" "$command_expanded"
  [ "$(dev_status_for "$workload")" = PASS ] || \
    [ "$(dev_status_for "$workload")" = PASS_THERMAL_LIMITED ]
}

dev_run_build() {
  local stage="$1"
  local threads="$2"
  local repetition="$3"
  local command_expanded="$4"
  local workload="${stage}-${threads}t-r${repetition}"
  local result_file="$RUN_DIR/${workload}.json"
  local status seconds

  if [ "$timing_tool" = hyperfine ]; then
    bench_run_monitored "$workload" bash -lc \
      'cd -- "$1" && hyperfine --runs 1 --warmup 0 --export-json "$2" -- "$3"' \
      _ "$project" "$result_file" "$command_expanded"
    status="$(dev_status_for "$workload")"
    seconds="$(jq -r '.results[0].mean // empty' "$result_file" 2>/dev/null || true)"
  else
    result_file="$RUN_DIR/${workload}.seconds"
    bench_run_monitored "$workload" bash -lc \
      'cd -- "$1" || exit; start=$(date +%s.%N); bash -lc "$3"; rc=$?; end=$(date +%s.%N); awk -v start="$start" -v end="$end" "BEGIN { printf \"%.6f\\n\", end - start }" >"$2"; exit "$rc"' \
      _ "$project" "$result_file" "$command_expanded"
    status="$(dev_status_for "$workload")"
    seconds="$(sed -n '1p' "$result_file" 2>/dev/null || true)"
  fi

  if [[ "$seconds" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    dev_record_result "$stage" "$threads" "$repetition" "$seconds" \
      "${status:-FAIL}" "$workload"
  else
    dev_record_result "$stage" "$threads" "$repetition" NA \
      "${status:-FAIL}" "$workload"
  fi

  [ "$status" = PASS ] || [ "$status" = PASS_THERMAL_LIMITED ]
}

for threads in "${thread_counts[@]}"; do
  for repetition in $(seq 1 "$repetitions"); do
    if [ -n "$cold_prepare" ]; then
      if ! dev_run_prepare "cold-prepare-${threads}t-r${repetition}" "$cold_prepare" "$threads"; then
        continue
      fi
      command_expanded="$(dev_replace_threads "$build_command" "$threads")"
      dev_run_build cold "$threads" "$repetition" "$command_expanded" || true
    fi
  done

  if [ -z "$cold_prepare" ]; then
    bench_record_skip "cold-${threads}t" 'no --cold-prepare command supplied' 0
  fi

  for repetition in $(seq 1 "$repetitions"); do
    command_expanded="$(dev_replace_threads "$build_command" "$threads")"
    dev_run_build warm "$threads" "$repetition" "$command_expanded" || true
  done

  if [ -n "$incremental_prepare" ]; then
    for repetition in $(seq 1 "$repetitions"); do
      if dev_run_prepare "incremental-prepare-${threads}t-r${repetition}" \
        "$incremental_prepare" "$threads"; then
        command_expanded="$(dev_replace_threads "$build_command" "$threads")"
        dev_run_build incremental "$threads" "$repetition" "$command_expanded" || true
      fi
    done
  else
    bench_record_skip "incremental-${threads}t" \
      'no --incremental-prepare command supplied' 0
  fi

  for repetition in $(seq 1 "$repetitions"); do
    command_expanded="$(dev_replace_threads "$build_command" "$threads")"
    dev_run_build noop "$threads" "$repetition" "$command_expanded" || true
  done
done

printf 'developer_results=%s\n' "$RUN_DIR/developer.tsv"
bench_finish
