#!/usr/bin/env bash

# The redirects intentionally belong to the calling user so benchmark logs are
# writable without granting the helper any filesystem access.
# shellcheck disable=SC2024
set -euo pipefail
export LC_ALL=C

PROFILE=performance
CO_OFFSET=-1
SAMPLE_INTERVAL=2
ONE_CORE_SECONDS=60
ALL_CORE_SECONDS=480
COOLDOWN_SECONDS=120
CPU_READY_MILLIC=70000
CPU_WARNING_MILLIC=95000
CPU_ABORT_MILLIC=98000
NATIVE_PROFILE=/run/current-system/sw/bin/native-power-profile
CO_CONTROL=/run/current-system/sw/bin/co-curve-control
PROFILE_STATE_FILE=/run/native-power-profile/active
PROFILE_LOCK_FILE=/run/native-power-profile/lock
output=""
active_pid=""
initial_profile=""
initial_ppd_profile=""
profile_lock_held=0
co_active=0
restored=0
restore_status=0
co_reset_status=NOT_RUN
journal_fault_seen=0
journal_unavailable=0
sudo_unavailable=0
sensor_failure=0
profile_drift=0
thermal_abort_seen=0

usage() {
  cat <<'EOF'
Usage: oc-curve.sh [--output DIR]

Run the fixed Hawk Point CO -1 smoke test in the performance profile.
The test applies CO only after eight zero readbacks, keeps the native profile
lock while active, and resets CO before restoring the initial profile.

The fixed workload is one worker on CPU0 for 60 seconds, followed by sixteen
workers on CPUs 0-15 for 480 seconds. Telemetry is sampled every 2 seconds.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --output)
      [ "$#" -ge 2 ] || die '--output needs a value'
      output="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

if [ -z "$output" ]; then
  output="docs/bench/$(date -u +%Y%m%d)-thinkbook-14-g6-plus-8845h-co-minus1"
fi

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

for command_name in awk date flock grep journalctl mkdir nproc powerprofilesctl setsid sleep stress-ng sudo taskset; do
  need_command "$command_name"
done

[ -x "$NATIVE_PROFILE" ] || die "missing native profile controller: $NATIVE_PROFILE"
[ -x "$CO_CONTROL" ] || die "missing CO controller: $CO_CONTROL"
[ -r "$PROFILE_STATE_FILE" ] || die "missing native profile state: $PROFILE_STATE_FILE"
[ -r "$PROFILE_LOCK_FILE" ] || die "missing native profile lock: $PROFILE_LOCK_FILE"

