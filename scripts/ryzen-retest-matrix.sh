#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: ryzen-retest-matrix.sh --root DIR --phase burst|sustained|tiebreak|report
EOF
}

ROOT=""
PHASE=""

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
    --phase)
      if [ "$#" -lt 2 ]; then
        usage
        exit 2
      fi
      PHASE="$2"
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [ -z "${ROOT}" ] || [ -z "${PHASE}" ]; then
  usage
  exit 2
fi

TEST_SCRIPT="$(cd "$(dirname "$0")" && pwd)/ryzen-test.sh"
RYZENADJ_BIN="/run/current-system/sw/bin/ryzenadj"
RUNNER_LOG="${ROOT}/runner.log"
RESULTS_TSV="${ROOT}/results.tsv"
SUMMARY_TSV="${ROOT}/summary.tsv"
WINNER_TXT="${ROOT}/winner.txt"
STATE_ENV="${ROOT}/state.env"
SCENARIOS=(A B C D E)
BURST_DURATION=30
SUSTAINED_DURATION=300
TIEBREAK_DURATION=600
SUPPORTED_PM_TABLE_VERSION="4980744"

IDLE_TEMP_C=""
BURST_COMPLETE=0
SUSTAINED_COMPLETE=0
TIEBREAK_COMPLETE=0
QUALIFIED_SCENARIOS=""
EXCLUDED_SCENARIOS=""
TOP1=""
TOP2=""
COMPARE_DURATION=""
WINNER=""

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

log() {
  printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" | tee -a "${RUNNER_LOG}"
}

float_lt() {
  awk -v a="$1" -v b="$2" 'BEGIN { exit !(a < b) }'
}

float_le() {
  awk -v a="$1" -v b="$2" 'BEGIN { exit !(a <= b) }'
}

float_gt() {
  awk -v a="$1" -v b="$2" 'BEGIN { exit !(a > b) }'
}

float_ge() {
  awk -v a="$1" -v b="$2" 'BEGIN { exit !(a >= b) }'
}

float_add() {
  awk -v a="$1" -v b="$2" 'BEGIN { printf "%.6f", a + b }'
}

float_mul() {
  awk -v a="$1" -v b="$2" 'BEGIN { printf "%.6f", a * b }'
}

float_range_width() {
  awk -v min="$1" -v max="$2" 'BEGIN { printf "%.6f", max - min }'
}

scenario_name() {
  case "$1" in
    A) echo "baseline54_skin42" ;;
    B) echo "repo56_skin43" ;;
    C) echo "efficiency50_skin42" ;;
    D) echo "skin44_probe" ;;
    E) echo "time120_skin43" ;;
    *) echo "unknown" ;;
  esac
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

ensure_root_files() {
  mkdir -p "${ROOT}"
  touch "${RUNNER_LOG}"
  if [ ! -f "${RESULTS_TSV}" ]; then
    printf 'scenario\tduration\tthroughput_bogo_ops_per_sec\ttdie_avg_c\ttdie_max_c\tmax_freq_avg_mhz\tavg_freq_avg_mhz\tstapm_value_avg_w\tfast_value_avg_w\tslow_value_avg_w\tskin_value_max_c\tskin_hit\tstapm_clamped\taborted\taborted_reason\tlog_path\n' > "${RESULTS_TSV}"
  fi
  if [ ! -f "${STATE_ENV}" ]; then
    save_state
  fi
}

save_state() {
  cat > "${STATE_ENV}" <<EOF
IDLE_TEMP_C="${IDLE_TEMP_C}"
BURST_COMPLETE=${BURST_COMPLETE}
SUSTAINED_COMPLETE=${SUSTAINED_COMPLETE}
TIEBREAK_COMPLETE=${TIEBREAK_COMPLETE}
QUALIFIED_SCENARIOS="${QUALIFIED_SCENARIOS}"
EXCLUDED_SCENARIOS="${EXCLUDED_SCENARIOS}"
TOP1="${TOP1}"
TOP2="${TOP2}"
COMPARE_DURATION="${COMPARE_DURATION}"
WINNER="${WINNER}"
EOF
}

load_state() {
  if [ -f "${STATE_ENV}" ]; then
    # shellcheck disable=SC1090
    . "${STATE_ENV}"
  fi
}

check_pm_table_version() {
  local version
  version="$(od -An -tu4 -N4 /sys/kernel/ryzen_smu_drv/pm_table_version 2>/dev/null | awk 'NF { print $1; exit }')"
  if [ "${version}" != "${SUPPORTED_PM_TABLE_VERSION}" ]; then
    echo "Unsupported pm_table_version: ${version:-unknown}" >&2
    exit 1
  fi
}

