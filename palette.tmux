#!/usr/bin/env bash
# tmux-palette — TPM entry point. Binds the palette key; everything else lives in scripts/.
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

opt() { # opt <name> <default>
  local v
  v=$(tmux show-option -gqv "$1")
  printf '%s' "${v:-$2}"
}

key=$(opt @palette-key P)
root_key=$(opt @palette-root-key "")
width=$(opt @palette-width 80%)
height=$(opt @palette-height 60%)
title=$(opt @palette-title " palette ")

cmd="display-popup -E -w '$width' -h '$height' -T '$title' '$CURRENT_DIR/scripts/palette.sh'"

[ -n "$key" ] && [ "$key" != none ] && tmux bind-key "$key" "$cmd"
[ -n "$root_key" ] && tmux bind-key -n "$root_key" "$cmd"
exit 0