is_ac_online() {
  local supply

  for supply in /sys/class/power_supply/*; do
    [ -d "$supply" ] || continue
    [ -r "$supply/type" ] || continue
    [ "$(<"$supply/type")" = Mains ] || continue
    [ -r "$supply/online" ] && [ "$(<"$supply/online")" = 1 ] && return 0
  done
  return 1
}

read_hwmon_name() {
  local dir="$1"

  [ -r "$dir/name" ] || return 1
  IFS= read -r REPLY <"$dir/name"
  printf '%s\n' "$REPLY"
}

hwmon_cpu=""
hwmon_power=""
cpu_temp_file=""
power_file=""
for hwmon in /sys/class/hwmon/hwmon*; do
  [ -d "$hwmon" ] || continue
  case "$(read_hwmon_name "$hwmon" 2>/dev/null || true)" in
    k10temp)
      hwmon_cpu="$hwmon"
      ;;
    amdgpu)
      hwmon_power="$hwmon"
      ;;
  esac
done

[ -n "$hwmon_cpu" ] || die 'k10temp hwmon was not found'
for temp_file in "$hwmon_cpu"/temp*_input; do
  [ -r "$temp_file" ] || continue
  temp_label="${temp_file%_input}_label"
  if [ -r "$temp_label" ] && [ "$(<"$temp_label")" = Tctl ]; then
    cpu_temp_file="$temp_file"
    break
  fi
done
[ -n "$cpu_temp_file" ] || die 'k10temp Tctl input was not found'

[ -n "$hwmon_power" ] || die 'amdgpu hwmon was not found'
for candidate in "$hwmon_power/power1_average" "$hwmon_power/power1_input"; do
  if [ -r "$candidate" ]; then
    power_file="$candidate"
    break
  fi
done
[ -n "$power_file" ] || die 'amdgpu power sysfs input was not found'

read_cpu_temp_raw() {
  local value

  value="$(<"$cpu_temp_file")" || return 1
  [[ "$value" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$value"
}

read_power_w() {
  local raw

  raw="$(<"$power_file")" || return 1
  [[ "$raw" =~ ^[0-9]+$ ]] || return 1
  awk -v value="$raw" 'BEGIN { printf "%.3f", value / 1000000 }'
}

read_freq_stats() {
  local dir avg_file value sum=0 count=0 max=0 min=9999999999
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
        [ "$value" -gt "$max" ] && max="$value"
        [ "$value" -lt "$min" ] && min="$value"
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
    freq_max="$(awk -v value="$max" 'BEGIN { printf "%.2f", value / 1000 }')"
    freq_min="$(awk -v value="$min" 'BEGIN { printf "%.2f", value / 1000 }')"
  else
    freq_avg=NA
    freq_max=NA
    freq_min=NA
  fi
  if [ "$limit_count" -gt 0 ]; then
    policy_max_mhz="$(awk -v value="$lowest_policy" 'BEGIN { printf "%.2f", value / 1000 }')"
    hardware_max_mhz="$(awk -v value="$highest_hardware" 'BEGIN { printf "%.2f", value / 1000 }')"
  else
    policy_max_mhz=NA
    hardware_max_mhz=NA
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$freq_avg" "$freq_max" "$freq_min" "$policy_max_mhz" "$hardware_max_mhz"
}

read_cpu_busy() {
  local previous_total="${1:-0}" previous_idle="${2:-0}"
  local user nice system idle iowait irq softirq steal
  local total idle_all delta_total delta_idle

  read -r _ user nice system idle iowait irq softirq steal _ _ < /proc/stat || {
    printf 'NA\t0\t0\n'
    return 1
  }
  if ! [[ "$user" =~ ^[0-9]+$ && "$nice" =~ ^[0-9]+$ && "$system" =~ ^[0-9]+$ && \
    "$idle" =~ ^[0-9]+$ && "$iowait" =~ ^[0-9]+$ && "$irq" =~ ^[0-9]+$ && \
    "$softirq" =~ ^[0-9]+$ && "$steal" =~ ^[0-9]+$ ]]; then
    printf 'NA\t0\t0\n'
    return 1
  fi

  total=$((user + nice + system + idle + iowait + irq + softirq + steal))
  idle_all=$((idle + iowait))
  if [ "$previous_total" -gt 0 ] && [ "$total" -gt "$previous_total" ]; then
    delta_total=$((total - previous_total))
    delta_idle=$((idle_all - previous_idle))
    busy="$(awk -v total="$delta_total" -v idle="$delta_idle" \
      'BEGIN { printf "%.1f", (total - idle) * 100 / total }')"
  else
    busy=NA
  fi
  printf '%s\t%s\t%s\n' "$busy" "$total" "$idle_all"
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

record_command() {
  printf '%s\n' "$*" >>"$commands"
}

valid_profile() {
  case "$1" in
    performance|sustained-build|balanced|power-saver) return 0 ;;
    *) return 1 ;;
  esac
}

refresh_sudo_timestamp() {
  sudo -n -v || {
    sudo_unavailable=1
    return 1
  }
}

capture_journal() {
  local phase_log="$1"

  if ! journalctl -k -b --since "$run_started_iso" --no-pager -o short-iso \
    >"$journal_log" 2>"$journal_error_log"; then
    journal_unavailable=1
    printf 'journal_status=FAIL\n' >>"$phase_log"
    return 1
  fi
  if grep -Eiq 'mce|machine check|hardware error|edac|smu.*(timeout|reject|fail)|timeout.*smu|reject.*smu' \
    "$journal_log"; then
    journal_fault_seen=1
    printf 'kernel_fault=matched\n' >>"$phase_log"
  fi
  return 0
}

verify_probe_readback() {
  local expected="$1" probe_log="$2"

  awk -v expected="$expected" '
    /^core=[0-9]+ co=-?[0-9]+$/ {
      split($1, core_field, "=")
      split($2, co_field, "=")
      core = core_field[2] + 0
      if (core < 0 || core > 7 || seen[core]++) {
        bad = 1
      } else {
        count++
      }
      if (co_field[2] != expected) {
        bad = 1
      }
    }
    END {
      if (count != 8 || bad) exit 1
    }
  ' "$probe_log"
}

run_control() {
  local action="$1" log="$2"

  record_command "sudo -n $CO_CONTROL $action"
  sudo -n "$CO_CONTROL" "$action" >"$log" 2>&1
}

read_active_profile() {
  local value

  value="$(<"$PROFILE_STATE_FILE")" || return 1
  valid_profile "$value" || return 1
  printf '%s\n' "$value"
}

release_profile_lock() {
  [ "$profile_lock_held" -eq 1 ] || return 0
  flock -u 8 2>/dev/null || true
  exec 8<&-
  profile_lock_held=0
}

stop_workload() {
  if [ -n "$active_pid" ] && kill -0 "$active_pid" 2>/dev/null; then
    kill -TERM -- "-$active_pid" 2>/dev/null || kill -TERM "$active_pid" 2>/dev/null || true
    sleep 2
    kill -KILL -- "-$active_pid" 2>/dev/null || kill -KILL "$active_pid" 2>/dev/null || true
  fi
}

restore_state() {
  local reset_rc=0 reset_probe_rc=0

  stop_workload
  if [ "$co_active" -eq 1 ]; then
    record_command "sudo -n $CO_CONTROL reset"
    if ! sudo -n "$CO_CONTROL" reset >"$output/co-reset.log" 2>&1; then
      reset_rc=1
    fi
    record_command "sudo -n $CO_CONTROL probe"
    if ! sudo -n "$CO_CONTROL" probe >"$output/co-reset-probe.log" 2>&1 || \
      ! verify_probe_readback 0 "$output/co-reset-probe.log"; then
      reset_probe_rc=1
    fi
    if [ "$reset_rc" -eq 0 ] && [ "$reset_probe_rc" -eq 0 ]; then
      co_reset_status=PASS
      co_active=0
    else
      co_reset_status=FAIL
      printf 'cold_reboot_required=yes\n' >>"$metadata"
      restore_status=1
    fi
  else
    co_reset_status=NOT_NEEDED
  fi

  if [ "$co_reset_status" != PASS ] && [ "$co_reset_status" != NOT_NEEDED ]; then
    printf 'profile_restore=SKIPPED_CO_RESET_FAIL\n' >>"$metadata"
    printf 'error: CO reset was not verified; stop using the system and cold reboot\n' >&2
    release_profile_lock
    return 1
  fi

  release_profile_lock
  if [ -n "$initial_profile" ]; then
    record_command "$NATIVE_PROFILE $initial_profile"
    if ! "$NATIVE_PROFILE" "$initial_profile" >"$output/profile-restore.log" 2>&1; then
      restore_status=1
    fi
    record_command "$NATIVE_PROFILE --verify"
    if ! "$NATIVE_PROFILE" --verify >>"$output/profile-restore.log" 2>&1; then
      restore_status=1
    fi
    printf 'restored_profile=%s\n' "$initial_profile" >>"$metadata"
    printf 'profile_restore=%s\n' "$([ "$restore_status" -eq 0 ] && echo PASS || echo FAIL)" >>"$metadata"
  fi
  return "$restore_status"
}

on_exit() {
  local rc=$?
  trap - EXIT INT TERM
  if [ "$restored" -eq 0 ] && [ -n "${metadata:-}" ]; then
    restored=1
    restore_state || rc=1
    printf 'result=%s\n' "$([ "$rc" -eq 0 ] && echo PASS || echo FAIL)" >>"$metadata"
    printf 'reset_status=%s\n' "$co_reset_status" >>"$metadata"
  fi
  exit "$rc"
}

mkdir -p -- "$output" || die "cannot create output directory: $output"
for artifact in summary.tsv telemetry.csv metadata.txt commands.txt; do
  [ ! -e "$output/$artifact" ] || die "output directory already contains a run: $output"
done

telemetry="$output/telemetry.csv"
summary="$output/summary.tsv"
metadata="$output/metadata.txt"
commands="$output/commands.txt"
journal_log="$output/kernel-journal.log"
journal_error_log="$output/kernel-journal.error.log"
journal_baseline_log="$output/kernel-journal-before.log"
printf 'timestamp_utc,phase,elapsed_s,tctl_c,amdgpu_power_w,freq_avg_mhz,freq_max_mhz,freq_min_mhz,policy_max_mhz,hardware_max_mhz,cpu_busy_pct,load1,thermal_throttle_count,kernel_fault\n' >"$telemetry"
printf 'phase,status,elapsed_s,peak_tctl_c,thermal_warning,co_readback,kernel_fault,log\n' >"$summary"
: >"$commands"
trap on_exit EXIT
trap 'exit 130' INT TERM

run_started_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if ! journalctl -k -b --no-pager -o short-iso >"$journal_baseline_log" 2>"$journal_error_log"; then
  die 'cannot capture the baseline kernel journal'
fi

product="$(< /sys/class/dmi/id/product_name)"
cpu_model="$(awk -F: '/^model name[[:space:]]*:/ && !found { sub(/^[[:space:]]*/, "", $2); print $2; found=1 } END { if (!found) print "unknown" }' /proc/cpuinfo)"
cpu_threads="$(nproc --all)"
cpu_temp_raw="$(read_cpu_temp_raw 2>/dev/null || true)"

