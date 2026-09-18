#!/usr/bin/env bash

# Shared helpers for repeatable, read-only hardware benchmark runs.

BENCH_SAMPLE_INTERVAL="${BENCH_SAMPLE_INTERVAL:-2}"
BENCH_CPU_LIMIT_MILLIC="${BENCH_CPU_LIMIT_MILLIC:-95000}"
BENCH_GPU_LIMIT_MILLIC="${BENCH_GPU_LIMIT_MILLIC:-90000}"
BENCH_CPU_HARD_ABORT_MILLIC="${BENCH_CPU_HARD_ABORT_MILLIC:-98000}"
BENCH_GPU_HARD_ABORT_MILLIC="${BENCH_GPU_HARD_ABORT_MILLIC:-95000}"
BENCH_THERMAL_MODE="${BENCH_THERMAL_MODE:-}"
BENCH_FAILURES=0
BENCH_SKIPS=0
BENCH_ACTIVE_PID=''

bench_cleanup() {
  local pid="$BENCH_ACTIVE_PID"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
    for _ in 1 2 3 4 5; do
      kill -0 "$pid" 2>/dev/null || break
      sleep 1
    done
    kill -KILL -- "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
  fi
  BENCH_ACTIVE_PID=''
}

trap bench_cleanup EXIT
trap 'exit 130' INT TERM

bench_die() {
  printf 'error: %s\n' "$*" >&2
  exit 2
}

bench_need_command() {
  command -v "$1" >/dev/null 2>&1 || bench_die "missing command: $1"
}

bench_positive_integer() {
  local name="$1"
  local value="$2"

  [[ "$value" =~ ^[1-9][0-9]*$ ]] || bench_die "$name must be a positive integer: $value"
}

bench_cpu_temp_raw() {
  local input label label_value

  for input in /sys/class/hwmon/hwmon*/temp*_input; do
    [ -r "$input" ] || continue
    label="${input%_input}_label"
    [ -r "$label" ] || continue
    label_value="$(<"$label")"
    case "${label_value,,}" in
      tctl|tdie|package*|cpu*)
        cat "$input"
        return 0
        ;;
    esac
  done

  return 1
}

bench_gpu_temp_raw() {
  local input label label_value hwmon_name hwmon_dir

  for input in /sys/class/hwmon/hwmon*/temp*_input; do
    [ -r "$input" ] || continue
    label="${input%_input}_label"
    label_value=""
    [ -r "$label" ] && label_value="$(<"$label")"
    hwmon_dir="${input%/temp*_input}"
    hwmon_name=""
    [ -r "$hwmon_dir/name" ] && hwmon_name="$(<"$hwmon_dir/name")"
    case "${label_value,,}:${hwmon_name,,}" in
      edge:*|junction:*|gpu*:|*:amdgpu)
        cat "$input"
        return 0
        ;;
    esac
  done

  return 1
}

bench_temp_c_from_raw() {
  local raw="${1:-}"

  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    awk -v raw="$raw" 'BEGIN { printf "%.1f", raw / 1000 }'
  else
    printf 'NA'
  fi
}

