#!/usr/bin/env bash
set -euo pipefail

# AMD/Ryzen quantitative benchmark suite (performance-first, no-crash)
# Baseline policy:
# - Use --compare <baseline_root> as canonical baseline source.
# - No hardcoded historical baseline.

PROFILE="safe"
ROUNDS=5
RUN_CPU=1
RUN_GPU=1
RUN_CPDA=1
WITH_KERNEL_LOG=0
COMPARE_ROOT=""
ROOT=""
CPDA_DIR="/home/will/dev/CPDA"
CPDA_CLI_REPEATS=5
CPDA_CLI_COOLDOWN_SEC=2
CPDA_THREAD_COUNT=""
SECONDARY_KPI_MODE="both"
BASELINE_POLICY="varlib_current_safe_manual_promotion"
NIXOS_REPO_ROOT="${NIXOS_REPO_ROOT:-/etc/nixos}"

START_ISO="$(date -Iseconds)"
TS="$(date +%Y%m%d-%H%M%S)"

declare -A SOFT_WARN_COUNTS=()
declare -a HARD_FAILS=()
declare -a LIMITATIONS=()

usage() {
  cat <<'USAGE'
Usage:
  amd-perf-suite.sh [options]

Options:
  --root <dir>                      Output root directory
  --profile <safe|balanced|aggressive>
                                    GPU workload profile (default: safe)
  --rounds <n>                      Number of measured rounds (default: 5)
  --run-cpu                         Enable CPU lane (default: enabled)
  --run-gpu                         Enable GPU lane (default: enabled)
  --run-cpda                        Enable CPDA lane (default: enabled)
  --no-run-cpu                      Disable CPU lane
  --no-run-gpu                      Disable GPU lane
  --no-run-cpda                     Disable CPDA lane
  --with-kernel-log                 Enable kernel log scan via journalctl/dmesg
  --compare <baseline_root>         Baseline root with metrics/summary.csv + scorecard.tsv
  --baseline-root <baseline_root>   Alias of --compare
  --cpda-dir <dir>                  CPDA repo path (default: /home/will/dev/CPDA)
  --cpda-cli-repeats <n>            CPDA CLI repeats per round (default: 5)
  --cpda-cli-cooldown-sec <n>       Cooldown seconds between CPDA CLI repeats (default: 2)
  --cpda-thread-count <n>           Fixed BLAS/OMP thread count for CPDA CLI (default: nproc)
  --secondary-kpi-mode <median|p95|both>
                                    Secondary KPI gate mode (default: both)
  --help                            Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      ROOT="${2:-}"
      shift 2
      ;;
    --profile)
      PROFILE="${2:-}"
      shift 2
      ;;
    --rounds)
      ROUNDS="${2:-}"
      shift 2
      ;;
    --run-cpu)
      RUN_CPU=1
      shift
      ;;
    --run-gpu)
      RUN_GPU=1
      shift
      ;;
    --run-cpda)
      RUN_CPDA=1
      shift
      ;;
    --no-run-cpu)
      RUN_CPU=0
      shift
      ;;
    --no-run-gpu)
      RUN_GPU=0
      shift
      ;;
    --no-run-cpda)
      RUN_CPDA=0
      shift
      ;;
    --with-kernel-log)
      WITH_KERNEL_LOG=1
      shift
      ;;
    --compare)
      COMPARE_ROOT="${2:-}"
      shift 2
      ;;
    --baseline-root)
      COMPARE_ROOT="${2:-}"
      shift 2
      ;;
    --cpda-dir)
      CPDA_DIR="${2:-}"
      shift 2
      ;;
    --cpda-cli-repeats)
      CPDA_CLI_REPEATS="${2:-}"
      shift 2
      ;;
    --cpda-cli-cooldown-sec)
      CPDA_CLI_COOLDOWN_SEC="${2:-}"
      shift 2
      ;;
    --cpda-thread-count)
      CPDA_THREAD_COUNT="${2:-}"
      shift 2
      ;;
    --secondary-kpi-mode)
      SECONDARY_KPI_MODE="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "${ROOT}" ]]; then
  ROOT="/var/tmp/amd-perf-suite-${TS}"
fi

if [[ "${PROFILE}" != "safe" && "${PROFILE}" != "balanced" && "${PROFILE}" != "aggressive" ]]; then
  echo "Invalid --profile: ${PROFILE}" >&2
  exit 2
fi

if ! [[ "${ROUNDS}" =~ ^[0-9]+$ ]] || [[ "${ROUNDS}" -lt 1 ]]; then
  echo "--rounds must be integer >= 1" >&2
  exit 2
fi

if ! [[ "${CPDA_CLI_REPEATS}" =~ ^[0-9]+$ ]] || [[ "${CPDA_CLI_REPEATS}" -lt 1 ]]; then
  echo "--cpda-cli-repeats must be integer >= 1" >&2
  exit 2
fi

if ! [[ "${CPDA_CLI_COOLDOWN_SEC}" =~ ^[0-9]+$ ]] || [[ "${CPDA_CLI_COOLDOWN_SEC}" -lt 0 ]]; then
  echo "--cpda-cli-cooldown-sec must be integer >= 0" >&2
  exit 2
fi

if [[ -z "${CPDA_THREAD_COUNT}" ]]; then
  CPDA_THREAD_COUNT="$(nproc 2>/dev/null || echo 16)"
fi
if ! [[ "${CPDA_THREAD_COUNT}" =~ ^[0-9]+$ ]] || [[ "${CPDA_THREAD_COUNT}" -lt 1 ]]; then
  echo "--cpda-thread-count must be integer >= 1" >&2
  exit 2
fi

if [[ "${SECONDARY_KPI_MODE}" != "median" && "${SECONDARY_KPI_MODE}" != "p95" && "${SECONDARY_KPI_MODE}" != "both" ]]; then
  echo "Invalid --secondary-kpi-mode: ${SECONDARY_KPI_MODE}" >&2
  exit 2
fi

if [[ ! -d "${CPDA_DIR}" ]]; then
  echo "CPDA dir not found: ${CPDA_DIR}" >&2
  exit 2
fi

if [[ -n "${COMPARE_ROOT}" && ! -d "${COMPARE_ROOT}" ]]; then
  echo "--compare root not found: ${COMPARE_ROOT}" >&2
  exit 2
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "Missing required command: rg" >&2
  exit 2
fi

LOG_DIR="${ROOT}/logs"
METRIC_DIR="${ROOT}/metrics"
MANIFEST_DIR="${ROOT}/manifest"
mkdir -p "${LOG_DIR}" "${METRIC_DIR}" "${MANIFEST_DIR}"

PARAMS_TSV="${MANIFEST_DIR}/params.tsv"
BASELINE_JSON="${MANIFEST_DIR}/baseline.json"
CPU_CSV="${METRIC_DIR}/cpu.csv"
GPU_CSV="${METRIC_DIR}/gpu.csv"
CPDA_CSV="${METRIC_DIR}/cpda.csv"
SUMMARY_CSV="${METRIC_DIR}/summary.csv"
SCORECARD_TSV="${ROOT}/scorecard.tsv"
FINAL_REPORT="${ROOT}/final-report.md"

KERNEL_SCAN_LOG="${LOG_DIR}/kernel-scan.log"
KERNEL_HARDFAIL_LOG="${LOG_DIR}/kernel-hardfail-matches.log"
KERNEL_SOFT_LOG="${LOG_DIR}/kernel-soft-observed.log"

printf 'component\tparam\tvalue\tis_non_default\tsource_file\timpact_note\n' > "${PARAMS_TSV}"
printf 'lane,test,round,seconds,status,cpu_asserted_ghz,temperature_c_max,notes\n' > "${CPU_CSV}"
printf 'lane,test,profile_requested,profile_effective,size,iters,round,seconds,avg_iter_ms,status,notes\n' > "${GPU_CSV}"
printf 'lane,test,round,repeat,seconds_wall,seconds_internal,seconds_internal_repeat,seconds_internal_round_median,seconds_internal_round_p95,primary_metric_used,status,details,output_file\n' > "${CPDA_CSV}"
printf 'metric\tstatus\tvalue\ttarget\tnote\n' > "${SCORECARD_TSV}"