[ "$product" = 21LF ] || die "unexpected product: $product"
[ "$cpu_model" = 'AMD Ryzen 7 8845H w/ Radeon 780M Graphics' ] || \
  die "unexpected CPU model: $cpu_model"
[ "$cpu_threads" -eq 16 ] || die "expected 16 CPU threads, got $cpu_threads"
[ -d /sys/devices/system/cpu/cpu15 ] || die 'CPU15 is not present'
is_ac_online || die 'CO smoke test requires an online AC adapter'
[[ "$cpu_temp_raw" =~ ^[0-9]+$ ]] || die 'cannot read k10temp Tctl'
[ "$cpu_temp_raw" -lt "$CPU_READY_MILLIC" ] || \
  die "CPU temperature must be below 70 C before the test: $((cpu_temp_raw / 1000)) C"

initial_profile="$(read_active_profile 2>/dev/null || true)"
valid_profile "$initial_profile" || die "cannot determine initial native profile: $initial_profile"
initial_ppd_profile="$(powerprofilesctl get 2>/dev/null || true)"
case "$initial_ppd_profile" in
  power-saver|balanced|performance) ;;
  *) die "cannot determine initial PPD profile: ${initial_ppd_profile:-unknown}" ;;
esac

SUDO_ASKPASS="${SUDO_ASKPASS:-/run/current-system/sw/bin/rofi-sudo-askpass}"
export SUDO_ASKPASS
record_command 'sudo -A -v'
sudo -A -v || die 'sudo credential acquisition via Rofi askpass failed'
refresh_sudo_timestamp || die 'sudo timestamp could not be retained noninteractively'

