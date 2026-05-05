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

RYZENADJ_BIN="/run/current-system/sw/bin/ryzenadj"
OUT="${HOME}/ryzen-test-${PROFILE_NAME}-$(date +%Y%m%d-%H%M%S).log"
SAMPLE_INTERVAL=2   # seconds between samples

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

cleanup() {
  if [ -n "${MONITOR_PID:-}" ]; then
    kill "${MONITOR_PID}" 2>/dev/null || true
  fi
  if [ -n "${SUDO_KEEPALIVE_PID:-}" ]; then
    kill "${SUDO_KEEPALIVE_PID}" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

need_cmd powerprofilesctl
need_cmd stress-ng
need_cmd sudo
need_cmd awk

if [ ! -x "${RYZENADJ_BIN}" ]; then
  echo "Missing required command: ${RYZENADJ_BIN}" >&2
  exit 1
fi

# --- Sensor helpers ---
# Read CPU die temp from k10temp hwmon (Tdie preferred over Tctl)
read_cpu_temp() {
  for hwmon in /sys/class/hwmon/hwmon*/; do
    local name
    name=$(cat "${hwmon}name" 2>/dev/null || true)
    if [ "$name" = "k10temp" ]; then
      # temp2 = Tdie (actual die, no offset), temp1 = Tctl (Tdie + 27 offset)
      local t
      t=$(cat "${hwmon}temp2_input" 2>/dev/null || cat "${hwmon}temp1_input" 2>/dev/null || true)
      if [ -n "$t" ]; then
        awk -v v="$t" 'BEGIN { printf "%.1f", v/1000 }'
        return
      fi
    fi
  done
  echo "N/A"
}

# Read max frequency across all cores (MHz)
read_max_freq_mhz() {
  local max=0
  for f in /sys/devices/system/cpu/cpufreq/policy*/scaling_cur_freq; do
    local v
    v=$(cat "$f" 2>/dev/null || true)
    if [ -n "$v" ] && [ "$v" -gt "$max" ] 2>/dev/null; then
      max=$v
    fi
  done
  awk -v v="$max" 'BEGIN { printf "%.0f", v/1000 }'
}

# Read average frequency across all cores (MHz)
read_avg_freq_mhz() {
  local sum=0 cnt=0
  for f in /sys/devices/system/cpu/cpufreq/policy*/scaling_cur_freq; do
    local v
    v=$(cat "$f" 2>/dev/null || true)
    if [ -n "$v" ]; then
      sum=$((sum + v))
      cnt=$((cnt + 1))
    fi
  done
  if [ "$cnt" -gt 0 ]; then
    awk -v s="$sum" -v c="$cnt" 'BEGIN { printf "%.0f", s/c/1000 }'
  else
    echo "N/A"
  fi
}

echo "Logging to: ${OUT}"

sudo -v
(
  while true; do
    sudo -n true
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
  echo "===== STRESS START ====="
  printf "%-12s  %-9s  %-12s  %-12s\n" "time" "Tdie(°C)" "maxFreq(MHz)" "avgFreq(MHz)"
  printf "%-12s  %-9s  %-12s  %-12s\n" "------------" "---------" "------------" "------------"
} | tee "${OUT}"

# --- Real-time monitor (freq + temp, every SAMPLE_INTERVAL seconds) ---
(
  while true; do
    ts=$(date '+%H:%M:%S')
    temp=$(read_cpu_temp)
    maxf=$(read_max_freq_mhz)
    avgf=$(read_avg_freq_mhz)
    printf "%-12s  %-9s  %-12s  %-12s\n" "$ts" "$temp" "$maxf" "$avgf" >> "${OUT}" 2>&1
    sleep "${SAMPLE_INTERVAL}"
  done
) &
MONITOR_PID=$!

stress-ng --cpu "$(nproc)" --timeout "${DURATION}s" --metrics-brief 2>&1 | tee -a "${OUT}" || true

kill "${MONITOR_PID}" 2>/dev/null || true
MONITOR_PID=""

# --- Summary statistics from the captured samples ---
{
  echo
  echo "===== LIVE SAMPLE SUMMARY ====="
  grep -E '^[0-9]{2}:[0-9]{2}:[0-9]{2}' "${OUT}" | awk '
  {
    temp=$2; maxf=$3; avgf=$4
    if (temp != "N/A" && temp+0 > 0) {
      tsum+=temp; tcnt++
      if (temp+0 > tmax) tmax=temp+0
      if (tcnt==1 || temp+0 < tmin) tmin=temp+0
    }
    if (maxf != "N/A" && maxf+0 > 0) {
      fsum+=maxf; fcnt++
      if (maxf+0 > fmax) fmax=maxf+0
      if (fcnt==1 || maxf+0 < fmin) fmin=maxf+0
    }
    if (avgf != "N/A" && avgf+0 > 0) {
      asum+=avgf; acnt++
    }
  }
  END {
    printf "Tdie  :  min=%.1f°C   max=%.1f°C   avg=%.1f°C\n", tmin, tmax, (tcnt>0?tsum/tcnt:0)
    printf "maxFreq: min=%dMHz  max=%dMHz  avg=%.0fMHz\n",     fmin, fmax, (fcnt>0?fsum/fcnt:0)
    printf "avgFreq: avg=%.0fMHz (all cores)\n",               (acnt>0?asum/acnt:0)
  }'
  echo
  echo "===== SYSTEM STATE AFTER TEST ====="
  date
  echo
  echo "dmesg errors:"
  sudo dmesg -T | grep -Ei "mce|hardware error|thermal|throttle|amdgpu error" | tail -20 || true
} | tee -a "${OUT}"

echo "Done: ${OUT}"
