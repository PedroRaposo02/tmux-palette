# shellcheck shell=bash
# Built-in actions:  action "<name>" "<group>" '<shell snippet>' ['<tmux command>' ['<match regex>']]
# The tmux command is shown in front of each action as the key it's bound to (or as
# ":command" when unbound), so the palette teaches the shortcuts.
# Snippets are eval'd in bash with the helpers from helpers.sh. Add your own (or override
# these by name) in ~/.config/tmux-palette/actions.sh — see README.

# ── sessions ──
action "Switch session"          session 's=$(tmux list-sessions -F "#S" | choose "session › ") && tmux switch-client -c "$CLIENT" -t "=$s"' 'switch-client -t'
action "New session"             session 'n=$(ask "Session name: ") && tmux new-session -d -s "$n" -c "$(here)" && tmux switch-client -c "$CLIENT" -t "=$n"' 'new-session'
action "Rename session"          session 'n=$(ask "New session name: " "$(fmt "#S")") && tmux rename-session -t "$PANE" -- "$n"' 'rename-session'
action "Kill session"            session 'confirm "Kill session $(fmt "#S")?" && tmux kill-session -t "$(fmt "#S")"' 'kill-session'
action "Detach"                  session 'tmux detach-client -t "$CLIENT"' 'detach-client'
action "Session tree"            session 'later "tmux choose-tree -Zs -t $PANE"' 'choose-tree -Zs'

# ── windows ──
action "Switch window"           window 'w=$(tmux list-windows -a -F "#S:#I  #W" | choose "window › ") && tmux switch-client -c "$CLIENT" -t "${w%% *}"' 'choose-tree -Zw'
action "New window"              window 'tmux new-window -a -t "$WINDOW" -c "$(here)"' 'new-window'
action "Rename window"           window 'n=$(ask "New window name: " "$(fmt "#W")") && tmux rename-window -t "$WINDOW" -- "$n"' 'rename-window'
action "Kill window"             window 'confirm "Kill window $(fmt "#W")?" && tmux kill-window -t "$WINDOW"' 'kill-window'
action "Next window"             window 'tmux next-window -t "$(fmt "#S")"' 'next-window'
action "Previous window"         window 'tmux previous-window -t "$(fmt "#S")"' 'previous-window'
action "Last window"             window 'tmux last-window -t "$(fmt "#S")"' 'last-window'
action "Move window left"        window 'tmux swap-window -d -s "$WINDOW" -t -1' 'swap-window -t -1'
action "Move window right"       window 'tmux swap-window -d -s "$WINDOW" -t +1' 'swap-window -t +1'
action "Move window to session"  window 's=$(tmux list-sessions -F "#S" | choose "to session › ") && tmux move-window -s "$WINDOW" -t "$s:"' 'move-window -t'

