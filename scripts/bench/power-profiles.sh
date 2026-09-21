#!/usr/bin/env bash

set -uo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=common.sh
. "$SCRIPT_DIR/common.sh"

BENCH_THERMAL_MODE="${BENCH_THERMAL_MODE:-record}"
SAMPLE_INTERVAL=2
ONE_CORE_SECONDS=60
ALL_CORE_SECONDS=480
COOLDOWN_SECONDS=120
PROFILE_LIST="performance,sustained-build,balanced,power-saver,light-use"
output=""
initial_profile=""
profile_lock_held=0
restored=0
run_started_iso=""
power_file=""

NATIVE_PROFILE=/run/current-system/sw/bin/native-power-profile
PROFILE_STATE_FILE=/run/native-power-profile/active
PROFILE_LOCK_FILE=/run/native-power-profile/lock

usage() {
  cat <<'EOF'
Usage: power-profiles.sh [options]

Benchmark every current native-power-profile preset with the same one-core and
all-core stress-ng workload. No RyzenAdj or Curve Optimizer write is performed.

Options:
  --profiles LIST       comma-separated profiles (default: all current profiles)
  --one-core-seconds N  one-core duration (default: 60)
  --all-core-seconds N  all-core duration (default: 480)
  --cooldown-seconds N  cooldown window (default: 120)
  --sample-interval N   telemetry interval (default: 2)
  --output DIR          persistent run directory
  -h, --help            show this help
EOF
}

valid_profile() {
  case "$1" in
    performance|sustained-build|balanced|power-saver|light-use) return 0 ;;
    *) return 1 ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --profiles)
      [ "$#" -ge 2 ] || bench_die '--profiles needs a value'
      PROFILE_LIST="$2"
      shift 2
      ;;
    --one-core-seconds)
      [ "$#" -ge 2 ] || bench_die '--one-core-seconds needs a value'
      ONE_CORE_SECONDS="$2"
      shift 2
      ;;
    --all-core-seconds)
      [ "$#" -ge 2 ] || bench_die '--all-core-seconds needs a value'
      ALL_CORE_SECONDS="$2"
      shift 2
      ;;
    --cooldown-seconds)
      [ "$#" -ge 2 ] || bench_die '--cooldown-seconds needs a value'
      COOLDOWN_SECONDS="$2"
      shift 2
      ;;
    --sample-interval)
      [ "$#" -ge 2 ] || bench_die '--sample-interval needs a value'
      SAMPLE_INTERVAL="$2"
      shift 2
      ;;
    --output)
      [ "$#" -ge 2 ] || bench_die '--output needs a value'
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

bench_positive_integer one_core_seconds "$ONE_CORE_SECONDS"
bench_positive_integer all_core_seconds "$ALL_CORE_SECONDS"
bench_positive_integer cooldown_seconds "$COOLDOWN_SECONDS"
bench_positive_integer sample_interval "$SAMPLE_INTERVAL"

IFS=',' read -r -a profiles <<< "$PROFILE_LIST"
profile_count=0
for profile in ${profiles[@]}; do
  valid_profile "$profile" || bench_die "unknown native profile: $profile"
  profile_count=$((profile_count + 1))
done
[ "$profile_count" -gt 0 ] || bench_die '--profiles cannot be empty'

if [ -z "$output" ]; then
  repo_root="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
  output="$repo_root/docs/bench/power-profiles/$(date -u +%Y%m%dT%H%M%SZ)-$BASHPID"
fi

for command_name in awk date flock nproc setsid stress-ng taskset; do
  bench_need_command "$command_name"
done
bench_require_ac
[ -x "$NATIVE_PROFILE" ] || bench_die "missing native profile controller: $NATIVE_PROFILE"
[ -r "$PROFILE_STATE_FILE" ] || bench_die "missing native profile state: $PROFILE_STATE_FILE"
[ -r "$PROFILE_LOCK_FILE" ] || bench_die "missing native profile lock: $PROFILE_LOCK_FILE"

initial_profile="$(<"$PROFILE_STATE_FILE")"
valid_profile "$initial_profile" || bench_die "invalid initial profile: $initial_profile"
"$NATIVE_PROFILE" --verify >/dev/null 2>&1 || bench_die 'initial native profile verification failed'

