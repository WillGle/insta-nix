#!/usr/bin/env bash
# Before sourcing, set PROG, FIT (llama-fit-params), MODEL, and CTX.
# fit_params sets FITTED_CTX, FITTED_NGL, and optional FITTED_OT.

# Forward extra fitter arguments for the KV-cache ladder (f16 -> q8_0 -> q4_0).
fit_params() {
  local output normalized

  if ! output="$("$FIT" -m "$MODEL" -c "$CTX" -fa on "$@")"; then
    printf '%s: llama-fit-params failed\n' "$PROG" >&2
    return 3
  fi

  # Preserve tensor CPU overrides (-ot) to avoid OOM.
  normalized="${output//$'\n'/ }"
  if ! [[ "$normalized" =~ ^[[:space:]]*-c[[:space:]]+([1-9][0-9]*)[[:space:]]+-ngl[[:space:]]+(-?[0-9]+|all|auto)([[:space:]]+-ot[[:space:]]+\"(.*)\")?[[:space:]]*$ ]]; then
    printf "%s: unexpected llama-fit-params output, expected '-c N -ngl M [-ot \"...\"]': %s\n" "$PROG" "$output" >&2
    return 3
  fi

  FITTED_CTX="${BASH_REMATCH[1]}"
  FITTED_NGL="${BASH_REMATCH[2]}"
  FITTED_OT="${BASH_REMATCH[4]:-}"
}

# Full GPU offload requires -ngl -1, no tensor override, and the requested context.
full_offload_at_requested_context() {
  [ "$FITTED_CTX" = "$CTX" ] && [ "$FITTED_NGL" = "-1" ] && [ -z "$FITTED_OT" ]
}