# ── panes ──
action "Split right"             pane 'tmux split-window -h -t "$PANE" -c "$(here)"' 'split-window -h'
action "Split down"              pane 'tmux split-window -v -t "$PANE" -c "$(here)"' 'split-window -v' '^split-window( -v)?( -c [^ ]+)?$'
action "Rename pane"             pane 'n=$(ask "Pane title: " "$(fmt "#{pane_title}")") && tmux select-pane -t "$PANE" -T "$n" && tmux set -w -t "$WINDOW" pane-border-status top' 'select-pane -T'
action "Show pane titles"        pane 'tmux set -w -t "$WINDOW" pane-border-status top' 'setw pane-border-status top'
action "Hide pane titles"        pane 'tmux set -w -t "$WINDOW" pane-border-status off' 'setw pane-border-status off'
action "Zoom pane (toggle)"      pane 'tmux resize-pane -Z -t "$PANE"' 'resize-pane -Z'
action "Kill pane"               pane 'tmux kill-pane -t "$PANE"' 'kill-pane'
action "Break pane into new window" pane 'tmux break-pane -s "$PANE"' 'break-pane'
action "Join pane from window"   pane 'w=$(tmux list-windows -F "#I  #W" | choose "from window › ") && tmux join-pane -h -s ":${w%% *}" -t "$PANE"' 'join-pane -s'
action "Swap pane with previous" pane 'tmux swap-pane -U -t "$PANE"' 'swap-pane -U'
action "Swap pane with next"     pane 'tmux swap-pane -D -t "$PANE"' 'swap-pane -D'
action "Rotate panes"            pane 'tmux rotate-window -t "$WINDOW"' 'rotate-window'
action "Type in all panes (toggle sync)" pane 'tmux set -w -t "$WINDOW" synchronize-panes && msg "Sync panes: $(fmt "#{?synchronize-panes,ON,OFF}")"' 'setw synchronize-panes' 'synchronize-panes'
action "Layout: tiled"           pane 'tmux select-layout -t "$PANE" tiled' 'select-layout tiled'
action "Layout: side by side"    pane 'tmux select-layout -t "$PANE" even-horizontal' 'select-layout even-horizontal'
action "Layout: stacked"         pane 'tmux select-layout -t "$PANE" even-vertical' 'select-layout even-vertical'
action "Layout: main + side"     pane 'tmux select-layout -t "$PANE" main-vertical' 'select-layout main-vertical'
action "Clear pane history"      pane 'tmux clear-history -t "$PANE"' 'clear-history'
action "Restart pane"            pane 'confirm "Kill what is running in this pane and restart it?" && tmux respawn-pane -k -t "$PANE"' 'respawn-pane -k'

# ── copy ──
action "Copy mode / scroll back" copy 'tmux copy-mode -t "$PANE"' 'copy-mode'
action "Paste"                   copy 'tmux paste-buffer -t "$PANE"' 'paste-buffer'
action "Choose buffer to paste"  copy 'later "tmux choose-buffer -Z -t $PANE"' 'choose-buffer'
action "Save pane output to file" copy 'f=$(ask "Save to: " "$HOME/tmux-$(fmt "#S-#I")-$(date +%F-%H%M).log") && tmux capture-pane -p -J -S - -t "$PANE" > "$f" && msg "Saved $f"' 'capture-pane -S -'

# ── tmux ──
action "Reload config"           tmux 'f=$(tmux display -p "#{config_files}"); f=${f%%,*}; tmux source-file "${f:-$HOME/.tmux.conf}" && msg "Config reloaded"' 'source-file'
action "List keybindings"        tmux 'tmux list-keys -N | less' 'list-keys -N'
action "Clock"                   tmux 'tmux clock-mode -t "$PANE"' 'clock-mode'
action "Kill server"             tmux 'confirm "Kill the tmux server and ALL sessions?" && tmux kill-server' 'kill-server'

# ── optional integrations (only listed when the plugin is installed) ──
[ -x "$PLUGINS_DIR/extrakto/scripts/open.sh" ] && \
action "Grab text from screen"   copy 'later "$PLUGINS_DIR/extrakto/scripts/open.sh $PANE"' 'run-shell extrakto' 'extrakto/scripts/open\.sh'
[ -x "$PLUGINS_DIR/tmux-resurrect/scripts/save.sh" ] && \
action "Save sessions"           session '"$PLUGINS_DIR/tmux-resurrect/scripts/save.sh" && msg "Sessions saved"' 'run-shell resurrect save' 'tmux-resurrect/scripts/save\.sh'
[ -x "$PLUGINS_DIR/tmux-resurrect/scripts/restore.sh" ] && \
action "Restore sessions"        session 'later "$PLUGINS_DIR/tmux-resurrect/scripts/restore.sh"' 'run-shell resurrect restore' 'tmux-resurrect/scripts/restore\.sh'
[ -x "$PLUGINS_DIR/tpm/bin/install_plugins" ] && \
action "Install / update plugins" tmux '"$PLUGINS_DIR/tpm/bin/install_plugins"; "$PLUGINS_DIR/tpm/bin/update_plugins" all; pause' 'run-shell tpm install' 'tpm/bindings/install_plugins'
true