log() {
  printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"
}

add_soft_warn() {
  local key="$1"
  SOFT_WARN_COUNTS["${key}"]=$(( ${SOFT_WARN_COUNTS["${key}"]:-0} + 1 ))
}

add_hard_fail() {
  HARD_FAILS+=("$*")
}

add_limitation() {
  LIMITATIONS+=("$*")
}

soft_warn_unique_count() {
  echo "${#SOFT_WARN_COUNTS[@]}"
}

soft_warn_total_count() {
  local total=0
  local k
  for k in "${!SOFT_WARN_COUNTS[@]}"; do
    total=$((total + SOFT_WARN_COUNTS["${k}"]))
  done
  echo "${total}"
}

param_row() {
  local component="$1"
  local param="$2"
  local value="$3"
  local non_default="$4"
  local source_file="$5"
  local impact="$6"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${component}" "${param}" "${value}" "${non_default}" "${source_file}" "${impact}" >> "${PARAMS_TSV}"
}

run_timed() {
  local out_log="$1"
  shift
  local start_ns end_ns rc sec
  start_ns="$(date +%s%N)"
  set +e
  "$@" > "${out_log}" 2>&1
  rc=$?
  set -e
  end_ns="$(date +%s%N)"
  sec="$(awk -v s="${start_ns}" -v e="${end_ns}" 'BEGIN{printf "%.6f", (e-s)/1000000000.0}')"
  {
    echo
    echo "[timing]"
    echo "timing_start_ns=${start_ns}"
    echo "timing_end_ns=${end_ns}"
    echo "timing_wall_seconds=${sec}"
  } >> "${out_log}"
  printf '%s|%s\n' "${rc}" "${sec}"
}

extract_asserted_ghz() {
  local log_file="$1"
  rg -o 'current CPU frequency: [0-9]+\.[0-9]+ GHz \(asserted by call to kernel\)' "${log_file}" \
    | tail -n1 \
    | rg -o '[0-9]+\.[0-9]+' \
    | tail -n1 || true
}

extract_temp_max() {
  local log_file="$1"
  awk '
    match($0, /^[[:space:]]*[[:alnum:] _-]+:[[:space:]]+\+([0-9]+\.[0-9]+)°C/, m) {
      print m[1]
    }
  ' "${log_file}" | sort -n | tail -n1 || true
}

parse_json_field() {
  local field="$1"
  local file="$2"
  rg -o "\"${field}\"\s*:\s*[0-9]+(\.[0-9]+)?" "${file}" | tail -n1 | rg -o '[0-9]+(\.[0-9]+)?' | tail -n1 || true
}

parse_pytest_seconds() {
  local file="$1"
  rg -o '[0-9]+\.[0-9]+s' "${file}" | tail -n1 | tr -d 's' || true
}

parse_cpda_cli_internal() {
  local csv_file="$1"
  direnv exec "${CPDA_DIR}" python - <<'PY' "${csv_file}" 2>/dev/null || true
import csv, sys
p=sys.argv[1]
val=""
with open(p, newline="") as f:
    rd=csv.DictReader(f)
    for r in rd:
        if r.get("model_key") != "cpda":
            continue
        t=(r.get("total_time") or "").strip()
        if t:
            try:
                x=float(t)
                if x > 0:
                    val=f"{x:.6f}"
                    break
            except Exception:
                pass
        ft=(r.get("fit_time") or "").strip()
        st=(r.get("score_time") or "").strip()
        try:
            fx=float(ft) if ft else 0.0
            sx=float(st) if st else 0.0
            if fx+sx > 0:
                val=f"{(fx+sx):.6f}"
                break
        except Exception:
            pass
print(val)
PY
}

