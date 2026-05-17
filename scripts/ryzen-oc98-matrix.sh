#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: ryzen-oc98-matrix.sh [--root DIR]
EOF
}

ROOT=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --root)
      if [ "$#" -lt 2 ]; then
        usage
        exit 2
      fi
      ROOT="$2"
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_SCRIPT="${SCRIPT_DIR}/ryzen-test.sh"
RYZENADJ_BIN="/run/current-system/sw/bin/ryzenadj"
RYZENADJ_PROFILE_BIN="/run/current-system/sw/bin/ryzenadj-profile"
AC_RECOVERY_TIMEOUT_SEC=900
AC_STABILITY_INTERVAL_SEC=10
INITIAL_IDLE_SEC=180
SUSTAINED_FALLBACK_COOLDOWN_SEC=180
BURST_FALLBACK_COOLDOWN_SEC=120
RYZEN_TEST_TCTL_FALLBACK_C_VALUE="98"

RESULTS_HEADER=$'attempt_id\tstage\tprofile_name\tduration_sec\tstapm_limit\tfast_limit\tslow_limit\ttctl_limit\tskin_limit\tvrm_current\tvrmmax_current\trequested_duration_sec\tcompleted_duration_sec\trun_status\tabort_reason\tinvalid_reason\tthroughput_bogo_ops_per_sec\tavg_freq_avg_mhz\tmax_freq_avg_mhz\ttdie_max_c\ttctl_value_max_c\tskin_value_max_c\tskin_hit\tbattery_discharging_observed\tdmesg_hard_issue\tac_online_before\tac_online_after\tbattery_status_before\tbattery_status_after\tlog_path\tcanonical_for_selection'
SUMMARY_HEADER=$'profile_name\tstapm_limit\tfast_limit\tslow_limit\ttctl_limit\tskin_limit\tvrm_current\tvrmmax_current\tstatus_300\tthroughput_300\tavg_freq_avg_mhz_300\tmax_freq_avg_mhz_300\ttdie_max_c_300\tskin_hit_300\tstatus_600\tthroughput_600\tavg_freq_avg_mhz_600\tmax_freq_avg_mhz_600\ttdie_max_c_600\tskin_hit_600\tburst_status\tburst_throughput\trejection_reason\trecommendation_rank'

RUNNER_LOG=""
RESULTS_TSV=""
SUMMARY_TSV=""
WINNER_TXT=""
ASKPASS_DIR=""
SUDO_KEEPALIVE_PID=""
ATTEMPT_COUNTER=0
IDLE_BASELINE_DONE="no"
IDLE_TEMP_C=""

LAST_RUN_STATUS=""
LAST_ABORT_REASON=""
LAST_INVALID_REASON=""
LAST_LOG_PATH=""
LAST_COMPLETED_DURATION=""
LAST_RUN_START_EPOCH=""
LAST_DMESG_HARD_ISSUE="no"
LAST_HARD_STOP_REASON=""
LAST_CANONICAL_FOR_SELECTION="no"
LAST_STAGE=""
LAST_PROFILE=""

SUSTAINED_FINAL_RECOMMENDATION=""
BURST_FINAL_RECOMMENDATION=""

SUSTAINED_PROFILES=(P44 P46 P48 P50 P52 P54 P56 P58)
SUSTAINED_ASCEND_PROFILES=(P48 P50 P52 P54 P56 P58)
BURST_PROFILES=(B58 B60 B62 B65)
ALL_PROFILES=(P44 P46 P48 P50 P52 P54 P56 P58 B58 B60 B62 B65)

cleanup() {
  if [ -n "${SUDO_KEEPALIVE_PID}" ]; then
    kill "${SUDO_KEEPALIVE_PID}" 2>/dev/null || true
  fi
  if [ -n "${ASKPASS_DIR}" ] && [ -d "${ASKPASS_DIR}" ]; then
    rm -rf "${ASKPASS_DIR}"
  fi
}

trap cleanup EXIT

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

log() {
  printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "${RUNNER_LOG}"
}

float_gt() {
  awk -v a="$1" -v b="$2" 'BEGIN { exit !(a > b) }'
}

float_ge() {
  awk -v a="$1" -v b="$2" 'BEGIN { exit !(a >= b) }'
}

float_lt() {
  awk -v a="$1" -v b="$2" 'BEGIN { exit !(a < b) }'
}

float_le() {
  awk -v a="$1" -v b="$2" 'BEGIN { exit !(a <= b) }'
}

float_mul() {
  awk -v a="$1" -v b="$2" 'BEGIN { printf "%.6f", a * b }'
}

read_cpu_temp() {
  local hwmon name temp
  for hwmon in /sys/class/hwmon/hwmon*/; do
    name="$(cat "${hwmon}name" 2>/dev/null || true)"
    if [ "${name}" = "k10temp" ]; then
      temp="$(cat "${hwmon}temp2_input" 2>/dev/null || cat "${hwmon}temp1_input" 2>/dev/null || true)"
      if [ -n "${temp}" ]; then
        awk -v v="${temp}" 'BEGIN { printf "%.1f", v / 1000 }'
        return
      fi
    fi
  done
  echo "N/A"
}

