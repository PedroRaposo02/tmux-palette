# shellcheck shell=bash
# Built-in actions:  action "<name>" "<group>" '<shell snippet>'
# Snippets are eval'd in bash with the helpers from helpers.sh. Add your own (or override
# these by name) in ~/.config/tmux-palette/actions.sh — see README.

# ── sessions ──
action "Switch session"          session 's=$(tmux list-sessions -F "#S" | choose "session › ") && tmux switch-client -c "$CLIENT" -t "=$s"'
action "New session"             session 'n=$(ask "Session name: ") && tmux new-session -d -s "$n" -c "$(here)" && tmux switch-client -c "$CLIENT" -t "=$n"'
action "Rename session"          session 'n=$(ask "New session name: " "$(fmt "#S")") && tmux rename-session -t "$PANE" -- "$n"'
action "Kill session"            session 'confirm "Kill session $(fmt "#S")?" && tmux kill-session -t "$(fmt "#S")"'
action "Detach"                  session 'tmux detach-client -t "$CLIENT"'
action "Session tree"            session 'later "tmux choose-tree -Zs -t $PANE"'

# ── windows ──
action "Switch window"           window 'w=$(tmux list-windows -a -F "#S:#I  #W" | choose "window › ") && tmux switch-client -c "$CLIENT" -t "${w%% *}"'
action "New window"              window 'tmux new-window -a -t "$WINDOW" -c "$(here)"'
action "Rename window"           window 'n=$(ask "New window name: " "$(fmt "#W")") && tmux rename-window -t "$WINDOW" -- "$n"'
action "Kill window"             window 'confirm "Kill window $(fmt "#W")?" && tmux kill-window -t "$WINDOW"'
action "Next window"             window 'tmux next-window -t "$(fmt "#S")"'
action "Previous window"         window 'tmux previous-window -t "$(fmt "#S")"'
action "Last window"             window 'tmux last-window -t "$(fmt "#S")"'
action "Move window left"        window 'tmux swap-window -d -s "$WINDOW" -t -1'
action "Move window right"       window 'tmux swap-window -d -s "$WINDOW" -t +1'
action "Move window to session"  window 's=$(tmux list-sessions -F "#S" | choose "to session › ") && tmux move-window -s "$WINDOW" -t "$s:"'

# ── panes ──
action "Split right"             pane 'tmux split-window -h -t "$PANE" -c "$(here)"'
action "Split down"              pane 'tmux split-window -v -t "$PANE" -c "$(here)"'
action "Rename pane"             pane 'n=$(ask "Pane title: " "$(fmt "#{pane_title}")") && tmux select-pane -t "$PANE" -T "$n" && tmux set -w -t "$WINDOW" pane-border-status top'
action "Show pane titles"        pane 'tmux set -w -t "$WINDOW" pane-border-status top'
action "Hide pane titles"        pane 'tmux set -w -t "$WINDOW" pane-border-status off'
action "Zoom pane (toggle)"      pane 'tmux resize-pane -Z -t "$PANE"'
action "Kill pane"               pane 'tmux kill-pane -t "$PANE"'
action "Break pane into new window" pane 'tmux break-pane -s "$PANE"'
action "Join pane from window"   pane 'w=$(tmux list-windows -F "#I  #W" | choose "from window › ") && tmux join-pane -h -s ":${w%% *}" -t "$PANE"'
action "Swap pane with previous" pane 'tmux swap-pane -U -t "$PANE"'
action "Swap pane with next"     pane 'tmux swap-pane -D -t "$PANE"'
action "Rotate panes"            pane 'tmux rotate-window -t "$WINDOW"'
action "Type in all panes (toggle sync)" pane 'tmux set -w -t "$WINDOW" synchronize-panes && msg "Sync panes: $(fmt "#{?synchronize-panes,ON,OFF}")"'
action "Layout: tiled"           pane 'tmux select-layout -t "$PANE" tiled'
action "Layout: side by side"    pane 'tmux select-layout -t "$PANE" even-horizontal'
action "Layout: stacked"         pane 'tmux select-layout -t "$PANE" even-vertical'
action "Layout: main + side"     pane 'tmux select-layout -t "$PANE" main-vertical'
action "Clear pane history"      pane 'tmux clear-history -t "$PANE"'
action "Restart pane"            pane 'confirm "Kill what is running in this pane and restart it?" && tmux respawn-pane -k -t "$PANE"'

# ── copy ──
action "Copy mode / scroll back" copy 'tmux copy-mode -t "$PANE"'
action "Paste"                   copy 'tmux paste-buffer -t "$PANE"'
action "Choose buffer to paste"  copy 'later "tmux choose-buffer -Z -t $PANE"'
action "Save pane output to file" copy 'f=$(ask "Save to: " "$HOME/tmux-$(fmt "#S-#I")-$(date +%F-%H%M).log") && tmux capture-pane -p -J -S - -t "$PANE" > "$f" && msg "Saved $f"'

# ── tmux ──
action "Reload config"           tmux 'f=$(tmux display -p "#{config_files}"); f=${f%%,*}; tmux source-file "${f:-$HOME/.tmux.conf}" && msg "Config reloaded"'
action "List keybindings"        tmux 'tmux list-keys -N | less'
action "Clock"                   tmux 'tmux clock-mode -t "$PANE"'
action "Kill server"             tmux 'confirm "Kill the tmux server and ALL sessions?" && tmux kill-server'

# ── optional integrations (only listed when the plugin is installed) ──
[ -x "$PLUGINS_DIR/extrakto/scripts/open.sh" ] && \
action "Grab text from screen"   copy 'later "$PLUGINS_DIR/extrakto/scripts/open.sh $PANE"'
[ -x "$PLUGINS_DIR/tmux-resurrect/scripts/save.sh" ] && \
action "Save sessions"           session '"$PLUGINS_DIR/tmux-resurrect/scripts/save.sh" && msg "Sessions saved"'
[ -x "$PLUGINS_DIR/tmux-resurrect/scripts/restore.sh" ] && \
action "Restore sessions"        session 'later "$PLUGINS_DIR/tmux-resurrect/scripts/restore.sh"'
[ -x "$PLUGINS_DIR/tpm/bin/install_plugins" ] && \
action "Install / update plugins" tmux '"$PLUGINS_DIR/tpm/bin/install_plugins"; "$PLUGINS_DIR/tpm/bin/update_plugins" all; pause'
true