run_preflight() {
  log "Running performance preflight"
  sudo -v
  sudo powerprofilesctl set performance
  echo performance | sudo tee /sys/firmware/acpi/platform_profile >/dev/null
  for policy in /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference; do
    echo performance | sudo tee "${policy}" >/dev/null
  done
  echo 0 | sudo tee /proc/sys/kernel/sched_autogroup_enabled >/dev/null

  local profile platform governor mismatches
  profile="$(powerprofilesctl get)"
  platform="$(cat /sys/firmware/acpi/platform_profile)"
  governor="$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor)"
  mismatches="$(grep -L '^performance$' /sys/devices/system/cpu/cpufreq/policy*/energy_performance_preference 2>/dev/null || true)"

  if [ "${profile}" != "performance" ] || [ "${platform}" != "performance" ] || [ "${governor}" != "performance" ] || [ -n "${mismatches}" ]; then
    echo "Preflight verification failed" >&2
    echo "powerprofilesctl=${profile}" >&2
    echo "platform_profile=${platform}" >&2
    echo "governor=${governor}" >&2
    printf '%s\n' "${mismatches}" >&2
    exit 1
  fi
}

wait_for_idle_baseline() {
  log "Idling for 180 seconds before burst phase"
  sleep 180
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
      break
    fi
    sleep 15
  done
}

apply_scenario() {
  local scenario="$1"
  local cmd=()

  case "${scenario}" in
    A)
      cmd=(
        sudo "${RYZENADJ_BIN}"
        --stapm-limit=54000
        --fast-limit=70000
        --slow-limit=65000
        --tctl-temp=97
        --apu-skin-temp=42
        --vrm-current=90000
        --vrmmax-current=110000
        --max-performance
      )
      ;;
    B)
      cmd=(
        sudo "${RYZENADJ_BIN}"
        --stapm-limit=56000
        --fast-limit=72000
        --slow-limit=67000
        --tctl-temp=97
        --apu-skin-temp=43
        --vrm-current=85000
        --vrmmax-current=105000
        --max-performance
      )
      ;;
    C)
      cmd=(
        sudo "${RYZENADJ_BIN}"
        --stapm-limit=50000
        --fast-limit=65000
        --slow-limit=60000
        --tctl-temp=97
        --apu-skin-temp=42
        --vrm-current=90000
        --vrmmax-current=110000
        --max-performance
      )
      ;;
    D)
      cmd=(
        sudo "${RYZENADJ_BIN}"
        --stapm-limit=54000
        --fast-limit=70000
        --slow-limit=65000
        --tctl-temp=97
        --apu-skin-temp=44
        --vrm-current=90000
        --vrmmax-current=110000
        --max-performance
      )
      ;;
    E)
      cmd=(
        sudo "${RYZENADJ_BIN}"
        --stapm-limit=54000
        --fast-limit=70000
        --slow-limit=65000
        --stapm-time=120
        --slow-time=120
        --tctl-temp=97
        --apu-skin-temp=43
        --vrm-current=90000
        --vrmmax-current=110000
        --max-performance
      )
      ;;
    *)
      echo "Unknown scenario: ${scenario}" >&2
      exit 2
      ;;
  esac

  log "Applying scenario ${scenario} ($(scenario_name "${scenario}"))"
  "${cmd[@]}" 2>&1 | tee -a "${RUNNER_LOG}"
}

summary_value() {
  local log_path="$1"
  local key="$2"
  awk -F= -v key="SUMMARY ${key}" '$1 == key { print $2 }' "${log_path}" | tail -1
}

result_value() {
  local scenario="$1"
  local duration="$2"
  local column="$3"
  awk -F'\t' -v scenario="${scenario}" -v duration="${duration}" -v column="${column}" '
    NR == 1 {
      for (i = 1; i <= NF; i++) {
        if ($i == column) {
          col = i
        }
      }
      next
    }
    $1 == scenario && $2 == duration {
      value = $col
    }
    END {
      print value
    }
  ' "${RESULTS_TSV}"
}

delete_result_row() {
  local scenario="$1"
  local duration="$2"
  local tmp
  tmp="$(mktemp)"
  awk -F'\t' -v scenario="${scenario}" -v duration="${duration}" 'NR == 1 || !($1 == scenario && $2 == duration)' "${RESULTS_TSV}" > "${tmp}"
  mv "${tmp}" "${RESULTS_TSV}"
}

log_has_hard_dmesg_issue() {
  local log_path="$1"
  awk '
    /^dmesg errors:/ { in_dmesg = 1; next }
    in_dmesg { print }
  ' "${log_path}" | grep -Eiv 'In-kernel MCE decoding enabled|Registered thermal governor|registered as thermal_zone|ACPI: thermal:' | \
    grep -Eiq 'hardware error|thermal throttle|throttled|machine check|mce:'
}

