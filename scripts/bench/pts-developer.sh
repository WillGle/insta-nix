#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$SCRIPT_DIR/common.sh"

BENCH_THERMAL_MODE="${BENCH_THERMAL_MODE:-record}"
mode=''
target=''
target_kind=''
list_only=0
output=''

usage() {
  cat <<'EOF'
Usage:
  pts-developer.sh --test PROFILE [--interactive|--batch] [--output DIR]
  pts-developer.sh --suite SUITE [--interactive|--batch] [--output DIR]
  pts-developer.sh --list

Run one explicitly selected Phoronix Test Suite developer workload. This
script does not select or start a benchmark until --test or --suite is given.

Options:
  --test PROFILE       PTS/OpenBenchmarking test profile, e.g.
                       build-linux-kernel, build-llvm, or build-gcc
  --suite SUITE        PTS/OpenBenchmarking suite, e.g. programmer
  --interactive        use PTS benchmark (default)
  --batch              use PTS batch-benchmark
  --output DIR         save wrapper logs and metadata in DIR
  --list               show public developer targets and local PTS entries
  -h, --help           show this help

The public-comparison entry points are documented at:
  https://openbenchmarking.org/suite/pts/programmer
  https://openbenchmarking.org/test/pts/build-linux-kernel-1.17.1
  https://openbenchmarking.org/test/pts/build-llvm
  https://openbenchmarking.org/test/pts/build-gcc

Notes:
  --interactive maps to `phoronix-test-suite benchmark PROFILE` and keeps the
  PTS prompts visible. --batch maps to the verified PTS command
  `phoronix-test-suite batch-benchmark PROFILE`.
  Batch mode uses the existing PTS batch configuration, including its save,
  browser, and upload settings. Run `phoronix-test-suite batch-setup`
  separately if it has not been configured; this wrapper never changes that
  configuration or invokes an upload command itself.
  Profile and suite names are restricted to safe identifier characters and
  are passed as one argument. No arbitrary PTS options are accepted.
  PTS result metadata is supplied through its supported
  TEST_RESULTS_NAME/IDENTIFIER/DESCRIPTION environment variables. PTS keeps
  the result under its configured ResultsDirectory (default:
  ~/.phoronix-test-suite/test-results/); the wrapper log, command, and host
  metadata are saved under --output.
  `--list` only queries PTS inventory; it does not install or run a test.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --test)
      [ "$#" -ge 2 ] || bench_die '--test needs a profile name'
      [ -z "$target" ] || bench_die '--test/--suite may be specified only once'
      target="$2"
      target_kind=test
      shift 2
      ;;
    --suite)
      [ "$#" -ge 2 ] || bench_die '--suite needs a suite name'
      [ -z "$target" ] || bench_die '--test/--suite may be specified only once'
      target="$2"
      target_kind=suite
      shift 2
      ;;
    --interactive)
      [ -z "$mode" ] || bench_die '--interactive and --batch are mutually exclusive'
      mode=interactive
      shift
      ;;
    --batch)
      [ -z "$mode" ] || bench_die '--interactive and --batch are mutually exclusive'
      mode=batch
      shift
      ;;
    --output)
      [ "$#" -ge 2 ] || bench_die '--output needs a directory'
      output="$2"
      shift 2
      ;;
    --list)
      [ "$list_only" -eq 0 ] || bench_die '--list may be specified only once'
      list_only=1
      shift
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

bench_need_command phoronix-test-suite
pts_command="$(command -v phoronix-test-suite)"

show_list() {
  local suites_rc tests_rc

  cat <<'EOF'
Public developer workload starting points:
  --suite programmer
  --test build-linux-kernel
  --test build-llvm
  --test build-gcc

Local PTS suites (availability depends on the local cache/repositories):
EOF
  "$pts_command" list-available-suites
  suites_rc=$?

  printf '\nLocal PTS test profiles (availability depends on the local cache/repositories):\n'
  "$pts_command" list-available-tests
  tests_rc=$?

  [ "$suites_rc" -eq 0 ] && [ "$tests_rc" -eq 0 ]
}

if [ "$list_only" -eq 1 ]; then
  [ -z "$target" ] || bench_die '--list cannot be combined with --test or --suite'
  [ -z "$mode" ] || bench_die '--list cannot be combined with --interactive or --batch'
  [ -z "$output" ] || bench_die '--list cannot be combined with --output'
  show_list
  exit $?
