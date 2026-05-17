#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: ryzen-postmod-sustained-matrix.sh [--root DIR]
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
AC_RECOVERY_TIMEOUT_SEC=900
AC_STABILITY_INTERVAL_SEC=10
IDLE_BASELINE_SEC=180
RYZEN_TEST_TCTL_FALLBACK_C_VALUE="95"
RESULTS_HEADER=$'attempt_id\tprofile_name\tduration_sec\tstapm_limit\tfast_limit\tslow_limit\ttctl_limit\tskin_limit\tvrm_current\tvrmmax_current\trequested_duration_sec\tcompleted_duration_sec\trun_status\tabort_reason\tinvalid_reason\tthroughput_bogo_ops_per_sec\tavg_freq_avg_mhz\tmax_freq_avg_mhz\ttdie_max_c\ttctl_value_max_c\tskin_value_max_c\tskin_hit\tbattery_discharging_observed\tdmesg_hard_issue\tac_online_before\tac_online_after\tbattery_status_before\tbattery_status_after\tlog_path\tcanonical_for_selection'
SUMMARY_HEADER=$'profile_name\tstapm_limit\tfast_limit\tslow_limit\ttctl_limit\tskin_limit\tvrm_current\tvrmmax_current\tstatus_300\tthroughput_300\tavg_freq_avg_mhz_300\tmax_freq_avg_mhz_300\ttdie_max_c_300\ttctl_value_max_c_300\tskin_value_max_c_300\tskin_hit_300\tstatus_600\tthroughput_600\tavg_freq_avg_mhz_600\tmax_freq_avg_mhz_600\ttdie_max_c_600\ttctl_value_max_c_600\tskin_value_max_c_600\tskin_hit_600\trejection_reason\trecommendation_rank'

RUNNER_LOG=""
RESULTS_TSV=""
SUMMARY_TSV=""
WINNER_TXT=""
ASKPASS_DIR=""
SUDO_KEEPALIVE_PID=""
IDLE_TEMP_C=""
ATTEMPT_COUNTER=0
FINAL_RECOMMENDATION=""
LAST_RUN_STATUS=""
LAST_ABORT_REASON=""
LAST_INVALID_REASON=""
LAST_LOG_PATH=""
LAST_COMPLETED_DURATION=""
LAST_RUN_START_EPOCH=""
LAST_DMESG_HARD_ISSUE="no"
LAST_HARD_STOP_REASON=""
LAST_CANONICAL_FOR_SELECTION="no"

ALL_PROFILES=(P44 P46 P48 P50 P52 P54 P56 P58 P60)
MAIN_ASCEND_PROFILES=(P50 P52 P54 P56 P58 P60)

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