record_metrics() {
  local scenario="$1"
  local duration="$2"
  local log_path="$3"

  delete_result_row "${scenario}" "${duration}"

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${scenario}" \
    "${duration}" \
    "$(summary_value "${log_path}" throughput_bogo_ops_per_sec)" \
    "$(summary_value "${log_path}" tdie_avg_c)" \
    "$(summary_value "${log_path}" tdie_max_c)" \
    "$(summary_value "${log_path}" max_freq_avg_mhz)" \
    "$(summary_value "${log_path}" avg_freq_avg_mhz)" \
    "$(summary_value "${log_path}" stapm_value_avg_w)" \
    "$(summary_value "${log_path}" fast_value_avg_w)" \
    "$(summary_value "${log_path}" slow_value_avg_w)" \
    "$(summary_value "${log_path}" skin_value_max_c)" \
    "$(summary_value "${log_path}" skin_hit)" \
    "$(summary_value "${log_path}" stapm_clamped)" \
    "$(summary_value "${log_path}" aborted)" \
    "$(summary_value "${log_path}" aborted_reason)" \
    "${log_path}" >> "${RESULTS_TSV}"
}

run_case() {
  local scenario="$1"
  local duration="$2"
  local output status log_path

  apply_scenario "${scenario}"

  set +e
  output="$("${TEST_SCRIPT}" "scenario${scenario}-${duration}s" "${duration}" 2>&1)"
  status=$?
  set -e

  printf '%s\n' "${output}" | tee -a "${RUNNER_LOG}" >/dev/null
  log_path="$(printf '%s\n' "${output}" | awk '/^Done: /{print $2}' | tail -1)"

  if [ -z "${log_path}" ] || [ ! -f "${log_path}" ]; then
    echo "Unable to locate log path for scenario ${scenario} duration ${duration}" >&2
    return 1
  fi

  record_metrics "${scenario}" "${duration}" "${log_path}"
  return "${status}"
}

ordered_scenarios_from_list() {
  local list="$1"
  local scenario output=()
  for scenario in "${SCENARIOS[@]}"; do
    case " ${list} " in
      *" ${scenario} "*) output+=("${scenario}") ;;
    esac
  done
  printf '%s\n' "${output[@]}"
}

scenario_is_aborted() {
  local scenario="$1"
  local duration="$2"
  [ "$(result_value "${scenario}" "${duration}" aborted)" = "yes" ]
}

scenario_has_hard_issue() {
  local scenario="$1"
  local duration="$2"
  local log_path
  log_path="$(result_value "${scenario}" "${duration}" log_path)"
  if [ -z "${log_path}" ] || [ ! -f "${log_path}" ]; then
    return 1
  fi
  log_has_hard_dmesg_issue "${log_path}"
}

scenario_allowed_for_sustained() {
  local scenario="$1"
  local a_thr a_tdie_avg a_tdie_max scenario_thr scenario_tdie_avg scenario_tdie_max scenario_skin_hit

  if scenario_is_aborted "${scenario}" "${BURST_DURATION}"; then
    return 1
  fi
  if scenario_has_hard_issue "${scenario}" "${BURST_DURATION}"; then
    return 1
  fi

  case "${scenario}" in
    A|B|C)
      return 0
      ;;
  esac

  a_thr="$(result_value A "${BURST_DURATION}" throughput_bogo_ops_per_sec)"
  a_tdie_avg="$(result_value A "${BURST_DURATION}" tdie_avg_c)"
  a_tdie_max="$(result_value A "${BURST_DURATION}" tdie_max_c)"
  scenario_thr="$(result_value "${scenario}" "${BURST_DURATION}" throughput_bogo_ops_per_sec)"
  scenario_tdie_avg="$(result_value "${scenario}" "${BURST_DURATION}" tdie_avg_c)"
  scenario_tdie_max="$(result_value "${scenario}" "${BURST_DURATION}" tdie_max_c)"
  scenario_skin_hit="$(result_value "${scenario}" "${BURST_DURATION}" skin_hit)"

  if [ -z "${a_thr}" ] || [ -z "${scenario_thr}" ]; then
    return 1
  fi

  if float_ge "${scenario_thr}" "$(float_mul "${a_thr}" "1.02")" && \
     float_le "${scenario_tdie_max}" "$(float_add "${a_tdie_max}" "2")"; then
    return 0
  fi

  if float_ge "${scenario_thr}" "$(float_mul "${a_thr}" "0.99")" && \
     float_lt "${scenario_tdie_avg}" "${a_tdie_avg}" && \
     [ "${scenario_skin_hit}" = "no" ]; then
    return 0
  fi

  return 1
}

