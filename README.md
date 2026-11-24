# tmux-palette

A command palette for tmux. Press a key, type what you want in plain words —
*"rename pane"*, *"split right"*, *"move window to session"* — and hit enter.
No more remembering `prefix ,` or `select-pane -T`.

```
╭───────────────────────────── palette ─────────────────────────────╮
│ › ren  < 3/47                                                       │
│ > Rename pane              pane               :select-pane -T  │
│   Rename window            window                   prefix ,  │
│   Rename session           session                  prefix $  │
╰─────────────────────────────────────────────────────────────────────╯
```

- **Teaches you the shortcuts** — each action shows, on the right, the key it's bound to *in your config*
  (looked up live, so rebinds show up), or the raw `:command` when nothing is bound
- **Fuzzy search** over ~45 named actions for sessions, windows, panes, copy and tmux itself
- **Prompts when needed** — renames are pre-filled with the current name, kills ask y/N
- **Pickers** for anything that targets something else (switch session, move window to session, join pane…)
- **Raw fallback** — text that matches nothing runs as a tmux command (`resize-pane -x 80`)
- **Extensible** — add your own actions (or override built-ins) in a small bash file
- Picks up **extrakto**, **tmux-resurrect** and **TPM** actions automatically when they're installed

## Requirements

- tmux **3.2+** (for `display-popup`)
- [fzf](https://github.com/junegunn/fzf)
- bash 4+

## Install

### With [TPM](https://github.com/tmux-plugins/tpm)

```tmux
set -g @plugin 'PedroRaposo02/tmux-palette'
```

Then press `prefix I` to install.

### Manually

```sh
git clone https://github.com/PedroRaposo02/tmux-palette ~/.tmux/plugins/tmux-palette
```

```tmux
run-shell ~/.tmux/plugins/tmux-palette/palette.tmux
```

Reload tmux (`tmux source ~/.tmux.conf`).

## Usage

`prefix P` opens the palette. Type, pick with the arrows or `Ctrl-j/k`, press enter. `Esc` closes it.

## Options

```tmux
set -g @palette-key 'P'               # key after the prefix ('none' to disable)
set -g @palette-root-key ''           # optional key without prefix, e.g. 'M-p' (Alt+p)
set -g @palette-width '80%'          # the columns adapt: narrow popups drop the group column
set -g @palette-height '60%'
set -g @palette-title ' palette '
set -g @palette-fzf-options ''        # extra fzf flags, e.g. '--color=dark'
set -g @palette-show-keys 'on'        # key / command column in front of each action
set -g @palette-actions-file '~/.config/tmux-palette/actions.sh'
```

## Custom actions

Create `~/.config/tmux-palette/actions.sh` (or wherever `@palette-actions-file` points):

```bash
# action "<name>" "<group>" '<bash snippet>' ['<tmux command>' ['<match regex>']]
action "Open lazygit"   tools 'tmux display-popup -E -d "$(here)" -w 90% -h 90% lazygit' 'display-popup lazygit' 'lazygit'
action "htop"           tools 'tmux new-window -a -t "$WINDOW" htop'
action "SSH to server"  tools 'h=$(printf "web1\ndb1\n" | choose "host › ") && tmux new-window -a -t "$WINDOW" "ssh $h"'

# same name as a built-in = override it
action "Kill pane"      pane  'confirm "Really?" && tmux kill-pane -t "$PANE"'

# hide a built-in
remove_action "Kill server"
```

The optional 4th argument is the equivalent tmux command. The palette searches your key
bindings for it and shows the key in front of the action, or shows `:<command>` if nothing
is bound. When a binding doesn't contain the command text literally (a script path, a popup),
pass a 5th argument: an extended regex matched against the bound commands instead.

Snippets run in bash inside the popup, with these available:

| | |
|---|---|
| `$PANE` / `$WINDOW` / `$CLIENT` | the pane, window and client the palette was opened over. Window commands (`new-window`, `kill-window`, …) need `$WINDOW`; tmux rejects pane ids there |
| `$PLUGINS_DIR` | TPM's plugin directory |
| `fmt '<format>'` | expand a tmux format for `$PANE`, e.g. `fmt '#{pane_current_path}'` |
| `here` | the pane's current directory |
| `ask "<prompt>" [default]` | read a line (fails on empty/Esc, so `&&` chains stop) |
| `confirm "<question>"` | y/N prompt |
| `choose "<prompt>"` | pick one line from stdin with fzf |
| `later '<shell cmd>'` | run after the popup closes — for tmux modes, menus or other popups |
| `msg "<text>"` | message in the status line |
| `pause` | wait for a key so output stays visible |

To pop open another fzf script (a project picker, theme switcher…), just `exec` it — it runs in the same popup:

```bash
action "Projects" tools 'exec ~/bin/project-picker'
```

## Built-in actions

| group | actions |
|---|---|
| session | switch, new, rename, kill, detach, session tree, *save / restore (tmux-resurrect)* |
| window | switch (any session), new, rename, kill, next, previous, last, move left/right, move to session |
| pane | split right/down, rename, show/hide titles, zoom, kill, break into window, join from window, swap, rotate, sync input, layouts (tiled, side by side, stacked, main + side), clear history, restart |
| copy | copy mode, paste, choose buffer, save pane output to file, *grab text (extrakto)* |
| tmux | reload config, list keybindings, clock, kill server, *install/update plugins (TPM)* |

Renaming a pane turns on pane titles (`pane-border-status top`) for that window, since tmux
hides them by default. *Hide pane titles* turns them off again.

## Tests

```sh
tests/e2e.sh
```

Starts a throwaway tmux server, drives a real client with keystrokes and checks the results.
Your own tmux sessions aren't touched.

## License

MIT
