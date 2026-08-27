#!/usr/bin/env bash

set -uo pipefail

# Compare managed Ryzenadj profiles without using forced OC voltage or clocks.

output=""
sample_interval="${BENCH_SAMPLE_INTERVAL:-2}"
one_core_seconds="${BENCH_OC_ONE_CORE_SECONDS:-60}"
all_core_seconds="${BENCH_OC_ALL_CORE_SECONDS:-480}"
cooldown_seconds="${BENCH_OC_COOLDOWN_SECONDS:-120}"
thermal_abort_millic="${BENCH_CPU_HARD_ABORT_MILLIC:-98000}"
thermal_warning_millic="${BENCH_CPU_LIMIT_MILLIC:-95000}"
profiles=(power-saver balanced performance)
profile_state_file=/run/ryzenadj-profile/active
profile_lock_file=/run/ryzenadj-profile/lock
selected_profile=""
active_pid=""
initial_profile=""
initial_ppd_profile=""
restored=0
restore_status=0
profile_lock_held=0

usage() {
  cat <<'EOF'
Usage: oc-curve.sh [options]

Run one-core and all-core measurements for the managed Ryzenadj profiles.
This does not use forced OC clocks, voltage, or curve-optimizer settings.

Options:
  --output DIR       write the run to DIR
  --sample SEC       telemetry interval (default: 2)
  --one-core SEC     one-core duration per profile (default: 60)
  --all-core SEC     all-core duration per profile (default: 480)
  --cooldown SEC     maximum cooldown between phases (default: 120)
  --profile NAME     run only one profile (including sustained-build)
  -h, --help         show this help
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 2
}

positive_integer() {
  [[ "$2" =~ ^[1-9][0-9]*$ ]] || die "$1 must be a positive integer: $2"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --output)
      [ "$#" -ge 2 ] || die '--output needs a value'
      output="$2"
      shift 2
      ;;
    --sample)
      [ "$#" -ge 2 ] || die '--sample needs a value'
      sample_interval="$2"
      shift 2
      ;;
    --one-core)
      [ "$#" -ge 2 ] || die '--one-core needs a value'
      one_core_seconds="$2"
      shift 2
      ;;
    --all-core)
      [ "$#" -ge 2 ] || die '--all-core needs a value'
      all_core_seconds="$2"
      shift 2
      ;;
    --cooldown)
      [ "$#" -ge 2 ] || die '--cooldown needs a value'
      cooldown_seconds="$2"
      shift 2
      ;;
    --profile)
      [ "$#" -ge 2 ] || die '--profile needs a value'
      selected_profile="$2"
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

positive_integer sample_interval "$sample_interval"
positive_integer one_core_seconds "$one_core_seconds"
positive_integer all_core_seconds "$all_core_seconds"
positive_integer cooldown_seconds "$cooldown_seconds"

if [ -n "$selected_profile" ]; then
  case "$selected_profile" in
    power-saver|balanced|performance|sustained-build)
      profiles=("$selected_profile")
      ;;
    *)
      die "unknown profile: $selected_profile"
      ;;
  esac
fi

command -v stress-ng >/dev/null 2>&1 || die 'stress-ng is not installed'
command -v taskset >/dev/null 2>&1 || die 'taskset is not installed'
command -v powerprofilesctl >/dev/null 2>&1 || die 'powerprofilesctl is not installed'
command -v sudo >/dev/null 2>&1 || die 'sudo is not installed'
command -v flock >/dev/null 2>&1 || die 'flock is not installed'