build_summary_table() {
  local scenario qualified
  printf 'scenario\tqualified_for_sustained\tthroughput_30s\tthroughput_300s\tthroughput_600s\ttdie_avg_300s\ttdie_max_300s\tmax_freq_avg_300s\tavg_freq_avg_300s\tstapm_value_avg_300s\tfast_value_avg_300s\tslow_value_avg_300s\tskin_value_max_300s\tskin_hit_300s\tstapm_clamped_300s\taborted_30s\taborted_300s\taborted_600s\tlog_30s\tlog_300s\tlog_600s\n' > "${SUMMARY_TSV}"
  for scenario in "${SCENARIOS[@]}"; do
    qualified="no"
    case " ${QUALIFIED_SCENARIOS} " in
      *" ${scenario} "*) qualified="yes" ;;
    esac

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "${scenario}" \
      "${qualified}" \
      "$(result_value "${scenario}" "${BURST_DURATION}" throughput_bogo_ops_per_sec)" \
      "$(result_value "${scenario}" "${SUSTAINED_DURATION}" throughput_bogo_ops_per_sec)" \
      "$(result_value "${scenario}" "${TIEBREAK_DURATION}" throughput_bogo_ops_per_sec)" \
      "$(result_value "${scenario}" "${SUSTAINED_DURATION}" tdie_avg_c)" \
      "$(result_value "${scenario}" "${SUSTAINED_DURATION}" tdie_max_c)" \
      "$(result_value "${scenario}" "${SUSTAINED_DURATION}" max_freq_avg_mhz)" \
      "$(result_value "${scenario}" "${SUSTAINED_DURATION}" avg_freq_avg_mhz)" \
      "$(result_value "${scenario}" "${SUSTAINED_DURATION}" stapm_value_avg_w)" \
      "$(result_value "${scenario}" "${SUSTAINED_DURATION}" fast_value_avg_w)" \
      "$(result_value "${scenario}" "${SUSTAINED_DURATION}" slow_value_avg_w)" \
      "$(result_value "${scenario}" "${SUSTAINED_DURATION}" skin_value_max_c)" \
      "$(result_value "${scenario}" "${SUSTAINED_DURATION}" skin_hit)" \
      "$(result_value "${scenario}" "${SUSTAINED_DURATION}" stapm_clamped)" \
      "$(result_value "${scenario}" "${BURST_DURATION}" aborted)" \
      "$(result_value "${scenario}" "${SUSTAINED_DURATION}" aborted)" \
      "$(result_value "${scenario}" "${TIEBREAK_DURATION}" aborted)" \
      "$(result_value "${scenario}" "${BURST_DURATION}" log_path)" \
      "$(result_value "${scenario}" "${SUSTAINED_DURATION}" log_path)" \
      "$(result_value "${scenario}" "${TIEBREAK_DURATION}" log_path)" >> "${SUMMARY_TSV}"
  done
}

write_failure_report() {
  local reason="$1"
  local details="${2:-}"
  {
    echo "status=failure"
    echo "reason=${reason}"
    if [ -n "${details}" ]; then
      echo "details=${details}"
    fi
    echo "burst_complete=${BURST_COMPLETE}"
    echo "sustained_complete=${SUSTAINED_COMPLETE}"
    echo "tiebreak_complete=${TIEBREAK_COMPLETE}"
    echo "qualified_scenarios=${QUALIFIED_SCENARIOS}"
    echo "excluded_scenarios=${EXCLUDED_SCENARIOS}"
  } > "${WINNER_TXT}"
}

valid_compare_scenarios() {
  local duration="$1"
  local scenario aborted throughput output=()
  for scenario in $(ordered_scenarios_from_list "${QUALIFIED_SCENARIOS}"); do
    throughput="$(result_value "${scenario}" "${duration}" throughput_bogo_ops_per_sec)"
    aborted="$(result_value "${scenario}" "${duration}" aborted)"
    if [ -n "${throughput}" ] && [ "${aborted}" != "yes" ]; then
      output+=("${scenario}")
    fi
  done
  printf '%s\n' "${output[@]}"
}

top_two_for_duration() {
  local duration="$1"
  local scenario
  while IFS= read -r scenario; do
    [ -n "${scenario}" ] || continue
    printf '%s\t%s\n' "${scenario}" "$(result_value "${scenario}" "${duration}" throughput_bogo_ops_per_sec)"
  done < <(valid_compare_scenarios "${duration}") | sort -k2,2gr | head -2
}