bench_is_ac() {
  local supply value

  for supply in /sys/class/power_supply/*; do
    [ -d "$supply" ] || continue
    [ -r "$supply/type" ] || continue
    [ "$(<"$supply/type")" = Mains ] || continue
    [ -r "$supply/online" ] || continue
    value="$(<"$supply/online")"
    [ "$value" = 1 ] && return 0
  done

  return 1
}

bench_require_ac() {
  bench_is_ac || bench_die 'long runs require an online AC adapter'
}

bench_collect_metadata() {
  local target="$1"
  local profile ppd_profile cpu_governor epp

  ppd_profile=""
  if command -v powerprofilesctl >/dev/null 2>&1; then
    ppd_profile="$(powerprofilesctl get 2>/dev/null || true)"
  fi
  profile=""
  if [ -r /run/native-power-profile/active ]; then
    profile="$(</run/native-power-profile/active)"
  fi
  case "$profile" in
    power-saver|balanced|performance|sustained-build) ;;
    *) profile="$ppd_profile" ;;
  esac

  cpu_governor=""
  [ -r /sys/devices/system/cpu/cpufreq/policy0/scaling_governor ] \
    && cpu_governor="$(</sys/devices/system/cpu/cpufreq/policy0/scaling_governor)"
  epp=""
  [ -r /sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference ] \
    && epp="$(</sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference)"

  {
    printf 'started_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'host=%s\n' "$(hostname)"
    printf 'kernel='; uname -srvm
    printf 'cpu_model='
    awk -F: '/^model name[[:space:]]*:/ && !found { sub(/^[[:space:]]*/, "", $2); print $2; found = 1 } END { if (!found) print "unknown" }' /proc/cpuinfo
    printf 'cpu_threads='; nproc
    printf 'memory_total_kib='
    awk '/^MemTotal:/ { print $2; found = 1 } END { if (!found) print "unknown" }' /proc/meminfo
    if bench_is_ac; then
      printf 'ac_online=yes\n'
    else
      printf 'ac_online=no\n'
    fi
    printf 'power_profile=%s\n' "${profile:-unknown}"
    printf 'powerprofilesd_profile=%s\n' "${ppd_profile:-unknown}"
    printf 'scaling_governor=%s\n' "${cpu_governor:-unknown}"
    printf 'energy_performance_preference=%s\n' "${epp:-unknown}"
    if [ -r /sys/firmware/acpi/platform_profile ]; then
      printf 'platform_profile='
      cat /sys/firmware/acpi/platform_profile
    fi
    if [ -r /sys/kernel/ryzen_smu_drv/pm_table ] && command -v od >/dev/null 2>&1; then
      printf 'ryzen_smu_pm_table_first_64_bytes_hex='
      od -An -tx1 -N 64 /sys/kernel/ryzen_smu_drv/pm_table | tr -d ' \n'
      printf '\n'
    fi
    printf 'thermal_mode=%s\n' "$BENCH_THERMAL_MODE"
    printf 'cpu_warning_c=%s\n' "$(bench_temp_c_from_raw "$BENCH_CPU_LIMIT_MILLIC")"
    printf 'gpu_warning_c=%s\n' "$(bench_temp_c_from_raw "$BENCH_GPU_LIMIT_MILLIC")"
    printf 'cpu_hard_abort_c=%s\n' "$(bench_temp_c_from_raw "$BENCH_CPU_HARD_ABORT_MILLIC")"
    printf 'gpu_hard_abort_c=%s\n' "$(bench_temp_c_from_raw "$BENCH_GPU_HARD_ABORT_MILLIC")"
  } >"$target"
}

bench_record_metadata() {
  printf '%s=%s\n' "$1" "$2" >>"$RUN_METADATA"
}

bench_record_tool_version() {
  local tool="$1"
  local version

  if [ "$tool" = llama-bench ]; then
    version='llama-bench does not expose a version option'
  else
    version="$("$tool" --version 2>&1 | sed -n '1p' || true)"
  fi
  printf 'tool.%s.path=%s\n' "$tool" "$(command -v "$tool")" >>"$RUN_METADATA"
  printf 'tool.%s.version=%s\n' "$tool" "$version" >>"$RUN_METADATA"
}