ac_online=0
for supply in /sys/class/power_supply/*; do
  [ -d "$supply" ] || continue
  [ -r "$supply/type" ] || continue
  [ "$(<"$supply/type")" = Mains ] || continue
  [ -r "$supply/online" ] && [ "$(<"$supply/online")" = 1 ] && ac_online=1
done
[ "$ac_online" -eq 1 ] || die 'OC sweep requires an online AC adapter'

workers="$(nproc)"
[ "$workers" -gt 0 ] || die 'nproc returned zero CPUs'
all_cpus="0-$((workers - 1))"

hwmon_cpu=""
hwmon_gpu=""
for hwmon in /sys/class/hwmon/hwmon*; do
  [ -r "$hwmon/name" ] || continue
  case "$(<"$hwmon/name")" in
    k10temp) hwmon_cpu="$hwmon" ;;
    amdgpu) hwmon_gpu="$hwmon" ;;
  esac
done
[ -n "$hwmon_cpu" ] || die 'k10temp hwmon was not found'

cpu_temp_file="$hwmon_cpu/temp1_input"
[ -r "$cpu_temp_file" ] || die 'Tctl input was not found'

throttle_files=()
for file in /sys/devices/system/cpu/cpu*/thermal_throttle/*_throttle_count; do
  [ -r "$file" ] && throttle_files+=("$file")
done

if [ -z "$output" ]; then
  output="/tmp/think14gryzen-oc-curve-$(date -u +%Y%m%dT%H%M%SZ)-$$"
fi
mkdir -p -- "$output" || die "cannot create output directory: $output"

telemetry="$output/telemetry.csv"
summary="$output/summary.tsv"
metadata="$output/metadata.txt"
commands="$output/commands.txt"
printf 'timestamp_utc,profile,phase,elapsed_s,tctl_c,apuppt_w,freq_avg_mhz,freq_max_any_mhz,freq_min_any_mhz,policy_max_mhz,hardware_max_mhz,cpu_busy_pct,load1,thermal_throttle_count,bottleneck\n' >"$telemetry"
printf 'profile\tphase\tstatus\telapsed_s\tpeak_tctl_c\tmean_freq_mhz\tpeak_freq_mhz\tpeak_apuppt_w\tthrottle_delta\tlog\n' >"$summary"
: >"$commands"

read_active_profile() {
  local value
  [ -r "$profile_state_file" ] || return 1
  value="$(<"$profile_state_file")"
  case "$value" in
    power-saver|balanced|performance|sustained-build) printf '%s\n' "$value" ;;
    *) return 1 ;;
  esac
}

release_profile_lock() {
  [ "$profile_lock_held" -eq 1 ] || return 0
  flock -u 8 2>/dev/null || true
  exec 8<&-
  profile_lock_held=0
}

acquire_profile_lock() {
  [ "$profile_lock_held" -eq 1 ] && return 0
  exec 8<"$profile_lock_file" || return 1
  if ! flock -s -n 8; then
    exec 8<&-
    return 1
  fi
  profile_lock_held=1
}

initial_ppd_profile="$(powerprofilesctl get 2>/dev/null || true)"
case "$initial_ppd_profile" in
  power-saver|balanced|performance) ;;
  *) die "cannot determine current power profile: ${initial_ppd_profile:-unknown}" ;;
esac
initial_profile="$(read_active_profile 2>/dev/null || true)"
case "$initial_profile" in
  power-saver|balanced|performance|sustained-build) ;;
  *) initial_profile="$initial_ppd_profile" ;;
esac

{
  printf 'started_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'host=%s\n' "$(hostname)"
  printf 'kernel='; uname -srvm
  printf 'cpu_model='; awk -F: '/^model name[[:space:]]*:/ && !found { sub(/^[[:space:]]*/, "", $2); print $2; found=1 } END { if (!found) print "unknown" }' /proc/cpuinfo
  printf 'cpu_threads=%s\n' "$workers"
  printf 'initial_power_profile=%s\n' "$initial_ppd_profile"
  printf 'initial_ryzenadj_profile=%s\n' "$initial_profile"
  printf 'ac_online=yes\n'
  printf 'sample_interval_s=%s\n' "$sample_interval"
  printf 'one_core_seconds=%s\n' "$one_core_seconds"
  printf 'all_core_seconds=%s\n' "$all_core_seconds"
  printf 'cooldown_seconds=%s\n' "$cooldown_seconds"
  printf 'thermal_warning_c=%.1f\n' "$(awk -v raw="$thermal_warning_millic" 'BEGIN { print raw / 1000 }')"
  printf 'thermal_abort_c=%.1f\n' "$(awk -v raw="$thermal_abort_millic" 'BEGIN { print raw / 1000 }')"
  printf 'cpu_ppt_w=NA\n'
  printf 'gpu_ppt_source=%s\n' "${hwmon_gpu:-unavailable}"
  printf 'thermal_throttle_counter_files=%s\n' "${#throttle_files[@]}"
  printf 'profiles=%s\n' "${profiles[*]}"
} >"$metadata"