choose_winner() {
  local duration="$1"
  local valid=()
  local selectable=()
  local scenario candidate strongest strongest_thr best_base best_base_thr
  local tdie_a tdie_d
  local min_stapm="" max_stapm="" clamp_similar="no"
  local strongest_tdie strongest_stapm c_thr c_tdie c_stapm
  local strongest_ref_thr strongest_ref_tdie strongest_ref_stapm

  while IFS= read -r scenario; do
    [ -n "${scenario}" ] || continue
    valid+=("${scenario}")
  done < <(valid_compare_scenarios "${duration}")

  if [ "${#valid[@]}" -eq 0 ]; then
    return 1
  fi

  for scenario in "${valid[@]}"; do
    if [ "${scenario}" = "D" ]; then
      if float_lt "$(result_value D "${SUSTAINED_DURATION}" throughput_bogo_ops_per_sec)" "$(float_mul "$(result_value A "${SUSTAINED_DURATION}" throughput_bogo_ops_per_sec)" "1.03")"; then
        continue
      fi
      if [ "$(result_value D "${SUSTAINED_DURATION}" skin_hit)" = "yes" ]; then
        continue
      fi
      tdie_a="$(result_value A "${SUSTAINED_DURATION}" tdie_avg_c)"
      tdie_d="$(result_value D "${SUSTAINED_DURATION}" tdie_avg_c)"
      if float_gt "${tdie_d}" "$(float_add "${tdie_a}" "2")"; then
        continue
      fi
    fi

    if [ "${scenario}" = "E" ] && ! float_gt "$(result_value E "${SUSTAINED_DURATION}" throughput_bogo_ops_per_sec)" "$(result_value A "${SUSTAINED_DURATION}" throughput_bogo_ops_per_sec)"; then
      continue
    fi

    selectable+=("${scenario}")
  done

  for scenario in "${selectable[@]}"; do
    candidate="${scenario}"
    if [ -z "${strongest:-}" ] || float_gt "$(result_value "${candidate}" "${duration}" throughput_bogo_ops_per_sec)" "${strongest_thr:-0}"; then
      strongest="${candidate}"
      strongest_thr="$(result_value "${candidate}" "${duration}" throughput_bogo_ops_per_sec)"
    fi
  done

  if [ -z "${strongest:-}" ]; then
    best_base=""
    best_base_thr="0"
    for scenario in A B C; do
      case " ${QUALIFIED_SCENARIOS} " in
        *" ${scenario} "*)
          if [ "$(result_value "${scenario}" "${SUSTAINED_DURATION}" aborted)" != "yes" ] && \
             float_gt "$(result_value "${scenario}" "${SUSTAINED_DURATION}" throughput_bogo_ops_per_sec)" "${best_base_thr}"; then
            best_base="${scenario}"
            best_base_thr="$(result_value "${scenario}" "${SUSTAINED_DURATION}" throughput_bogo_ops_per_sec)"
          fi
          ;;
      esac
    done
    if [ -n "${best_base}" ]; then
      strongest="${best_base}"
      strongest_thr="${best_base_thr}"
    fi
  fi

  if [ -z "${strongest:-}" ]; then
    return 1
  fi

  for scenario in "${selectable[@]}"; do
    if [ -z "${min_stapm}" ] || float_lt "$(result_value "${scenario}" "${duration}" stapm_value_avg_w)" "${min_stapm}"; then
      min_stapm="$(result_value "${scenario}" "${duration}" stapm_value_avg_w)"
    fi
    if [ -z "${max_stapm}" ] || float_gt "$(result_value "${scenario}" "${duration}" stapm_value_avg_w)" "${max_stapm}"; then
      max_stapm="$(result_value "${scenario}" "${duration}" stapm_value_avg_w)"
    fi
  done

  if [ -n "${min_stapm}" ] && [ -n "${max_stapm}" ] && float_le "$(float_range_width "${min_stapm}" "${max_stapm}")" "1.0"; then
    clamp_similar="yes"
  fi

  if [ "${clamp_similar}" = "yes" ]; then
    best_base=""
    best_base_thr="0"
    for scenario in A B C; do
      case " ${QUALIFIED_SCENARIOS} " in
        *" ${scenario} "*)
          if [ "$(result_value "${scenario}" "${duration}" aborted)" != "yes" ] && \
             float_gt "$(result_value "${scenario}" "${duration}" throughput_bogo_ops_per_sec)" "${best_base_thr}"; then
            best_base="${scenario}"
            best_base_thr="$(result_value "${scenario}" "${duration}" throughput_bogo_ops_per_sec)"
          fi
          ;;
      esac
    done
    if [ -n "${best_base}" ]; then
      strongest="${best_base}"
      strongest_thr="${best_base_thr}"
    fi
  fi

  strongest_ref_thr="$(result_value "${strongest}" "${SUSTAINED_DURATION}" throughput_bogo_ops_per_sec)"
  if [ -z "${strongest_ref_thr}" ]; then
    strongest_ref_thr="${strongest_thr}"
  fi
  strongest_ref_tdie="$(result_value "${strongest}" "${SUSTAINED_DURATION}" tdie_avg_c)"
  if [ -z "${strongest_ref_tdie}" ]; then
    strongest_ref_tdie="$(result_value "${strongest}" "${duration}" tdie_avg_c)"
  fi
  strongest_ref_stapm="$(result_value "${strongest}" "${SUSTAINED_DURATION}" stapm_value_avg_w)"
  if [ -z "${strongest_ref_stapm}" ]; then
    strongest_ref_stapm="$(result_value "${strongest}" "${duration}" stapm_value_avg_w)"
  fi

  strongest_tdie="$(result_value "${strongest}" "${duration}" tdie_avg_c)"
  strongest_stapm="$(result_value "${strongest}" "${duration}" stapm_value_avg_w)"
  if case " ${QUALIFIED_SCENARIOS} " in *" C "*) true ;; *) false ;; esac && [ "$(result_value C "${duration}" aborted)" != "yes" ]; then
    c_thr="$(result_value C "${SUSTAINED_DURATION}" throughput_bogo_ops_per_sec)"
    c_tdie="$(result_value C "${SUSTAINED_DURATION}" tdie_avg_c)"
    c_stapm="$(result_value C "${SUSTAINED_DURATION}" stapm_value_avg_w)"
    if [ -n "${c_thr}" ] && float_ge "${c_thr}" "$(float_mul "${strongest_ref_thr}" "0.98")" && \
       { float_lt "${c_tdie}" "${strongest_ref_tdie}" || float_lt "${c_stapm}" "${strongest_ref_stapm}"; }; then
      echo "C"
      return 0
    fi
  fi

  candidate="${strongest}"
  for scenario in "${selectable[@]}"; do
    if [ "$(result_value "${scenario}" "${duration}" aborted)" = "yes" ]; then
      continue
    fi
    if float_lt "$(result_value "${scenario}" "${duration}" throughput_bogo_ops_per_sec)" "$(float_mul "${strongest_thr}" "0.97")"; then
      continue
    fi

    if float_lt "$(result_value "${scenario}" "${duration}" tdie_avg_c)" "$(result_value "${candidate}" "${duration}" tdie_avg_c)"; then
      candidate="${scenario}"
      continue
    fi

    if [ "$(result_value "${scenario}" "${duration}" tdie_avg_c)" = "$(result_value "${candidate}" "${duration}" tdie_avg_c)" ]; then
      if [ "$(result_value "${scenario}" "${duration}" skin_hit)" = "no" ] && [ "$(result_value "${candidate}" "${duration}" skin_hit)" = "yes" ]; then
        candidate="${scenario}"
        continue
      fi
      if [ "$(result_value "${scenario}" "${duration}" skin_hit)" = "$(result_value "${candidate}" "${duration}" skin_hit)" ] && \
         float_lt "$(result_value "${scenario}" "${duration}" stapm_value_avg_w)" "$(result_value "${candidate}" "${duration}" stapm_value_avg_w)"; then
        candidate="${scenario}"
        continue
      fi
      if [ "$(result_value "${scenario}" "${duration}" skin_hit)" = "$(result_value "${candidate}" "${duration}" skin_hit)" ] && \
         [ "$(result_value "${scenario}" "${duration}" stapm_value_avg_w)" = "$(result_value "${candidate}" "${duration}" stapm_value_avg_w)" ] && \
         float_gt "$(result_value "${scenario}" "${duration}" throughput_bogo_ops_per_sec)" "$(result_value "${candidate}" "${duration}" throughput_bogo_ops_per_sec)"; then
        candidate="${scenario}"
      fi
    fi
  done

  echo "${candidate}"
}

