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

# ── layout: fit name · group · key into the popup width ──
# Priority: name column, then real keys (prefix ,); drop the group column first when short
# on space, and trim long ":command" hints with … rather than letting fzf clip the line.
budget=$(( cols - 4 ))          # fzf pointer (2) + right margin (2)
keyw=0 showgroup=1
if [ "$SHOW_KEYS" = on ] && [ "$width" -gt 0 ]; then
  keyw=$(( budget - namew - 2 - groupw - 2 ))
  if [ "$keyw" -lt 14 ] && [ "$keyw" -lt "$width" ]; then   # not enough room: drop groups
    showgroup=0; keyw=$(( budget - namew - 2 ))
  fi
  [ "$keyw" -gt "$width" ] && keyw=$width
  if [ "$keyw" -lt 10 ]; then        # tiny popup: shrink the name column instead
    keyw=$(( width < 10 ? width : 10 ))
    namew=$(( budget - keyw - 2 )); [ "$namew" -lt 12 ] && namew=12
  fi
fi
[ $showgroup = 1 ] && groupcol=$(( groupw + 2 )) || groupcol=0

fit() { # fit <text> <width>: cut to width with a trailing … when too long
  if [ ${#1} -gt "$2" ]; then printf '%s…' "${1:0:$(( $2 - 1 ))}"; else printf '%s' "$1"; fi
}

list() {
  local i k pad g name
  for i in "${!NAMES[@]}"; do
    name=$(fit "${NAMES[$i]}" "$namew")
    g=""; [ $showgroup = 1 ] && g=$(printf '  \033[2m%-*s\033[0m' "$groupw" "${GROUPS_[$i]}")
    k=""
    if [ "$keyw" -gt 0 ] && [ -n "${KEYTXT[$i]}" ]; then
      pad=$(( budget - namew - groupcol - keyw ))
      [ "$pad" -lt 2 ] && pad=2
      k=$(printf '%*s' "$pad" "")$'\033['"${KEYCLR[$i]}m"$(printf '%*s' "$keyw" "$(fit "${KEYTXT[$i]}" "$keyw")")$'\033[0m'
    fi
    printf '%-*s%s%s\n' "$namew" "$name" "$g" "$k"
  done
}

read -r -a extra_opts <<<"$(tmux show-option -gqv @palette-fzf-options)"
out=$(list | fzf --ansi --delimiter=' {2,}' --nth="$([ $showgroup = 1 ] && echo 1,2 || echo 1)" --print-query --reverse --tiebreak=begin,index \
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
  [ "${NAMES[$i]}" = "$pick" ] && { eval "${CMDS[$i]}"; exit; }
done
# name was trimmed with … to fit a narrow popup: match on what's left
if [[ $pick == *… ]]; then
  for i in "${!NAMES[@]}"; do
    [[ ${NAMES[$i]} == "${pick%…}"* ]] && { eval "${CMDS[$i]}"; exit; }
  done
fi