cleanup_active() {
  if [ -n "$active_pid" ] && kill -0 "$active_pid" 2>/dev/null; then
    kill -TERM -- "-$active_pid" 2>/dev/null || kill -TERM "$active_pid" 2>/dev/null || true
    sleep 2
    kill -KILL -- "-$active_pid" 2>/dev/null || kill -KILL "$active_pid" 2>/dev/null || true
  fi
}

restore_profile() {
  [ "$restored" -eq 0 ] || return 0
  restored=1
  cleanup_active
  release_profile_lock
  if [ -n "$initial_profile" ]; then
    if ! sudo -n /run/current-system/sw/bin/ryzenadj-profile "$initial_profile" >>"$output/restore.log" 2>&1; then
      restore_status=1
    fi
    printf 'restored_profile=%s\n' "$initial_profile" >>"$metadata"
    printf 'restore_status=%s\n' "$([ "$restore_status" -eq 0 ] && echo PASS || echo FAIL)" >>"$metadata"
  fi
  return "$restore_status"
}

on_exit() {
  local rc=$?
  trap - EXIT
  restore_profile || rc=1
  exit "$rc"
}

trap on_exit EXIT
trap 'exit 130' INT TERM

read_temp_raw() {
  cat "$cpu_temp_file" 2>/dev/null || printf 'NA'
}

read_temp_c() {
  local raw
  raw="$(read_temp_raw)"
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    awk -v value="$raw" 'BEGIN { printf "%.1f", value / 1000 }'
  else
    printf 'NA'
  fi
}

read_apuppt_w() {
  local file raw
  [ -n "$hwmon_gpu" ] || { printf 'NA'; return; }
  for file in "$hwmon_gpu/power1_average" "$hwmon_gpu/power1_input"; do
    [ -r "$file" ] || continue
    raw="$(<"$file")"
    [[ "$raw" =~ ^[0-9]+$ ]] || continue
    awk -v value="$raw" 'BEGIN { printf "%.2f", value / 1000000 }'
    return
  done
  printf 'NA'
}

read_freq_stats() {
  local dir file value sum=0 count=0 max=0 min=9999999999
  for dir in /sys/devices/system/cpu/cpufreq/policy*; do
    [ -d "$dir" ] || continue
    file="$dir/cpuinfo_avg_freq"
    [ -r "$file" ] || file="$dir/scaling_cur_freq"
    [ -r "$file" ] || continue
    value="$(<"$file")"
    [[ "$value" =~ ^[0-9]+$ ]] || continue
    sum=$((sum + value))
    count=$((count + 1))
    [ "$value" -gt "$max" ] && max="$value"
    [ "$value" -lt "$min" ] && min="$value"
  done
  [ "$count" -gt 0 ] || { printf 'NA\tNA\tNA'; return; }
  awk -v sum="$sum" -v count="$count" -v max="$max" -v min="$min" \
    'BEGIN { printf "%.2f\t%.2f\t%.2f", sum / count / 1000, max / 1000, min / 1000 }'
}