fi

[ -n "$target" ] || bench_die 'choose --test PROFILE, --suite SUITE, or --list'
[[ "$target" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]] || \
  bench_die 'profile/suite must contain only letters, digits, ., _, /, and -'
[ -n "$mode" ] || mode=interactive

case "$mode" in
  interactive) pts_action=benchmark ;;
  batch) pts_action=batch-benchmark ;;
  *) bench_die "unsupported mode: $mode" ;;
esac

bench_init_run pts-developer "$output"
bench_record_metadata benchmark 'phoronix-test-suite developer workload'
bench_record_metadata pts_version "$(
  "$pts_command" version 2>&1 |
    awk '/^Phoronix Test Suite v/ { print; found = 1 } END { if (!found) print "unknown" }' || true
)"
bench_record_metadata pts_path "$pts_command"
bench_record_metadata pts_target_kind "$target_kind"
bench_record_metadata pts_target "$target"
bench_record_metadata pts_mode "$mode"
bench_record_metadata wrapper_output "$RUN_DIR"
bench_record_metadata pts_log "$RUN_DIR/pts.log"
bench_record_metadata pts_user_path_override "${PTS_USER_PATH_OVERRIDE:-not-set}"
if [ -n "${PTS_USER_PATH_OVERRIDE:-}" ]; then
  bench_record_metadata pts_results_path_hint "${PTS_USER_PATH_OVERRIDE%/}/test-results/"
else
  bench_record_metadata pts_results_path_hint 'PTS configured ResultsDirectory (default: ~/.phoronix-test-suite/test-results/)'
fi

target_slug="${target//\//-}"
target_slug="${target_slug//[^A-Za-z0-9_.-]/-}"
target_slug="${target_slug:0:80}"
run_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
result_name="pts-${target_slug}-${run_stamp}-$$"
result_identifier="${HOSTNAME:-unknown}-${target_slug}"
result_identifier="${result_identifier//[^A-Za-z0-9_.-]/-}"
result_description="pts-developer.sh ${target_kind}=${target} mode=${mode}"

bench_record_metadata pts_result_name "$result_name"
bench_record_metadata pts_result_identifier "$result_identifier"
bench_record_metadata pts_result_description "$result_description"
bench_record_metadata result_metadata_source 'TEST_RESULTS_NAME, TEST_RESULTS_IDENTIFIER, TEST_RESULTS_DESCRIPTION'
bench_record_metadata batch_configuration 'existing PTS batch configuration; batch-setup not invoked'

pts_exec=(
  env
  "TEST_RESULTS_NAME=$result_name"
  "TEST_RESULTS_IDENTIFIER=$result_identifier"
  "TEST_RESULTS_DESCRIPTION=$result_description"
  "$pts_command"
  "$pts_action"
  "$target"
)
bench_record_command pts "${pts_exec[@]}"

pts_log="$RUN_DIR/pts.log"
workload="pts-${target_slug}"
SECONDS=0
printf 'running: %s %s (%s mode)\n' "$target_kind" "$target" "$mode"
if command -v script >/dev/null 2>&1; then
  pts_shell_command=''
  printf -v pts_shell_command '%q ' "${pts_exec[@]}"
  bench_run_monitored "$workload" script --quiet --flush --return \
    --command "$pts_shell_command" "$pts_log"
else
  printf 'warning: util-linux script is unavailable; interactive prompts use the current terminal without a PTY log\n' >&2
  bench_run_monitored "$workload" "${pts_exec[@]}"
fi
pts_rc="$(awk -F '\t' -v workload="$workload" \
  '$1 == workload { code = $3 } END { print code }' "$RUN_SUMMARY")"
pts_rc="${pts_rc:-1}"

bench_record_metadata exit_code "$pts_rc"
bench_record_metadata elapsed_seconds "$SECONDS"
status="$(awk -F '\t' -v workload="$workload" \
  '$1 == workload { value = $2 } END { print value }' "$RUN_SUMMARY")"
printf '%s: %s (exit %s)\n' "$target" "$status" "$pts_rc"

bench_finish_rc=0
bench_finish || bench_finish_rc=$?
if [ "$pts_rc" -ne 0 ]; then
  exit "$pts_rc"
fi
exit "$bench_finish_rc"