calc_stats_from_values() {
  if [[ $# -lt 1 ]]; then
    echo "|"
    return 0
  fi
  direnv exec "${CPDA_DIR}" python - <<'PY' "$@" 2>/dev/null || true
import statistics, sys
vals=[]
for x in sys.argv[1:]:
    try:
        vals.append(float(x))
    except Exception:
        pass
if not vals:
    print("|")
    raise SystemExit(0)
vals=sorted(vals)
med=statistics.median(vals)
p95_idx=min(len(vals)-1, max(0, int((len(vals)*0.95 + 0.999999) - 1)))
p95=vals[p95_idx]
print(f"{med:.6f}|{p95:.6f}")
PY
}

kpi_percent_improve() {
  local baseline="$1"
  local current="$2"
  awk -v b="${baseline}" -v c="${current}" 'BEGIN{if(b<=0){print ""; exit}; printf "%.4f", ((b-c)/b)*100.0}'
}

kpi_percent_regress() {
  local baseline="$1"
  local current="$2"
  awk -v b="${baseline}" -v c="${current}" 'BEGIN{if(b<=0){print ""; exit}; printf "%.4f", ((c-b)/b)*100.0}'
}

compute_summary_csv() {
  direnv exec "${CPDA_DIR}" python - <<'PY' "${CPU_CSV}" "${GPU_CSV}" "${CPDA_CSV}" "${SUMMARY_CSV}"
import csv, statistics, sys
cpu_csv, gpu_csv, cpda_csv, out_csv = sys.argv[1:]
rows = []

def _p95(vals):
    idx = min(len(vals)-1, max(0, int((len(vals)*0.95 + 0.999999) - 1)))
    return vals[idx]

def aggregate(path, lane, test_key, metric_key, allowed_status, extra_filter=None, out_metric=None):
    grouped = {}
    with open(path, newline="") as f:
        rd = csv.DictReader(f)
        for r in rd:
            if r.get("status") not in allowed_status:
                continue
            if extra_filter and not extra_filter(r):
                continue
            test = r.get(test_key, "")
            if not test:
                continue
            raw = (r.get(metric_key, "") or "").strip()
            if not raw:
                continue
            try:
                val = float(raw)
            except Exception:
                continue
            grouped.setdefault(test, []).append(val)

    for test, vals in grouped.items():
        vals = sorted(vals)
        if not vals:
            continue
        med = statistics.median(vals)
        p95 = _p95(vals)
        stdev = statistics.pstdev(vals) if len(vals) > 1 else 0.0
        rows.append({
            "lane": lane,
            "test": test,
            "metric": out_metric or metric_key,
            "samples": len(vals),
            "median": f"{med:.6f}",
            "p95": f"{p95:.6f}",
            "stdev": f"{stdev:.6f}",
        })

aggregate(cpu_csv, "cpu", "test", "seconds", {"PASS"})
aggregate(gpu_csv, "gpu", "test", "seconds", {"PASS"})
aggregate(gpu_csv, "gpu", "test", "avg_iter_ms", {"PASS"})
aggregate(
    cpda_csv,
    "cpda",
    "test",
    "seconds_wall",
    {"PASS", "WARN"},
    extra_filter=lambda r: (r.get("test") != "cpda_cli_short_benchmark" or (r.get("repeat") or "") == "0"),
)
aggregate(
    cpda_csv,
    "cpda",
    "test",
    "seconds_internal",
    {"PASS", "WARN"},
    extra_filter=lambda r: (r.get("test") != "cpda_cli_short_benchmark" or (r.get("repeat") or "") == "0"),
)
aggregate(
    cpda_csv,
    "cpda",
    "test",
    "seconds_internal_repeat",
    {"PASS", "WARN"},
    extra_filter=lambda r: r.get("test") == "cpda_cli_short_benchmark" and (r.get("repeat") or "") != "0",
)
aggregate(
    cpda_csv,
    "cpda",
    "test",
    "seconds_internal_round_median",
    {"PASS", "WARN"},
    extra_filter=lambda r: r.get("test") == "cpda_cli_short_benchmark" and (r.get("repeat") or "") == "0",
    out_metric="seconds_internal_median",
)
aggregate(
    cpda_csv,
    "cpda",
    "test",
    "seconds_internal_round_p95",
    {"PASS", "WARN"},
    extra_filter=lambda r: r.get("test") == "cpda_cli_short_benchmark" and (r.get("repeat") or "") == "0",
    out_metric="seconds_internal_p95",
)

with open(out_csv, "w", newline="") as f:
    wr = csv.DictWriter(f, fieldnames=["lane", "test", "metric", "samples", "median", "p95", "stdev"])
    wr.writeheader()
    wr.writerows(rows)
PY
}

get_summary_stat() {
  local lane="$1"
  local test="$2"
  local metric="$3"
  local stat="$4"
  local col=5
  if [[ "${stat}" == "p95" ]]; then
    col=6
  elif [[ "${stat}" == "stdev" ]]; then
    col=7
  fi
  awk -F',' -v l="${lane}" -v t="${test}" -v m="${metric}" -v c="${col}" 'NR>1 && $1==l && $2==t && $3==m {print $c; exit}' "${SUMMARY_CSV}" || true
}

baseline_lookup_stat() {
  local lane="$1"
  local test="$2"
  local metric="$3"
  local stat="$4"
  if [[ -z "${COMPARE_SUMMARY_CSV}" || ! -f "${COMPARE_SUMMARY_CSV}" ]]; then
    return 0
  fi
  local col=5
  if [[ "${stat}" == "p95" ]]; then
    col=6
  elif [[ "${stat}" == "stdev" ]]; then
    col=7
  fi
  awk -F',' -v l="${lane}" -v t="${test}" -v m="${metric}" -v c="${col}" 'NR>1 && $1==l && $2==t && $3==m {print $c; exit}' "${COMPARE_SUMMARY_CSV}" || true
}

kernel_hard_regex='amdgpu.*(ring.*timeout|gpu reset|fault|hang)|amdgpu_job_timedout|kfd.*(timeout|fault|error)|kernel panic|BUG:|soft lockup|hard LOCKUP'

scan_kernel_log() {
  : > "${KERNEL_HARDFAIL_LOG}"
  : > "${KERNEL_SOFT_LOG}"

  if [[ "${WITH_KERNEL_LOG}" -ne 1 ]]; then
    add_limitation "Kernel log scan disabled (use --with-kernel-log)."
    return 0
  fi

  if command -v journalctl >/dev/null 2>&1; then
    if ! journalctl -k --since "${START_ISO}" --no-pager > "${KERNEL_SCAN_LOG}" 2>&1; then
      add_limitation "journalctl -k unavailable/permission denied for current user"
      return 0
    fi
  else
    if ! dmesg -T > "${KERNEL_SCAN_LOG}" 2>&1; then
      add_limitation "dmesg unavailable/permission denied for current user"
      return 0
    fi
  fi

  rg -ni "${kernel_hard_regex}" "${KERNEL_SCAN_LOG}" > "${KERNEL_HARDFAIL_LOG}" || true
  if [[ -s "${KERNEL_HARDFAIL_LOG}" ]]; then
    add_hard_fail "Kernel log matched hard-fail regex"
  fi

  rg -ni 'amdgpu|kfd|gpu|drm|hip|hsa' "${KERNEL_SCAN_LOG}" | rg -vi "${kernel_hard_regex}" > "${KERNEL_SOFT_LOG}" || true
}

select_cpda_dataset() {
  local ds=""
  local candidates=(
    "${CPDA_DIR}/OCCPDA/datasets/Classical/38_thyroid.npz"
    "${CPDA_DIR}/OCCPDA/datasets/Classical/31_satellite.npz"
  )
  for c in "${candidates[@]}"; do
    if [[ -f "${c}" ]]; then
      ds="${c}"
      break
    fi
  done

  if [[ -z "${ds}" ]]; then
    ds="$(find "${CPDA_DIR}/OCCPDA/datasets" -type f -name '*.npz' 2>/dev/null | head -n1 || true)"
  fi

  echo "${ds}"
}

# ---------------------------
# Phase 0: baseline freeze + manifest
# ---------------------------
log "Phase 0: Freeze baseline"

run_timed "${LOG_DIR}/0-uname.log" uname -a >/dev/null || true
lscpu > "${LOG_DIR}/0-lscpu.log" 2>&1 || true
free -h > "${LOG_DIR}/0-free.log" 2>&1 || true
lsblk -o NAME,TYPE,SIZE,FSTYPE,MOUNTPOINTS > "${LOG_DIR}/0-lsblk.log" 2>&1 || true
nix-env -p /nix/var/nix/profiles/system --list-generations > "${LOG_DIR}/0-generations.log" 2>&1 || true
readlink -f /run/current-system > "${LOG_DIR}/0-current-system.log" 2>&1 || true

NIXOS_GIT_REV="$(git -C "${NIXOS_REPO_ROOT}" rev-parse HEAD 2>/dev/null || echo unknown)"
CPDA_GIT_REV="$(git -C "${CPDA_DIR}" rev-parse HEAD 2>/dev/null || echo unknown)"

COMPARE_SUMMARY_CSV=""
COMPARE_SCORECARD_TSV=""
BASELINE_MODE="none"
if [[ -n "${COMPARE_ROOT}" ]]; then
  if [[ -f "${COMPARE_ROOT}/metrics/summary.csv" ]]; then
    COMPARE_SUMMARY_CSV="${COMPARE_ROOT}/metrics/summary.csv"
    BASELINE_MODE="compare_summary"
  else
    add_limitation "--compare provided but metrics/summary.csv not found"
  fi
  if [[ -f "${COMPARE_ROOT}/scorecard.tsv" ]]; then
    COMPARE_SCORECARD_TSV="${COMPARE_ROOT}/scorecard.tsv"
  fi
else
  add_limitation "No --compare provided, baseline-relative KPIs are WARN"
fi

cat > "${BASELINE_JSON}" <<JSON
{
  "captured_at": "${START_ISO}",
  "baseline_policy": "${BASELINE_POLICY}",
  "baseline_mode": "${BASELINE_MODE}",
  "baseline_root": "${COMPARE_ROOT}",
  "baseline_summary_csv": "${COMPARE_SUMMARY_CSV}",
  "baseline_scorecard_tsv": "${COMPARE_SCORECARD_TSV}",
  "secondary_kpi_mode": "${SECONDARY_KPI_MODE}",
  "cpda_cli_repeats": ${CPDA_CLI_REPEATS},
  "cpda_thread_count": ${CPDA_THREAD_COUNT},
  "nixos_git_rev": "${NIXOS_GIT_REV}",
  "cpda_git_rev": "${CPDA_GIT_REV}"
}
JSON

param_row "suite" "profile" "${PROFILE}" "$( [[ "${PROFILE}" != "safe" ]] && echo true || echo false )" "cli" "GPU workload profile"
param_row "suite" "rounds" "${ROUNDS}" "$( [[ "${ROUNDS}" != "5" ]] && echo true || echo false )" "cli" "Measured rounds per lane"
param_row "suite" "run_cpu" "${RUN_CPU}" "false" "cli" "Enable CPU lane"
param_row "suite" "run_gpu" "${RUN_GPU}" "false" "cli" "Enable GPU lane"
param_row "suite" "run_cpda" "${RUN_CPDA}" "false" "cli" "Enable CPDA lane"
param_row "suite" "with_kernel_log" "${WITH_KERNEL_LOG}" "$( [[ "${WITH_KERNEL_LOG}" != "0" ]] && echo true || echo false )" "cli" "Kernel safety scan"
param_row "suite" "secondary_kpi_mode" "${SECONDARY_KPI_MODE}" "$( [[ "${SECONDARY_KPI_MODE}" != "both" ]] && echo true || echo false )" "cli" "Secondary KPI decision mode"
param_row "baseline" "mode" "${BASELINE_MODE}" "$( [[ "${BASELINE_MODE}" != "compare_summary" ]] && echo true || echo false )" "cli" "Baseline source mode"
param_row "baseline" "compare_root" "${COMPARE_ROOT:-NA}" "$( [[ -z "${COMPARE_ROOT}" ]] && echo true || echo false )" "cli" "Explicit baseline root"
param_row "baseline" "policy" "${BASELINE_POLICY}" "false" "suite-default" "Baseline governance policy"
param_row "runtime" "cpda_dir" "${CPDA_DIR}" "false" "cli" "CPDA repository path"
param_row "cpda" "cli_repeats" "${CPDA_CLI_REPEATS}" "$( [[ "${CPDA_CLI_REPEATS}" != "5" ]] && echo true || echo false )" "cli" "CPDA CLI repeats per round"
param_row "cpda" "cli_cooldown_sec" "${CPDA_CLI_COOLDOWN_SEC}" "$( [[ "${CPDA_CLI_COOLDOWN_SEC}" != "2" ]] && echo true || echo false )" "cli" "CPDA CLI cooldown between repeats"
param_row "cpda" "thread_count" "${CPDA_THREAD_COUNT}" "$( [[ "${CPDA_THREAD_COUNT}" != "16" ]] && echo true || echo false )" "cli" "Fixed BLAS/OMP threads for CPDA CLI"

CPU_STATUS="$(cat /sys/devices/system/cpu/amd_pstate/status 2>/dev/null || echo unknown)"
CPU_DRIVER="$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_driver 2>/dev/null || echo unknown)"
CPU_GOV="$(cat /sys/devices/system/cpu/cpufreq/policy0/scaling_governor 2>/dev/null || echo unknown)"
CPU_EPP="$(cat /sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference 2>/dev/null || echo unknown)"

param_row "cpu" "amd_pstate" "${CPU_STATUS}" "$( [[ "${CPU_STATUS}" != "active" ]] && echo true || echo false )" "${NIXOS_REPO_ROOT}/hosts/think14gryzen/system.nix" "CPU power-state driver mode"
param_row "cpu" "scaling_driver" "${CPU_DRIVER}" "$( [[ "${CPU_DRIVER}" != "amd-pstate-epp" ]] && echo true || echo false )" "sysfs" "CPU frequency driver"
param_row "cpu" "governor" "${CPU_GOV}" "$( [[ "${CPU_GOV}" != "performance" ]] && echo true || echo false )" "sysfs" "CPU scaling governor"
param_row "cpu" "epp" "${CPU_EPP}" "$( [[ "${CPU_EPP}" != "performance" ]] && echo true || echo false )" "sysfs" "Energy-performance preference"

TORCH_META="$(direnv exec "${CPDA_DIR}" python - <<'PY' 2>/dev/null || true
import torch
backend = "cuda" if torch.cuda.is_available() else "cpu"
print(f"{torch.__version__}|{backend}|{getattr(torch.version, 'cuda', None)}|{getattr(torch.version, 'hip', None)}")
PY
)"
if [[ -n "${TORCH_META}" ]]; then
  TORCH_VER="${TORCH_META%%|*}"
  _rest="${TORCH_META#*|}"
  TORCH_BACKEND="${_rest%%|*}"
  _rest="${_rest#*|}"
  TORCH_CUDA_VER="${_rest%%|*}"
  TORCH_HIP_VER="${_rest#*|}"
  param_row "cpda" "torch_version" "${TORCH_VER}" "false" "${CPDA_DIR}/pyproject.toml" "PyTorch runtime version in CPDA env"
  param_row "cpda" "torch_backend_active" "${TORCH_BACKEND}" "false" "runtime-detect" "Detected active torch backend"
  param_row "cpda" "torch_cuda_version" "${TORCH_CUDA_VER}" "false" "runtime-detect" "Torch CUDA runtime tag"
  param_row "cpda" "torch_hip_version" "${TORCH_HIP_VER}" "false" "runtime-detect" "Torch HIP runtime tag"
fi

# ---------------------------
# Phase 1: environment normalization
# ---------------------------
log "Phase 1: Normalize environment"

AC_ONLINE="unknown"
AC_PATH=""
for p in /sys/class/power_supply/AC*/online /sys/class/power_supply/ADP*/online /sys/class/power_supply/ACAD/online; do
  if [[ -f "${p}" ]]; then
    AC_PATH="${p}"
    AC_ONLINE="$(cat "${p}" 2>/dev/null || echo unknown)"
    break
  fi
done

if [[ -n "${AC_PATH}" ]]; then
  param_row "power" "ac_online" "${AC_ONLINE}" "$( [[ "${AC_ONLINE}" != "1" ]] && echo true || echo false )" "${AC_PATH}" "AC power connected recommended"
  if [[ "${AC_ONLINE}" != "1" ]]; then
    add_soft_warn "power_ac_not_online"
  fi
else
  add_limitation "Cannot detect AC online status from /sys/class/power_supply"
fi

PPD_ENABLED="$(systemctl is-enabled power-profiles-daemon 2>/dev/null || true)"
if [[ -z "${PPD_ENABLED}" ]]; then
  PPD_ENABLED="unknown"
fi
PPD_ACTIVE_PROFILE="$(powerprofilesctl get 2>/dev/null || echo unknown)"
param_row "power" "power-profiles-daemon.enabled" "${PPD_ENABLED}" "$( [[ "${PPD_ENABLED}" != "enabled" && "${PPD_ENABLED}" != "linked" && "${PPD_ENABLED}" != "enabled-runtime" ]] && echo true || echo false )" "systemd" "Main power policy daemon"
param_row "power" "power_profile" "${PPD_ACTIVE_PROFILE}" "$( [[ "${PPD_ACTIVE_PROFILE}" != "performance" ]] && echo true || echo false )" "powerprofilesctl" "Requested profile for reproducible benchmarks"

if [[ "${CPU_GOV}" != "performance" ]]; then
  add_hard_fail "CPU governor is not performance (${CPU_GOV})"
fi
if [[ "${CPU_DRIVER}" != "amd-pstate-epp" ]]; then
  add_hard_fail "CPU scaling driver is not amd-pstate-epp (${CPU_DRIVER})"
fi

log "Phase 1: Warmup"
if [[ "${RUN_CPU}" -eq 1 ]]; then
  stress-ng --cpu "$(nproc)" --timeout 5s --metrics-brief > "${LOG_DIR}/warmup-cpu.log" 2>&1 || true
fi
if [[ "${RUN_GPU}" -eq 1 ]]; then
  direnv exec "${CPDA_DIR}" env \
    python - <<'PY' > "${LOG_DIR}/warmup-gpu.log" 2>&1 || true
import torch
if torch.cuda.is_available():
    x = torch.randn((64,64), device='cuda')
    y = torch.randn((64,64), device='cuda')
    _ = x @ y
    torch.cuda.synchronize()
print('warmup_done')
PY
fi

# ---------------------------
# Phase 2: CPU lane
# ---------------------------
if [[ "${RUN_CPU}" -eq 1 ]]; then
  log "Phase 2: CPU benchmark lane"
  for round in $(seq 1 "${ROUNDS}"); do
    stress_log="${LOG_DIR}/cpu-stress-round${round}.log"
    stress_res="$(run_timed "${stress_log}" stress-ng --cpu "$(nproc)" --vm 2 --vm-bytes 40% --timeout 20s --metrics-brief)"
    stress_rc="${stress_res%%|*}"
    stress_sec="${stress_res#*|}"

    cpufreq_log="${LOG_DIR}/cpu-cpupower-round${round}.log"
    cpupower frequency-info > "${cpufreq_log}" 2>&1 || true
    ghz="$(extract_asserted_ghz "${cpufreq_log}")"

    sensors_log="${LOG_DIR}/cpu-sensors-round${round}.log"
    sensors > "${sensors_log}" 2>&1 || true
    tmax="$(extract_temp_max "${sensors_log}")"

    if [[ "${stress_rc}" -eq 0 ]]; then
      printf 'cpu,stress_ng_cpu_vm,%s,%s,PASS,%s,%s,%s\n' "${round}" "${stress_sec}" "${ghz}" "${tmax}" "timeout=20s vm=2 vm-bytes=40%" >> "${CPU_CSV}"
    else
      printf 'cpu,stress_ng_cpu_vm,%s,%s,FAIL,%s,%s,%s\n' "${round}" "${stress_sec}" "${ghz}" "${tmax}" "stress-ng rc=${stress_rc}" >> "${CPU_CSV}"
      add_hard_fail "CPU stress-ng failed at round ${round}"
    fi

    np_log="${LOG_DIR}/cpu-numpy-round${round}.log"
    np_res="$(run_timed "${np_log}" direnv exec "${CPDA_DIR}" python - <<'PY'
import numpy as np
rng = np.random.default_rng(42)
a = rng.standard_normal((1024,1024), dtype=np.float32)
b = rng.standard_normal((1024,1024), dtype=np.float32)
for _ in range(8):
    _ = a @ b
print('ok')
PY
)"
    np_rc="${np_res%%|*}"
    np_sec="${np_res#*|}"

    if [[ "${np_rc}" -eq 0 ]]; then
      printf 'cpu,numpy_matmul_short,%s,%s,PASS,%s,%s,%s\n' "${round}" "${np_sec}" "${ghz}" "${tmax}" "shape=1024 iters=8" >> "${CPU_CSV}"
    else
      printf 'cpu,numpy_matmul_short,%s,%s,FAIL,%s,%s,%s\n' "${round}" "${np_sec}" "${ghz}" "${tmax}" "numpy task rc=${np_rc}" >> "${CPU_CSV}"
      add_hard_fail "CPU numpy task failed at round ${round}"
    fi
  done