write_winner_report() {
  local winner="$1"
  local duration="$2"
  local metrics_duration="$2"

  if [ -z "$(result_value "${winner}" "${metrics_duration}" throughput_bogo_ops_per_sec)" ]; then
    metrics_duration="${SUSTAINED_DURATION}"
  fi

  {
    echo "status=success"
    echo "winner=${winner}"
    echo "scenario_name=$(scenario_name "${winner}")"
    echo "comparison_duration=${duration}"
    echo "metrics_duration=${metrics_duration}"
    echo "throughput_bogo_ops_per_sec=$(result_value "${winner}" "${metrics_duration}" throughput_bogo_ops_per_sec)"
    echo "tdie_avg_c=$(result_value "${winner}" "${metrics_duration}" tdie_avg_c)"
    echo "tdie_max_c=$(result_value "${winner}" "${metrics_duration}" tdie_max_c)"
    echo "stapm_value_avg_w=$(result_value "${winner}" "${metrics_duration}" stapm_value_avg_w)"
    echo "skin_hit=$(result_value "${winner}" "${metrics_duration}" skin_hit)"
    echo "stapm_clamped=$(result_value "${winner}" "${metrics_duration}" stapm_clamped)"
    echo "log_path=$(result_value "${winner}" "${metrics_duration}" log_path)"
    echo
    echo "Repo mapping:"
    case "${winner}" in
      A) echo "Set performance preset to Scenario A command." ;;
      B) echo "Set performance preset to Scenario B command with tctl-temp=97." ;;
      C) echo "Set performance preset to Scenario C command." ;;
      D) echo "Set performance preset to Scenario D command." ;;
      E) echo "Set performance preset to Scenario E command." ;;
    esac
  } > "${WINNER_TXT}"
}

