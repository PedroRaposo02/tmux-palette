#!/usr/bin/env bash
# Runs inside the popup. Lists actions in fzf, then runs the chosen one against the
# pane/client the popup was opened over. Unmatched input runs as a raw tmux command.
set -uo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

command -v fzf >/dev/null || { echo "tmux-palette needs fzf: https://github.com/junegunn/fzf"; read -r -n1 -s; exit 1; }

# The popup's client and the pane underneath it (display-popup doesn't expand formats
# in its command, but tmux commands run from inside the popup resolve to them).
CLIENT=$(tmux display -p '#{client_name}')
PANE=$(tmux display -p '#{pane_id}')
WINDOW=$(tmux display -p '#{window_id}')
PLUGINS_DIR=$(tmux show-environment -g TMUX_PLUGIN_MANAGER_PATH 2>/dev/null | cut -d= -f2-)
PLUGINS_DIR=${PLUGINS_DIR:-$HOME/.tmux/plugins}
PLUGINS_DIR=${PLUGINS_DIR%/}
export CLIENT PANE WINDOW PLUGINS_DIR

# shellcheck source=helpers.sh
. "$SCRIPTS_DIR/helpers.sh"

# ── collect actions ──
NAMES=() GROUPS_=() CMDS=()
action() { # action <name> <group> <shell snippet>
  local i
  for i in "${!NAMES[@]}"; do   # same name again = override
    [ "${NAMES[$i]}" = "$1" ] && { GROUPS_[$i]=$2; CMDS[$i]=$3; return; }
  done
  NAMES+=("$1"); GROUPS_+=("$2"); CMDS+=("$3")
}
remove_action() { # remove_action <name>
  local i
  for i in "${!NAMES[@]}"; do
    [ "${NAMES[$i]}" = "$1" ] && unset 'NAMES[i]' 'GROUPS_[i]' 'CMDS[i]'
  done
}

# shellcheck source=actions.sh
. "$SCRIPTS_DIR/actions.sh"
user_file=$(tmux show-option -gqv @palette-actions-file)
user_file=${user_file:-${XDG_CONFIG_HOME:-$HOME/.config}/tmux-palette/actions.sh}
user_file=${user_file/#\~/$HOME}
# shellcheck disable=SC1090
[ -f "$user_file" ] && . "$user_file"

# ── pick ──
list() {
  local i
  for i in "${!NAMES[@]}"; do
    printf '%s\t\033[2m%s\033[0m\n' "${NAMES[$i]}" "${GROUPS_[$i]}"
  done
}

read -r -a extra_opts <<<"$(tmux show-option -gqv @palette-fzf-options)"
out=$(list | fzf --ansi --delimiter=$'\t' --print-query --reverse --tiebreak=begin,index \
  --border=none --prompt='› ' --info=inline \
  --header='type what you want · enter: run · no match: run as tmux command' \
  "${extra_opts[@]}")
rc=$?
query=$(sed -n 1p <<<"$out")
pick=$(sed -n 2p <<<"$out" | cut -f1)

if [ -z "$pick" ]; then
  [ $rc -eq 1 ] && [ -n "$query" ] || exit 0
  msg=$(eval "tmux $query" 2>&1) || { echo "tmux: $msg"; pause; exit 1; }
  [ -n "$msg" ] && { echo "$msg"; pause; }
  exit 0
fi

for i in "${!NAMES[@]}"; do
  if [ "${NAMES[$i]}" = "$pick" ]; then
    eval "${CMDS[$i]}"
    exit
  fi
done