else
  add_limitation "CPU lane disabled by user option"
fi

# ---------------------------
# Phase 3: GPU lane
# ---------------------------
if [[ "${RUN_GPU}" -eq 1 ]]; then
  log "Phase 3: GPU microbench lane"
  req_profile="${PROFILE}"
  eff_profile="${PROFILE}"
  size=128
  if [[ "${PROFILE}" == "balanced" ]]; then
    size=256
  elif [[ "${PROFILE}" == "aggressive" ]]; then
    size=512
  fi
  iters=20

  for round in $(seq 1 "${ROUNDS}"); do
    gpu_log="${LOG_DIR}/gpu-${eff_profile}-round${round}.log"
    gpu_res="$(run_timed "${gpu_log}" direnv exec "${CPDA_DIR}" env \
      GPU_SIZE="${size}" GPU_ITERS="${iters}" \
      python - <<'PY'
import json, os, time, torch
size = int(os.getenv('GPU_SIZE', '128'))
iters = int(os.getenv('GPU_ITERS', '20'))
res = {
    'torch_version': torch.__version__,
    'hip': getattr(torch.version, 'hip', None),
    'cuda_available': bool(torch.cuda.is_available()),
    'size': size,
    'iters': iters,
}
if not torch.cuda.is_available():
    raise SystemExit('cuda_not_available')
