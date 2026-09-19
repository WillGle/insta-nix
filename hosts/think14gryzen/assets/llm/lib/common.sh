#!/usr/bin/env bash
# Shared model-fitting helpers.
#
# Callers set, before sourcing: PROG (name used in error messages), FIT (the
# llama-fit-params binary), MODEL, CTX. fit_params sets FITTED_CTX/FITTED_NGL
# and, when needed, FITTED_OT for tensor-level CPU placement.

# Ask llama-fit-params what actually fits. Extra arguments are passed straight
# through, which is how the KV-cache ladder (f16 -> q8_0 -> q4_0) is walked.
fit_params() {
  local output normalized

  if ! output="$("$FIT" -m "$MODEL" -c "$CTX" -fa on "$@")"; then
    printf '%s: llama-fit-params failed\n' "$PROG" >&2
    return 3
  fi

  # The fitter may add -ot when only a tensor-level CPU override makes the
  # requested context fit. Preserve it; dropping it would recreate the OOM
  # that caused the fitter to emit the plan.
  normalized="${output//$'\n'/ }"
  if ! [[ "$normalized" =~ ^[[:space:]]*-c[[:space:]]+([1-9][0-9]*)[[:space:]]+-ngl[[:space:]]+(-?[0-9]+|all|auto)([[:space:]]+-ot[[:space:]]+\"(.*)\")?[[:space:]]*$ ]]; then
    printf "%s: unexpected llama-fit-params output, expected '-c N -ngl M [-ot \"...\"]': %s\n" "$PROG" "$output" >&2
    return 3
  fi

  FITTED_CTX="${BASH_REMATCH[1]}"
  FITTED_NGL="${BASH_REMATCH[2]}"
  FITTED_OT="${BASH_REMATCH[4]:-}"
}

# -ngl -1 with no tensor override means every layer went to the GPU; a fitted
# context below the requested one means it did not fit and the fitter shrank
# the request.
full_offload_at_requested_context() {
  [ "$FITTED_CTX" = "$CTX" ] && [ "$FITTED_NGL" = "-1" ] && [ -z "$FITTED_OT" ]
}
