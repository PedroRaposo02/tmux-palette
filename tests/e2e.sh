#!/usr/bin/env bash
# End-to-end test: drives a real tmux client on a throwaway server (-L), opens the palette
# with keystrokes and checks the result. Needs tmux >= 3.2 and fzf. Usage: tests/e2e.sh
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOCK="palette-test-$$"
T() { tmux -L "$SOCK" "$@"; }
CONF=$(mktemp)
XDG=$(mktemp -d)
trap 'T kill-server 2>/dev/null; rm -rf "$CONF" "$XDG"' EXIT

cat >"$CONF" <<EOF
set -g prefix C-b
set -g status off
set -g @palette-key P
run-shell "$ROOT/palette.tmux"
EOF

# user actions file: one custom action + one override
mkdir -p "$XDG/tmux-palette"
cat >"$XDG/tmux-palette/actions.sh" <<'EOF'
action "Custom hello" custom 'tmux set -g @palette-test-hello yes'
EOF

export XDG_CONFIG_HOME="$XDG"
T -f "$CONF" new-session -d -s target -x 140 -y 35
# "host" session runs a nested client attached to "target": keys sent to host reach that client
T new-session -d -s host -x 140 -y 35 "env -u TMUX XDG_CONFIG_HOME='$XDG' tmux -L '$SOCK' attach -t target"
sleep 1

k() { T send-keys -t host "$@"; sleep 0.7; }
palette() { k C-b P; k -l "$1"; k Enter; }
pass=0 fail=0
check() { # check <description> <actual> <expected>
  if [ "$2" = "$3" ]; then echo "ok   - $1"; pass=$((pass+1))
  else echo "FAIL - $1 (got '$2', want '$3')"; fail=$((fail+1)); fi
}

palette "split right";   check "split right"   "$(T list-panes -t target | wc -l | tr -d ' ')" 2
palette "rename pane";   k C-u; k -l "logs"; k Enter
check "rename pane title"  "$(T display -p -t target '#{pane_title}')" logs
check "pane titles shown"  "$(T show -wv -t target pane-border-status)" top
palette "rename window"; k C-u; k -l "editor"; k Enter
check "rename window"  "$(T display -p -t target '#W')" editor
palette "kill pane";     check "kill pane"     "$(T list-panes -t target | wc -l | tr -d ' ')" 1
palette "new window";    check "new window"    "$(T list-windows -t target | wc -l | tr -d ' ')" 2
palette "custom hello";  check "user action"   "$(T show -gv @palette-test-hello)" yes
palette "set -g @palette-test-raw 1"
check "raw tmux command" "$(T show -gv @palette-test-raw)" 1
palette "kill window";   k n
check "confirm 'n' keeps window" "$(T list-windows -t target | wc -l | tr -d ' ')" 2

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