res['device'] = torch.cuda.get_device_name(0)
x = torch.randn((size, size), device='cuda')
y = torch.randn((size, size), device='cuda')
torch.cuda.synchronize()
t0 = time.time()
for _ in range(iters):
    _ = x @ y
torch.cuda.synchronize()
res['avg_iter_ms'] = ((time.time() - t0) / iters) * 1000.0
print(json.dumps(res))
PY
)"

    gpu_rc="${gpu_res%%|*}"
    gpu_sec="${gpu_res#*|}"
    avg_iter_ms="$(parse_json_field avg_iter_ms "${gpu_log}")"

    if rg -qi '/opt/amdgpu/share/libdrm/amdgpu.ids: No such file or directory' "${gpu_log}"; then
      add_soft_warn "gpu_loader_amdgpu_ids_missing"
    fi
    if rg -qi 'terminator_CreateInstance|dzn\.so' "${gpu_log}"; then
      add_soft_warn "gpu_vulkan_loader_dzn_warning"
    fi

    if [[ "${gpu_rc}" -eq 0 ]]; then
      printf 'gpu,gpu_matmul,%s,%s,%s,%s,%s,%s,%s,PASS,%s\n' \
        "${req_profile}" "${eff_profile}" "${size}" "${iters}" "${round}" "${gpu_sec}" "${avg_iter_ms}" "stable" >> "${GPU_CSV}"
      continue
    fi

    if [[ "${req_profile}" == "aggressive" && "${eff_profile}" == "aggressive" ]]; then
      add_soft_warn "gpu_profile_fallback_aggressive_to_balanced"
      eff_profile="balanced"
      size=256

      gpu_fb_log="${LOG_DIR}/gpu-${eff_profile}-fallback-round${round}.log"
      gpu_fb_res="$(run_timed "${gpu_fb_log}" direnv exec "${CPDA_DIR}" env \
        GPU_SIZE="${size}" GPU_ITERS="${iters}" \
        python - <<'PY'
import json, os, time, torch
size = int(os.getenv('GPU_SIZE', '256'))
iters = int(os.getenv('GPU_ITERS', '20'))
if not torch.cuda.is_available():
    raise SystemExit('cuda_not_available')
x = torch.randn((size, size), device='cuda')
y = torch.randn((size, size), device='cuda')
torch.cuda.synchronize()
t0 = time.time()
for _ in range(iters):
    _ = x @ y
torch.cuda.synchronize()
print(json.dumps({'avg_iter_ms': ((time.time() - t0) / iters) * 1000.0}))
PY
)"

      gpu_fb_rc="${gpu_fb_res%%|*}"
      gpu_fb_sec="${gpu_fb_res#*|}"
      gpu_fb_avg="$(parse_json_field avg_iter_ms "${gpu_fb_log}")"
      if [[ "${gpu_fb_rc}" -eq 0 ]]; then
        printf 'gpu,gpu_matmul,%s,%s,%s,%s,%s,%s,%s,PASS,%s\n' \
          "${req_profile}" "${eff_profile}" "${size}" "${iters}" "${round}" "${gpu_fb_sec}" "${gpu_fb_avg}" "fallback_from_aggressive" >> "${GPU_CSV}"
      else
        printf 'gpu,gpu_matmul,%s,%s,%s,%s,%s,%s,%s,FAIL,%s\n' \
          "${req_profile}" "${eff_profile}" "${size}" "${iters}" "${round}" "${gpu_fb_sec}" "" "fallback_failed rc=${gpu_fb_rc}" >> "${GPU_CSV}"
        add_hard_fail "GPU failed after aggressive->balanced fallback at round ${round}"
      fi
    else
      printf 'gpu,gpu_matmul,%s,%s,%s,%s,%s,%s,%s,FAIL,%s\n' \
        "${req_profile}" "${eff_profile}" "${size}" "${iters}" "${round}" "${gpu_sec}" "${avg_iter_ms}" "gpu_rc=${gpu_rc}" >> "${GPU_CSV}"
      add_hard_fail "GPU lane failed at round ${round} (profile=${eff_profile})"
    fi
  done
else
  add_limitation "GPU lane disabled by user option"
fi

# ---------------------------
# Phase 4: CPDA lane
# ---------------------------
CPDA_PYTEST_TOTAL=0
CPDA_PYTEST_FALLBACK=0
CPDA_CLI_TOTAL_REPEAT=0
CPDA_CLI_FALLBACK_REPEAT=0