read_clock_limits_mhz() {
  local dir policy_file hardware_file policy_max hardware_max
  local lowest_policy=0 highest_hardware=0 count=0

  for dir in /sys/devices/system/cpu/cpufreq/policy*; do
    [ -d "$dir" ] || continue
    policy_file="$dir/scaling_max_freq"
    hardware_file="$dir/amd_pstate_max_freq"
    [ -r "$hardware_file" ] || hardware_file="$dir/cpuinfo_max_freq"
    [ -r "$policy_file" ] || continue
    [ -r "$hardware_file" ] || continue
    policy_max="$(<"$policy_file")"
    hardware_max="$(<"$hardware_file")"
    [[ "$policy_max" =~ ^[0-9]+$ ]] || continue
    [[ "$hardware_max" =~ ^[0-9]+$ ]] || continue
    count=$((count + 1))
    if [ "$lowest_policy" -eq 0 ] || [ "$policy_max" -lt "$lowest_policy" ]; then
      lowest_policy="$policy_max"
    fi
    [ "$hardware_max" -gt "$highest_hardware" ] && highest_hardware="$hardware_max"
  done

  [ "$count" -gt 0 ] || { printf 'NA\tNA'; return 0; }
  awk -v policy="$lowest_policy" -v hardware="$highest_hardware" \
    'BEGIN { printf "%.2f\t%.2f", policy / 1000, hardware / 1000 }'
}

read_busy_pct() {
  local previous_total="${1:-0}" previous_idle="${2:-0}"
  local user nice system idle iowait irq softirq steal guest guest_nice
  local total idle_all delta_total delta_idle
  read -r _ user nice system idle iowait irq softirq steal guest guest_nice \
    < <(awk '/^cpu / { print; exit }' /proc/stat)
  total=$((user + nice + system + idle + iowait + irq + softirq + steal))
  idle_all=$((idle + iowait))
  if [ "$previous_total" -gt 0 ] && [ "$total" -gt "$previous_total" ]; then
    delta_total=$((total - previous_total))
    delta_idle=$((idle_all - previous_idle))
    awk -v total="$delta_total" -v idle="$delta_idle" \
      'BEGIN { printf "%.1f", (total - idle) * 100 / total }'
  else
    printf 'NA'
  fi
  printf '\t%s\t%s' "$total" "$idle_all"
}

read_throttle_count() {
  local file value total=0
  [ "${#throttle_files[@]}" -gt 0 ] || { printf 'NA'; return 0; }
  for file in "${throttle_files[@]}"; do
    value="$(<"$file")"
    [[ "$value" =~ ^[0-9]+$ ]] && total=$((total + value))
  done
  printf '%s' "$total"
}

sample_once() {
  local profile="$1" phase="$2" phase_start="$3" elapsed="$4"
  local previous_total="${5:-0}" previous_idle="${6:-0}"
  local tctl_raw tctl_c apuppt freq_avg freq_max freq_min policy_max hardware_max busy load1 throttle bottleneck
  local busy_total busy_idle
  tctl_raw="$(read_temp_raw)"
  tctl_c="$(read_temp_c)"
  apuppt="$(read_apuppt_w)"
  read -r freq_avg freq_max freq_min <<<"$(read_freq_stats)"
  read -r policy_max hardware_max <<<"$(read_clock_limits_mhz)"
  read -r busy busy_total busy_idle <<<"$(read_busy_pct "$previous_total" "$previous_idle")"
  load1="$(awk '{ print $1 }' /proc/loadavg)"
  throttle="$(read_throttle_count)"
  bottleneck='none-observed'
  if [[ "$tctl_raw" =~ ^[0-9]+$ ]] && [ "$tctl_raw" -ge "$thermal_warning_millic" ]; then
    bottleneck='thermal-near-limit'
  fi
  if [[ "$policy_max" != 'NA' && "$hardware_max" != 'NA' ]] && \
    awk -v policy="$policy_max" -v hardware="$hardware_max" 'BEGIN { exit !(policy < hardware) }'; then
    if [ "$bottleneck" = none-observed ]; then
      bottleneck='policy-cap'
    else
      bottleneck="$bottleneck+policy-cap"
    fi
  fi
  printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$profile" "$phase" "$elapsed" \
    "$tctl_c" "$apuppt" "$freq_avg" "$freq_max" "$freq_min" "$policy_max" "$hardware_max" \
    "$busy" "$load1" "$throttle" "$bottleneck" >>"$telemetry"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' \
    "$tctl_raw" "$tctl_c" "$apuppt" "$freq_avg" "$freq_max" "$freq_min" \
    "$policy_max" "$hardware_max" "$busy" "$load1" "$throttle" "$bottleneck" "$phase_start" "$elapsed" \
    "$busy_total" "$busy_idle"
}

