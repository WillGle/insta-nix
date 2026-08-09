#!/usr/bin/env bash
# Shared by llm-fit and llm-run, which otherwise carried byte-identical copies
# of both functions below.
#
# Callers set, before sourcing: PROG (name used in error messages), FIT (the
# llama-fit-params binary), MODEL, CTX. fit_params sets FITTED_CTX/FITTED_NGL.

# Ask llama-fit-params what actually fits. Extra arguments are passed straight
# through, which is how the KV-cache ladder (f16 -> q8_0 -> q4_0) is walked.
fit_params() {
  local output

  if ! output="$("$FIT" -m "$MODEL" -c "$CTX" -fa on "$@")"; then
    printf '%s: llama-fit-params failed\n' "$PROG" >&2
    return 3
  fi

  # The contract is exactly "-c N -ngl M". Anything else means a version skew,
  # and guessing our way through it would hand llama-server a wrong -ngl.
  if ! [[ "${output//$'\n'/ }" =~ ^[[:space:]]*-c[[:space:]]+([1-9][0-9]*)[[:space:]]+-ngl[[:space:]]+(-?[0-9]+)[[:space:]]*$ ]]; then
    printf "%s: unexpected llama-fit-params output, expected '-c N -ngl M': %s\n" "$PROG" "$output" >&2
    return 3
  fi

  FITTED_CTX="${BASH_REMATCH[1]}"
  FITTED_NGL="${BASH_REMATCH[2]}"
}

# -ngl -1 means every layer went to the GPU; a fitted context below the
# requested one means it did not fit and the fitter shrank the request.
full_offload_at_requested_context() {
  [ "$FITTED_CTX" = "$CTX" ] && [ "$FITTED_NGL" = "-1" ]
}