float_pct_of() {
  awk -v value="$1" -v pct="$2" 'BEGIN { printf "%.6f", value * pct / 100 }'
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

power_is_stable_once() {
  [ "$(read_ac_online)" = "yes" ] && ! battery_is_discharging
}

ensure_root() {
  if [ -z "${ROOT}" ]; then
    ROOT="$(mktemp -d "/var/tmp/ryzen-postmod-sustained-$(date +%Y%m%d-%H%M%S)-XXXXXX")"
  elif [ -e "${ROOT}" ]; then
    if [ -e "${ROOT}/results.tsv" ] || [ -e "${ROOT}/summary.tsv" ] || [ -e "${ROOT}/winner.txt" ] || [ -e "${ROOT}/runner.log" ]; then
      echo "Refusing to reuse existing result root: ${ROOT}" >&2
      exit 1
    fi
    mkdir -p "${ROOT}"
  else
    mkdir -p "${ROOT}"
  fi

  RUNNER_LOG="${ROOT}/runner.log"
  RESULTS_TSV="${ROOT}/results.tsv"
  SUMMARY_TSV="${ROOT}/summary.tsv"
  WINNER_TXT="${ROOT}/winner.txt"
  : > "${RUNNER_LOG}"
  printf '%s\n' "${RESULTS_HEADER}" > "${RESULTS_TSV}"
}

ensure_sudo() {
  if sudo -n true >/dev/null 2>&1; then
    return
  fi
  need_cmd rofi
  ASKPASS_DIR="$(mktemp -d)"
  printf '%s\n' '#!/usr/bin/env bash' 'exec /run/current-system/sw/bin/rofi -dmenu -password -p "sudo for ryzen sustained matrix"' > "${ASKPASS_DIR}/askpass"
  chmod 700 "${ASKPASS_DIR}/askpass"
  export SUDO_ASKPASS="${ASKPASS_DIR}/askpass"
  sudo -A -v
}

start_sudo_keepalive() {
  (
    while true; do
      if ! sudo -n true >/dev/null 2>&1; then
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
    write_failure_report "dmesg_since_unsupported" "since_time=${since_time}"
    build_summary_table
    exit 1
  fi
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
      write_failure_report "ac_recovery_timeout" "ac_online=$(read_ac_online) battery_status=$(read_battery_status)"
      build_summary_table
      exit 1
    fi
    sleep "${AC_STABILITY_INTERVAL_SEC}"
  done
}

run_preflight() {
  local profile platform governor mismatches
  log "Running performance preflight"
  sudo -v
  sudo powerprofilesctl set performance >/dev/null 2>&1 || true
  if [ -e /sys/firmware/acpi/platform_profile ]; then
    echo performance | sudo tee /sys/firmware/acpi/platform_profile >/dev/null 2>&1 || true
  fi
  for policy in /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference; do
    echo performance | sudo tee "${policy}" >/dev/null 2>&1 || true
  done

  profile="$(powerprofilesctl get 2>/dev/null || true)"
  platform="$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo unavailable)"
  governor="$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null || echo unavailable)"
  mismatches="$(grep -L '^performance$' /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference 2>/dev/null || true)"

  {
    echo "powerprofilesctl_get=${profile}"
    echo "powerprofilesctl_list:"
    powerprofilesctl list 2>&1
    echo "platform_profile=${platform}"
    echo "boost=$(cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || echo unavailable)"
    echo "ac_online=$(cat /sys/class/power_supply/AC*/online 2>/dev/null || echo unavailable)"
    echo "battery_status=$(read_battery_status)"
  } >> "${RUNNER_LOG}"

  if [ "${profile}" != "performance" ]; then
    write_failure_report "preflight_failed" "powerprofilesctl=${profile}"
    build_summary_table
    exit 1
  fi
  if [ -e /sys/firmware/acpi/platform_profile ] && [ "${platform}" != "performance" ]; then
    write_failure_report "preflight_failed" "platform_profile=${platform}"
    build_summary_table
    exit 1
  fi
  if [ "${governor}" != "performance" ]; then
    write_failure_report "preflight_failed" "governor=${governor}"
    build_summary_table
    exit 1
  fi
  if [ -n "${mismatches}" ]; then
    write_failure_report "preflight_failed" "epp_mismatch=${mismatches}"
    build_summary_table
    exit 1
  fi
}

prepare_for_run() {
  wait_for_ac_stable_or_stop
  run_preflight
  if [ -z "${IDLE_TEMP_C}" ]; then
    log "Idling for ${IDLE_BASELINE_SEC} seconds before first run"
    sleep "${IDLE_BASELINE_SEC}"
    IDLE_TEMP_C="$(read_cpu_temp)"
    log "Idle baseline Tdie=${IDLE_TEMP_C}C"
  else
    wait_for_cooldown "${IDLE_TEMP_C}"
  fi
}

wait_for_cooldown() {
  local idle_temp="$1"
  local threshold current
  threshold="$(awk -v idle="${idle_temp}" 'BEGIN { t = idle + 3; if (t < 50) t = 50; printf "%.1f", t }')"
  log "Waiting for cooldown to <= ${threshold}C"
  while true; do
    current="$(read_cpu_temp)"
    log "Cooldown check: current=${current}C threshold=${threshold}C"
    if [ "${current}" != "N/A" ] && float_le "${current}" "${threshold}"; then
      return 0
    fi
    sleep 15
  done
}

set_profile_values() {
  PROFILE_NAME="$1"
  case "${PROFILE_NAME}" in
    P44)
      STAPM=44000; FAST=60000; SLOW=56000; TCTL=95; SKIN=43; VRM=90000; VRMMAX=110000 ;;
    P46)
      STAPM=46000; FAST=62000; SLOW=58000; TCTL=95; SKIN=43; VRM=90000; VRMMAX=110000 ;;
    P48)
      STAPM=48000; FAST=64000; SLOW=60000; TCTL=95; SKIN=43; VRM=90000; VRMMAX=110000 ;;
    P50)
      STAPM=50000; FAST=66000; SLOW=62000; TCTL=95; SKIN=43; VRM=90000; VRMMAX=110000 ;;
    P52)
      STAPM=52000; FAST=68000; SLOW=64000; TCTL=95; SKIN=43; VRM=90000; VRMMAX=110000 ;;
    P54)
      STAPM=54000; FAST=70000; SLOW=65000; TCTL=95; SKIN=43; VRM=95000; VRMMAX=115000 ;;
    P56)
      STAPM=56000; FAST=72000; SLOW=67000; TCTL=95; SKIN=43; VRM=95000; VRMMAX=115000 ;;
    P58)
      STAPM=58000; FAST=74000; SLOW=69000; TCTL=95; SKIN=43; VRM=100000; VRMMAX=120000 ;;
    P60)
      STAPM=60000; FAST=76000; SLOW=71000; TCTL=95; SKIN=43; VRM=105000; VRMMAX=125000 ;;
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