bench_init_run() {
  local label="$1"
  local requested_output="${2:-}"
  local thermal_mode="${BENCH_THERMAL_MODE:-abort}"

  case "$thermal_mode" in
    abort|record) ;;
    *) bench_die "BENCH_THERMAL_MODE must be abort or record: $thermal_mode" ;;
  esac
  BENCH_THERMAL_MODE="$thermal_mode"

  if [ -n "$requested_output" ]; then
    RUN_DIR="$requested_output"
  else
    RUN_DIR="${BENCH_OUTPUT_ROOT:-/var/tmp/think14gryzen-bench}/${label}-$(date -u +%Y%m%dT%H%M%SZ)-$$"
  fi

  mkdir -p -- "$RUN_DIR" || bench_die "cannot create output directory: $RUN_DIR"
  RUN_SUMMARY="$RUN_DIR/summary.tsv"
  RUN_TELEMETRY="$RUN_DIR/telemetry.tsv"
  RUN_METADATA="$RUN_DIR/metadata.txt"
  RUN_COMMANDS="$RUN_DIR/commands.txt"

  [ ! -e "$RUN_SUMMARY" ] || bench_die "output directory already contains a benchmark: $RUN_DIR"
  printf 'workload\tstatus\texit_code\tmax_cpu_temp_c\tmax_gpu_temp_c\tlog\n' >"$RUN_SUMMARY"
  printf 'timestamp_utc\tcpu_temp_c\tgpu_temp_c\n' >"$RUN_TELEMETRY"
  : >"$RUN_COMMANDS"
  bench_collect_metadata "$RUN_METADATA"
  if [ -f "${BASH_SOURCE[1]:-}" ] && command -v sha256sum >/dev/null 2>&1; then
    printf 'benchmark_script=%s\n' "$(readlink -f "${BASH_SOURCE[1]}")" >>"$RUN_METADATA"
    printf 'benchmark_script_sha256=%s\n' \
      "$(sha256sum "${BASH_SOURCE[1]}" | awk '{ print $1 }')" >>"$RUN_METADATA"
  fi
  if [ -e /run/current-system ]; then
    printf 'nixos_system=%s\n' "$(readlink -f /run/current-system 2>/dev/null || printf unknown)" >>"$RUN_METADATA"
  fi
  printf 'output=%s\n' "$RUN_DIR"
}

bench_record_command() {
  local workload="$1"
  shift

  printf '%s command=' "$workload" >>"$RUN_COMMANDS"
  printf '%q ' "$@" >>"$RUN_COMMANDS"
  printf '\n' >>"$RUN_COMMANDS"
}

bench_exit_code_allowed() {
  local code="$1"
  local allowed=" ${BENCH_ALLOWED_EXIT_CODES:-} "

  case "$allowed" in
    *" $code "*) return 0 ;;
    *) return 1 ;;
  esac
}

