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
NAMES=() GROUPS_=() CMDS=() HINTS=() MATCHES=()
# action <name> <group> <shell snippet> [tmux command] [match regex]
#   tmux command: the equivalent tmux command, e.g. "rename-window". The palette shows the
#     key bound to it (looked up live in your bindings), or ":<command>" when nothing is bound.
#   match regex: optional ERE to find the binding instead, for commands that don't contain
#     the tmux command text literally (e.g. a run-shell script path).
action() {
  local i
  for i in "${!NAMES[@]}"; do   # same name again = override
    [ "${NAMES[$i]}" = "$1" ] && { GROUPS_[$i]=$2; CMDS[$i]=$3; HINTS[$i]=${4:-}; MATCHES[$i]=${5:-}; return; }
  done
  NAMES+=("$1"); GROUPS_+=("$2"); CMDS+=("$3"); HINTS+=("${4:-}"); MATCHES+=("${5:-}")
}
remove_action() { # remove_action <name>
  local i
  for i in "${!NAMES[@]}"; do
    [ "${NAMES[$i]}" = "$1" ] && unset 'NAMES[i]' 'GROUPS_[i]' 'CMDS[i]' 'HINTS[i]' 'MATCHES[i]'
  done
}

# shellcheck source=actions.sh
. "$SCRIPTS_DIR/actions.sh"
user_file=$(tmux show-option -gqv @palette-actions-file)
user_file=${user_file:-${XDG_CONFIG_HOME:-$HOME/.config}/tmux-palette/actions.sh}
user_file=${user_file/#\~/$HOME}
# shellcheck disable=SC1090
[ -f "$user_file" ] && . "$user_file"

# ── key hints: find the key bound to each action's tmux command ──
BIND_KEYS=() BIND_CMDS=()
load_bindings() { # prefix table first, then root; skips mouse keys and menus
  local table line re='^bind-key[[:space:]]+(-r[[:space:]]+)?-T[[:space:]]+[^[:space:]]+[[:space:]]+([^[:space:]]+)[[:space:]]+(.*)$'
  for table in prefix root; do
    while IFS= read -r line; do
      [[ $line =~ $re ]] || continue
      local key=${BASH_REMATCH[2]} cmd=${BASH_REMATCH[3]}
      [[ $key =~ ^(Mouse|Wheel|Double|Triple|Second) ]] && continue
      [[ $cmd == display-menu* ]] && continue
      key=${key#\\}; key=${key#\'}; key=${key%\'}
      [ "$table" = prefix ] && key="prefix $key"
      BIND_KEYS+=("$key"); BIND_CMDS+=("$cmd")
    done < <(tmux list-keys -T "$table" 2>/dev/null)
  done
}

key_for() { # key_for <tmux command> [regex] — prints the best key bound to it
  local hint=$1 custom=${2:-} esc start contains i best="" best_score=999999 score pass
  esc=$(printf '%s' "$hint" | sed 's/[][\.*^$(){}+?|/]/\\&/g')
  start="^$esc( |\$)"
  contains="(^|[ ;{\"'])$esc( |\$|[;}\"'])"
  for pass in 1 2; do   # 1: binding starts with the command, 2: contains it
    for i in "${!BIND_CMDS[@]}"; do
      if [ -n "$custom" ]; then [ $pass = 1 ] && continue; [[ ${BIND_CMDS[$i]} =~ $custom ]] || continue
      elif [ $pass = 1 ]; then [[ ${BIND_CMDS[$i]} =~ $start ]] || continue
      else [[ ${BIND_CMDS[$i]} =~ $contains ]] || continue; fi
      score=${#BIND_KEYS[$i]}                                  # shorter key wins…
      [[ ${BIND_KEYS[$i]} == prefix* ]] || score=$((score + 1000))   # …prefix table before root
      [ "$score" -lt "$best_score" ] && { best_score=$score; best=${BIND_KEYS[$i]}; }
    done
    [ -n "$best" ] && break
  done
  printf '%s' "$best"
}

SHOW_KEYS=$(tmux show-option -gqv @palette-show-keys)
[ "${SHOW_KEYS:-on}" = off ] && SHOW_KEYS=off || SHOW_KEYS=on
KEYTXT=() KEYCLR=() width=0
if [ "$SHOW_KEYS" = on ]; then
  load_bindings
  for i in "${!NAMES[@]}"; do
    k=""
    [ -n "${HINTS[$i]}${MATCHES[$i]}" ] && k=$(key_for "${HINTS[$i]}" "${MATCHES[$i]}")
    if [ -n "$k" ]; then KEYTXT[$i]=$k; KEYCLR[$i]=36                 # bound key: cyan
    elif [ -n "${HINTS[$i]}" ]; then KEYTXT[$i]=":${HINTS[$i]}"; KEYCLR[$i]=2   # no key: dim command
    else KEYTXT[$i]=""; KEYCLR[$i]=0; fi
    [ ${#KEYTXT[$i]} -gt "$width" ] && width=${#KEYTXT[$i]}
  done
  [ "$width" -gt 30 ] && width=30
fi
namew=0
for i in "${!NAMES[@]}"; do [ ${#NAMES[$i]} -gt "$namew" ] && namew=${#NAMES[$i]}; done

# ── pick ──  (columns: name, group, key — separated by 2+ spaces, so names must not contain
#   double spaces; only name and group are searched, the key sits on the right)
groupw=0
for i in "${!NAMES[@]}"; do [ ${#GROUPS_[$i]} -gt "$groupw" ] && groupw=${#GROUPS_[$i]}; done
cols=$(stty size </dev/tty 2>/dev/null | cut -d' ' -f2)   # popup's inner width
[[ $cols =~ ^[0-9]+$ ]] || cols=80
list() {
  local i k pad
  for i in "${!NAMES[@]}"; do
    k=""
    if [ "$SHOW_KEYS" = on ] && [ -n "${KEYTXT[$i]}" ]; then
      # right-align the key against the popup edge (fzf's pointer takes 2 columns)
      pad=$(( cols - 4 - namew - 2 - groupw - width ))
      [ "$pad" -lt 2 ] && pad=2
      k=$(printf '%*s' "$pad" "")$(printf '%*.*s' "$width" "$width" "${KEYTXT[$i]}")
      k=$'\033['"${KEYCLR[$i]}m$k"$'\033[0m'
    fi
    printf '%-*s  \033[2m%-*s\033[0m%s\n' "$namew" "${NAMES[$i]}" "$groupw" "${GROUPS_[$i]}" "$k"
  done
}

read -r -a extra_opts <<<"$(tmux show-option -gqv @palette-fzf-options)"
out=$(list | fzf --ansi --delimiter=' {2,}' --nth=1,2 --print-query --reverse --tiebreak=begin,index \
  --border=none --prompt='› ' --info=inline \
  --header='type what you want · enter: run · no match: run as tmux command' \
  "${extra_opts[@]}")
rc=$?
query=$(sed -n 1p <<<"$out")
pick=$(sed -n 2p <<<"$out" | sed 's/\x1b\[[0-9;]*m//g; s/  .*//; s/[[:space:]]*$//')

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