lower_profile_step() {
  case "$1" in
    P60) echo P58 ;;
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
  local duration="$2"
  local column="$3"
  awk -F'\t' -v profile_name="${profile_name}" -v duration="${duration}" -v column="${column}" '
    NR == 1 {
      for (i = 1; i <= NF; i++) {
        if ($i == column) {
          col = i
        }
      }
      next
    }
    $2 == profile_name && $3 == duration {
      value = $col
    }
    END {
      print value
    }
  ' "${RESULTS_TSV}"
}

canonical_result_value() {
  local profile_name="$1"
  local duration="$2"
  local column="$3"
  awk -F'\t' -v profile_name="${profile_name}" -v duration="${duration}" -v column="${column}" '
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
    $2 == profile_name && $3 == duration && $canonical_col == "yes" {
      value = $col
    }
    END {
      print value
    }
  ' "${RESULTS_TSV}"
}

result_value_for_display() {
  local profile_name="$1"
  local duration="$2"
  local column="$3"
  local value
  value="$(canonical_result_value "${profile_name}" "${duration}" "${column}")"
  if [ -n "${value}" ]; then
    printf '%s\n' "${value}"
  else
    latest_result_value "${profile_name}" "${duration}" "${column}"
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
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}" "${12}" "${13}" "${14}" "${15}" "${16}" "${17}" "${18}" "${19}" "${20}" \
    "${21}" "${22}" "${23}" "${24}" "${25}" "${26}" "${27}" "${28}" "${29}" "${30}" >> "${RESULTS_TSV}"
}

write_failure_report() {
  local reason="$1"
  local details="${2:-}"
  local profile_name profile_reason
  {
    echo "status=failure"
    echo "reason=${reason}"
    if [ -n "${details}" ]; then
      echo "details=${details}"
    fi
    echo "results_root=${ROOT}"
    echo "bottleneck=$(detect_bottleneck)"
    echo
    echo "Profile outcomes:"
    for profile_name in "${ALL_PROFILES[@]}"; do
      profile_reason="$(class_reason_for_duration "${profile_name}" 600)"
      if [ "${profile_reason}" = "not_tested" ]; then
        profile_reason="$(class_reason_for_duration "${profile_name}" 300)"
      fi
      printf '%s: %s\n' "${profile_name}" "${profile_reason}"
    done
  } > "${WINNER_TXT}"
}