cooldown() {
  local started=$SECONDS temp_raw elapsed
  while [ $((SECONDS - started)) -lt "$cooldown_seconds" ]; do
    temp_raw="$(read_temp_raw)"
    if [[ "$temp_raw" =~ ^[0-9]+$ ]] && [ "$temp_raw" -le 55000 ]; then
      break
    fi
    sleep "$sample_interval"
  done
  elapsed=$((SECONDS - started))
  printf 'cooldown=%ss\n' "$elapsed" >>"$commands"
}

apply_profile() {
  local profile="$1" ppd_profile="$1"
  case "$profile" in
    sustained-build) ppd_profile=performance ;;
  esac
  printf 'profile=%s ppd_profile=%s\n' "$profile" "$ppd_profile" >>"$commands"
  sudo -n /run/current-system/sw/bin/ryzenadj-profile "$profile" \
    >>"$output/${profile}.apply.log" 2>&1 || return 1
  sleep 3
  [ "$(powerprofilesctl get 2>/dev/null || true)" = "$ppd_profile" ] || return 1
  [ "$(read_active_profile 2>/dev/null || true)" = "$profile" ] || return 1
  acquire_profile_lock || return 1
  return 0
}

run_phase() {
  local profile="$1" phase="$2" duration="$3" cpus="$4" cpu_workers="$5"
  local log="$output/${profile}-${phase}.log"
  local phase_start_epoch="$(date +%s)" phase_start_seconds="$SECONDS"
  local peak_temp=-1 freq_sum=0 freq_samples=0 peak_freq=0 peak_power=0
  local throttle_before throttle_after throttle_delta=NA thermal_abort=0 profile_drift=0 rc status elapsed
  local metrics tctl_raw tctl_c apuppt freq_avg freq_max freq_min policy_max hardware_max busy load1 throttle bottleneck _
  local active_profile
  local previous_total=0 previous_idle=0 next_total next_idle

  printf '%s command=taskset --cpu-list %s stress-ng --cpu %s --cpu-method matrixprod --verify --timeout %ss --metrics-brief --times\n' \
    "$phase" "$cpus" "$cpu_workers" "$duration" >>"$commands"
  : >"$log"
  throttle_before="$(read_throttle_count)"
  setsid -- taskset --cpu-list "$cpus" stress-ng --cpu "$cpu_workers" \
    --cpu-method matrixprod --verify --timeout "${duration}s" --metrics-brief --times \
    >"$log" 2>&1 &
  active_pid=$!

  while kill -0 "$active_pid" 2>/dev/null; do
    elapsed=$((SECONDS - phase_start_seconds))
    metrics="$(sample_once "$profile" "$phase" "$phase_start_epoch" "$elapsed" "$previous_total" "$previous_idle")"
    IFS=$'\t' read -r tctl_raw tctl_c apuppt freq_avg freq_max freq_min policy_max hardware_max busy load1 throttle bottleneck _ _ next_total next_idle <<<"$metrics"
    previous_total="$next_total"
    previous_idle="$next_idle"
    active_profile="$(read_active_profile 2>/dev/null || true)"
    if [ "$active_profile" != "$profile" ]; then
      profile_drift=1
      printf 'profile_drift=expected_%s_observed_%s\n' "$profile" "${active_profile:-missing}" >>"$log"
      kill -TERM -- "-$active_pid" 2>/dev/null || kill -TERM "$active_pid" 2>/dev/null || true
    fi
    if [[ "$tctl_raw" =~ ^[0-9]+$ ]]; then
      [ "$tctl_raw" -gt "$peak_temp" ] && peak_temp="$tctl_raw"
      if [ "$tctl_raw" -ge "$thermal_abort_millic" ]; then
        thermal_abort=1
        printf 'thermal_abort=tctl_%sC\n' "$tctl_c" >>"$log"
        kill -TERM -- "-$active_pid" 2>/dev/null || kill -TERM "$active_pid" 2>/dev/null || true
        sleep 2
        kill -KILL -- "-$active_pid" 2>/dev/null || kill -KILL "$active_pid" 2>/dev/null || true
      fi
    fi
    if [[ "$freq_avg" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      freq_sum="$(awk -v sum="$freq_sum" -v value="$freq_avg" 'BEGIN { printf "%.4f", sum + value }')"
      freq_samples=$((freq_samples + 1))
    fi
    if [[ "$freq_max" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      awk -v value="$freq_max" -v peak="$peak_freq" 'BEGIN { exit !(value > peak) }' && peak_freq="$freq_max"
    fi
    if [[ "$apuppt" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      awk -v value="$apuppt" -v peak="$peak_power" 'BEGIN { exit !(value > peak) }' && peak_power="$apuppt"
    fi
    [ "$thermal_abort" -eq 1 ] || [ "$profile_drift" -eq 1 ] && break
    sleep "$sample_interval"
  done

  if wait "$active_pid"; then
    rc=0
  else
    rc=$?
  fi
  active_pid=""
  elapsed=$((SECONDS - phase_start_seconds))
  throttle_after="$(read_throttle_count)"
  if [ "$profile_drift" -eq 1 ]; then
    status='PROFILE_DRIFT'
  elif [ "$thermal_abort" -eq 1 ]; then
    status='THERMAL_ABORT'
  elif [ "$rc" -eq 0 ]; then
    if [ "$peak_temp" -ge "$thermal_warning_millic" ]; then
      status='PASS_THERMAL_LIMITED'
    else
      status='PASS'
    fi
  else
    status='FAIL'
  fi
  if [ "$peak_temp" -ge 0 ]; then
    tctl_c="$(awk -v raw="$peak_temp" 'BEGIN { printf "%.1f", raw / 1000 }')"
  else
    tctl_c='NA'
  fi
  if [ "$freq_samples" -gt 0 ]; then
    freq_avg="$(awk -v sum="$freq_sum" -v count="$freq_samples" 'BEGIN { printf "%.2f", sum / count }')"
  else
    freq_avg='NA'
  fi
  if [[ "$throttle_before" =~ ^[0-9]+$ && "$throttle_after" =~ ^[0-9]+$ ]]; then
    throttle_delta=$((throttle_after - throttle_before))
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$profile" "$phase" "$status" "$elapsed" "$tctl_c" "$freq_avg" \
    "$peak_freq" "$peak_power" "$throttle_delta" "$(basename "$log")" >>"$summary"
  printf '%s/%s: %s, peak %s C, mean %s MHz, peak %s MHz, peak APU PPT %s W\n' \
    "$profile" "$phase" "$status" "$tctl_c" "$freq_avg" "$peak_freq" "$peak_power"
  [ "$status" = PASS ] || [ "$status" = PASS_THERMAL_LIMITED ]
}

printf 'output=%s\n' "$output"
run_failed=0
for profile in "${profiles[@]}"; do
  release_profile_lock
  cooldown
  if ! apply_profile "$profile"; then
    printf '%s\tapply\tFAIL\t0\tNA\tNA\tNA\tNA\tNA\t%s.apply.log\n' \
      "$profile" "$profile" >>"$summary"
    printf 'error: could not apply profile %s\n' "$profile" >&2
    exit 1
  fi
  if ! run_phase "$profile" one-core "$one_core_seconds" 0 1; then
    run_failed=1
    break
  fi
  cooldown
  if ! run_phase "$profile" all-core "$all_core_seconds" "$all_cpus" "$workers"; then
    run_failed=1
    break
  fi
done

printf 'summary=%s\ntelemetry=%s\nmetadata=%s\n' "$summary" "$telemetry" "$metadata"
[ "$run_failed" -eq 0 ] || exit 1
exit 0
