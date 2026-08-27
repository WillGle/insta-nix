#!/usr/bin/env bash

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
. "$SCRIPT_DIR/common.sh"

BENCH_THERMAL_MODE="${BENCH_THERMAL_MODE:-record}"
model=''
repetitions=3
prompt_tokens=512
gen_tokens=128
threads=8
gpu_layers=999
flash_attn=on
device=auto
output=''

usage() {
  cat <<'EOF'
Usage: llm.sh --model PATH [options]

Run llama-bench with the same pp512/tg128 Vulkan setup used by the local LLM
guide. The model file is read but never modified.

Options:
  --model PATH        GGUF model file (required)
  --repetitions N     llama-bench repetitions (default: 3)
  --prompt-tokens N   prompt tokens (default: 512)
  --gen-tokens N      generated tokens (default: 128)
  --threads N         CPU threads (default: 8)
  --gpu-layers N      GPU layers (default: 999)
  --flash-attn MODE   on, off, or auto (default: on)
  --device NAME       llama.cpp device (default: auto)
  --output DIR        write this run to DIR
  -h, --help          show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --model)
      [ "$#" -ge 2 ] || bench_die "--model needs a path"
      model="$2"
      shift 2
      ;;
    --repetitions)
      [ "$#" -ge 2 ] || bench_die "--repetitions needs a value"
      repetitions="$2"
      shift 2
      ;;
    --prompt-tokens)
      [ "$#" -ge 2 ] || bench_die "--prompt-tokens needs a value"
      prompt_tokens="$2"
      shift 2
      ;;
    --gen-tokens)
      [ "$#" -ge 2 ] || bench_die "--gen-tokens needs a value"
      gen_tokens="$2"
      shift 2
      ;;
    --threads)
      [ "$#" -ge 2 ] || bench_die "--threads needs a value"
      threads="$2"
      shift 2
      ;;
    --gpu-layers)
      [ "$#" -ge 2 ] || bench_die "--gpu-layers needs a value"
      gpu_layers="$2"
      shift 2
      ;;
    --flash-attn)
      [ "$#" -ge 2 ] || bench_die "--flash-attn needs a value"
      flash_attn="$2"
      shift 2
      ;;
    --device)
      [ "$#" -ge 2 ] || bench_die "--device needs a value"
      device="$2"
      shift 2
      ;;
    --output)
      [ "$#" -ge 2 ] || bench_die "--output needs a directory"
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

[ -n "$model" ] || bench_die '--model is required'
[ -f "$model" ] || bench_die "not an existing model file: $model"
bench_positive_integer repetitions "$repetitions"
bench_positive_integer prompt_tokens "$prompt_tokens"
bench_positive_integer gen_tokens "$gen_tokens"
bench_positive_integer threads "$threads"
bench_positive_integer gpu_layers "$gpu_layers"
case "$flash_attn" in
  on|off|auto) ;;
  *) bench_die '--flash-attn must be on, off, or auto' ;;
esac
[ -n "$device" ] || bench_die '--device cannot be empty'
bench_need_command llama-bench

bench_init_run llm "$output"
bench_record_tool_version llama-bench
bench_record_metadata benchmark llama-bench
bench_record_metadata model "$model"
bench_record_metadata model_size_bytes "$(stat -c '%s' -- "$model")"
bench_record_metadata repetitions "$repetitions"
bench_record_metadata prompt_tokens "$prompt_tokens"
bench_record_metadata generation_tokens "$gen_tokens"
bench_record_metadata threads "$threads"
bench_record_metadata gpu_layers "$gpu_layers"
bench_record_metadata flash_attention "$flash_attn"
bench_record_metadata device "$device"

bench_run_monitored \
  llama-bench \
  llama-bench \
    --model "$model" \
    --n-prompt "$prompt_tokens" \
    --n-gen "$gen_tokens" \
    --repetitions "$repetitions" \
    --n-gpu-layers "$gpu_layers" \
    --flash-attn "$flash_attn" \
    --threads "$threads" \
    --device "$device" \
    --output md

bench_finish