record_command "$NATIVE_PROFILE --verify"
"$NATIVE_PROFILE" --verify >"$output/native-profile-before.log" 2>&1 || \
  die 'initial native profile verification failed'

{
  printf 'started_utc=%s\n' "$run_started_iso"
  printf 'host=%s\n' "$(hostname)"
  printf 'kernel='; uname -srvm
  printf 'product=%s\n' "$product"
  printf 'cpu_model=%s\n' "$cpu_model"
  printf 'cpu_threads=%s\n' "$cpu_threads"
  printf 'initial_native_profile=%s\n' "$initial_profile"
  printf 'initial_powerprofilesd_profile=%s\n' "$initial_ppd_profile"
  printf 'ac_online=yes\n'
  printf 'k10temp=%s\n' "$cpu_temp_file"
  printf 'power_sysfs=%s\n' "$power_file"
  printf 'co_controller=%s\n' "$CO_CONTROL"
  printf 'co_offset=%s\n' "$CO_OFFSET"
  printf 'profile=%s\n' "$PROFILE"
  printf 'sample_interval_s=%s\n' "$SAMPLE_INTERVAL"
  printf 'one_core_seconds=%s\n' "$ONE_CORE_SECONDS"
  printf 'all_core_seconds=%s\n' "$ALL_CORE_SECONDS"
  printf 'cooldown_seconds=%s\n' "$COOLDOWN_SECONDS"
  printf 'thermal_ready_c=70.0\n'
  printf 'thermal_warning_c=95.0\n'
  printf 'thermal_abort_c=98.0\n'
  printf 'journal_baseline=%s\n' "$journal_baseline_log"
} >"$metadata"

