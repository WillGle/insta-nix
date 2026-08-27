#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$SCRIPT_DIR/common.sh"

BENCH_THERMAL_MODE="${BENCH_THERMAL_MODE:-record}"
duration=15
repetitions=3
size=1G
file=''
output=''

usage() {
  cat <<'EOF'
Usage: storage.sh --file PATH [options]

Run fio read-only tests against an existing regular file. No benchmark file is
created and no block device is accepted by this script.

Options:
  --file PATH          existing file on the target filesystem (required)
  --size SIZE          amount to read, e.g. 1G (default: 1G)
  --duration SEC       seconds per run (default: 15)
  --repetitions N      runs per access pattern (default: 3)
  --output DIR         write this run to DIR
  -h, --help           show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --file)
      [ "$#" -ge 2 ] || bench_die "--file needs a path"
      file="$2"
      shift 2
      ;;
    --size)
      [ "$#" -ge 2 ] || bench_die "--size needs a value"
      size="$2"
      shift 2
      ;;
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

[ -n "$file" ] || bench_die '--file is required'
[ -f "$file" ] || bench_die "not an existing regular file: $file"
bench_positive_integer duration "$duration"
bench_positive_integer repetitions "$repetitions"
bench_need_command numfmt
bench_need_command stat

requested_bytes="$(numfmt --from=iec "$size" 2>/dev/null || true)"
[[ "$requested_bytes" =~ ^[0-9]+$ ]] || bench_die "invalid --size: $size"
file_bytes="$(stat -c '%s' -- "$file")"
[ "$requested_bytes" -le "$file_bytes" ] || bench_die "--size exceeds file size ($size > $file_bytes bytes)"

bench_init_run storage "$output"
if ! command -v fio >/dev/null 2>&1; then
  bench_record_skip fio 'fio is not installed; use nix shell nixpkgs#fio'
  bench_finish
  exit $?
fi

bench_record_tool_version fio
bench_record_metadata benchmark fio
bench_record_metadata file "$file"
bench_record_metadata file_size_bytes "$file_bytes"
bench_record_metadata read_size "$size"
bench_record_metadata duration_seconds "$duration"
bench_record_metadata repetitions "$repetitions"
bench_record_metadata safety 'readonly regular-file direct I/O'

for pattern in seqread randread; do
  for rep in $(seq 1 "$repetitions"); do
    fio_args=(
      fio
      "--name=$pattern"
      "--filename=$file"
      --readonly
      --direct=1
      --ioengine=psync
      --iodepth=1
      "--size=$size"
      "--runtime=${duration}s"
      --time_based=1
      --group_reporting=1
      --eta=never
      --output-format=json
    )
    if [ "$pattern" = seqread ]; then
      fio_args+=(--rw=read --bs=1M)
    else
      fio_args+=(--rw=randread --bs=4k --randrepeat=1)
    fi
    bench_run_monitored "${pattern}-r${rep}" "${fio_args[@]}"
  done
done

bench_finish