run_burst_phase() {
  local scenario status qualified=() excluded=()

  if [ "${BURST_COMPLETE}" -eq 1 ]; then
    echo "Burst phase already completed for ${ROOT}" >&2
    exit 1
  fi

  run_preflight
  wait_for_idle_baseline
  IDLE_TEMP_C="$(read_cpu_temp)"
  log "Idle baseline Tdie=${IDLE_TEMP_C}C"

  for scenario in "${SCENARIOS[@]}"; do
    if run_case "${scenario}" "${BURST_DURATION}"; then
      status=0
    else
      status=$?
    fi

    if [ "${status}" -eq 4 ] || [ "${status}" -eq 5 ]; then
      exit "${status}"
    fi
    if [ "${status}" -ne 0 ] && [ "${status}" -ne 3 ]; then
      write_failure_report "burst_run_failed" "scenario=${scenario} status=${status}"
      exit "${status}"
    fi

    if [ "${scenario}" != "E" ]; then
      wait_for_cooldown "${IDLE_TEMP_C}"
    fi
  done

  for scenario in "${SCENARIOS[@]}"; do
    if scenario_allowed_for_sustained "${scenario}"; then
      qualified+=("${scenario}")
    else
      excluded+=("${scenario}")
    fi
  done

  QUALIFIED_SCENARIOS="${qualified[*]}"
  EXCLUDED_SCENARIOS="${excluded[*]}"
  BURST_COMPLETE=1
  SUSTAINED_COMPLETE=0
  TIEBREAK_COMPLETE=0
  TOP1=""
  TOP2=""
  COMPARE_DURATION=""
  WINNER=""
  save_state
  build_summary_table
  log "Burst phase complete. Reuse this root for next phases: ${ROOT}"
}

run_sustained_phase() {
  local scenario status
  local sustained_scenarios=()
  local last_sustained=""

  if [ "${BURST_COMPLETE}" -ne 1 ]; then
    echo "Burst phase must complete before sustained. Reuse the same --root directory from burst: ${ROOT}" >&2
    exit 1
  fi
  if [ -z "${QUALIFIED_SCENARIOS}" ]; then
    write_failure_report "no_qualified_scenarios"
    exit 1
  fi
  if [ "${SUSTAINED_COMPLETE}" -eq 1 ]; then
    echo "Sustained phase already completed for ${ROOT}" >&2
    exit 1
  fi

  run_preflight
  wait_for_cooldown "${IDLE_TEMP_C}"

  mapfile -t sustained_scenarios < <(ordered_scenarios_from_list "${QUALIFIED_SCENARIOS}")
  last_sustained="${sustained_scenarios[${#sustained_scenarios[@]}-1]}"

  for scenario in "${sustained_scenarios[@]}"; do
    [ -n "${scenario}" ] || continue

    if run_case "${scenario}" "${SUSTAINED_DURATION}"; then
      status=0
    else
      status=$?
    fi

    if [ "${status}" -eq 4 ] || [ "${status}" -eq 5 ]; then
      exit "${status}"
    fi

    if scenario_has_hard_issue "${scenario}" "${SUSTAINED_DURATION}"; then
      SUSTAINED_COMPLETE=0
      save_state
      write_failure_report "hard_system_error" "scenario=${scenario}"
      exit 1
    fi

    if [ "${status}" -ne 0 ] && [ "${status}" -ne 3 ]; then
      SUSTAINED_COMPLETE=0
      save_state
      write_failure_report "sustained_run_failed" "scenario=${scenario} status=${status}"
      exit "${status}"
    fi

    if [ "${scenario}" != "${last_sustained}" ]; then
      wait_for_cooldown "${IDLE_TEMP_C}"
    fi
  done

  SUSTAINED_COMPLETE=1
  TIEBREAK_COMPLETE=0
  TOP1=""
  TOP2=""
  COMPARE_DURATION=""
  WINNER=""
  save_state
  build_summary_table
  log "Sustained phase complete. Reuse this root for next phases: ${ROOT}"
}