for hwmon in /sys/class/hwmon/hwmon*; do
  [ -d "$hwmon" ] || continue
  [ -r "$hwmon/name" ] || continue
  [ "$(<"$hwmon/name")" = amdgpu ] || continue
  for candidate in "$hwmon/power1_average" "$hwmon/power1_input"; do
    if [ -r "$candidate" ]; then
      power_file="$candidate"
      break 2
    fi
  done
done
[ -n "$power_file" ] || bench_die 'amdgpu power sysfs input was not found'

bench_init_run power-profiles "$output"
printf 'profile\tphase\tstatus\texit_code\telapsed_s\tpeak_cpu_temp_c\tpeak_gpu_temp_c\tpeak_apu_power_w\tpeak_freq_avg_mhz\tpolicy_max_mhz\thardware_max_mhz\tlog\n' >"$RUN_SUMMARY"
printf 'timestamp_utc\tprofile\tphase\telapsed_s\tcpu_temp_c\tgpu_temp_c\tamdgpu_power_w\tfreq_avg_mhz\tpolicy_max_mhz\thardware_max_mhz\tload1\tthermal_throttle_count\n' >"$RUN_TELEMETRY"
bench_record_metadata benchmark 'native power profile comparison'
bench_record_metadata profiles "$PROFILE_LIST"
bench_record_metadata sample_interval_s "$SAMPLE_INTERVAL"
bench_record_metadata one_core_seconds "$ONE_CORE_SECONDS"
bench_record_metadata all_core_seconds "$ALL_CORE_SECONDS"
bench_record_metadata cooldown_seconds "$COOLDOWN_SECONDS"
bench_record_metadata native_profile_controller "$NATIVE_PROFILE"
bench_record_metadata ryzenadj_write no
bench_record_metadata curve_optimizer_write no

run_started_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'journal_baseline=%s/kernel-journal-before.log\n' "$RUN_DIR" >>"$RUN_METADATA"
journalctl -k --no-pager -o short-iso >"$RUN_DIR/kernel-journal-before.log" 2>"$RUN_DIR/kernel-journal-before.error.log" || \
  printf 'journal_status=UNAVAILABLE\n' >>"$RUN_METADATA"

release_profile_lock() {
  [ "$profile_lock_held" -eq 1 ] || return 0
  flock -u 8 2>/dev/null || true
  exec 8<&-
  profile_lock_held=0
}

restore_state() {
  local restore_log="$RUN_DIR/profile-restore.log"
  local restore_rc=0

  release_profile_lock
  [ -n "$initial_profile" ] || return 0
  printf 'restore_command=%q %q\n' "$NATIVE_PROFILE" "$initial_profile" >>"$RUN_COMMANDS"
  if ! "$NATIVE_PROFILE" "$initial_profile" >"$restore_log" 2>&1; then
    restore_rc=1
  fi
  if ! "$NATIVE_PROFILE" --verify >>"$restore_log" 2>&1; then
    restore_rc=1
  fi
  printf 'restored_profile=%s\n' "$initial_profile" >>"$RUN_METADATA"
  printf 'profile_restore=%s\n' "$([ "$restore_rc" -eq 0 ] && echo PASS || echo FAIL)" >>"$RUN_METADATA"
  return "$restore_rc"
}

on_exit() {
  local rc=$?
  trap - EXIT INT TERM
  bench_cleanup
  if [ "$restored" -eq 0 ] && [ -n "${RUN_METADATA:-}" ]; then
    restored=1
    restore_state || rc=1
    printf 'result=%s\n' "$([ "$rc" -eq 0 ] && echo PASS || echo FAIL)" >>"$RUN_METADATA"
  fi
  exit "$rc"
}

trap on_exit EXIT
trap 'exit 130' INT TERM

