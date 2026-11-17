# shellcheck shell=bash
# Helpers available to every action snippet (built-in and user-defined).
#   $PANE    pane the palette was opened over (e.g. %3)
#   $WINDOW  its window (e.g. @2) — use this for window commands, they reject pane ids
#   $CLIENT  client that opened it (e.g. /dev/pts/1)
#   $PLUGINS_DIR  TPM plugin directory

# fmt <format>: expand a tmux format for $PANE, e.g. fmt '#{pane_current_path}'
fmt() { tmux display -p -t "$PANE" "$1"; }

# ask <prompt> [default]: read a line (pre-filled with default); fails on empty input or Esc/Ctrl-D
ask() {
  local a
  read -r -e -p "$1" -i "${2:-}" a || return 1
  [ -n "$a" ] || return 1
  printf '%s' "$a"
}

# confirm <question>: y/N prompt
confirm() {
  local a
  read -r -n1 -p "$1 [y/N] " a
  echo
  [[ $a == [yY] ]]
}

# choose <prompt>: choose one line from stdin with fzf, prints it
choose() { fzf --reverse --border=none --prompt="$1" --info=inline; }

# later <shell command>: run after the popup closes (for tmux modes/menus/popups that
# can't open while the palette popup is still on screen)
later() { tmux run-shell -b "sleep 0.15; $1"; }

# msg <text>: show a message in the status line of the client
msg() { tmux display-message -c "$CLIENT" "$1"; }

# pause: wait for a key so output stays visible before the popup closes
pause() { echo; read -r -n1 -s -p "press any key"; }

# here: current directory of $PANE, for new splits/windows
here() { fmt '#{pane_current_path}'; }