run_tiebreak_phase() {
  local top_lines diff status scenario_a scenario_b

  if [ "${SUSTAINED_COMPLETE}" -ne 1 ]; then
    echo "Sustained phase must complete before tiebreak. Reuse the same --root directory from sustained: ${ROOT}" >&2
    exit 1
  fi

  mapfile -t top_lines < <(top_two_for_duration "${SUSTAINED_DURATION}")
  if [ "${#top_lines[@]}" -eq 0 ]; then
    write_failure_report "no_valid_sustained_results"
    exit 1
  fi

  TOP1="$(printf '%s\n' "${top_lines[0]}" | awk -F'\t' '{print $1}')"
  TOP2="$(printf '%s\n' "${top_lines[1]:-}" | awk -F'\t' '{print $1}')"

  if [ -z "${TOP2}" ]; then
    COMPARE_DURATION="${SUSTAINED_DURATION}"
    TIEBREAK_COMPLETE=1
    save_state
    build_summary_table
    log "Tie-break skipped. Reuse this root for report: ${ROOT}"
    return
  fi

  diff="$(awk -v a="$(printf '%s\n' "${top_lines[0]}" | awk -F'\t' '{print $2}')" -v b="$(printf '%s\n' "${top_lines[1]}" | awk -F'\t' '{print $2}')" 'BEGIN { printf "%.6f", ((a - b) / b) * 100 }')"
  if float_ge "${diff}" "2"; then
    COMPARE_DURATION="${SUSTAINED_DURATION}"
    TIEBREAK_COMPLETE=1
    save_state
    build_summary_table
    return
  fi

  run_preflight
  wait_for_cooldown "${IDLE_TEMP_C}"

  scenario_a="${TOP1}"
  scenario_b="${TOP2}"

  if run_case "${scenario_a}" "${TIEBREAK_DURATION}"; then
    status=0
  else
    status=$?
  fi
  if [ "${status}" -eq 4 ] || [ "${status}" -eq 5 ]; then
    exit "${status}"
  fi
  if scenario_has_hard_issue "${scenario_a}" "${TIEBREAK_DURATION}"; then
    TIEBREAK_COMPLETE=0
    save_state
    write_failure_report "hard_system_error" "scenario=${scenario_a}"
    exit 1
  fi
  if [ "${status}" -ne 0 ] && [ "${status}" -ne 3 ]; then
    TIEBREAK_COMPLETE=0
    save_state
    write_failure_report "tiebreak_run_failed" "scenario=${scenario_a} status=${status}"
    exit "${status}"
  fi

  wait_for_cooldown "${IDLE_TEMP_C}"

  if run_case "${scenario_b}" "${TIEBREAK_DURATION}"; then
    status=0
  else
    status=$?
  fi
  if [ "${status}" -eq 4 ] || [ "${status}" -eq 5 ]; then
    exit "${status}"
  fi
  if scenario_has_hard_issue "${scenario_b}" "${TIEBREAK_DURATION}"; then
    TIEBREAK_COMPLETE=0
    save_state
    write_failure_report "hard_system_error" "scenario=${scenario_b}"
    exit 1
  fi
  if [ "${status}" -ne 0 ] && [ "${status}" -ne 3 ]; then
    TIEBREAK_COMPLETE=0
    save_state
    write_failure_report "tiebreak_run_failed" "scenario=${scenario_b} status=${status}"
    exit "${status}"
  fi

  COMPARE_DURATION="${TIEBREAK_DURATION}"
  TIEBREAK_COMPLETE=1
  save_state
  build_summary_table
  log "Tie-break phase complete. Reuse this root for report: ${ROOT}"
}

run_report_phase() {
  local duration

  build_summary_table

  if [ "${BURST_COMPLETE}" -ne 1 ]; then
    write_failure_report "burst_incomplete"
    return
  fi
  if [ "${SUSTAINED_COMPLETE}" -ne 1 ]; then
    write_failure_report "sustained_incomplete"
    return
  fi
  if [ "${TIEBREAK_COMPLETE}" -ne 1 ]; then
    write_failure_report "tiebreak_incomplete"
    return
  fi

  duration="${COMPARE_DURATION:-${SUSTAINED_DURATION}}"
  if ! WINNER="$(choose_winner "${duration}")"; then
    write_failure_report "winner_not_found"
    return
  fi
  save_state
  write_winner_report "${WINNER}" "${duration}"
}

need_cmd sudo
need_cmd awk
need_cmd od
need_cmd grep
need_cmd sort
need_cmd tail
need_cmd stress-ng

if [ ! -x "${TEST_SCRIPT}" ]; then
  echo "Missing test script: ${TEST_SCRIPT}" >&2
  exit 1
fi
if [ ! -x "${RYZENADJ_BIN}" ]; then
  echo "Missing ryzenadj binary: ${RYZENADJ_BIN}" >&2
  exit 1
fi

ensure_root_files
load_state
check_pm_table_version
log "Using retest root: ${ROOT}"

case "${PHASE}" in
  burst)
    run_burst_phase
    ;;
  sustained)
    run_sustained_phase
    ;;
  tiebreak)
    run_tiebreak_phase
    ;;
  report)
    run_report_phase
    ;;
  *)
    usage
    exit 2
    ;;
esac