class_reason_for_duration() {
  local profile_name="$1"
  local duration="$2"
  local status abort_reason invalid_reason
  status="$(result_value_for_display "${profile_name}" "${duration}" run_status)"
  abort_reason="$(result_value_for_display "${profile_name}" "${duration}" abort_reason)"
  invalid_reason="$(result_value_for_display "${profile_name}" "${duration}" invalid_reason)"
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

build_summary_table() {
  local tmp_summary profile_name recommendation_rank sort_group rejection_reason
  local status_300 throughput_300 avg_300 max_300 tdie_300 tctl_300 skin_300 skin_hit_300
  local status_600 throughput_600 avg_600 max_600 tdie_600 tctl_600 skin_600 skin_hit_600
  tmp_summary="$(mktemp)"
  printf '%s\n' "${SUMMARY_HEADER}" > "${tmp_summary}"

  for profile_name in "${ALL_PROFILES[@]}"; do
    set_profile_values "${profile_name}"
    status_300="$(result_value_for_display "${profile_name}" 300 run_status)"
    throughput_300="$(result_value_for_display "${profile_name}" 300 throughput_bogo_ops_per_sec)"
    avg_300="$(result_value_for_display "${profile_name}" 300 avg_freq_avg_mhz)"
    max_300="$(result_value_for_display "${profile_name}" 300 max_freq_avg_mhz)"
    tdie_300="$(result_value_for_display "${profile_name}" 300 tdie_max_c)"
    tctl_300="$(result_value_for_display "${profile_name}" 300 tctl_value_max_c)"
    skin_300="$(result_value_for_display "${profile_name}" 300 skin_value_max_c)"
    skin_hit_300="$(result_value_for_display "${profile_name}" 300 skin_hit)"

    status_600="$(result_value_for_display "${profile_name}" 600 run_status)"
    throughput_600="$(result_value_for_display "${profile_name}" 600 throughput_bogo_ops_per_sec)"
    avg_600="$(result_value_for_display "${profile_name}" 600 avg_freq_avg_mhz)"
    max_600="$(result_value_for_display "${profile_name}" 600 max_freq_avg_mhz)"
    tdie_600="$(result_value_for_display "${profile_name}" 600 tdie_max_c)"
    tctl_600="$(result_value_for_display "${profile_name}" 600 tctl_value_max_c)"
    skin_600="$(result_value_for_display "${profile_name}" 600 skin_value_max_c)"
    skin_hit_600="$(result_value_for_display "${profile_name}" 600 skin_hit)"

    recommendation_rank=""
    if [ -n "${FINAL_RECOMMENDATION}" ] && [ "${profile_name}" = "${FINAL_RECOMMENDATION}" ]; then
      recommendation_rank="1"
      sort_group="1"
      rejection_reason="selected"
    elif [ "${status_600}" = "pass" ]; then
      sort_group="2"
      rejection_reason="passed_600_not_selected"
    elif [ "${status_300}" = "pass" ]; then
      sort_group="3"
      rejection_reason="passed_300_not_selected"
    elif [ "${status_300}" = "invalid" ] || [ "${status_600}" = "invalid" ]; then
      sort_group="4"
      rejection_reason="$(class_reason_for_duration "${profile_name}" 600)"
      if [ "${rejection_reason}" = "not_tested" ]; then
        rejection_reason="$(class_reason_for_duration "${profile_name}" 300)"
      fi
    elif [ "${status_300}" = "fail" ] || [ "${status_600}" = "fail" ]; then
      sort_group="5"
      rejection_reason="$(class_reason_for_duration "${profile_name}" 600)"
      if [ "${rejection_reason}" = "not_tested" ]; then
        rejection_reason="$(class_reason_for_duration "${profile_name}" 300)"
      fi
    else
      sort_group="6"
      rejection_reason="not_tested"
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "${profile_name}" "${STAPM}" "${FAST}" "${SLOW}" "${TCTL}" "${SKIN}" "${VRM}" "${VRMMAX}" \
      "${status_300:-not_tested}" "${throughput_300}" "${avg_300}" "${max_300}" "${tdie_300}" "${tctl_300}" "${skin_300}" "${skin_hit_300}" \
      "${status_600:-not_tested}" "${throughput_600}" "${avg_600}" "${max_600}" "${tdie_600}" "${tctl_600}" "${skin_600}" "${skin_hit_600}" \
      "${rejection_reason}" "${recommendation_rank}" >> "${tmp_summary}"
    printf '%s\t%s\t%s\n' "${sort_group}" "${throughput_600:-${throughput_300:-0}}" "${profile_name}" >> "${tmp_summary}.sort"
  done

  {
    printf '%s\n' "${SUMMARY_HEADER}"
    while IFS=$'\t' read -r _sort_group _sort_throughput profile_name; do
      awk -F'\t' -v profile_name="${profile_name}" 'NR > 1 && $1 == profile_name { print }' "${tmp_summary}"
    done < <(sort -t$'\t' -k1,1n -k2,2gr -k3,3 "${tmp_summary}.sort")
  } > "${SUMMARY_TSV}"

  rm -f "${tmp_summary}" "${tmp_summary}.sort"
}

profile_passes_at_duration() {
  [ "$(canonical_result_value "$1" "$2" run_status)" = "pass" ]
}

rank_pass_profiles() {
  local duration="$1"
  shift
  local remaining=("$@")
  local ranked=()
  local max_throughput=""
  local candidate_name=""
  local candidate_throughput=""
  local chosen=""
  local chosen_stapm=0
  local chosen_tdie=""
  local chosen_skin=""
  local profile_name throughput profile_stapm profile_tdie profile_skin threshold
  local close_profiles=()
  local next_remaining=()

  while [ "${#remaining[@]}" -gt 0 ]; do
    max_throughput=""
    for profile_name in "${remaining[@]}"; do
      throughput="$(canonical_result_value "${profile_name}" "${duration}" throughput_bogo_ops_per_sec)"
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
      throughput="$(canonical_result_value "${profile_name}" "${duration}" throughput_bogo_ops_per_sec)"
      if [ -n "${throughput}" ] && float_ge "${throughput}" "${threshold}"; then
        close_profiles+=("${profile_name}")
      fi
    done

    chosen="${close_profiles[0]}"
    set_profile_values "${chosen}"
    chosen_stapm="${STAPM}"
    chosen_tdie="$(canonical_result_value "${chosen}" "${duration}" tdie_max_c)"
    chosen_skin="$(canonical_result_value "${chosen}" "${duration}" skin_value_max_c)"

    for profile_name in "${close_profiles[@]:1}"; do
      set_profile_values "${profile_name}"
      profile_stapm="${STAPM}"
      profile_tdie="$(canonical_result_value "${profile_name}" "${duration}" tdie_max_c)"
      profile_skin="$(canonical_result_value "${profile_name}" "${duration}" skin_value_max_c)"
      candidate_throughput="$(canonical_result_value "${profile_name}" "${duration}" throughput_bogo_ops_per_sec)"
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
          continue
        fi
        if [ -n "${candidate_throughput}" ] && [ -n "$(canonical_result_value "${chosen}" "${duration}" throughput_bogo_ops_per_sec)" ] && \
           [ "${profile_tdie}" = "${chosen_tdie}" ] && [ "${profile_skin}" = "${chosen_skin}" ] && \
           float_gt "${candidate_throughput}" "$(canonical_result_value "${chosen}" "${duration}" throughput_bogo_ops_per_sec)"; then
          chosen="${profile_name}"
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

collect_pass_profiles() {
  local duration="$1"
  local profile_name
  for profile_name in "${ALL_PROFILES[@]}"; do
    if profile_passes_at_duration "${profile_name}" "${duration}"; then
      printf '%s\n' "${profile_name}"
    fi
  done
}

write_success_report() {
  local recommended_profile="$1"
  local bottleneck="$2"
  local profile_name reason
  {
    echo "status=success"
    echo "results_root=${ROOT}"
    echo "recommended_profile=${recommended_profile}"
    echo "ryzenadj_command=$(profile_command_string "${recommended_profile}")"
    echo "reason=best sustained candidate after 300s ladder and 600s confirmation"
    echo "bottleneck=${bottleneck}"
    echo
    echo "300s metrics:"
    echo "throughput_bogo_ops_per_sec=$(canonical_result_value "${recommended_profile}" 300 throughput_bogo_ops_per_sec)"
    echo "avg_freq_avg_mhz=$(canonical_result_value "${recommended_profile}" 300 avg_freq_avg_mhz)"
    echo "max_freq_avg_mhz=$(canonical_result_value "${recommended_profile}" 300 max_freq_avg_mhz)"
    echo "tdie_max_c=$(canonical_result_value "${recommended_profile}" 300 tdie_max_c)"
    echo "skin_value_max_c=$(canonical_result_value "${recommended_profile}" 300 skin_value_max_c)"
    echo
    echo "600s metrics:"
    echo "throughput_bogo_ops_per_sec=$(canonical_result_value "${recommended_profile}" 600 throughput_bogo_ops_per_sec)"
    echo "avg_freq_avg_mhz=$(canonical_result_value "${recommended_profile}" 600 avg_freq_avg_mhz)"
    echo "max_freq_avg_mhz=$(canonical_result_value "${recommended_profile}" 600 max_freq_avg_mhz)"
    echo "tdie_max_c=$(canonical_result_value "${recommended_profile}" 600 tdie_max_c)"
    echo "skin_value_max_c=$(canonical_result_value "${recommended_profile}" 600 skin_value_max_c)"
    echo
    echo "Rejected profiles:"
    for profile_name in "${ALL_PROFILES[@]}"; do
      if [ "${profile_name}" = "${recommended_profile}" ]; then
        continue
      fi
      reason="$(class_reason_for_duration "${profile_name}" 600)"
      if [ "${reason}" = "not_tested" ]; then
        reason="$(class_reason_for_duration "${profile_name}" 300)"
      fi
      printf '%s: %s\n' "${profile_name}" "${reason}"
    done
  } > "${WINNER_TXT}"
}

run_profile_once() {
  local profile_name="$1"
  local duration="$2"
  local attempt_id output status log_path run_status abort_reason invalid_reason requested_duration completed_duration
  local throughput avg_freq max_freq tdie_max tctl_value_max skin_value_max skin_hit battery_discharging_observed
  local ac_before ac_after battery_before battery_after canonical_for_selection dmesg_hard_issue run_start_epoch

  ATTEMPT_COUNTER=$((ATTEMPT_COUNTER + 1))
  attempt_id="attempt-${ATTEMPT_COUNTER}"

  prepare_for_run
  apply_profile "${profile_name}"

  set +e
  output="$(RYZEN_TEST_TCTL_FALLBACK_C="${RYZEN_TEST_TCTL_FALLBACK_C_VALUE}" "${TEST_SCRIPT}" "postmod_${profile_name}_${duration}s" "${duration}" 2>&1)"
  status=$?
  set -e

  printf '%s\n' "${output}" | tee -a "${RUNNER_LOG}" >/dev/null
  log_path="$(printf '%s\n' "${output}" | awk '/^Done: /{print $2}' | tail -1)"
  if [ -z "${log_path}" ] || [ ! -f "${log_path}" ]; then
    append_results_row "${attempt_id}" "${profile_name}" "${duration}" "${STAPM}" "${FAST}" "${SLOW}" "${TCTL}" "${SKIN}" "${VRM}" "${VRMMAX}" \
      "${duration}" "" "fail" "missing_log" "none" "" "" "" "" "" "" "" "" "no" "" "" "" "" "" "yes"
    set_last_run_fields "fail" "missing_log" "none" "" "" "" "no" "missing_log" "yes"
    write_failure_report "missing_log" "profile=${profile_name} duration=${duration}"
    build_summary_table
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
    append_results_row "${attempt_id}" "${profile_name}" "${duration}" "${STAPM}" "${FAST}" "${SLOW}" "${TCTL}" "${SKIN}" "${VRM}" "${VRMMAX}" \
      "${requested_duration}" "${completed_duration}" "fail" "summary_missing" "none" "${throughput}" "${avg_freq}" "${max_freq}" \
      "${tdie_max}" "${tctl_value_max}" "${skin_value_max}" "${skin_hit}" "${battery_discharging_observed}" "no" \
      "${ac_before}" "${ac_after}" "${battery_before}" "${battery_after}" "${log_path}" "yes"
    set_last_run_fields "fail" "summary_missing" "none" "${log_path}" "${completed_duration}" "${run_start_epoch}" "no" "summary_missing" "yes"
    write_failure_report "summary_missing" "profile=${profile_name} duration=${duration}"
    build_summary_table
    exit 1
  fi

  scan_dmesg_since_epoch "${run_start_epoch}"
  dmesg_hard_issue="${LAST_DMESG_HARD_ISSUE}"

  if [ "${dmesg_hard_issue}" = "yes" ]; then
    run_status="fail"
    canonical_for_selection="yes"
    append_results_row "${attempt_id}" "${profile_name}" "${duration}" "${STAPM}" "${FAST}" "${SLOW}" "${TCTL}" "${SKIN}" "${VRM}" "${VRMMAX}" \
      "${requested_duration}" "${completed_duration}" "${run_status}" "${abort_reason:-none}" "${invalid_reason:-none}" "${throughput}" "${avg_freq}" "${max_freq}" \
      "${tdie_max}" "${tctl_value_max}" "${skin_value_max}" "${skin_hit}" "${battery_discharging_observed}" "${dmesg_hard_issue}" \
      "${ac_before}" "${ac_after}" "${battery_before}" "${battery_after}" "${log_path}" "${canonical_for_selection}"
    set_last_run_fields "${run_status}" "${abort_reason:-none}" "${invalid_reason:-none}" "${log_path}" "${completed_duration}" "${run_start_epoch}" "${dmesg_hard_issue}" "hard_dmesg_issue" "${canonical_for_selection}"
    write_failure_report "hard_dmesg_issue" "profile=${profile_name} duration=${duration}"
    build_summary_table
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
    append_results_row "${attempt_id}" "${profile_name}" "${duration}" "${STAPM}" "${FAST}" "${SLOW}" "${TCTL}" "${SKIN}" "${VRM}" "${VRMMAX}" \
      "${requested_duration}" "${completed_duration}" "${run_status}" "${abort_reason:-other}" "${invalid_reason:-none}" "${throughput}" "${avg_freq}" "${max_freq}" \
      "${tdie_max}" "${tctl_value_max}" "${skin_value_max}" "${skin_hit}" "${battery_discharging_observed}" "${dmesg_hard_issue}" \
      "${ac_before}" "${ac_after}" "${battery_before}" "${battery_after}" "${log_path}" "${canonical_for_selection}"
    set_last_run_fields "${run_status}" "${abort_reason:-other}" "${invalid_reason:-none}" "${log_path}" "${completed_duration}" "${run_start_epoch}" "${dmesg_hard_issue}" "stress_ng_failure" "${canonical_for_selection}"
    write_failure_report "stress_ng_failure" "profile=${profile_name} duration=${duration} status=${status}"
    build_summary_table
    exit 1
  else
    run_status="fail"
    canonical_for_selection="yes"
  fi

  append_results_row "${attempt_id}" "${profile_name}" "${duration}" "${STAPM}" "${FAST}" "${SLOW}" "${TCTL}" "${SKIN}" "${VRM}" "${VRMMAX}" \
    "${requested_duration}" "${completed_duration}" "${run_status}" "${abort_reason:-none}" "${invalid_reason:-none}" "${throughput}" "${avg_freq}" "${max_freq}" \
    "${tdie_max}" "${tctl_value_max}" "${skin_value_max}" "${skin_hit}" "${battery_discharging_observed}" "${dmesg_hard_issue}" \
    "${ac_before}" "${ac_after}" "${battery_before}" "${battery_after}" "${log_path}" "${canonical_for_selection}"

  set_last_run_fields "${run_status}" "${abort_reason:-none}" "${invalid_reason:-none}" "${log_path}" "${completed_duration}" "${run_start_epoch}" "${dmesg_hard_issue}" "" "${canonical_for_selection}"

  if [ "${abort_reason}" = "skin_limit" ]; then
    write_failure_report "unexpected_skin_limit" "profile=${profile_name} duration=${duration}"
    build_summary_table
    exit 1
  fi
}

run_profile_with_retries() {
  local profile_name="$1"
  local duration="$2"
  while true; do
    run_profile_once "${profile_name}" "${duration}"
    if [ "${LAST_RUN_STATUS}" = "invalid" ]; then
      log "Invalid run for ${profile_name} ${duration}s: ${LAST_INVALID_REASON}. Waiting for AC recovery before retry."
      wait_for_ac_stable_or_stop
      continue
    fi
    return 0
  done
}

find_best_pass_profile() {
  local duration="$1"
  local ranked=()
  mapfile -t ranked < <(rank_pass_profiles "${duration}" "$(collect_pass_profiles "${duration}")")
  printf '%s\n' "${ranked[0]:-}"
}

find_ranked_pass_profiles() {
  local duration="$1"
  local pass_profiles=()
  mapfile -t pass_profiles < <(collect_pass_profiles "${duration}")
  if [ "${#pass_profiles[@]}" -eq 0 ]; then
    return 0
  fi
  rank_pass_profiles "${duration}" "${pass_profiles[@]}"
}

detect_bottleneck() {
  if awk -F'\t' 'NR > 1 && $14 == "skin_limit" { found = 1 } END { exit !found }' "${RESULTS_TSV}"; then
    echo "skin/STT"
  elif awk -F'\t' 'NR > 1 && $14 == "tdie_limit" { found = 1 } END { exit !found }' "${RESULTS_TSV}"; then
    echo "Tdie"
  elif awk -F'\t' 'NR > 1 && $24 == "yes" { found = 1 } END { exit !found }' "${RESULTS_TSV}"; then
    echo "hardware/stability"
  elif awk -F'\t' 'NR > 1 && $13 == "invalid" { found = 1 } END { exit !found }' "${RESULTS_TSV}"; then
    echo "power validity"
  else
    echo "unknown"
  fi
}

run_300s_ladder() {
  local profile_name

  run_profile_with_retries "P48" 300
  case "${LAST_RUN_STATUS}:${LAST_ABORT_REASON}" in
    pass:*)
      for profile_name in "${MAIN_ASCEND_PROFILES[@]}"; do
        run_profile_with_retries "${profile_name}" 300
        if [ "${LAST_RUN_STATUS}" = "fail" ] && [ "${LAST_ABORT_REASON}" = "tdie_limit" ]; then
          break
        fi
      done
      ;;
    fail:tdie_limit)
      run_profile_with_retries "P46" 300
      if [ "${LAST_RUN_STATUS}" = "fail" ] && [ "${LAST_ABORT_REASON}" = "tdie_limit" ]; then
        run_profile_with_retries "P44" 300
      fi
      ;;
    *)
      write_failure_report "p48_failed_without_tdie_limit" "status=${LAST_RUN_STATUS} abort_reason=${LAST_ABORT_REASON}"
      build_summary_table
      exit 1
      ;;
  esac
}

