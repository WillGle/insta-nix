#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Usage: ryzen-test.sh PROFILE_NAME [DURATION_SECONDS]" >&2
  exit 2
fi

PROFILE_NAME="$1"
DURATION="${2:-180}"

if ! [[ "${DURATION}" =~ ^[0-9]+$ ]] || [ "${DURATION}" -lt 1 ]; then
  echo "DURATION_SECONDS must be a positive integer" >&2
  exit 2
fi

OUT="${HOME}/ryzen-test-${PROFILE_NAME}-$(date +%Y%m%d-%H%M%S).log"
SAMPLE_INTERVAL=2
PM_TABLE_PATH="/sys/kernel/ryzen_smu_drv/pm_table"
PM_TABLE_VERSION_PATH="/sys/kernel/ryzen_smu_drv/pm_table_version"
SUPPORTED_PM_TABLE_VERSION="4980744"
PM_TABLE_EXIT_CODE=4
PREFLIGHT_EXIT_CODE=5
THERMAL_ABORT_EXIT_CODE=3
INVALID_POWER_EXIT_CODE=6

RUN_STATE_DIR="$(mktemp -d)"
ABORT_REASON_FILE="${RUN_STATE_DIR}/abort_reason"
INVALID_REASON_FILE="${RUN_STATE_DIR}/invalid_reason"

ABORTED="no"
ABORTED_REASON="none"
INVALID_RUN="no"
INVALID_REASON="none"
BATTERY_DISCHARGING_OBSERVED="no"
THERMAL_ABORT_THRESHOLD_C=""
RUN_START_EPOCH=0
AC_ONLINE_BEFORE="unknown"
AC_ONLINE_AFTER="unknown"
BATTERY_STATUS_BEFORE="unknown"
BATTERY_STATUS_AFTER="unknown"
REQUESTED_DURATION_SEC="${DURATION}"
COMPLETED_DURATION_SEC=0
EXIT_CODE=0
START_TS=0
MANUAL_SIGNAL=0

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

float_gt() {
  awk -v a="$1" -v b="$2" 'BEGIN { exit !(a > b) }'
}

float_ge() {
  awk -v a="$1" -v b="$2" 'BEGIN { exit !(a >= b) }'
}

read_abort_reason() {
  if [ -f "${ABORT_REASON_FILE}" ]; then
    cat "${ABORT_REASON_FILE}"
  else
    echo ""
  fi
}

read_invalid_reason() {
  if [ -f "${INVALID_REASON_FILE}" ]; then
    cat "${INVALID_REASON_FILE}"
  else
    echo ""
  fi
}

set_abort_reason() {
  local reason="$1"
  if [ ! -f "${ABORT_REASON_FILE}" ]; then
    printf '%s\n' "${reason}" > "${ABORT_REASON_FILE}"
  fi
}