apply_performance() {
  record_command "$NATIVE_PROFILE performance"
  "$NATIVE_PROFILE" performance >"$output/performance-apply.log" 2>&1 || return 1
  record_command "$NATIVE_PROFILE --verify"
  "$NATIVE_PROFILE" --verify >>"$output/performance-apply.log" 2>&1
}

apply_performance || die 'could not apply and verify native performance profile'

exec 8<"$PROFILE_LOCK_FILE" || die 'cannot open native profile lock'
flock -s -n 8 || die 'another native profile transition is active'
profile_lock_held=1
record_command "$NATIVE_PROFILE --verify"
"$NATIVE_PROFILE" --verify >"$output/native-profile-locked.log" 2>&1 || \
  die 'native performance profile was not healthy after locking'

if ! run_control probe "$output/co-probe-before.log" || \
  ! verify_probe_readback 0 "$output/co-probe-before.log"; then
  printf 'cold_reboot_required=yes\n' >>"$metadata"
  die 'initial CO probe was not eight zero values; no CO write was attempted'
fi

co_active=1
if ! run_control apply-minus-one "$output/co-apply.log" || \
  ! verify_probe_readback -1 "$output/co-apply.log"; then
  die 'CO -1 apply/readback failed'
fi

phase_peak_temp=-1
phase_warning=0
phase_kernel_fault=0
phase_sensor_failure=0
phase_sudo_failure=0
phase_profile_drift=0
previous_total=0
previous_idle=0
current_temp_raw=NA
current_temp_c=NA
current_power_w=NA
current_freq_avg=NA
current_freq_max=NA
current_freq_min=NA
current_policy_max=NA
current_hardware_max=NA
current_busy=NA
current_load1=NA
current_throttle=NA
current_total=0
current_idle=0
last_sudo_refresh=$SECONDS