read_power_raw() {
  local raw

  raw="$(<"$power_file")" || return 1
  [[ "$raw" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$raw"
}

read_policy_stats() {
  local dir avg_file value sum=0 count=0
  local policy_max hardware_max lowest_policy=0 highest_hardware=0 limit_count=0

  for dir in /sys/devices/system/cpu/cpufreq/policy*; do
    [ -d "$dir" ] || continue
    avg_file="$dir/cpuinfo_avg_freq"
    [ -r "$avg_file" ] || avg_file="$dir/scaling_cur_freq"
    if [ -r "$avg_file" ]; then
      value="$(<"$avg_file")"
      if [[ "$value" =~ ^[0-9]+$ ]]; then
        sum=$((sum + value))
        count=$((count + 1))
      fi
    fi

    policy_max=""
    hardware_max=""
    [ -r "$dir/scaling_max_freq" ] && policy_max="$(<"$dir/scaling_max_freq")"
    if [ -r "$dir/amd_pstate_max_freq" ]; then
      hardware_max="$(<"$dir/amd_pstate_max_freq")"
    elif [ -r "$dir/cpuinfo_max_freq" ]; then
      hardware_max="$(<"$dir/cpuinfo_max_freq")"
    fi
    if [[ "$policy_max" =~ ^[0-9]+$ && "$hardware_max" =~ ^[0-9]+$ ]]; then
      limit_count=$((limit_count + 1))
      if [ "$lowest_policy" -eq 0 ] || [ "$policy_max" -lt "$lowest_policy" ]; then
        lowest_policy="$policy_max"
      fi
      [ "$hardware_max" -gt "$highest_hardware" ] && highest_hardware="$hardware_max"
    fi
  done

  if [ "$count" -gt 0 ]; then
    freq_avg="$(awk -v sum="$sum" -v count="$count" 'BEGIN { printf "%.2f", sum / count / 1000 }')"
  else
    freq_avg=NA
  fi
  if [ "$limit_count" -gt 0 ]; then
    policy_max_mhz="$(awk -v value="$lowest_policy" 'BEGIN { printf "%.2f", value / 1000 }')"
    hardware_max_mhz="$(awk -v value="$highest_hardware" 'BEGIN { printf "%.2f", value / 1000 }')"
  else
    policy_max_mhz=NA
    hardware_max_mhz=NA
  fi
  printf '%s\t%s\t%s\n' "$freq_avg" "$policy_max_mhz" "$hardware_max_mhz"
}

read_throttle_count() {
  local file value total=0 count=0

  for file in /sys/devices/system/cpu/cpu*/thermal_throttle/*_throttle_count; do
    [ -r "$file" ] || continue
    value="$(<"$file")"
    [[ "$value" =~ ^[0-9]+$ ]] || continue
    total=$((total + value))
    count=$((count + 1))
  done
  [ "$count" -gt 0 ] || {
    printf 'NA\n'
    return 0
  }
  printf '%s\n' "$total"
}

current_cpu_raw=NA
current_gpu_raw=NA
current_power_raw=NA
current_cpu_c=NA
current_gpu_c=NA
current_power_w=NA
current_freq_avg=NA
current_policy_max=NA
current_hardware_max=NA
current_load1=NA
current_throttle=NA
previous_total=0
previous_idle=0
phase_peak_cpu=-1
phase_peak_gpu=-1
phase_peak_power=-1
phase_peak_freq=NA
phase_warning=0
thermal_abort=0
sensor_failure=0
profile_drift=0

sample_once() {
  local profile="$1" phase="$2" phase_log="$3" elapsed="$4"
  local policy_stats busy_stats active_profile
  local current_total current_idle

  current_cpu_raw="$(bench_cpu_temp_raw 2>/dev/null || true)"
  if [[ "$current_cpu_raw" =~ ^[0-9]+$ ]]; then
    current_cpu_c="$(bench_temp_c_from_raw "$current_cpu_raw")"
    [ "$current_cpu_raw" -gt "$phase_peak_cpu" ] && phase_peak_cpu="$current_cpu_raw"
  else
    current_cpu_c=NA
    sensor_failure=1
    printf 'sensor_failure=cpu_temperature\n' >>"$phase_log"
  fi

  current_gpu_raw="$(bench_gpu_temp_raw 2>/dev/null || true)"
  if [[ "$current_gpu_raw" =~ ^[0-9]+$ ]]; then
    current_gpu_c="$(bench_temp_c_from_raw "$current_gpu_raw")"
    [ "$current_gpu_raw" -gt "$phase_peak_gpu" ] && phase_peak_gpu="$current_gpu_raw"
  else
    current_gpu_c=NA
  fi

  current_power_raw="$(read_power_raw 2>/dev/null || true)"
  if [[ "$current_power_raw" =~ ^[0-9]+$ ]]; then
    current_power_w="$(awk -v raw="$current_power_raw" 'BEGIN { printf "%.3f", raw / 1000000 }')"
    [ "$current_power_raw" -gt "$phase_peak_power" ] && phase_peak_power="$current_power_raw"
  else
    current_power_w=NA
    sensor_failure=1
    printf 'sensor_failure=amdgpu_power\n' >>"$phase_log"
  fi

  policy_stats="$(read_policy_stats)"
  IFS=$'\t' read -r current_freq_avg current_policy_max current_hardware_max <<<"$policy_stats"
  if [ "$current_freq_avg" = NA ]; then
    sensor_failure=1
    printf 'sensor_failure=cpu_frequency\n' >>"$phase_log"
  fi
  if [ "$phase_peak_freq" = NA ] || awk -v current="$current_freq_avg" -v peak="$phase_peak_freq" 'BEGIN { exit !(current > peak) }'; then
    phase_peak_freq="$current_freq_avg"
  fi

  busy_stats="$(awk '/^cpu / { total=$2+$3+$4+$5+$6+$7+$8+$9; idle=$5+$6; print total, idle; exit }' /proc/stat)"
  read -r current_total current_idle <<<"$busy_stats"
  if [[ "$current_total" =~ ^[0-9]+$ && "$previous_total" -gt 0 && "$current_total" -gt "$previous_total" ]]; then
    current_busy="$(awk -v total="$current_total" -v idle="$current_idle" -v prev_total="$previous_total" -v prev_idle="$previous_idle" 'BEGIN { printf "%.1f", (total - prev_total - (idle - prev_idle)) * 100 / (total - prev_total) }')"
  else
    current_busy=NA
  fi
  previous_total="${current_total:-0}"
  previous_idle="${current_idle:-0}"
  current_load1="$(awk '{ print $1 }' /proc/loadavg 2>/dev/null || printf NA)"
  current_throttle="$(read_throttle_count)"

  active_profile="$(cat "$PROFILE_STATE_FILE" 2>/dev/null || true)"
  if [ "$active_profile" != "$profile" ]; then
    profile_drift=1
    printf 'profile_drift=expected_%s_observed_%s\n' "$profile" "${active_profile:-missing}" >>"$phase_log"
  fi

  if [[ "$current_cpu_raw" =~ ^[0-9]+$ ]]; then
    if [ "$current_cpu_raw" -ge "$BENCH_CPU_LIMIT_MILLIC" ]; then
      phase_warning=1
      printf 'thermal_warning=cpu_%sC\n' "$current_cpu_c" >>"$phase_log"
    fi
    if [ "$current_cpu_raw" -ge "$BENCH_CPU_HARD_ABORT_MILLIC" ]; then
      thermal_abort=1
      printf 'thermal_abort=cpu_%sC\n' "$current_cpu_c" >>"$phase_log"
    fi
  fi
  if [[ "$current_gpu_raw" =~ ^[0-9]+$ ]]; then
    if [ "$current_gpu_raw" -ge "$BENCH_GPU_LIMIT_MILLIC" ]; then
      phase_warning=1
      printf 'thermal_warning=gpu_%sC\n' "$current_gpu_c" >>"$phase_log"
    fi
    if [ "$current_gpu_raw" -ge "$BENCH_GPU_HARD_ABORT_MILLIC" ]; then
      thermal_abort=1
      printf 'thermal_abort=gpu_%sC\n' "$current_gpu_c" >>"$phase_log"
    fi
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$profile" "$phase" "$elapsed" \
    "$current_cpu_c" "$current_gpu_c" "$current_power_w" "$current_freq_avg" \
    "$current_policy_max" "$current_hardware_max" "$current_load1" "$current_throttle" >>"$RUN_TELEMETRY"
}

stop_workload() {
  if [ -n "$BENCH_ACTIVE_PID" ] && kill -0 "$BENCH_ACTIVE_PID" 2>/dev/null; then
    kill -TERM -- -"$BENCH_ACTIVE_PID" 2>/dev/null || kill -TERM "$BENCH_ACTIVE_PID" 2>/dev/null || true
    for _ in 1 2 3 4 5; do
      kill -0 "$BENCH_ACTIVE_PID" 2>/dev/null || break
      sleep 1
    done
    kill -KILL -- -"$BENCH_ACTIVE_PID" 2>/dev/null || kill -KILL "$BENCH_ACTIVE_PID" 2>/dev/null || true
  fi
}

write_phase_summary() {
  local profile="$1" phase="$2" status="$3" exit_code="$4" elapsed="$5" log="$6"
  local peak_cpu_c=NA peak_gpu_c=NA peak_power_w=NA

  [ "$phase_peak_cpu" -ge 0 ] && peak_cpu_c="$(bench_temp_c_from_raw "$phase_peak_cpu")"
  [ "$phase_peak_gpu" -ge 0 ] && peak_gpu_c="$(bench_temp_c_from_raw "$phase_peak_gpu")"
  [ "$phase_peak_power" -ge 0 ] && peak_power_w="$(awk -v raw="$phase_peak_power" 'BEGIN { printf "%.3f", raw / 1000000 }')"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$profile" "$phase" "$status" "$exit_code" "$elapsed" "$peak_cpu_c" "$peak_gpu_c" \
    "$peak_power_w" "$phase_peak_freq" "$current_policy_max" "$current_hardware_max" "$log" >>"$RUN_SUMMARY"
  printf '%s/%s: %s, peak Tctl %s C, peak APU PPT %s W, policy max %s MHz\n' \
    "$profile" "$phase" "$status" "$peak_cpu_c" "$peak_power_w" "$current_policy_max"
}

run_phase() {
  local profile="$1" phase="$2" duration="$3" cpus="$4" workers="$5"
  local phase_log="$RUN_DIR/$profile/$phase.log"
  local start_seconds="$SECONDS" elapsed=0 rc=0 status stop_requested=0

  phase_peak_cpu=-1
  phase_peak_gpu=-1
  phase_peak_power=-1
  phase_peak_freq=NA
  phase_warning=0
  thermal_abort=0
  sensor_failure=0
  profile_drift=0
  previous_total=0
  previous_idle=0
  : >"$phase_log"

  bench_record_command "$profile/$phase" setsid taskset --cpu-list "$cpus" stress-ng --cpu "$workers" \
    --cpu-method matrixprod --verify --timeout "${duration}s" --metrics-brief --times
  setsid -- taskset --cpu-list "$cpus" stress-ng --cpu "$workers" \
    --cpu-method matrixprod --verify --timeout "${duration}s" --metrics-brief --times \
    >"$phase_log" 2>&1 &
  BENCH_ACTIVE_PID=$!

  while kill -0 "$BENCH_ACTIVE_PID" 2>/dev/null; do
    elapsed=$((SECONDS - start_seconds))
    sample_once "$profile" "$phase" "$phase_log" "$elapsed"
    if [ "$thermal_abort" -eq 1 ] || [ "$sensor_failure" -eq 1 ] || [ "$profile_drift" -eq 1 ]; then
      stop_requested=1
      stop_workload
      break
    fi
    sleep "$SAMPLE_INTERVAL"
  done

  if wait "$BENCH_ACTIVE_PID"; then
    rc=0
  else
    rc=$?
  fi
  BENCH_ACTIVE_PID=''
  elapsed=$((SECONDS - start_seconds))
  sample_once "$profile" "$phase" "$phase_log" "$elapsed"

  if [ "$thermal_abort" -eq 1 ]; then
    status=THERMAL_ABORT
  elif [ "$sensor_failure" -eq 1 ]; then
    status=SENSOR_READ_FAIL
  elif [ "$profile_drift" -eq 1 ]; then
    status=PROFILE_DRIFT
  elif [ "$rc" -ne 0 ] || [ "$stop_requested" -eq 1 ]; then
    status=FAIL
  elif [ "$phase_warning" -eq 1 ]; then
    status=PASS_THERMAL_WARNING
  else
    status=PASS
  fi
  write_phase_summary "$profile" "$phase" "$status" "$rc" "$elapsed" "$(basename "$phase_log")"
  case "$status" in
    PASS|PASS_THERMAL_WARNING) return 0 ;;
    *) BENCH_FAILURES=$((BENCH_FAILURES + 1)); return 1 ;;
  esac
}

cooldown_profile() {
  local profile="$1" phase="$2" phase_log="$RUN_DIR/$1/$2.log"
  local started="$SECONDS" elapsed=0 temp_raw

  phase_peak_cpu=-1
  phase_peak_gpu=-1
  phase_peak_power=-1
  phase_peak_freq=NA
  phase_warning=0
  thermal_abort=0
  sensor_failure=0
  profile_drift=0
  previous_total=0
  previous_idle=0
  : >"$phase_log"

  while [ $((SECONDS - started)) -lt "$COOLDOWN_SECONDS" ]; do
    elapsed=$((SECONDS - started))
    sample_once "$profile" "$phase" "$phase_log" "$elapsed"
    temp_raw="$current_cpu_raw"
    if [ "$thermal_abort" -eq 1 ] || [ "$sensor_failure" -eq 1 ] || [ "$profile_drift" -eq 1 ]; then
      return 1
    fi
    if [[ "$temp_raw" =~ ^[0-9]+$ ]] && [ "$temp_raw" -lt 70000 ]; then
      printf 'last_cooldown_phase=%s\n' "$phase" >>"$RUN_DIR/$profile/profile-metadata.txt"
      printf 'last_cooldown_elapsed_s=%s\n' "$elapsed" >>"$RUN_DIR/$profile/profile-metadata.txt"
      return 0
    fi
    sleep "$SAMPLE_INTERVAL"
  done
  printf 'cooldown_status=TIMEOUT\n' >>"$phase_log"
  return 1
}

run_profile() {
  local profile="$1" profile_dir="$RUN_DIR/$1" apply_log
  local phase_failed=0

  mkdir -p -- "$profile_dir"
  apply_log="$profile_dir/profile-apply.log"
  printf 'requested_profile=%s\n' "$profile" >"$profile_dir/profile-metadata.txt"
  bench_record_command "$profile/apply" "$NATIVE_PROFILE" "$profile"
  if ! "$NATIVE_PROFILE" "$profile" >"$apply_log" 2>&1 || \
    ! "$NATIVE_PROFILE" --verify >>"$apply_log" 2>&1; then
    printf 'profile_apply=FAIL\n' >>"$profile_dir/profile-metadata.txt"
    printf '%s\tapply\tPROFILE_APPLY_FAIL\t-\t0\tNA\tNA\tNA\tNA\tNA\tNA\t%s\n' \
      "$profile" "$(basename "$apply_log")" >>"$RUN_SUMMARY"
    BENCH_FAILURES=$((BENCH_FAILURES + 1))
    return 0
  fi
  printf 'profile_apply=PASS\n' >>"$profile_dir/profile-metadata.txt"
  bench_collect_metadata "$profile_dir/runtime-metadata.txt"

  exec 8<"$PROFILE_LOCK_FILE"
  flock -s -n 8 || bench_die "cannot lock profile for $profile"
  profile_lock_held=1

  if ! cooldown_profile "$profile" cooldown-before; then
    phase_failed=1
  elif ! run_phase "$profile" one-core "$ONE_CORE_SECONDS" 0 1; then
    phase_failed=1
  elif ! cooldown_profile "$profile" cooldown-between; then
    phase_failed=1
  elif ! run_phase "$profile" all-core "$ALL_CORE_SECONDS" 0-15 16; then
    phase_failed=1
  elif ! cooldown_profile "$profile" cooldown-after; then
    phase_failed=1
  fi

  release_profile_lock
  printf 'status=%s\n' "$([ "$phase_failed" -eq 0 ] && echo PASS || echo FAIL)" >"$profile_dir/profile-status.txt"
  [ "$phase_failed" -eq 0 ]
}

printf 'output=%s\n' "$RUN_DIR"
for profile in ${profiles[@]}; do
  printf '\n=== %s ===\n' "$profile"
  run_profile "$profile" || true
done

bench_finish