run_600s_confirmations() {
  local ranked_300=()
  local winner_300=""
  local second_300=""
  local winner_300_thr second_300_thr fallback_profile lower_failed_profile
  local tested_600=()
  local pass_600=()
  local recommended_600=""

  mapfile -t ranked_300 < <(find_ranked_pass_profiles 300)
  if [ "${#ranked_300[@]}" -eq 0 ]; then
    write_failure_report "no_300s_pass_candidate"
    build_summary_table
    exit 1
  fi

  winner_300="${ranked_300[0]}"
  run_profile_with_retries "${winner_300}" 600
  tested_600+=("${winner_300}")

  if profile_passes_at_duration "${winner_300}" 600; then
    pass_600+=("${winner_300}")
  fi

  if [ "${#ranked_300[@]}" -ge 2 ]; then
    second_300="${ranked_300[1]}"
    winner_300_thr="$(canonical_result_value "${winner_300}" 300 throughput_bogo_ops_per_sec)"
    second_300_thr="$(canonical_result_value "${second_300}" 300 throughput_bogo_ops_per_sec)"
    if [ -n "${winner_300_thr}" ] && [ -n "${second_300_thr}" ] && float_ge "${second_300_thr}" "$(float_mul "${winner_300_thr}" "0.97")"; then
      run_profile_with_retries "${second_300}" 600
      tested_600+=("${second_300}")
      if profile_passes_at_duration "${second_300}" 600; then
        pass_600+=("${second_300}")
      fi
    fi
  fi

  if [ "${#pass_600[@]}" -gt 0 ]; then
    mapfile -t pass_600 < <(rank_pass_profiles 600 "${pass_600[@]}")
    FINAL_RECOMMENDATION="${pass_600[0]}"
    return 0
  fi

  lower_failed_profile="${tested_600[0]}"
  if [ "${#tested_600[@]}" -ge 2 ]; then
    set_profile_values "${tested_600[0]}"
    local lowest_stapm="${STAPM}"
    local candidate_stapm
    for profile_name in "${tested_600[@]:1}"; do
      set_profile_values "${profile_name}"
      candidate_stapm="${STAPM}"
      if [ "${candidate_stapm}" -lt "${lowest_stapm}" ]; then
        lowest_stapm="${candidate_stapm}"
        lower_failed_profile="${profile_name}"
      fi
    done
  fi

  fallback_profile="$(lower_profile_step "${lower_failed_profile}")"
  if [ -z "${fallback_profile}" ]; then
    write_failure_report "all_600s_failed" "no lower fallback after ${lower_failed_profile}"
    build_summary_table
    exit 1
  fi

  run_profile_with_retries "${fallback_profile}" 600
  if profile_passes_at_duration "${fallback_profile}" 600; then
    FINAL_RECOMMENDATION="${fallback_profile}"
    return 0
  fi

  write_failure_report "all_600s_failed" "fallback=${fallback_profile} abort_reason=${LAST_ABORT_REASON}"
  build_summary_table
  exit 1
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
run_300s_ladder
run_600s_confirmations
build_summary_table
write_success_report "${FINAL_RECOMMENDATION}" "$(detect_bottleneck)"
log "Completed sustained tuning matrix. Winner: ${FINAL_RECOMMENDATION}"