bench_run_monitored() {
  local workload="$1"
  shift
  local log="$RUN_DIR/${workload}.log"
  local pid cpu gpu max_cpu=-1 max_gpu=-1
  local running rc status reason='' cpu_warning gpu_warning
  local aborted=0
  local thermal_warned=0
  local thermal_warning_logged=0

  bench_record_command "$workload" "$@"
  if command -v setsid >/dev/null 2>&1; then
    setsid -- "$@" >"$log" 2>&1 &
  else
    "$@" >"$log" 2>&1 &
  fi
  pid=$!
  BENCH_ACTIVE_PID="$pid"

  while :; do
    cpu="$(bench_cpu_temp_raw 2>/dev/null || true)"
    gpu="$(bench_gpu_temp_raw 2>/dev/null || true)"
    if [[ "$cpu" =~ ^[0-9]+$ ]] && [ "$cpu" -gt "$max_cpu" ]; then
      max_cpu="$cpu"
    fi
    if [[ "$gpu" =~ ^[0-9]+$ ]] && [ "$gpu" -gt "$max_gpu" ]; then
      max_gpu="$gpu"
    fi
    printf '%s\t%s\t%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      "$(bench_temp_c_from_raw "$cpu")" \
      "$(bench_temp_c_from_raw "$gpu")" >>"$RUN_TELEMETRY"

    if kill -0 "$pid" 2>/dev/null; then
      running=1
    else
      running=0
    fi
    [ "$running" -eq 1 ] || break

    if [ "$aborted" -eq 0 ]; then
      cpu_warning=0
      gpu_warning=0
      [[ "$cpu" =~ ^[0-9]+$ ]] && [ "$cpu" -ge "$BENCH_CPU_LIMIT_MILLIC" ] && cpu_warning=1
      [[ "$gpu" =~ ^[0-9]+$ ]] && [ "$gpu" -ge "$BENCH_GPU_LIMIT_MILLIC" ] && gpu_warning=1
      if [ "$cpu_warning" -eq 1 ] || [ "$gpu_warning" -eq 1 ]; then
        thermal_warned=1
        if [ "$thermal_warning_logged" -eq 0 ]; then
          printf 'thermal_warning=cpu_%sC_gpu_%sC\n' \
            "$(bench_temp_c_from_raw "$cpu")" "$(bench_temp_c_from_raw "$gpu")" >>"$log"
          thermal_warning_logged=1
        fi
      fi

      if [ "$BENCH_THERMAL_MODE" = abort ]; then
        if [ "$cpu_warning" -eq 1 ]; then
          aborted=1
          reason="cpu temperature reached $(bench_temp_c_from_raw "$cpu") C"
        elif [ "$gpu_warning" -eq 1 ]; then
          aborted=1
          reason="gpu temperature reached $(bench_temp_c_from_raw "$gpu") C"
        fi
      elif [[ "$cpu" =~ ^[0-9]+$ ]] && [ "$cpu" -ge "$BENCH_CPU_HARD_ABORT_MILLIC" ]; then
        aborted=1
        reason="cpu hard temperature limit reached $(bench_temp_c_from_raw "$cpu") C"
      elif [[ "$gpu" =~ ^[0-9]+$ ]] && [ "$gpu" -ge "$BENCH_GPU_HARD_ABORT_MILLIC" ]; then
        aborted=1
        reason="gpu hard temperature limit reached $(bench_temp_c_from_raw "$gpu") C"
      fi
      if [ "$aborted" -eq 1 ]; then
        printf 'thermal_abort=%s\n' "$reason" >>"$log"
        kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true
        for _ in 1 2 3 4 5; do
          kill -0 "$pid" 2>/dev/null || break
          sleep 1
        done
        kill -KILL -- "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
      fi
    fi
    sleep "$BENCH_SAMPLE_INTERVAL"
  done

  if wait "$pid"; then
    rc=0
  else
    rc=$?
  fi
  BENCH_ACTIVE_PID=''

  if [ "$aborted" -eq 1 ]; then
    status='THERMAL_ABORT'
    BENCH_FAILURES=$((BENCH_FAILURES + 1))
  elif [ "$rc" -eq 0 ] || bench_exit_code_allowed "$rc"; then
    if [ "$thermal_warned" -eq 1 ]; then
      status='PASS_THERMAL_LIMITED'
    else
      status='PASS'
    fi
  else
    status='FAIL'
    BENCH_FAILURES=$((BENCH_FAILURES + 1))
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$workload" "$status" "$rc" \
    "$(bench_temp_c_from_raw "$max_cpu")" \
    "$(bench_temp_c_from_raw "$max_gpu")" \
    "$(basename "$log")" >>"$RUN_SUMMARY"
  printf '%s: %s (exit %s)\n' "$workload" "$status" "$rc"
}

bench_record_skip() {
  local workload="$1"
  local reason="$2"
  local count="${3:-1}"

  printf '%s\tSKIP\t-\tNA\tNA\t-\n' "$workload" >>"$RUN_SUMMARY"
  printf '%s\n' "$reason" >"$RUN_DIR/${workload}.skip"
  [ "$count" -eq 0 ] || BENCH_SKIPS=$((BENCH_SKIPS + 1))
  printf '%s: SKIP (%s)\n' "$workload" "$reason"
}

bench_finish() {
  printf 'summary=%s\n' "$RUN_SUMMARY"
  printf 'telemetry=%s\n' "$RUN_TELEMETRY"
  printf 'metadata=%s\n' "$RUN_METADATA"

  if [ "$BENCH_FAILURES" -gt 0 ]; then
    return 1
  fi
  if [ "$BENCH_SKIPS" -gt 0 ]; then
    return 3
  fi
  return 0
}