set_invalid_reason() {
  local reason="$1"
  if [ ! -f "${INVALID_REASON_FILE}" ]; then
    printf '%s\n' "${reason}" > "${INVALID_REASON_FILE}"
  fi
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

resolve_thermal_abort_threshold() {
  local live_threshold="${1:-}"
  local fallback_threshold="${RYZEN_TEST_TCTL_FALLBACK_C:-}"
  if [ -n "${live_threshold}" ] && [ "${live_threshold}" != "N/A" ]; then
    awk -v v="${live_threshold}" 'BEGIN { printf "%.3f", v }'
    return 0
  fi
  if [[ "${fallback_threshold}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    awk -v v="${fallback_threshold}" 'BEGIN { printf "%.3f", v }'
    return 0
  fi
  return 1
}

cleanup() {
  if [ -n "${MONITOR_PID:-}" ]; then
    kill "${MONITOR_PID}" 2>/dev/null || true
  fi
  if [ -n "${STRESS_PID:-}" ]; then
    kill "${STRESS_PID}" 2>/dev/null || true
  fi
  if [ -n "${SUDO_KEEPALIVE_PID:-}" ]; then
    kill "${SUDO_KEEPALIVE_PID}" 2>/dev/null || true
  fi
  rm -rf "${RUN_STATE_DIR}"
}

handle_signal() {
  MANUAL_SIGNAL=1
  if [ "${ABORTED}" = "no" ]; then
    ABORTED="yes"
    ABORTED_REASON="manual"
  fi
  set_abort_reason "manual"
  if [ -n "${STRESS_PID:-}" ]; then
    kill "${STRESS_PID}" 2>/dev/null || true
  fi
  if [ -n "${MONITOR_PID:-}" ]; then
    kill "${MONITOR_PID}" 2>/dev/null || true
  fi
}

trap cleanup EXIT
trap handle_signal INT TERM

need_cmd powerprofilesctl
need_cmd stress-ng
need_cmd sudo
need_cmd awk
need_cmd od
need_cmd grep
need_cmd date

read_pm_table_version() {
  od -An -tu4 -N4 "${PM_TABLE_VERSION_PATH}" 2>/dev/null | awk 'NF { print $1; exit }'
}

ensure_supported_pm_table() {
  local version
  version="$(read_pm_table_version)"
  if [ ! -r "${PM_TABLE_PATH}" ] || [ -z "${version}" ] || [ "${version}" != "${SUPPORTED_PM_TABLE_VERSION}" ]; then
    echo "Unsupported pm_table_version or pm_table unreadable" >&2
    return 1
  fi
  return 0
}

read_pm_float_at_offset() {
  local offset="$1"
  local value
  value="$(od -An -tfF -j "${offset}" -N 4 "${PM_TABLE_PATH}" 2>/dev/null | awk 'NF { print $1; exit }')"
  if [ -n "${value}" ]; then
    awk -v v="${value}" 'BEGIN { printf "%.3f", v }'
  else
    echo "N/A"
  fi
}

read_pm_snapshot() {
  printf "%s %s %s %s %s %s %s %s %s %s\n" \
    "$(read_pm_float_at_offset 0)" \
    "$(read_pm_float_at_offset 4)" \
    "$(read_pm_float_at_offset 8)" \
    "$(read_pm_float_at_offset 12)" \
    "$(read_pm_float_at_offset 16)" \
    "$(read_pm_float_at_offset 20)" \
    "$(read_pm_float_at_offset 64)" \
    "$(read_pm_float_at_offset 68)" \
    "$(read_pm_float_at_offset 88)" \
    "$(read_pm_float_at_offset 92)"
}

read_cpu_temp() {
  local hwmon name temp
  for hwmon in /sys/class/hwmon/hwmon*/; do
    name="$(cat "${hwmon}name" 2>/dev/null || true)"
    if [ "${name}" = "k10temp" ]; then
      temp="$(cat "${hwmon}temp2_input" 2>/dev/null || cat "${hwmon}temp1_input" 2>/dev/null || true)"
      if [ -n "${temp}" ]; then
        awk -v v="${temp}" 'BEGIN { printf "%.1f", v/1000 }'
        return
      fi
    fi
  done
  echo "N/A"
}

read_max_freq_mhz() {
  local max=0
  local value
  for value_file in /sys/devices/system/cpu/cpufreq/policy*/scaling_cur_freq; do
    value="$(cat "${value_file}" 2>/dev/null || true)"
    if [ -n "${value}" ] && [ "${value}" -gt "${max}" ] 2>/dev/null; then
      max="${value}"
    fi
  done
  awk -v v="${max}" 'BEGIN { printf "%.0f", v/1000 }'
}

read_avg_freq_mhz() {
  local sum=0
  local count=0
  local value
  for value_file in /sys/devices/system/cpu/cpufreq/policy*/scaling_cur_freq; do
    value="$(cat "${value_file}" 2>/dev/null || true)"
    if [ -n "${value}" ]; then
      sum=$((sum + value))
      count=$((count + 1))
    fi
  done
  if [ "${count}" -gt 0 ]; then
    awk -v s="${sum}" -v c="${count}" 'BEGIN { printf "%.0f", s/c/1000 }'
  else
    echo "N/A"
  fi
}

if ! ensure_supported_pm_table; then
  exit "${PM_TABLE_EXIT_CODE}"
fi

AC_ONLINE_BEFORE="$(read_ac_online)"
BATTERY_STATUS_BEFORE="$(read_battery_status)"
THERMAL_ABORT_THRESHOLD_C="$(resolve_thermal_abort_threshold "$(read_pm_float_at_offset 64)")" || {
  echo "Unable to determine thermal abort threshold" >&2
  exit "${PREFLIGHT_EXIT_CODE}"
}

echo "Logging to: ${OUT}"

if ! sudo -v; then
  exit "${PREFLIGHT_EXIT_CODE}"
fi

(
  while true; do
    if ! sudo -n true >/dev/null 2>&1; then
      break
    fi
    sleep 30
  done
) &
SUDO_KEEPALIVE_PID=$!

{
  echo "===== SYSTEM STATE BEFORE TEST ====="
  date
  echo
  echo "powerprofilesctl:"
  powerprofilesctl get || true
  echo
  echo "platform_profile:"
  cat /sys/firmware/acpi/platform_profile 2>/dev/null || true
  echo
  echo "cpufreq driver:"
  cat /sys/devices/system/cpu/cpufreq/policy0/scaling_driver 2>/dev/null || true
  echo
  echo "governor:"
  cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null || true
  echo
  echo "EPP:"
  grep . /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference 2>/dev/null || true
  echo
  echo "boost:"
  cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || true
  echo
  echo "pm_table_version:"
  echo "${SUPPORTED_PM_TABLE_VERSION} (expected)"
  echo "$(read_pm_table_version) (actual)"
  echo
  echo "thermal_abort_threshold_c:"
  echo "${THERMAL_ABORT_THRESHOLD_C}"
  echo
  echo "ac_online_before:"
  echo "${AC_ONLINE_BEFORE}"
  echo
  echo "battery_status_before:"
  echo "${BATTERY_STATUS_BEFORE}"
  echo
  echo "pm_table_snapshot_before:"
  echo "stapm_limit_w stapm_value_w fast_limit_w fast_value_w slow_limit_w slow_value_w tctl_limit_c tctl_value_c skin_limit_c skin_value_c"
  read_pm_snapshot
  echo
  echo "===== STRESS START ====="
  printf "%-10s %-7s %-11s %-11s %-11s %-11s %-11s %-11s %-11s %-11s %-11s %-11s %-11s %-11s\n" \
    "time" "TdieC" "maxFreqMHz" "avgFreqMHz" "stapmLimitW" "stapmValueW" "fastLimitW" "fastValueW" "slowLimitW" "slowValueW" "tctlLimitC" "tctlValueC" "skinLimitC" "skinValueC"
} | tee "${OUT}"

START_TS="$(date +%s)"
RUN_START_EPOCH="${START_TS}"

stress-ng --cpu "$(nproc)" --timeout "${DURATION}s" --metrics-brief > >(tee -a "${OUT}") 2>&1 &
STRESS_PID=$!

(
  local_tdie_limit_hits=0
  local_skin_limit_hits=0

  while kill -0 "${STRESS_PID}" 2>/dev/null; do
    ts="$(date '+%H:%M:%S')"
    temp="$(read_cpu_temp)"
    maxf="$(read_max_freq_mhz)"
    avgf="$(read_avg_freq_mhz)"
    current_ac_online="$(read_ac_online)"
    current_battery_status="$(read_battery_status)"
    read -r stapm_limit stapm_value fast_limit fast_value slow_limit slow_value tctl_limit tctl_value skin_limit skin_value <<<"$(read_pm_snapshot)"

    printf "%-10s %-7s %-11s %-11s %-11s %-11s %-11s %-11s %-11s %-11s %-11s %-11s %-11s %-11s\n" \
      "${ts}" "${temp}" "${maxf}" "${avgf}" "${stapm_limit}" "${stapm_value}" "${fast_limit}" "${fast_value}" "${slow_limit}" "${slow_value}" "${tctl_limit}" "${tctl_value}" "${skin_limit}" "${skin_value}" >> "${OUT}" 2>&1

    if [ "${current_ac_online}" = "no" ]; then
      set_invalid_reason "ac_drop"
      set_abort_reason "ac_drop"
      kill "${STRESS_PID}" 2>/dev/null || true
      break
    fi

    if battery_is_discharging; then
      set_invalid_reason "battery_discharging"
      set_abort_reason "battery_discharging"
      kill "${STRESS_PID}" 2>/dev/null || true
      break
    fi

    if [ "${temp}" != "N/A" ] && float_ge "${temp}" "${THERMAL_ABORT_THRESHOLD_C}"; then
      local_tdie_limit_hits=$((local_tdie_limit_hits + 1))
    else
      local_tdie_limit_hits=0
    fi

    if [ "${skin_limit}" != "N/A" ] && [ "${skin_value}" != "N/A" ] && float_gt "${skin_value}" "$(awk -v limit="${skin_limit}" 'BEGIN { printf "%.3f", limit + 0.7 }')"; then
      local_skin_limit_hits=$((local_skin_limit_hits + 1))
    else
      local_skin_limit_hits=0
    fi

    if [ "${local_tdie_limit_hits}" -ge 5 ]; then
      set_abort_reason "tdie_limit"
      kill "${STRESS_PID}" 2>/dev/null || true
      break
    fi

    if [ "${local_skin_limit_hits}" -ge 3 ]; then
      set_abort_reason "skin_limit"
      kill "${STRESS_PID}" 2>/dev/null || true
      break
    fi

    sleep "${SAMPLE_INTERVAL}"
  done
) &
MONITOR_PID=$!

set +e
wait "${STRESS_PID}"
STRESS_STATUS=$?
set -e

END_TS="$(date +%s)"
COMPLETED_DURATION_SEC=$((END_TS - START_TS))

kill "${MONITOR_PID}" 2>/dev/null || true
wait "${MONITOR_PID}" 2>/dev/null || true
MONITOR_PID=""

ABORT_REASON_FROM_FILE="$(read_abort_reason)"
INVALID_REASON_FROM_FILE="$(read_invalid_reason)"
if [ -n "${ABORT_REASON_FROM_FILE}" ]; then
  ABORTED="yes"
  ABORTED_REASON="${ABORT_REASON_FROM_FILE}"
fi

if [ -n "${INVALID_REASON_FROM_FILE}" ]; then
  INVALID_RUN="yes"
  INVALID_REASON="${INVALID_REASON_FROM_FILE}"
  ABORTED="yes"
  if [ "${ABORTED_REASON}" = "none" ]; then
    ABORTED_REASON="${INVALID_REASON_FROM_FILE}"
  fi
fi

AC_ONLINE_AFTER="$(read_ac_online)"
BATTERY_STATUS_AFTER="$(read_battery_status)"
if [ "${INVALID_REASON}" = "battery_discharging" ] || battery_is_discharging; then
  BATTERY_DISCHARGING_OBSERVED="yes"
fi

if [ "${INVALID_RUN}" = "yes" ]; then
  EXIT_CODE="${INVALID_POWER_EXIT_CODE}"
elif [ "${ABORTED_REASON}" = "tdie_limit" ] || [ "${ABORTED_REASON}" = "skin_limit" ]; then
  EXIT_CODE="${THERMAL_ABORT_EXIT_CODE}"
elif [ "${ABORTED_REASON}" = "manual" ] || [ "${MANUAL_SIGNAL}" -eq 1 ]; then
  ABORTED="yes"
  ABORTED_REASON="manual"
  EXIT_CODE=130
elif [ "${STRESS_STATUS}" -ne 0 ]; then
  ABORTED="yes"
  ABORTED_REASON="other"
  EXIT_CODE="${STRESS_STATUS}"
fi

throughput="$(grep 'stress-ng: metrc:' "${OUT}" | grep -E '[[:space:]]cpu[[:space:]]+[0-9]' | tail -1 | awk '{ print $(NF-1) }')"

{
  echo
  echo "===== LIVE SAMPLE SUMMARY ====="
  grep -E '^[0-9]{2}:[0-9]{2}:[0-9]{2}[[:space:]]' "${OUT}" | awk -v throughput="${throughput:-N/A}" '
  function set_minmax(value, count, min_name, max_name, sum_name,   current) {
    current = value + 0
    if (count == 0 || current < mins[min_name]) {
      mins[min_name] = current
    }
    if (count == 0 || current > maxs[max_name]) {
      maxs[max_name] = current
    }
    sums[sum_name] += current
  }
  function render_num(count, value, fmt) {
    if (count > 0) {
      return sprintf(fmt, value)
    }
    return "N/A"
  }
  {
    temp=$2; maxf=$3; avgf=$4
    stapm_limit=$5; stapm_value=$6
    fast_limit=$7; fast_value=$8
    slow_limit=$9; slow_value=$10
    tctl_limit=$11; tctl_value=$12
    skin_limit=$13; skin_value=$14

    if (temp != "N/A") {
      set_minmax(temp, tcnt, "tdie", "tdie", "tdie")
      tcnt++
    }
    if (maxf != "N/A") {
      set_minmax(maxf, maxfcnt, "maxf", "maxf", "maxf")
      maxfcnt++
    }
    if (avgf != "N/A") {
      sums["avgf"] += avgf + 0
      avgfcnt++
    }
    if (stapm_value != "N/A") {
      set_minmax(stapm_value, stapmcnt, "stapm", "stapm", "stapm")
      stapmcnt++
    }
    if (fast_value != "N/A") {
      set_minmax(fast_value, fastcnt, "fast", "fast", "fast")
      fastcnt++
    }
    if (slow_value != "N/A") {
      set_minmax(slow_value, slowcnt, "slow", "slow", "slow")
      slowcnt++
    }
    if (tctl_value != "N/A") {
      set_minmax(tctl_value, tctlcnt, "tctl", "tctl", "tctl")
      tctlcnt++
    }
    if (skin_value != "N/A") {
      set_minmax(skin_value, skincnt, "skin", "skin", "skin")
      skincnt++
    }

    hit = 0
    if (skin_limit != "N/A" && skin_value != "N/A" && (skin_value + 0) >= ((skin_limit + 0) - 0.5)) {
      hit = 1
    }
    if (hit) {
      skin_run++
      if (skin_run >= 3) {
        skin_hit = "yes"
      }
    } else {
      skin_run = 0
    }

    clamp = 0
    if (stapm_limit != "N/A" && stapm_value != "N/A" && (stapm_value + 0) <= (0.8 * (stapm_limit + 0))) {
      clamp = 1
    }
    if (hit && clamp) {
      clamp_run++
      if (clamp_run >= 3) {
        stapm_clamped = "yes"
      }
    } else {
      clamp_run = 0
    }
  }
  END {
    if (skin_hit == "") {
      skin_hit = "no"
    }
    if (stapm_clamped == "") {
      stapm_clamped = "no"
    }

    tdie_min = render_num(tcnt, mins["tdie"], "%.1f")
    tdie_max = render_num(tcnt, maxs["tdie"], "%.1f")
    tdie_avg = render_num(tcnt, (tcnt > 0 ? sums["tdie"] / tcnt : 0), "%.1f")
    maxf_min = render_num(maxfcnt, mins["maxf"], "%.0f")
    maxf_max = render_num(maxfcnt, maxs["maxf"], "%.0f")
    maxf_avg = render_num(maxfcnt, (maxfcnt > 0 ? sums["maxf"] / maxfcnt : 0), "%.0f")
    avgf_avg = render_num(avgfcnt, (avgfcnt > 0 ? sums["avgf"] / avgfcnt : 0), "%.0f")
    stapm_min = render_num(stapmcnt, mins["stapm"], "%.3f")
    stapm_max = render_num(stapmcnt, maxs["stapm"], "%.3f")
    stapm_avg = render_num(stapmcnt, (stapmcnt > 0 ? sums["stapm"] / stapmcnt : 0), "%.3f")
    fast_min = render_num(fastcnt, mins["fast"], "%.3f")
    fast_max = render_num(fastcnt, maxs["fast"], "%.3f")
    fast_avg = render_num(fastcnt, (fastcnt > 0 ? sums["fast"] / fastcnt : 0), "%.3f")
    slow_min = render_num(slowcnt, mins["slow"], "%.3f")
    slow_max = render_num(slowcnt, maxs["slow"], "%.3f")
    slow_avg = render_num(slowcnt, (slowcnt > 0 ? sums["slow"] / slowcnt : 0), "%.3f")
    tctl_min = render_num(tctlcnt, mins["tctl"], "%.3f")
    tctl_max = render_num(tctlcnt, maxs["tctl"], "%.3f")
    tctl_avg = render_num(tctlcnt, (tctlcnt > 0 ? sums["tctl"] / tctlcnt : 0), "%.3f")
    skin_min = render_num(skincnt, mins["skin"], "%.3f")
    skin_max = render_num(skincnt, maxs["skin"], "%.3f")
    skin_avg = render_num(skincnt, (skincnt > 0 ? sums["skin"] / skincnt : 0), "%.3f")

    printf "Throughput: %s bogo ops/s (real time)\n", throughput
    printf "Tdie       : min=%sC max=%sC avg=%sC\n", tdie_min, tdie_max, tdie_avg
    printf "maxFreq    : min=%sMHz max=%sMHz avg=%sMHz\n", maxf_min, maxf_max, maxf_avg
    printf "avgFreq    : avg=%sMHz (all cores)\n", avgf_avg
    printf "STAPM VALUE: min=%sW max=%sW avg=%sW\n", stapm_min, stapm_max, stapm_avg
    printf "FAST VALUE : min=%sW max=%sW avg=%sW\n", fast_min, fast_max, fast_avg
    printf "SLOW VALUE : min=%sW max=%sW avg=%sW\n", slow_min, slow_max, slow_avg
    printf "Tctl VALUE : min=%sC max=%sC avg=%sC\n", tctl_min, tctl_max, tctl_avg
    printf "Skin VALUE : min=%sC max=%sC avg=%sC\n", skin_min, skin_max, skin_avg
    printf "skin_hit=%s\n", skin_hit
    printf "stapm_clamped=%s\n", stapm_clamped

    printf "SUMMARY throughput_bogo_ops_per_sec=%s\n", throughput
    printf "SUMMARY tdie_min_c=%s\n", tdie_min
    printf "SUMMARY tdie_max_c=%s\n", tdie_max
    printf "SUMMARY tdie_avg_c=%s\n", tdie_avg
    printf "SUMMARY max_freq_min_mhz=%s\n", maxf_min
    printf "SUMMARY max_freq_max_mhz=%s\n", maxf_max
    printf "SUMMARY max_freq_avg_mhz=%s\n", maxf_avg
    printf "SUMMARY avg_freq_avg_mhz=%s\n", avgf_avg
    printf "SUMMARY stapm_value_min_w=%s\n", stapm_min
    printf "SUMMARY stapm_value_max_w=%s\n", stapm_max
    printf "SUMMARY stapm_value_avg_w=%s\n", stapm_avg
    printf "SUMMARY fast_value_min_w=%s\n", fast_min
    printf "SUMMARY fast_value_max_w=%s\n", fast_max
    printf "SUMMARY fast_value_avg_w=%s\n", fast_avg
    printf "SUMMARY slow_value_min_w=%s\n", slow_min
    printf "SUMMARY slow_value_max_w=%s\n", slow_max
    printf "SUMMARY slow_value_avg_w=%s\n", slow_avg
    printf "SUMMARY tctl_value_min_c=%s\n", tctl_min
    printf "SUMMARY tctl_value_max_c=%s\n", tctl_max
    printf "SUMMARY tctl_value_avg_c=%s\n", tctl_avg
    printf "SUMMARY skin_value_min_c=%s\n", skin_min
    printf "SUMMARY skin_value_max_c=%s\n", skin_max
    printf "SUMMARY skin_value_avg_c=%s\n", skin_avg
    printf "SUMMARY skin_hit=%s\n", skin_hit
    printf "SUMMARY stapm_clamped=%s\n", stapm_clamped
  }'
  echo "aborted=${ABORTED}"
  echo "aborted_reason=${ABORTED_REASON}"
  echo "invalid_run=${INVALID_RUN}"
  echo "invalid_reason=${INVALID_REASON}"
  echo "completed_duration_sec=${COMPLETED_DURATION_SEC}"
  echo "requested_duration_sec=${REQUESTED_DURATION_SEC}"
  echo "run_start_epoch=${RUN_START_EPOCH}"
  echo "thermal_abort_threshold_c=${THERMAL_ABORT_THRESHOLD_C}"
  echo "ac_online_before=${AC_ONLINE_BEFORE}"
  echo "ac_online_after=${AC_ONLINE_AFTER}"
  echo "battery_status_before=${BATTERY_STATUS_BEFORE}"
  echo "battery_status_after=${BATTERY_STATUS_AFTER}"
  echo "battery_discharging_observed=${BATTERY_DISCHARGING_OBSERVED}"
  echo "SUMMARY aborted=${ABORTED}"
  echo "SUMMARY aborted_reason=${ABORTED_REASON}"
  echo "SUMMARY invalid_run=${INVALID_RUN}"
  echo "SUMMARY invalid_reason=${INVALID_REASON}"
  echo "SUMMARY completed_duration_sec=${COMPLETED_DURATION_SEC}"
  echo "SUMMARY requested_duration_sec=${REQUESTED_DURATION_SEC}"
  echo "SUMMARY run_start_epoch=${RUN_START_EPOCH}"
  echo "SUMMARY thermal_abort_threshold_c=${THERMAL_ABORT_THRESHOLD_C}"
  echo "SUMMARY ac_online_before=${AC_ONLINE_BEFORE}"
  echo "SUMMARY ac_online_after=${AC_ONLINE_AFTER}"
  echo "SUMMARY battery_status_before=${BATTERY_STATUS_BEFORE}"
  echo "SUMMARY battery_status_after=${BATTERY_STATUS_AFTER}"
  echo "SUMMARY battery_discharging_observed=${BATTERY_DISCHARGING_OBSERVED}"
  echo
  echo "===== SYSTEM STATE AFTER TEST ====="
  date
  echo
  echo "pm_table_snapshot_after:"
  echo "stapm_limit_w stapm_value_w fast_limit_w fast_value_w slow_limit_w slow_value_w tctl_limit_c tctl_value_c skin_limit_c skin_value_c"
  read_pm_snapshot
  echo
  echo "dmesg errors:"
  sudo dmesg -T | grep -Ei "mce|hardware error|thermal|throttle|amdgpu error" | tail -20 || true
} | tee -a "${OUT}"

printf '%s\n' "Done: ${OUT}"

exit "${EXIT_CODE}"