if [[ "${RUN_CPDA}" -eq 1 ]]; then
  log "Phase 4: CPDA workload lane"
  ds_path="$(select_cpda_dataset)"
  if [[ -z "${ds_path}" ]]; then
    add_hard_fail "Cannot find CPDA dataset for short benchmark"
  else
    param_row "cpda" "benchmark_dataset" "${ds_path}" "false" "runtime-detect" "Short benchmark dataset for CPDA lane"
  fi

  for round in $(seq 1 "${ROUNDS}"); do
    py_log="${LOG_DIR}/cpda-pytest-round${round}.log"
    py_res="$(run_timed "${py_log}" direnv exec "${CPDA_DIR}" python -m pytest -q "${CPDA_DIR}/tests/integration/test_phase1_regressions.py::test_sparse_pipeline_smoke")"
    py_rc="${py_res%%|*}"
    py_wall="${py_res#*|}"

    CPDA_PYTEST_TOTAL=$((CPDA_PYTEST_TOTAL + 1))
    py_internal="$(parse_pytest_seconds "${py_log}")"
    py_status="PASS"
    py_details="pytest_ok"

    if [[ "${py_rc}" -ne 0 ]]; then
      py_status="FAIL"
      py_details="pytest_rc=${py_rc}"
      add_hard_fail "CPDA pytest smoke failed at round ${round}"
    elif [[ -z "${py_internal}" ]]; then
      py_status="WARN"
      py_internal="${py_wall}"
      py_details="fallback_wall_time"
      CPDA_PYTEST_FALLBACK=$((CPDA_PYTEST_FALLBACK + 1))
      add_soft_warn "cpda_pytest_internal_parse_fallback"
    fi

    printf 'cpda,cpda_pytest_sparse_smoke,%s,0,%s,%s,,,,internal,%s,%s,%s\n' \
      "${round}" "${py_wall}" "${py_internal}" "${py_status}" "${py_details}" "${py_log}" >> "${CPDA_CSV}"

    if [[ -n "${ds_path}" ]]; then
      declare -a cli_round_internal_vals=()
      declare -a cli_round_wall_vals=()
      cli_round_fail=0

      for rep in $(seq 1 "${CPDA_CLI_REPEATS}"); do
        CPDA_CLI_TOTAL_REPEAT=$((CPDA_CLI_TOTAL_REPEAT + 1))
        bench_csv="${LOG_DIR}/cpda-short-bench-round${round}-rep${rep}.csv"
        bench_avg_csv="${LOG_DIR}/cpda-short-bench-round${round}-rep${rep}_avg.csv"
        cli_log="${LOG_DIR}/cpda-cli-round${round}-rep${rep}.log"
        cli_res="$(run_timed "${cli_log}" direnv exec "${CPDA_DIR}" env \
          OMP_NUM_THREADS="${CPDA_THREAD_COUNT}" \
          OPENBLAS_NUM_THREADS="${CPDA_THREAD_COUNT}" \
          MKL_NUM_THREADS="${CPDA_THREAD_COUNT}" \
          NUMEXPR_NUM_THREADS="${CPDA_THREAD_COUNT}" \
          python -m OCCPDA.evaluation.benchmark_runner \
            --data "${ds_path}" \
            --csv_out "${bench_csv}" \
            --seed 42 \
            --min_n 1 \
            --max_n 10000 \
            --max_train_samples 10000 \
            --methods cpda \
            --multi_seed)"
        cli_rc="${cli_res%%|*}"
        cli_wall="${cli_res#*|}"

        cli_parse_csv="${bench_csv}"
        if [[ -f "${bench_avg_csv}" ]]; then
          cli_parse_csv="${bench_avg_csv}"
        fi

        cli_internal="$(parse_cpda_cli_internal "${cli_parse_csv}")"
        cli_status="PASS"
        cli_details="cli_ok"

        if [[ "${cli_rc}" -ne 0 ]]; then
          cli_status="FAIL"
          cli_details="cli_rc=${cli_rc}"
          cli_round_fail=1
          add_hard_fail "CPDA CLI benchmark failed at round ${round}, repeat ${rep}"
        elif [[ -z "${cli_internal}" ]]; then
          cli_status="WARN"
          cli_internal="${cli_wall}"
          cli_details="fallback_wall_time"
          CPDA_CLI_FALLBACK_REPEAT=$((CPDA_CLI_FALLBACK_REPEAT + 1))
          add_soft_warn "cpda_cli_internal_parse_fallback"
        fi

        if [[ "${cli_status}" == "PASS" || "${cli_status}" == "WARN" ]]; then
          cli_round_internal_vals+=("${cli_internal}")
          cli_round_wall_vals+=("${cli_wall}")
        fi

        printf 'cpda,cpda_cli_short_benchmark,%s,%s,%s,%s,%s,,,internal,%s,%s,%s\n' \
          "${round}" "${rep}" "${cli_wall}" "${cli_internal}" "${cli_internal}" "${cli_status}" "${cli_details}" "${cli_parse_csv}" >> "${CPDA_CSV}"

        if [[ "${rep}" -lt "${CPDA_CLI_REPEATS}" && "${CPDA_CLI_COOLDOWN_SEC}" -gt 0 ]]; then
          sleep "${CPDA_CLI_COOLDOWN_SEC}"
        fi
      done

      round_status="PASS"
      round_details="round_aggregated"
      if [[ "${cli_round_fail}" -eq 1 ]]; then
        round_status="FAIL"
        round_details="contains_failed_repeat"
      fi

      if [[ "${#cli_round_internal_vals[@]}" -gt 0 ]]; then
        internal_stats="$(calc_stats_from_values "${cli_round_internal_vals[@]}")"
        round_internal_median="${internal_stats%%|*}"
        round_internal_p95="${internal_stats#*|}"

        wall_stats="$(calc_stats_from_values "${cli_round_wall_vals[@]}")"
        round_wall_median="${wall_stats%%|*}"
      else
        round_internal_median=""
        round_internal_p95=""
        round_wall_median=""
        round_status="FAIL"
        round_details="no_valid_repeat"
        add_hard_fail "CPDA CLI has no valid repeat values at round ${round}"
      fi

      if [[ -z "${round_internal_median}" || -z "${round_internal_p95}" ]]; then
        if [[ "${round_status}" != "FAIL" ]]; then
          round_status="WARN"
          round_details="round_stat_missing"
        fi
      fi

      printf 'cpda,cpda_cli_short_benchmark,%s,0,%s,%s,,%s,%s,internal,%s,%s,%s\n' \
        "${round}" "${round_wall_median}" "${round_internal_median}" "${round_internal_median}" "${round_internal_p95}" "${round_status}" "${round_details}" "${LOG_DIR}/cpda-short-bench-round${round}-rep*" >> "${CPDA_CSV}"
    fi
  done

  if [[ "${CPDA_CLI_TOTAL_REPEAT}" -gt 0 ]] && awk -v f="${CPDA_CLI_FALLBACK_REPEAT}" -v t="${CPDA_CLI_TOTAL_REPEAT}" 'BEGIN{exit !((f/t)>0.2)}'; then
    add_soft_warn "cpda_cli_internal_parse_instability"
  fi
else
  add_limitation "CPDA lane disabled by user option"
fi

# ---------------------------
# Phase 5: kernel/log safety lane
# ---------------------------
log "Phase 5: Kernel/log safety lane"
scan_kernel_log

# ---------------------------
# Phase 6: summarize + compare + score
# ---------------------------
log "Phase 6: Summarize and score"
compute_summary_csv

CUR_GPU_MS="$(get_summary_stat gpu gpu_matmul avg_iter_ms median)"
CUR_CPDA_INTERNAL="$(get_summary_stat cpda cpda_pytest_sparse_smoke seconds_internal median)"
CUR_CPDA_CLI_REPEAT_MEDIAN="$(get_summary_stat cpda cpda_cli_short_benchmark seconds_internal_repeat median)"
CUR_CPDA_CLI_REPEAT_P95="$(get_summary_stat cpda cpda_cli_short_benchmark seconds_internal_repeat p95)"

BASE_GPU_MS="$(baseline_lookup_stat gpu gpu_matmul avg_iter_ms median)"
BASE_CPDA_INTERNAL="$(baseline_lookup_stat cpda cpda_pytest_sparse_smoke seconds_internal median)"
BASE_CPDA_CLI_REPEAT_MEDIAN="$(baseline_lookup_stat cpda cpda_cli_short_benchmark seconds_internal_repeat median)"
BASE_CPDA_CLI_REPEAT_P95="$(baseline_lookup_stat cpda cpda_cli_short_benchmark seconds_internal_repeat p95)"

GPU_IMPROVE=""
CPDA_IMPROVE=""
if [[ -n "${BASE_GPU_MS}" && -n "${CUR_GPU_MS}" ]]; then
  GPU_IMPROVE="$(kpi_percent_improve "${BASE_GPU_MS}" "${CUR_GPU_MS}")"