read_ac_online() {
  local supply type online found=0
  for supply in /sys/class/power_supply/*; do
    [ -d "${supply}" ] || continue
    type="$(cat "${supply}/type" 2>/dev/null || true)"
    if [ "${type}" = "Mains" ]; then
      found=1
      online="$(cat "${supply}/online" 2>/dev/null || echo 0)"
      if [ "${online}" = "1" ]; then
        echo "yes"
        return
      fi
    fi
  done
  if [ "${found}" -eq 1 ]; then
    echo "no"
  else
    echo "unknown"
  fi
}

read_battery_status() {
  local supply type status found=0
  local statuses=()
  local joined=""
  for supply in /sys/class/power_supply/*; do
    [ -d "${supply}" ] || continue
    type="$(cat "${supply}/type" 2>/dev/null || true)"
    if [ "${type}" = "Battery" ]; then
      found=1
      status="$(cat "${supply}/status" 2>/dev/null || echo unknown)"
      statuses+=("${status}")
    fi
  done
  if [ "${found}" -eq 0 ]; then
    echo "unknown"
    return
  fi
  for status in "${statuses[@]}"; do
    if [ -n "${joined}" ]; then
      joined="${joined},${status}"
    else
      joined="${status}"
    fi
  done
  echo "${joined}"
}

battery_is_discharging() {
  local supply type status
  for supply in /sys/class/power_supply/*; do
    [ -d "${supply}" ] || continue
    type="$(cat "${supply}/type" 2>/dev/null || true)"
    if [ "${type}" = "Battery" ]; then
      status="$(cat "${supply}/status" 2>/dev/null || echo unknown)"
      if [ "${status}" = "Discharging" ]; then
        return 0
      fi
    fi
  done
  return 1
}

append_tsv_line() {
  local file="$1"
  shift
  local value first=1
  {
    for value in "$@"; do
      if [ "${first}" -eq 1 ]; then
        printf '%s' "${value}"
        first=0
      else
        printf '\t%s' "${value}"
      fi
    done
    printf '\n'
  } >> "${file}"
}

ensure_root() {
  if [ -z "${ROOT}" ]; then
    ROOT="$(mktemp -d "/var/tmp/ryzen-oc98-$(date +%Y%m%d-%H%M%S)-XXXXXX")"
  elif [ -e "${ROOT}" ]; then
    if [ -e "${ROOT}/oc98_results.tsv" ] || [ -e "${ROOT}/oc98_summary.tsv" ] || [ -e "${ROOT}/oc98_winner.txt" ] || [ -e "${ROOT}/runner.log" ]; then
      echo "Refusing to reuse existing result root: ${ROOT}" >&2
      exit 1
    fi
    mkdir -p "${ROOT}"
  else
    mkdir -p "${ROOT}"
  fi

  RUNNER_LOG="${ROOT}/runner.log"
  RESULTS_TSV="${ROOT}/oc98_results.tsv"
  SUMMARY_TSV="${ROOT}/oc98_summary.tsv"
  WINNER_TXT="${ROOT}/oc98_winner.txt"
  : > "${RUNNER_LOG}"
  printf '%s\n' "${RESULTS_HEADER}" > "${RESULTS_TSV}"
}

ensure_sudo() {
  if sudo -n true >/dev/null 2>&1; then
    return
  fi
  need_cmd rofi
  ASKPASS_DIR="$(mktemp -d)"
  printf '%s\n' '#!/usr/bin/env bash' 'exec rofi -dmenu -password -p "sudo for ryzen oc98 matrix"' > "${ASKPASS_DIR}/askpass"
  chmod 700 "${ASKPASS_DIR}/askpass"
  export SUDO_ASKPASS="${ASKPASS_DIR}/askpass"
  sudo -A -v
}

start_sudo_keepalive() {
  (
    while true; do
      if ! sudo -n -v >/dev/null 2>&1; then
        break
      fi
      sleep 30
    done
  ) &
  SUDO_KEEPALIVE_PID=$!
}

ensure_dmesg_since_supported() {
  local since_time
  since_time="$(date -d "@$(date +%s)" '+%F %T')"
  if ! sudo dmesg -T --since "${since_time}" >/dev/null 2>&1; then
    build_summary_table
    write_failure_report "failure" "dmesg_since_unsupported" "since_time=${since_time}"
    exit 1
  fi
}

class_reason_for_stage() {
  local profile_name="$1"
  local stage="$2"
  local status abort_reason invalid_reason
  status="$(result_value_for_display "${profile_name}" "${stage}" run_status)"
  abort_reason="$(result_value_for_display "${profile_name}" "${stage}" abort_reason)"
  invalid_reason="$(result_value_for_display "${profile_name}" "${stage}" invalid_reason)"
  case "${status}" in
    pass)
      echo "pass"
      ;;
    invalid)
      echo "invalid:${invalid_reason:-unknown}"
      ;;
    fail)
      if [ -n "${abort_reason}" ] && [ "${abort_reason}" != "none" ]; then
        echo "fail:${abort_reason}"
      else
        echo "fail"
      fi
      ;;
    *)
      echo "not_tested"
      ;;
  esac
}

best_reason_for_profile() {
  local profile_name="$1"
  local reason
  reason="$(class_reason_for_stage "${profile_name}" sustained_600)"
  if [ "${reason}" != "not_tested" ]; then
    echo "${reason}"
    return
  fi
  reason="$(class_reason_for_stage "${profile_name}" sustained_300)"
  if [ "${reason}" != "not_tested" ]; then
    echo "${reason}"
    return
  fi
  reason="$(class_reason_for_stage "${profile_name}" burst_60)"
  echo "${reason}"
}

detect_bottleneck() {
  if awk -F'\t' 'NR > 1 && $15 == "skin_limit" { found = 1 } END { exit !found }' "${RESULTS_TSV}"; then
    echo "skin/STT"
  elif awk -F'\t' 'NR > 1 && $15 == "tdie_limit" { found = 1 } END { exit !found }' "${RESULTS_TSV}"; then
    echo "Tdie"
  elif awk -F'\t' 'NR > 1 && $25 == "yes" { found = 1 } END { exit !found }' "${RESULTS_TSV}"; then
    echo "hardware/stability"
  elif awk -F'\t' 'NR > 1 && $14 == "invalid" { found = 1 } END { exit !found }' "${RESULTS_TSV}"; then
    echo "power validity"
  else
    echo "unknown"
  fi
}

write_failure_report() {
  local status_value="$1"
  local reason="$2"
  local details="${3:-}"
  local profile_name
  {
    echo "status=${status_value}"
    echo "reason=${reason}"
    if [ -n "${details}" ]; then
      echo "details=${details}"
    fi
    echo "results_root=${ROOT}"
    echo "no_safe_98c_oc_sustained_candidate_found=yes"
    echo "bottleneck=$(detect_bottleneck)"
    echo "p44_95_daily_profile=remain_only_recommended_sustained_profile"
    echo
    echo "Tested sustained profiles:"
    for profile_name in "${SUSTAINED_PROFILES[@]}"; do
      printf '%s: %s\n' "${profile_name}" "$(best_reason_for_profile "${profile_name}")"
    done
    echo
    echo "Burst results:"
    for profile_name in "${BURST_PROFILES[@]}"; do
      printf '%s: %s\n' "${profile_name}" "$(best_reason_for_profile "${profile_name}")"
    done
    echo
    echo "burst_oc_winner=${BURST_FINAL_RECOMMENDATION:-none}"
    if [ -n "${BURST_FINAL_RECOMMENDATION}" ]; then
      echo "burst_ryzenadj_command=$(profile_command_string "${BURST_FINAL_RECOMMENDATION}")"
      echo "burst_throughput_bogo_ops_per_sec=$(canonical_result_value "${BURST_FINAL_RECOMMENDATION}" burst_60 throughput_bogo_ops_per_sec)"
      echo "burst_avg_freq_avg_mhz=$(canonical_result_value "${BURST_FINAL_RECOMMENDATION}" burst_60 avg_freq_avg_mhz)"
      echo "burst_max_freq_avg_mhz=$(canonical_result_value "${BURST_FINAL_RECOMMENDATION}" burst_60 max_freq_avg_mhz)"
      echo "burst_tdie_max_c=$(canonical_result_value "${BURST_FINAL_RECOMMENDATION}" burst_60 tdie_max_c)"
    fi
  } > "${WINNER_TXT}"
}

write_success_report() {
  local sustained_profile="$1"
  local burst_profile="${2:-}"
  local profile_name
  {
    echo "status=success"
    echo "results_root=${ROOT}"
    echo "sustained_oc_winner=${sustained_profile}"
    echo "sustained_ryzenadj_command=$(profile_command_string "${sustained_profile}")"
    echo
    echo "300s evidence:"
    echo "throughput_bogo_ops_per_sec=$(canonical_result_value "${sustained_profile}" sustained_300 throughput_bogo_ops_per_sec)"
    echo "avg_freq_avg_mhz=$(canonical_result_value "${sustained_profile}" sustained_300 avg_freq_avg_mhz)"
    echo "max_freq_avg_mhz=$(canonical_result_value "${sustained_profile}" sustained_300 max_freq_avg_mhz)"
    echo "tdie_max_c=$(canonical_result_value "${sustained_profile}" sustained_300 tdie_max_c)"
    echo "skin_value_max_c=$(canonical_result_value "${sustained_profile}" sustained_300 skin_value_max_c)"
    echo
    echo "600s evidence:"
    echo "throughput_bogo_ops_per_sec=$(canonical_result_value "${sustained_profile}" sustained_600 throughput_bogo_ops_per_sec)"
    echo "avg_freq_avg_mhz=$(canonical_result_value "${sustained_profile}" sustained_600 avg_freq_avg_mhz)"
    echo "max_freq_avg_mhz=$(canonical_result_value "${sustained_profile}" sustained_600 max_freq_avg_mhz)"
    echo "tdie_max_c=$(canonical_result_value "${sustained_profile}" sustained_600 tdie_max_c)"
    echo "skin_value_max_c=$(canonical_result_value "${sustained_profile}" sustained_600 skin_value_max_c)"
    echo
    echo "reason_selected=best 98C sustained candidate after 300s ladder and 600s confirmation"
    echo
    echo "Rejected sustained profiles:"
    for profile_name in "${SUSTAINED_PROFILES[@]}"; do
      if [ "${profile_name}" = "${sustained_profile}" ]; then
        continue
      fi
      printf '%s: %s\n' "${profile_name}" "$(best_reason_for_profile "${profile_name}")"
    done
    echo
    echo "burst_oc_winner=${burst_profile:-none}"
    if [ -n "${burst_profile}" ]; then
      echo "burst_ryzenadj_command=$(profile_command_string "${burst_profile}")"
      echo "burst_throughput_bogo_ops_per_sec=$(canonical_result_value "${burst_profile}" burst_60 throughput_bogo_ops_per_sec)"
      echo "burst_avg_freq_avg_mhz=$(canonical_result_value "${burst_profile}" burst_60 avg_freq_avg_mhz)"
      echo "burst_max_freq_avg_mhz=$(canonical_result_value "${burst_profile}" burst_60 max_freq_avg_mhz)"
      echo "burst_tdie_max_c=$(canonical_result_value "${burst_profile}" burst_60 tdie_max_c)"
    fi
    echo
    echo "bottleneck=$(detect_bottleneck)"
    echo "recommendation_1=Daily safe profile remains P44 @95C unless user explicitly wants OC."
    echo "recommendation_2=OC sustained profile is only for plugged-in performance mode."
    echo "recommendation_3=Burst profile is benchmark-only."
  } > "${WINNER_TXT}"
}

wait_for_ac_stable_or_stop() {
  local deadline now ac_status battery_status
  deadline=$(( $(date +%s) + AC_RECOVERY_TIMEOUT_SEC ))
  while true; do
    ac_status="$(read_ac_online)"
    battery_status="$(read_battery_status)"
    log "AC stability check: ac_online=${ac_status} battery_status=${battery_status}"
    if [ "${ac_status}" = "yes" ] && ! battery_is_discharging; then
      sleep "${AC_STABILITY_INTERVAL_SEC}"
      ac_status="$(read_ac_online)"
      battery_status="$(read_battery_status)"
      log "AC stability recheck: ac_online=${ac_status} battery_status=${battery_status}"
      if [ "${ac_status}" = "yes" ] && ! battery_is_discharging; then
        return 0
      fi
    fi
    now="$(date +%s)"
    if [ "${now}" -ge "${deadline}" ]; then
      build_summary_table
      write_failure_report "failure_power_invalid" "ac_recovery_timeout" "ac_online=$(read_ac_online) battery_status=$(read_battery_status)"
      exit 1
    fi
    sleep "${AC_STABILITY_INTERVAL_SEC}"
  done
}

log_power_supply_status() {
  local battery
  echo "powerprofilesctl_get=$(powerprofilesctl get 2>/dev/null || true)" >> "${RUNNER_LOG}"
  echo "powerprofilesctl_list:" >> "${RUNNER_LOG}"
  powerprofilesctl list >> "${RUNNER_LOG}" 2>&1 || true
  echo "platform_profile=$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || true)" >> "${RUNNER_LOG}"
  echo "boost=$(cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true)" >> "${RUNNER_LOG}"
  echo "ac_online=$(cat /sys/class/power_supply/AC*/online 2>/dev/null || true)" >> "${RUNNER_LOG}"
  for battery in /sys/class/power_supply/*; do
    [ -f "${battery}/type" ] || continue
    if [ "$(cat "${battery}/type" 2>/dev/null || true)" = "Battery" ]; then
      echo "${battery} status=$(cat "${battery}/status" 2>/dev/null || true)" >> "${RUNNER_LOG}"
    fi
  done
}

run_preflight() {
  local profile platform governor mismatches
  log "Running performance preflight"
  sudo -v
  sudo powerprofilesctl set performance >/dev/null 2>&1 || true
  if [ -w /sys/firmware/acpi/platform_profile ]; then
    echo performance | sudo tee /sys/firmware/acpi/platform_profile >/dev/null 2>&1 || true
  fi
  for policy in /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference; do
    echo performance | sudo tee "${policy}" >/dev/null 2>&1 || true
  done

  profile="$(powerprofilesctl get 2>/dev/null || true)"
  platform="$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo unavailable)"
  governor="$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null || echo unavailable)"
  mismatches="$(grep -L '^performance$' /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference 2>/dev/null || true)"

  log_power_supply_status

  if [ "${profile}" != "performance" ]; then
    build_summary_table
    write_failure_report "failure" "preflight_failed" "powerprofilesctl=${profile}"
    exit 1
  fi
  if [ -e /sys/firmware/acpi/platform_profile ] && [ "${platform}" != "performance" ]; then
    build_summary_table
    write_failure_report "failure" "preflight_failed" "platform_profile=${platform}"
    exit 1
  fi
  if [ "${governor}" != "performance" ]; then
    build_summary_table
    write_failure_report "failure" "preflight_failed" "governor=${governor}"
    exit 1
  fi
  if [ -n "${mismatches}" ]; then
    build_summary_table
    write_failure_report "failure" "preflight_failed" "epp_mismatch=${mismatches}"
    exit 1
  fi
}

record_idle_baseline() {
  local temp
  log "Idling for ${INITIAL_IDLE_SEC} seconds before first run"
  sleep "${INITIAL_IDLE_SEC}"
  temp="$(read_cpu_temp)"
  if [ "${temp}" = "N/A" ]; then
    log "Idle baseline Tdie unavailable; fixed cooldown fallback will be used"
    IDLE_TEMP_C=""
  else
    IDLE_TEMP_C="${temp}"
    log "Idle baseline Tdie=${IDLE_TEMP_C}C"
  fi
  IDLE_BASELINE_DONE="yes"
}

wait_for_cooldown() {
  local run_kind="$1"
  local fallback_sleep current threshold
  if [ "${run_kind}" = "burst" ]; then
    fallback_sleep="${BURST_FALLBACK_COOLDOWN_SEC}"
  else
    fallback_sleep="${SUSTAINED_FALLBACK_COOLDOWN_SEC}"
  fi

  if [ -z "${IDLE_TEMP_C}" ]; then
    log "Tdie unavailable; sleeping ${fallback_sleep}s before next ${run_kind} run"
    sleep "${fallback_sleep}"
    return 0
  fi

  threshold="$(awk -v idle="${IDLE_TEMP_C}" 'BEGIN { t = idle + 3; if (t < 52.0) t = 52.0; printf "%.1f", t }')"
  log "Waiting for cooldown to <= ${threshold}C"
  while true; do
    current="$(read_cpu_temp)"
    log "Cooldown check: current=${current}C threshold=${threshold}C"
    if [ "${current}" = "N/A" ]; then
      log "Tdie unavailable during cooldown; sleeping ${fallback_sleep}s"
      sleep "${fallback_sleep}"
      return 0
    fi
    if float_le "${current}" "${threshold}"; then
      return 0
    fi
    sleep 15
  done
}

prepare_for_run() {
  local run_kind="$1"
  wait_for_ac_stable_or_stop
  run_preflight
  if [ "${IDLE_BASELINE_DONE}" != "yes" ]; then
    record_idle_baseline
  else
    wait_for_cooldown "${run_kind}"
  fi
}

set_profile_values() {
  PROFILE_NAME="$1"
  case "${PROFILE_NAME}" in
    P44)
      STAPM=44000; FAST=60000; SLOW=56000; TCTL=98; SKIN=43; VRM=90000; VRMMAX=110000 ;;
    P46)
      STAPM=46000; FAST=62000; SLOW=58000; TCTL=98; SKIN=43; VRM=90000; VRMMAX=110000 ;;
    P48)
      STAPM=48000; FAST=64000; SLOW=60000; TCTL=98; SKIN=43; VRM=90000; VRMMAX=110000 ;;
    P50)
      STAPM=50000; FAST=66000; SLOW=62000; TCTL=98; SKIN=43; VRM=90000; VRMMAX=110000 ;;
    P52)
      STAPM=52000; FAST=68000; SLOW=64000; TCTL=98; SKIN=43; VRM=95000; VRMMAX=115000 ;;
    P54)
      STAPM=54000; FAST=70000; SLOW=65000; TCTL=98; SKIN=43; VRM=95000; VRMMAX=115000 ;;
    P56)
      STAPM=56000; FAST=72000; SLOW=67000; TCTL=98; SKIN=43; VRM=100000; VRMMAX=120000 ;;
    P58)
      STAPM=58000; FAST=74000; SLOW=69000; TCTL=98; SKIN=43; VRM=100000; VRMMAX=120000 ;;
    B58)
      STAPM=58000; FAST=76000; SLOW=70000; TCTL=98; SKIN=44; VRM=105000; VRMMAX=125000 ;;
    B60)
      STAPM=60000; FAST=78000; SLOW=72000; TCTL=98; SKIN=44; VRM=110000; VRMMAX=130000 ;;
    B62)
      STAPM=62000; FAST=80000; SLOW=74000; TCTL=98; SKIN=44; VRM=115000; VRMMAX=135000 ;;
    B65)
      STAPM=65000; FAST=82000; SLOW=76000; TCTL=98; SKIN=44; VRM=120000; VRMMAX=140000 ;;
    *)
      echo "Unknown profile: ${PROFILE_NAME}" >&2
      exit 2
      ;;
  esac
}

profile_command_string() {
  set_profile_values "$1"
  printf 'sudo ryzenadj --stapm-limit=%s --fast-limit=%s --slow-limit=%s --tctl-temp=%s --apu-skin-temp=%s --vrm-current=%s --vrmmax-current=%s --max-performance' \
    "${STAPM}" "${FAST}" "${SLOW}" "${TCTL}" "${SKIN}" "${VRM}" "${VRMMAX}"
}

lower_sustained_profile_step() {
  case "$1" in
    P58) echo P56 ;;
    P56) echo P54 ;;
    P54) echo P52 ;;
    P52) echo P50 ;;
    P50) echo P48 ;;
    P48) echo P46 ;;
    P46) echo P44 ;;
    *) echo "" ;;
  esac
}

apply_profile() {
  local profile_name="$1"
  set_profile_values "${profile_name}"
  log "Applying ${profile_name}: STAPM=${STAPM} FAST=${FAST} SLOW=${SLOW} TCTL=${TCTL} SKIN=${SKIN} VRM=${VRM} VRMMAX=${VRMMAX}"
  sudo "${RYZENADJ_BIN}" \
    --stapm-limit="${STAPM}" \
    --fast-limit="${FAST}" \
    --slow-limit="${SLOW}" \
    --tctl-temp="${TCTL}" \
    --apu-skin-temp="${SKIN}" \
    --vrm-current="${VRM}" \
    --vrmmax-current="${VRMMAX}" \
    --max-performance 2>&1 | tee -a "${RUNNER_LOG}"
}

summary_value() {
  local log_path="$1"
  local key="$2"
  awk -F= -v key="SUMMARY ${key}" '$1 == key { print $2 }' "${log_path}" | tail -1
}

latest_result_value() {
  local profile_name="$1"
  local stage="$2"
  local column="$3"
  awk -F'\t' -v profile_name="${profile_name}" -v stage="${stage}" -v column="${column}" '
    NR == 1 {
      for (i = 1; i <= NF; i++) {
        if ($i == column) {
          col = i
        }
      }
      next
    }
    $2 == stage && $3 == profile_name {
      value = $col
    }
    END {
      print value
    }
  ' "${RESULTS_TSV}"
}

canonical_result_value() {
  local profile_name="$1"
  local stage="$2"
  local column="$3"
  awk -F'\t' -v profile_name="${profile_name}" -v stage="${stage}" -v column="${column}" '
    NR == 1 {
      for (i = 1; i <= NF; i++) {
        if ($i == column) {
          col = i
        }
        if ($i == "canonical_for_selection") {
          canonical_col = i
        }
      }
      next
    }
    $2 == stage && $3 == profile_name && $canonical_col == "yes" {
      value = $col
    }
    END {
      print value
    }
  ' "${RESULTS_TSV}"
}

result_value_for_display() {
  local profile_name="$1"
  local stage="$2"
  local column="$3"
  local value
  value="$(canonical_result_value "${profile_name}" "${stage}" "${column}")"
  if [ -n "${value}" ]; then
    printf '%s\n' "${value}"
  else
    latest_result_value "${profile_name}" "${stage}" "${column}"
  fi
}

set_last_run_fields() {
  LAST_RUN_STATUS="$1"
  LAST_ABORT_REASON="$2"
  LAST_INVALID_REASON="$3"
  LAST_LOG_PATH="$4"
  LAST_COMPLETED_DURATION="$5"
  LAST_RUN_START_EPOCH="$6"
  LAST_DMESG_HARD_ISSUE="$7"
  LAST_HARD_STOP_REASON="$8"
  LAST_CANONICAL_FOR_SELECTION="$9"
}

scan_dmesg_since_epoch() {
  local run_start_epoch="$1"
  local since_time dmesg_output
  LAST_DMESG_HARD_ISSUE="no"
  if [ -z "${run_start_epoch}" ]; then
    return 0
  fi
  since_time="$(date -d "@${run_start_epoch}" '+%F %T')"
  dmesg_output="$(sudo dmesg -T --since "${since_time}" 2>/dev/null || true)"
  {
    echo "===== DMESG SINCE ${since_time} ====="
    printf '%s\n' "${dmesg_output}"
  } >> "${RUNNER_LOG}"
  if printf '%s\n' "${dmesg_output}" | grep -Eiq 'hardware error|machine check|mce:'; then
    LAST_DMESG_HARD_ISSUE="yes"
  fi
}

append_results_row() {
  append_tsv_line "${RESULTS_TSV}" "$@"
}

profile_passes_stage() {
  [ "$(canonical_result_value "$1" "$2" run_status)" = "pass" ]
}

collect_pass_profiles() {
  local stage="$1"
  shift
  local profile_name
  for profile_name in "$@"; do
    if profile_passes_stage "${profile_name}" "${stage}"; then
      printf '%s\n' "${profile_name}"
    fi
  done
}

rank_pass_profiles() {
  local stage="$1"
  shift
  local remaining=("$@")
  local ranked=()
  local max_throughput=""
  local chosen chosen_stapm chosen_tdie chosen_skin
  local profile_name throughput threshold
  local profile_stapm profile_tdie profile_skin
  local close_profiles=()
  local next_remaining=()

  while [ "${#remaining[@]}" -gt 0 ]; do
    max_throughput=""
    for profile_name in "${remaining[@]}"; do
      throughput="$(canonical_result_value "${profile_name}" "${stage}" throughput_bogo_ops_per_sec)"
      if [ -z "${throughput}" ]; then
        continue
      fi
      if [ -z "${max_throughput}" ] || float_gt "${throughput}" "${max_throughput}"; then
        max_throughput="${throughput}"
      fi
    done
    if [ -z "${max_throughput}" ]; then
      break
    fi

    threshold="$(float_mul "${max_throughput}" "0.98")"
    close_profiles=()
    for profile_name in "${remaining[@]}"; do
      throughput="$(canonical_result_value "${profile_name}" "${stage}" throughput_bogo_ops_per_sec)"
      if [ -n "${throughput}" ] && float_ge "${throughput}" "${threshold}"; then
        close_profiles+=("${profile_name}")
      fi
    done

    chosen="${close_profiles[0]}"
    set_profile_values "${chosen}"
    chosen_stapm="${STAPM}"
    chosen_tdie="$(canonical_result_value "${chosen}" "${stage}" tdie_max_c)"
    chosen_skin="$(canonical_result_value "${chosen}" "${stage}" skin_value_max_c)"

    for profile_name in "${close_profiles[@]:1}"; do
      set_profile_values "${profile_name}"
      profile_stapm="${STAPM}"
      profile_tdie="$(canonical_result_value "${profile_name}" "${stage}" tdie_max_c)"
      profile_skin="$(canonical_result_value "${profile_name}" "${stage}" skin_value_max_c)"
      if [ "${profile_stapm}" -lt "${chosen_stapm}" ]; then
        chosen="${profile_name}"
        chosen_stapm="${profile_stapm}"
        chosen_tdie="${profile_tdie}"
        chosen_skin="${profile_skin}"
        continue
      fi
      if [ "${profile_stapm}" -eq "${chosen_stapm}" ]; then
        if [ -n "${profile_tdie}" ] && [ -n "${chosen_tdie}" ] && float_lt "${profile_tdie}" "${chosen_tdie}"; then
          chosen="${profile_name}"
          chosen_tdie="${profile_tdie}"
          chosen_skin="${profile_skin}"
          continue
        fi
        if [ -n "${profile_tdie}" ] && [ -n "${chosen_tdie}" ] && [ "${profile_tdie}" = "${chosen_tdie}" ] && \
           [ -n "${profile_skin}" ] && [ -n "${chosen_skin}" ] && float_lt "${profile_skin}" "${chosen_skin}"; then
          chosen="${profile_name}"
          chosen_skin="${profile_skin}"
        fi
      fi
    done

    ranked+=("${chosen}")
    next_remaining=()
    for profile_name in "${remaining[@]}"; do
      if [ "${profile_name}" != "${chosen}" ]; then
        next_remaining+=("${profile_name}")
      fi
    done
    remaining=("${next_remaining[@]}")
  done

  printf '%s\n' "${ranked[@]}"
}

build_summary_table() {
  local tmp_summary sort_file
  local profile_name sort_group sort_throughput recommendation_rank rejection_reason
  local status_300 throughput_300 avg_300 max_300 tdie_300 skin_hit_300
  local status_600 throughput_600 avg_600 max_600 tdie_600 skin_hit_600
  local burst_status burst_throughput

  tmp_summary="$(mktemp)"
  sort_file="${tmp_summary}.sort"
  printf '%s\n' "${SUMMARY_HEADER}" > "${tmp_summary}"

  for profile_name in "${ALL_PROFILES[@]}"; do
    set_profile_values "${profile_name}"
    status_300="$(result_value_for_display "${profile_name}" sustained_300 run_status)"
    throughput_300="$(result_value_for_display "${profile_name}" sustained_300 throughput_bogo_ops_per_sec)"
    avg_300="$(result_value_for_display "${profile_name}" sustained_300 avg_freq_avg_mhz)"
    max_300="$(result_value_for_display "${profile_name}" sustained_300 max_freq_avg_mhz)"
    tdie_300="$(result_value_for_display "${profile_name}" sustained_300 tdie_max_c)"
    skin_hit_300="$(result_value_for_display "${profile_name}" sustained_300 skin_hit)"

    status_600="$(result_value_for_display "${profile_name}" sustained_600 run_status)"
    throughput_600="$(result_value_for_display "${profile_name}" sustained_600 throughput_bogo_ops_per_sec)"
    avg_600="$(result_value_for_display "${profile_name}" sustained_600 avg_freq_avg_mhz)"
    max_600="$(result_value_for_display "${profile_name}" sustained_600 max_freq_avg_mhz)"
    tdie_600="$(result_value_for_display "${profile_name}" sustained_600 tdie_max_c)"
    skin_hit_600="$(result_value_for_display "${profile_name}" sustained_600 skin_hit)"

    burst_status="$(result_value_for_display "${profile_name}" burst_60 run_status)"
    burst_throughput="$(result_value_for_display "${profile_name}" burst_60 throughput_bogo_ops_per_sec)"

    recommendation_rank=""
    if [ -n "${SUSTAINED_FINAL_RECOMMENDATION}" ] && [ "${profile_name}" = "${SUSTAINED_FINAL_RECOMMENDATION}" ]; then
      recommendation_rank="1"
      sort_group="1"
      rejection_reason="selected_sustained"
      sort_throughput="${throughput_600:-0}"
    elif [ -z "${SUSTAINED_FINAL_RECOMMENDATION}" ] && [ -n "${BURST_FINAL_RECOMMENDATION}" ] && [ "${profile_name}" = "${BURST_FINAL_RECOMMENDATION}" ]; then
      recommendation_rank="1"
      sort_group="4"
      rejection_reason="selected_burst_only"
      sort_throughput="${burst_throughput:-0}"
    elif [ -n "${BURST_FINAL_RECOMMENDATION}" ] && [ "${profile_name}" = "${BURST_FINAL_RECOMMENDATION}" ]; then
      recommendation_rank="2"
      sort_group="4"
      rejection_reason="selected_burst"
      sort_throughput="${burst_throughput:-0}"
    elif [ "${status_600}" = "pass" ]; then
      sort_group="2"
      rejection_reason="passed_600_not_selected"
      sort_throughput="${throughput_600:-0}"
    elif [ "${status_300}" = "pass" ]; then
      sort_group="3"
      rejection_reason="passed_300_not_selected"
      sort_throughput="${throughput_300:-0}"
    elif [ "${burst_status}" = "pass" ]; then
      sort_group="4"
      rejection_reason="burst_only_pass"
      sort_throughput="${burst_throughput:-0}"
    elif [ "${status_300}" = "invalid" ] || [ "${status_600}" = "invalid" ] || [ "${burst_status}" = "invalid" ]; then
      sort_group="5"
      rejection_reason="$(best_reason_for_profile "${profile_name}")"
      sort_throughput="0"
    elif [ "${status_300}" = "fail" ] || [ "${status_600}" = "fail" ] || [ "${burst_status}" = "fail" ]; then
      sort_group="6"
      rejection_reason="$(best_reason_for_profile "${profile_name}")"
      sort_throughput="0"
    else
      sort_group="7"
      rejection_reason="not_tested"
      sort_throughput="0"
    fi

    append_tsv_line "${tmp_summary}" \
      "${profile_name}" "${STAPM}" "${FAST}" "${SLOW}" "${TCTL}" "${SKIN}" "${VRM}" "${VRMMAX}" \
      "${status_300:-not_tested}" "${throughput_300}" "${avg_300}" "${max_300}" "${tdie_300}" "${skin_hit_300}" \
      "${status_600:-not_tested}" "${throughput_600}" "${avg_600}" "${max_600}" "${tdie_600}" "${skin_hit_600}" \
      "${burst_status:-not_tested}" "${burst_throughput}" "${rejection_reason}" "${recommendation_rank}"
    append_tsv_line "${sort_file}" "${sort_group}" "${sort_throughput}" "${profile_name}"
  done

  {
    printf '%s\n' "${SUMMARY_HEADER}"
    while IFS=$'\t' read -r _group _throughput profile_name; do
      awk -F'\t' -v profile_name="${profile_name}" 'NR > 1 && $1 == profile_name { print }' "${tmp_summary}"
    done < <(sort -t$'\t' -k1,1n -k2,2gr -k3,3 "${sort_file}")
  } > "${SUMMARY_TSV}"

  rm -f "${tmp_summary}" "${sort_file}"
}

run_profile_once() {
  local stage="$1"
  local profile_name="$2"
  local duration="$3"
  local run_kind output status log_path run_status abort_reason invalid_reason requested_duration completed_duration
  local throughput avg_freq max_freq tdie_max tctl_value_max skin_value_max skin_hit battery_discharging_observed
  local ac_before ac_after battery_before battery_after canonical_for_selection dmesg_hard_issue run_start_epoch
  local attempt_id test_name

  if [ "${stage}" = "burst_60" ]; then
    run_kind="burst"
  else
    run_kind="sustained"
  fi

  ATTEMPT_COUNTER=$((ATTEMPT_COUNTER + 1))
  attempt_id="attempt-${ATTEMPT_COUNTER}"
  LAST_STAGE="${stage}"
  LAST_PROFILE="${profile_name}"

  prepare_for_run "${run_kind}"
  apply_profile "${profile_name}"

  test_name="oc98_${profile_name}_${duration}s"

  set +e
  output="$(RYZEN_TEST_TCTL_FALLBACK_C="${RYZEN_TEST_TCTL_FALLBACK_C_VALUE}" "${TEST_SCRIPT}" "${test_name}" "${duration}" 2>&1)"
  status=$?
  set -e

  printf '%s\n' "${output}" | tee -a "${RUNNER_LOG}" >/dev/null
  log_path="$(printf '%s\n' "${output}" | awk '/^Done: /{print $2}' | tail -1)"

  if [ -z "${log_path}" ] || [ ! -f "${log_path}" ]; then
    append_results_row \
      "${attempt_id}" "${stage}" "${profile_name}" "${duration}" "${STAPM}" "${FAST}" "${SLOW}" "${TCTL}" "${SKIN}" "${VRM}" "${VRMMAX}" \
      "${duration}" "" "fail" "missing_log" "none" "" "" "" "" "" "" "" "" "no" "" "" "" "" "" "yes"
    set_last_run_fields "fail" "missing_log" "none" "" "" "" "no" "missing_log" "yes"
    build_summary_table
    write_failure_report "failure" "missing_log" "profile=${profile_name} stage=${stage} duration=${duration}"
    exit 1
  fi

  requested_duration="$(summary_value "${log_path}" requested_duration_sec)"
  completed_duration="$(summary_value "${log_path}" completed_duration_sec)"
  abort_reason="$(summary_value "${log_path}" aborted_reason)"
  invalid_reason="$(summary_value "${log_path}" invalid_reason)"
  run_start_epoch="$(summary_value "${log_path}" run_start_epoch)"
  throughput="$(summary_value "${log_path}" throughput_bogo_ops_per_sec)"
  avg_freq="$(summary_value "${log_path}" avg_freq_avg_mhz)"
  max_freq="$(summary_value "${log_path}" max_freq_avg_mhz)"
  tdie_max="$(summary_value "${log_path}" tdie_max_c)"
  tctl_value_max="$(summary_value "${log_path}" tctl_value_max_c)"
  skin_value_max="$(summary_value "${log_path}" skin_value_max_c)"
  skin_hit="$(summary_value "${log_path}" skin_hit)"
  battery_discharging_observed="$(summary_value "${log_path}" battery_discharging_observed)"
  ac_before="$(summary_value "${log_path}" ac_online_before)"
  ac_after="$(summary_value "${log_path}" ac_online_after)"
  battery_before="$(summary_value "${log_path}" battery_status_before)"
  battery_after="$(summary_value "${log_path}" battery_status_after)"

  if [ -z "${requested_duration}" ] || [ -z "${completed_duration}" ] || [ -z "${run_start_epoch}" ]; then
    append_results_row \
      "${attempt_id}" "${stage}" "${profile_name}" "${duration}" "${STAPM}" "${FAST}" "${SLOW}" "${TCTL}" "${SKIN}" "${VRM}" "${VRMMAX}" \
      "${requested_duration}" "${completed_duration}" "fail" "summary_missing" "none" "${throughput}" "${avg_freq}" "${max_freq}" \
      "${tdie_max}" "${tctl_value_max}" "${skin_value_max}" "${skin_hit}" "${battery_discharging_observed}" "no" \
      "${ac_before}" "${ac_after}" "${battery_before}" "${battery_after}" "${log_path}" "yes"
    set_last_run_fields "fail" "summary_missing" "none" "${log_path}" "${completed_duration}" "${run_start_epoch}" "no" "summary_missing" "yes"
    build_summary_table
    write_failure_report "failure" "summary_missing" "profile=${profile_name} stage=${stage}"
    exit 1
  fi

  scan_dmesg_since_epoch "${run_start_epoch}"
  dmesg_hard_issue="${LAST_DMESG_HARD_ISSUE}"

  if [ "${dmesg_hard_issue}" = "yes" ]; then
    run_status="fail"
    canonical_for_selection="yes"
    append_results_row \
      "${attempt_id}" "${stage}" "${profile_name}" "${duration}" "${STAPM}" "${FAST}" "${SLOW}" "${TCTL}" "${SKIN}" "${VRM}" "${VRMMAX}" \
      "${requested_duration}" "${completed_duration}" "${run_status}" "${abort_reason:-none}" "${invalid_reason:-none}" "${throughput}" "${avg_freq}" "${max_freq}" \
      "${tdie_max}" "${tctl_value_max}" "${skin_value_max}" "${skin_hit}" "${battery_discharging_observed}" "${dmesg_hard_issue}" \
      "${ac_before}" "${ac_after}" "${battery_before}" "${battery_after}" "${log_path}" "${canonical_for_selection}"
    set_last_run_fields "${run_status}" "${abort_reason:-none}" "${invalid_reason:-none}" "${log_path}" "${completed_duration}" "${run_start_epoch}" "${dmesg_hard_issue}" "hard_dmesg_issue" "${canonical_for_selection}"
    build_summary_table
    write_failure_report "failure" "hard_dmesg_issue" "profile=${profile_name} stage=${stage}"
    exit 1
  fi

  if [ "$(summary_value "${log_path}" invalid_run)" = "yes" ] || [ "${status}" -eq 6 ]; then
    run_status="invalid"
    canonical_for_selection="no"
  elif [ "${abort_reason}" = "tdie_limit" ] || [ "${abort_reason}" = "skin_limit" ] || [ "${status}" -eq 3 ]; then
    run_status="fail"
    canonical_for_selection="yes"
  elif [ "${status}" -eq 0 ] && [ "$(summary_value "${log_path}" aborted)" = "no" ] && [ "${completed_duration}" = "${requested_duration}" ]; then
    run_status="pass"
    canonical_for_selection="yes"
  elif [ "${status}" -ne 0 ]; then
    run_status="fail"
    canonical_for_selection="yes"
    append_results_row \
      "${attempt_id}" "${stage}" "${profile_name}" "${duration}" "${STAPM}" "${FAST}" "${SLOW}" "${TCTL}" "${SKIN}" "${VRM}" "${VRMMAX}" \
      "${requested_duration}" "${completed_duration}" "${run_status}" "${abort_reason:-other}" "${invalid_reason:-none}" "${throughput}" "${avg_freq}" "${max_freq}" \
      "${tdie_max}" "${tctl_value_max}" "${skin_value_max}" "${skin_hit}" "${battery_discharging_observed}" "${dmesg_hard_issue}" \
      "${ac_before}" "${ac_after}" "${battery_before}" "${battery_after}" "${log_path}" "${canonical_for_selection}"
    set_last_run_fields "${run_status}" "${abort_reason:-other}" "${invalid_reason:-none}" "${log_path}" "${completed_duration}" "${run_start_epoch}" "${dmesg_hard_issue}" "stress_ng_failure" "${canonical_for_selection}"
    build_summary_table
    write_failure_report "failure" "stress_ng_failure" "profile=${profile_name} stage=${stage} status=${status}"
    exit 1
  else
    run_status="fail"
    canonical_for_selection="yes"
  fi

  append_results_row \
    "${attempt_id}" "${stage}" "${profile_name}" "${duration}" "${STAPM}" "${FAST}" "${SLOW}" "${TCTL}" "${SKIN}" "${VRM}" "${VRMMAX}" \
    "${requested_duration}" "${completed_duration}" "${run_status}" "${abort_reason:-none}" "${invalid_reason:-none}" "${throughput}" "${avg_freq}" "${max_freq}" \
    "${tdie_max}" "${tctl_value_max}" "${skin_value_max}" "${skin_hit}" "${battery_discharging_observed}" "${dmesg_hard_issue}" \
    "${ac_before}" "${ac_after}" "${battery_before}" "${battery_after}" "${log_path}" "${canonical_for_selection}"

  set_last_run_fields "${run_status}" "${abort_reason:-none}" "${invalid_reason:-none}" "${log_path}" "${completed_duration}" "${run_start_epoch}" "${dmesg_hard_issue}" "" "${canonical_for_selection}"
}

run_profile_with_retries() {
  local stage="$1"
  local profile_name="$2"
  local duration="$3"
  while true; do
    run_profile_once "${stage}" "${profile_name}" "${duration}"
    if [ "${LAST_RUN_STATUS}" = "invalid" ]; then
      log "Invalid run for ${profile_name} ${stage}: ${LAST_INVALID_REASON}. Waiting for AC recovery before retry."
      wait_for_ac_stable_or_stop
      continue
    fi
    return 0
  done
}

is_thermal_failure() {
  [ "${LAST_RUN_STATUS}" = "fail" ] && { [ "${LAST_ABORT_REASON}" = "tdie_limit" ] || [ "${LAST_ABORT_REASON}" = "skin_limit" ]; }
}

run_sustained_300_ladder() {
  local profile_name

  run_profile_with_retries "sustained_300" "P46" 300
  if [ "${LAST_RUN_STATUS}" = "pass" ]; then
    for profile_name in "${SUSTAINED_ASCEND_PROFILES[@]}"; do
      run_profile_with_retries "sustained_300" "${profile_name}" 300
      if is_thermal_failure; then
        break
      fi
      if [ "${LAST_RUN_STATUS}" != "pass" ]; then
        build_summary_table
        write_failure_report "failure" "unexpected_sustained_300_failure" "profile=${profile_name} abort_reason=${LAST_ABORT_REASON}"
        exit 1
      fi
    done
    return 0
  fi

  if is_thermal_failure; then
    run_profile_with_retries "sustained_300" "P44" 300
    if [ "${LAST_RUN_STATUS}" = "pass" ] || is_thermal_failure; then
      return 0
    fi
  fi

  if [ "${LAST_RUN_STATUS}" != "pass" ] && ! is_thermal_failure; then
    build_summary_table
    write_failure_report "failure" "unexpected_sustained_300_failure" "profile=${LAST_PROFILE} abort_reason=${LAST_ABORT_REASON}"
    exit 1
  fi
}

run_sustained_600_confirmations() {
  local pass_300=()
  local ranked_300=()
  local pass_600=()
  local tested_600=()
  local winner_300 second_300 winner_thr second_thr
  local fallback_profile fallback_status lowest_profile profile_name lowest_stapm candidate_stapm

  mapfile -t pass_300 < <(collect_pass_profiles "sustained_300" "${SUSTAINED_PROFILES[@]}")
  mapfile -t ranked_300 < <(rank_pass_profiles "sustained_300" "${pass_300[@]}")
  if [ "${#ranked_300[@]}" -eq 0 ]; then
    SUSTAINED_FINAL_RECOMMENDATION=""
    return 0
  fi

  winner_300="${ranked_300[0]}"
  run_profile_with_retries "sustained_600" "${winner_300}" 600
  tested_600+=("${winner_300}")
  if profile_passes_stage "${winner_300}" "sustained_600"; then
    pass_600+=("${winner_300}")
  fi

  if [ "${#ranked_300[@]}" -ge 2 ]; then
    second_300="${ranked_300[1]}"
    winner_thr="$(canonical_result_value "${winner_300}" "sustained_300" throughput_bogo_ops_per_sec)"
    second_thr="$(canonical_result_value "${second_300}" "sustained_300" throughput_bogo_ops_per_sec)"
    if [ -n "${winner_thr}" ] && [ -n "${second_thr}" ] && float_ge "${second_thr}" "$(float_mul "${winner_thr}" "0.97")"; then
      run_profile_with_retries "sustained_600" "${second_300}" 600
      tested_600+=("${second_300}")
      if profile_passes_stage "${second_300}" "sustained_600"; then
        pass_600+=("${second_300}")
      fi
    fi
  fi

  if [ "${#pass_600[@]}" -gt 0 ]; then
    mapfile -t pass_600 < <(rank_pass_profiles "sustained_600" "${pass_600[@]}")
    SUSTAINED_FINAL_RECOMMENDATION="${pass_600[0]}"
    return 0
  fi

  lowest_profile="${tested_600[0]}"
  set_profile_values "${lowest_profile}"
  lowest_stapm="${STAPM}"
  for profile_name in "${tested_600[@]:1}"; do
    set_profile_values "${profile_name}"
    candidate_stapm="${STAPM}"
    if [ "${candidate_stapm}" -lt "${lowest_stapm}" ]; then
      lowest_stapm="${candidate_stapm}"
      lowest_profile="${profile_name}"
    fi
  done

  fallback_profile="$(lower_sustained_profile_step "${lowest_profile}")"
  if [ -z "${fallback_profile}" ]; then
    SUSTAINED_FINAL_RECOMMENDATION=""
    return 0
  fi

  fallback_status="$(latest_result_value "${fallback_profile}" "sustained_600" run_status)"
  if [ -z "${fallback_status}" ]; then
    run_profile_with_retries "sustained_600" "${fallback_profile}" 600
  fi
  if profile_passes_stage "${fallback_profile}" "sustained_600"; then
    SUSTAINED_FINAL_RECOMMENDATION="${fallback_profile}"
  else
    SUSTAINED_FINAL_RECOMMENDATION=""
  fi
}

run_burst_stage() {
  local burst_passes=()
  local burst_ranked=()
  local previous_throughput="" current_throughput threshold consecutive_drops=0
  local profile_name
  for profile_name in "${BURST_PROFILES[@]}"; do
    run_profile_with_retries "burst_60" "${profile_name}" 60
    if [ "${LAST_RUN_STATUS}" = "pass" ]; then
      current_throughput="$(canonical_result_value "${profile_name}" "burst_60" throughput_bogo_ops_per_sec)"
      if [ -n "${previous_throughput}" ] && [ -n "${current_throughput}" ]; then
        threshold="$(float_mul "${previous_throughput}" "0.98")"
        if float_lt "${current_throughput}" "${threshold}"; then
          consecutive_drops=$((consecutive_drops + 1))
        else
          consecutive_drops=0
        fi
      fi
      previous_throughput="${current_throughput}"
      if [ "${consecutive_drops}" -ge 2 ]; then
        break
      fi
      continue
    fi

    if is_thermal_failure; then
      break
    fi

    break
  done

  mapfile -t burst_passes < <(collect_pass_profiles "burst_60" "${BURST_PROFILES[@]}")
  mapfile -t burst_ranked < <(rank_pass_profiles "burst_60" "${burst_passes[@]}")
  BURST_FINAL_RECOMMENDATION="${burst_ranked[0]:-}"
}

restore_daily_profile() {
  log "Restoring daily-safe profile via ryzenadj-profile performance"
  sudo powerprofilesctl set performance >/dev/null 2>&1 || true
  if [ -w /sys/firmware/acpi/platform_profile ]; then
    echo performance | sudo tee /sys/firmware/acpi/platform_profile >/dev/null 2>&1 || true
  fi
  for policy in /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference; do
    echo performance | sudo tee "${policy}" >/dev/null 2>&1 || true
  done
  if [ -x "${RYZENADJ_PROFILE_BIN}" ]; then
    sudo -n "${RYZENADJ_PROFILE_BIN}" performance >/dev/null 2>&1 || true
  fi
}

need_cmd sudo
need_cmd awk
need_cmd grep
need_cmd sort
need_cmd tail
need_cmd date
need_cmd powerprofilesctl
need_cmd stress-ng

if [ ! -x "${TEST_SCRIPT}" ]; then
  echo "Missing test script: ${TEST_SCRIPT}" >&2
  exit 1
fi
if [ ! -x "${RYZENADJ_BIN}" ]; then
  echo "Missing ryzenadj binary: ${RYZENADJ_BIN}" >&2
  exit 1
fi

ensure_root
log "Using result root: ${ROOT}"
ensure_sudo
start_sudo_keepalive
ensure_dmesg_since_supported
run_sustained_300_ladder
run_sustained_600_confirmations
run_burst_stage
build_summary_table

if [ -n "${SUSTAINED_FINAL_RECOMMENDATION}" ]; then
  write_success_report "${SUSTAINED_FINAL_RECOMMENDATION}" "${BURST_FINAL_RECOMMENDATION:-}"
else
  write_failure_report "failure" "no_safe_98c_oc_sustained_candidate_found"
fi

restore_daily_profile
log "Completed OC98 matrix. Sustained winner: ${SUSTAINED_FINAL_RECOMMENDATION:-none}; burst winner: ${BURST_FINAL_RECOMMENDATION:-none}"