sample_once() {
  local phase="$1" phase_log="$2" elapsed="$3" freq_stats busy_stats active_profile

  current_temp_raw="$(read_cpu_temp_raw 2>/dev/null || true)"
  if [[ "$current_temp_raw" =~ ^[0-9]+$ ]]; then
    current_temp_c="$(awk -v value="$current_temp_raw" 'BEGIN { printf "%.1f", value / 1000 }')"
  else
    current_temp_c=NA
    sensor_failure=1
    printf 'sensor_failure=k10temp\n' >>"$phase_log"
  fi

  current_power_w="$(read_power_w 2>/dev/null || true)"
  if ! [[ "$current_power_w" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    current_power_w=NA
    sensor_failure=1
    printf 'sensor_failure=power_sysfs\n' >>"$phase_log"
  fi

  freq_stats="$(read_freq_stats)"
  IFS=$'\t' read -r current_freq_avg current_freq_max current_freq_min \
    current_policy_max current_hardware_max <<<"$freq_stats"
  [ "$current_freq_avg" != NA ] || sensor_failure=1

  busy_stats="$(read_cpu_busy "$previous_total" "$previous_idle")"
  IFS=$'\t' read -r current_busy current_total current_idle <<<"$busy_stats"
  previous_total="$current_total"
  previous_idle="$current_idle"

  read -r current_load1 _ < /proc/loadavg || current_load1=NA
  current_throttle="$(read_throttle_count)"

  capture_journal "$phase_log" || true
  if [ "$SECONDS" -ge $((last_sudo_refresh + 60)) ]; then
    refresh_sudo_timestamp || printf 'sudo_refresh=FAIL\n' >>"$phase_log"
    last_sudo_refresh=$SECONDS
  fi
  active_profile="$(read_active_profile 2>/dev/null || true)"
  if [ "$active_profile" != "$PROFILE" ]; then
    profile_drift=1
    printf 'profile_drift=expected_%s_observed_%s\n' "$PROFILE" "${active_profile:-missing}" >>"$phase_log"
  fi

  if [[ "$current_temp_raw" =~ ^[0-9]+$ ]]; then
    [ "$current_temp_raw" -gt "$phase_peak_temp" ] && phase_peak_temp="$current_temp_raw"
    if [ "$current_temp_raw" -ge "$CPU_WARNING_MILLIC" ]; then
      phase_warning=1
      printf 'thermal_warning=tctl_%sC\n' "$current_temp_c" >>"$phase_log"
    fi
    if [ "$current_temp_raw" -ge "$CPU_ABORT_MILLIC" ]; then
      thermal_abort_seen=1
      printf 'thermal_abort=tctl_%sC\n' "$current_temp_c" >>"$phase_log"
    fi
  fi
  [ "$journal_fault_seen" -eq 0 ] || phase_kernel_fault=1
  [ "$sudo_unavailable" -eq 0 ] || phase_sudo_failure=1
  [ "$sensor_failure" -eq 0 ] || phase_sensor_failure=1
  [ "$profile_drift" -eq 0 ] || phase_profile_drift=1

  printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$phase" "$elapsed" "$current_temp_c" "$current_power_w" \
    "$current_freq_avg" "$current_freq_max" "$current_freq_min" "$current_policy_max" \
    "$current_hardware_max" "$current_busy" "$current_load1" "$current_throttle" \
    "$([ "$journal_fault_seen" -eq 0 ] && echo no || echo yes)" >>"$telemetry"
}

run_phase() {
  local phase="$1" duration="$2" cpus="$3" workers="$4"
  local phase_log="$output/$phase.log" readback_log="$output/$phase-co-probe.log"
  local phase_elapsed rc=0 status peak_temp_c=NA co_readback=FAIL
  local stop_requested=0

  phase_start_seconds=$SECONDS
  phase_peak_temp=-1
  phase_warning=0
  phase_kernel_fault=0
  phase_sensor_failure=0
  phase_sudo_failure=0
  phase_profile_drift=0
  previous_total=0
  previous_idle=0
  : >"$phase_log"
  record_command "setsid -- taskset --cpu-list $cpus stress-ng --cpu $workers --cpu-method matrixprod --verify --timeout ${duration}s --metrics-brief --times"
  setsid -- taskset --cpu-list "$cpus" stress-ng --cpu "$workers" \
    --cpu-method matrixprod --verify --timeout "${duration}s" --metrics-brief --times \
    >"$phase_log" 2>&1 &
  active_pid=$!

  while kill -0 "$active_pid" 2>/dev/null; do
    phase_elapsed=$((SECONDS - phase_start_seconds))
    sample_once "$phase" "$phase_log" "$phase_elapsed"
    if [ "$thermal_abort_seen" -eq 1 ] || [ "$phase_kernel_fault" -eq 1 ] || \
      [ "$phase_sensor_failure" -eq 1 ] || [ "$phase_sudo_failure" -eq 1 ] || \
      [ "$phase_profile_drift" -eq 1 ]; then
      stop_requested=1
      stop_workload
      break
    fi
    sleep "$SAMPLE_INTERVAL"
  done

  if wait "$active_pid"; then
    rc=0
  else
    rc=$?
  fi
  active_pid=""
  phase_elapsed=$((SECONDS - phase_start_seconds))
  sample_once "$phase" "$phase_log" "$phase_elapsed"

  record_command "sudo -n $CO_CONTROL probe"
  if sudo -n "$CO_CONTROL" probe >"$readback_log" 2>&1 && \
    verify_probe_readback -1 "$readback_log"; then
    co_readback=PASS
  fi

  if [ "$phase_peak_temp" -ge 0 ]; then
    peak_temp_c="$(awk -v value="$phase_peak_temp" 'BEGIN { printf "%.1f", value / 1000 }')"
  fi
  if [ "$co_readback" != PASS ]; then
    status=CO_READBACK_FAIL
  elif [ "$phase_kernel_fault" -eq 1 ]; then
    status=KERNEL_FAULT
  elif [ "$journal_unavailable" -eq 1 ]; then
    status=JOURNAL_UNAVAILABLE
  elif [ "$thermal_abort_seen" -eq 1 ]; then
    status=THERMAL_ABORT
  elif [ "$phase_sudo_failure" -eq 1 ]; then
    status=SUDO_REFRESH_FAIL
  elif [ "$phase_sensor_failure" -eq 1 ]; then
    status=SENSOR_READ_FAIL
  elif [ "$phase_profile_drift" -eq 1 ]; then
    status=PROFILE_DRIFT
  elif grep -Eiq 'verify.*(fail|error)|fail.*verif|verification.*fail' "$phase_log"; then
    status=VERIFY_FAIL
  elif [ "$rc" -ne 0 ] || [ "$stop_requested" -eq 1 ]; then
    status=FAIL
  elif [ "$phase_warning" -eq 1 ]; then
    status=PASS_THERMAL_WARNING
  else
    status=PASS
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$phase" "$status" "$phase_elapsed" "$peak_temp_c" "$([ "$phase_warning" -eq 1 ] && echo yes || echo no)" \
    "$co_readback" "$([ "$phase_kernel_fault" -eq 1 ] && echo yes || echo no)" "$(basename "$phase_log")" >>"$summary"
  printf '%s: %s, peak Tctl %s C, CO readback %s\n' "$phase" "$status" "$peak_temp_c" "$co_readback"
  [ "$status" = PASS ] || [ "$status" = PASS_THERMAL_WARNING ]
}

cooldown() {
  local phase_log="$output/cooldown.log" started=$SECONDS elapsed temp_raw

  : >"$phase_log"
  record_command "cooldown up to ${COOLDOWN_SECONDS}s below 70C"
  while [ $((SECONDS - started)) -lt "$COOLDOWN_SECONDS" ]; do
    elapsed=$((SECONDS - started))
    sample_once cooldown "$phase_log" "$elapsed"
    temp_raw="$current_temp_raw"
    if [ "$thermal_abort_seen" -eq 1 ] || [ "$journal_fault_seen" -eq 1 ] || \
      [ "$journal_unavailable" -eq 1 ] || [ "$sensor_failure" -eq 1 ] || \
      [ "$sudo_unavailable" -eq 1 ] || [ "$profile_drift" -eq 1 ]; then
      return 1
    fi
    if [[ "$temp_raw" =~ ^[0-9]+$ ]] && [ "$temp_raw" -lt "$CPU_READY_MILLIC" ]; then
      printf 'cooldown_elapsed_s=%s\n' "$elapsed" >>"$metadata"
      return 0
    fi
    sleep "$SAMPLE_INTERVAL"
  done
  printf 'cooldown_status=TIMEOUT\n' >>"$phase_log"
  return 1
}

printf 'output=%s\n' "$output"
if ! run_phase one-core "$ONE_CORE_SECONDS" 0 1; then
  die 'one-core CO workload did not pass'
fi
if ! cooldown; then
  die 'cooldown did not return the CPU below 70 C safely'
fi
if ! run_phase all-core "$ALL_CORE_SECONDS" 0-15 16; then
  die 'all-core CO workload did not pass'
fi

printf 'workloads=PASS\n' >>"$metadata"
exit 0
