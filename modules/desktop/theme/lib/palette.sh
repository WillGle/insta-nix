#!/usr/bin/env bash
# Read the generated Matugen palette once and expose its ten colour slots.
# Consumers keep their own static fallbacks and map slots to their variables.

THEME_PALETTE_FILE="${THEME_PALETTE_FILE:-${THEME_GENERATED_DIR:-${XDG_CONFIG_HOME:-${HOME}/.config}/theme/generated}/palette.json}"

load_runtime_palette() {
  local values=""
  local -a palette=()

  [ -r "$THEME_PALETTE_FILE" ] || return 1
  values="$(
    jq -er '
      [
        .colors.surface.default.color,
        .colors.surface_container.default.color,
        .colors.on_surface.default.color,
        .colors.on_surface_variant.default.color,
        .colors.primary.default.color,
        .colors.secondary.default.color,
        .colors.tertiary.default.color,
        .colors.error.default.color,
        .palettes.tertiary["70"].color,
        .palettes.secondary["70"].color
      ] as $palette
      | if all($palette[]; type == "string" and test("^#[0-9A-Fa-f]{6}$"))
        then $palette | @tsv
        else error("invalid runtime palette")
        end
    ' "$THEME_PALETTE_FILE" 2>/dev/null
  )" || return 1

  IFS=$'\t' read -r -a palette <<< "$values"
  [ "${#palette[@]}" -eq 10 ] || return 1
  RUNTIME_PALETTE=("${palette[@]}")
}