fi
if [[ -n "${BASE_CPDA_INTERNAL}" && -n "${CUR_CPDA_INTERNAL}" ]]; then
  CPDA_IMPROVE="$(kpi_percent_improve "${BASE_CPDA_INTERNAL}" "${CUR_CPDA_INTERNAL}")"
fi

GPU_KPI_STATUS="WARN"
GPU_KPI_NOTE="no_baseline_mapping"
if [[ -n "${BASE_GPU_MS}" && -n "${CUR_GPU_MS}" ]]; then
  GPU_KPI_NOTE="baseline=${BASE_GPU_MS} current=${CUR_GPU_MS}"
  if awk -v x="${GPU_IMPROVE}" 'BEGIN{exit !(x>=8.0)}'; then
    GPU_KPI_STATUS="PASS"
  else
    GPU_KPI_STATUS="FAIL"
  fi
fi

CPDA_KPI_STATUS="WARN"
CPDA_KPI_NOTE="no_baseline_mapping"
if [[ "${CPDA_PYTEST_TOTAL}" -gt 0 ]] && awk -v f="${CPDA_PYTEST_FALLBACK}" -v t="${CPDA_PYTEST_TOTAL}" 'BEGIN{exit !((f/t)>0.5)}'; then
  CPDA_KPI_STATUS="WARN"
  CPDA_KPI_NOTE="fallback_ratio_gt_50pct fallback=${CPDA_PYTEST_FALLBACK}/${CPDA_PYTEST_TOTAL}"
elif [[ -n "${BASE_CPDA_INTERNAL}" && -n "${CUR_CPDA_INTERNAL}" ]]; then
  CPDA_KPI_NOTE="baseline=${BASE_CPDA_INTERNAL} current=${CUR_CPDA_INTERNAL}"
  if awk -v x="${CPDA_IMPROVE}" 'BEGIN{exit !(x>=8.0)}'; then
    CPDA_KPI_STATUS="PASS"
  else
    CPDA_KPI_STATUS="FAIL"
  fi
fi

PRIMARY_PASS=0
BEST_PRIMARY="none"
BEST_VALUE=""
if [[ "${GPU_KPI_STATUS}" == "PASS" ]]; then
  PRIMARY_PASS=1
  BEST_PRIMARY="gpu"
  BEST_VALUE="${GPU_IMPROVE}"
fi
if [[ "${CPDA_KPI_STATUS}" == "PASS" ]]; then
  if [[ "${PRIMARY_PASS}" -eq 0 ]]; then
    PRIMARY_PASS=1
    BEST_PRIMARY="cpda"
    BEST_VALUE="${CPDA_IMPROVE}"
  elif awk -v a="${CPDA_IMPROVE:-0}" -v b="${BEST_VALUE:-0}" 'BEGIN{exit !(a>b)}'; then
    BEST_PRIMARY="cpda"
    BEST_VALUE="${CPDA_IMPROVE}"
  fi
fi

PRIMARY_KPI_STATUS="WARN"
PRIMARY_KPI_VALUE="NA"
PRIMARY_KPI_NOTE="no_primary_baseline"
if [[ "${PRIMARY_PASS}" -eq 1 ]]; then
  PRIMARY_KPI_STATUS="PASS"
  PRIMARY_KPI_VALUE="${BEST_VALUE}"
  PRIMARY_KPI_NOTE="best_primary_workload=${BEST_PRIMARY}"
elif [[ "${GPU_KPI_STATUS}" == "FAIL" || "${CPDA_KPI_STATUS}" == "FAIL" ]]; then
  PRIMARY_KPI_STATUS="FAIL"
  PRIMARY_KPI_VALUE="-9999"
  PRIMARY_KPI_NOTE="no_primary_metric_passed"
fi

printf 'primary_gpu_latency_improve_pct\t%s\t%s\t>=8.0\t%s\n' \
  "${GPU_KPI_STATUS}" "${GPU_IMPROVE:-NA}" "${GPU_KPI_NOTE}" >> "${SCORECARD_TSV}"
printf 'primary_cpda_smoke_latency_improve_pct\t%s\t%s\t>=8.0\t%s\n' \
  "${CPDA_KPI_STATUS}" "${CPDA_IMPROVE:-NA}" "${CPDA_KPI_NOTE}" >> "${SCORECARD_TSV}"
printf 'primary_kpi\t%s\t%s\t>=8.0\t%s\n' \
  "${PRIMARY_KPI_STATUS}" "${PRIMARY_KPI_VALUE}" "${PRIMARY_KPI_NOTE}" >> "${SCORECARD_TSV}"

SECONDARY_FAIL_COUNT=0
SECONDARY_WARN_COUNT=0

secondary_eval_stat() {
  local metric_name="$1"
  local lane="$2"
  local test="$3"
  local metric="$4"
  local stat="$5"
  local gate_enabled="$6"

  local current baseline
  current="$(get_summary_stat "${lane}" "${test}" "${metric}" "${stat}")"
  baseline="$(baseline_lookup_stat "${lane}" "${test}" "${metric}" "${stat}")"

  local status value note regress
  status="PASS"
  value="NA"
  note="ok"

  if [[ -z "${current}" ]]; then
    status="WARN"
    note="current_metric_missing;stat=${stat}"
  elif [[ -z "${baseline}" ]]; then
    status="WARN"
    note="no_baseline_mapping;stat=${stat}"
  else
    regress="$(kpi_percent_regress "${baseline}" "${current}")"
    value="${regress:-NA}"
    if [[ -n "${regress}" ]] && awk -v r="${regress}" 'BEGIN{exit !(r>5.0)}'; then
      status="FAIL"
      note="baseline=${baseline} current=${current};stat=${stat}"
    else
      status="PASS"
      note="baseline=${baseline} current=${current};stat=${stat}"
    fi
  fi

  if [[ "${gate_enabled}" -eq 1 ]]; then
    if [[ "${status}" == "FAIL" ]]; then
      SECONDARY_FAIL_COUNT=$((SECONDARY_FAIL_COUNT + 1))
    elif [[ "${status}" == "WARN" ]]; then
      SECONDARY_WARN_COUNT=$((SECONDARY_WARN_COUNT + 1))
    fi
  else
    if [[ "${status}" == "FAIL" ]]; then
      status="WARN"
    fi
    note="${note};not_gated_by_mode=${SECONDARY_KPI_MODE}"
  fi

  printf '%s\t%s\t%s\t<=5.0\t%s\n' "${metric_name}" "${status}" "${value}" "${note}" >> "${SCORECARD_TSV}"
}

GATE_MEDIAN=0
GATE_P95=0
if [[ "${SECONDARY_KPI_MODE}" == "median" || "${SECONDARY_KPI_MODE}" == "both" ]]; then
  GATE_MEDIAN=1
fi
if [[ "${SECONDARY_KPI_MODE}" == "p95" || "${SECONDARY_KPI_MODE}" == "both" ]]; then
  GATE_P95=1
fi

secondary_eval_stat "secondary_regress_cpda_pytest_sparse_smoke_internal" "cpda" "cpda_pytest_sparse_smoke" "seconds_internal" "median" "${GATE_MEDIAN}"
secondary_eval_stat "secondary_regress_cpda_pytest_sparse_smoke_internal_p95" "cpda" "cpda_pytest_sparse_smoke" "seconds_internal" "p95" "${GATE_P95}"
secondary_eval_stat "secondary_regress_cpda_cli_internal_median" "cpda" "cpda_cli_short_benchmark" "seconds_internal_repeat" "median" "${GATE_MEDIAN}"
secondary_eval_stat "secondary_regress_cpda_cli_internal_p95" "cpda" "cpda_cli_short_benchmark" "seconds_internal_repeat" "p95" "${GATE_P95}"
secondary_eval_stat "secondary_regress_gpu_matmul_avg_iter_ms" "gpu" "gpu_matmul" "avg_iter_ms" "median" "${GATE_MEDIAN}"
secondary_eval_stat "secondary_regress_gpu_matmul_avg_iter_ms_p95" "gpu" "gpu_matmul" "avg_iter_ms" "p95" "${GATE_P95}"

PREV_SECONDARY_FAIL=0
if [[ -n "${COMPARE_SCORECARD_TSV}" && -f "${COMPARE_SCORECARD_TSV}" ]]; then
  if rg -q '^secondary_regress_.*\tFAIL\t' "${COMPARE_SCORECARD_TSV}"; then
    PREV_SECONDARY_FAIL=1
  fi
fi

SECONDARY_KPI_STATUS="PASS"
SECONDARY_KPI_NOTE="regressions=0"
CONSECUTIVE_SECONDARY_FAIL=0
if [[ "${SECONDARY_FAIL_COUNT}" -gt 0 ]]; then
  if [[ "${PREV_SECONDARY_FAIL}" -eq 1 ]]; then
    SECONDARY_KPI_STATUS="FAIL"
    SECONDARY_KPI_NOTE="regressions=${SECONDARY_FAIL_COUNT}; repeated_fail_with_compare"
    CONSECUTIVE_SECONDARY_FAIL=1
  else
    SECONDARY_KPI_STATUS="WARN"
    SECONDARY_KPI_NOTE="regressions=${SECONDARY_FAIL_COUNT}; first_observed_fail"
  fi
elif [[ "${SECONDARY_WARN_COUNT}" -gt 0 ]]; then
  SECONDARY_KPI_STATUS="WARN"
  SECONDARY_KPI_NOTE="warn_metrics=${SECONDARY_WARN_COUNT}"
fi

printf 'secondary_kpi\t%s\tregressions=%s\t0\t%s\n' \
  "${SECONDARY_KPI_STATUS}" "${SECONDARY_FAIL_COUNT}" "${SECONDARY_KPI_NOTE}" >> "${SCORECARD_TSV}"

HARD_FAIL_COUNT="${#HARD_FAILS[@]}"
SOFT_WARN_UNIQUE="$(soft_warn_unique_count)"
SOFT_WARN_TOTAL="$(soft_warn_total_count)"

printf 'hard_fail_count\t%s\t%s\t0\thard_fail events detected\n' \
  "$( [[ "${HARD_FAIL_COUNT}" -eq 0 ]] && echo PASS || echo FAIL )" "${HARD_FAIL_COUNT}" >> "${SCORECARD_TSV}"
printf 'soft_warn_count\t%s\tunique=%s,total=%s\t0\tdeduplicated warning signatures\n' \
  "$( [[ "${SOFT_WARN_UNIQUE}" -eq 0 ]] && echo PASS || echo WARN )" "${SOFT_WARN_UNIQUE}" "${SOFT_WARN_TOTAL}" >> "${SCORECARD_TSV}"

HAS_WARN_SIGNAL=0
if [[ "${SOFT_WARN_UNIQUE}" -gt 0 || "${SECONDARY_KPI_STATUS}" == "WARN" || "${PRIMARY_KPI_STATUS}" == "WARN" || "${#LIMITATIONS[@]}" -gt 0 ]]; then
  HAS_WARN_SIGNAL=1
fi

DECISION="GO-WITH-WARN"
if [[ "${HARD_FAIL_COUNT}" -gt 0 ]]; then
  DECISION="NO-GO"
elif [[ "${PRIMARY_KPI_STATUS}" == "FAIL" ]]; then
  DECISION="NO-GO"
elif [[ "${CONSECUTIVE_SECONDARY_FAIL}" -eq 1 ]]; then
  DECISION="NO-GO"
elif [[ "${HAS_WARN_SIGNAL}" -eq 0 && "${SECONDARY_FAIL_COUNT}" -eq 0 ]]; then
  DECISION="GO"
else
  DECISION="GO-WITH-WARN"
fi

printf 'final_decision\t%s\t%s\tGO|GO-WITH-WARN|NO-GO\tpolicy=performance-first-no-crash\n' \
  "$( [[ "${DECISION}" == "NO-GO" ]] && echo FAIL || echo PASS )" "${DECISION}" >> "${SCORECARD_TSV}"

# Final markdown report
{
  echo "# AMD/Ryzen Performance Suite Report"
  echo
  echo "- Started: ${START_ISO}"
  echo "- Finished: $(date -Iseconds)"
  echo "- Root: \`${ROOT}\`"
  echo "- Profile requested: ${PROFILE}"
  echo "- Rounds: ${ROUNDS}"
  echo "- Secondary KPI mode: ${SECONDARY_KPI_MODE}"
  echo "- CPDA CLI repeats: ${CPDA_CLI_REPEATS}"
  echo "- CPDA thread count: ${CPDA_THREAD_COUNT}"
  echo "- Baseline mode: ${BASELINE_MODE}"
  echo "- Baseline policy: ${BASELINE_POLICY}"
  echo "- Baseline root: ${COMPARE_ROOT:-NA}"
  echo "- Decision: **${DECISION}**"
  echo
  echo "## KPI Summary"
  echo
  echo "| Metric | Status | Value | Target | Note |"
  echo "|---|---|---:|---|---|"
  tail -n +2 "${SCORECARD_TSV}" | while IFS=$'\t' read -r metric status value target note; do
    esc_note="${note//|/\\|}"
    echo "| ${metric} | ${status} | ${value} | ${target} | ${esc_note} |"
  done
  echo
  echo "## Regression List"
  echo
  if [[ "${SECONDARY_FAIL_COUNT}" -eq 0 ]]; then
    echo "- No >5% mapped regression found in this run."
  else
    rg '^secondary_regress_.*\tFAIL\t' "${SCORECARD_TSV}" | while IFS=$'\t' read -r metric status value target note; do
      echo "- ${metric}: ${value}% (${note})"
    done
  fi
  echo
  echo "## Soft Warnings (deduplicated)"
  echo
  if [[ "${SOFT_WARN_UNIQUE}" -eq 0 ]]; then
    echo "- None"
  else
    for key in "${!SOFT_WARN_COUNTS[@]}"; do
      echo "- ${key} (count=${SOFT_WARN_COUNTS["${key}"]})"
    done
  fi
  echo
  echo "## Hard Failures"
  echo
  if [[ "${HARD_FAIL_COUNT}" -eq 0 ]]; then
    echo "- None"
  else
    for h in "${HARD_FAILS[@]}"; do
      echo "- ${h}"
    done
  fi
  echo
  echo "## Kernel Log Summary"
  echo
  if [[ "${WITH_KERNEL_LOG}" -eq 1 ]]; then
    echo "- Hard-fail match file: \`${KERNEL_HARDFAIL_LOG}\`"
    echo "- Soft-observed file: \`${KERNEL_SOFT_LOG}\`"
    echo "- Hard-fail match lines: $(wc -l < "${KERNEL_HARDFAIL_LOG}" 2>/dev/null || echo 0)"
    echo "- Soft-observed lines: $(wc -l < "${KERNEL_SOFT_LOG}" 2>/dev/null || echo 0)"
  else
    echo "- Kernel log scan disabled."
  fi
  echo
  echo "## Limitations"
  echo
  if [[ "${#LIMITATIONS[@]}" -eq 0 ]]; then
    echo "- None"
  else
    for l in "${LIMITATIONS[@]}"; do
      echo "- ${l}"
    done
  fi
  echo
  echo "## Output Artifacts"
  echo
  echo "1. \`${MANIFEST_DIR}/params.tsv\`"
  echo "2. \`${MANIFEST_DIR}/baseline.json\`"
  echo "3. \`${CPU_CSV}\`"
  echo "4. \`${GPU_CSV}\`"
  echo "5. \`${CPDA_CSV}\`"
  echo "6. \`${SUMMARY_CSV}\`"
  echo "7. \`${SCORECARD_TSV}\`"
  echo "8. \`${FINAL_REPORT}\`"
  echo "9. \`${KERNEL_HARDFAIL_LOG}\`"
  echo "10. \`${KERNEL_SOFT_LOG}\`"
} > "${FINAL_REPORT}"

log "Done. Root: ${ROOT}"
log "Report: ${FINAL_REPORT}"

echo "ROOT=${ROOT}"
