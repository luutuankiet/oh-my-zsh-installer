# Why this tmux.conf looks the way it does

Short field notes from a debugging session where a customized tmux.conf was
eating keypresses inside Claude Code. Keep this around so the next machine
doesn't relearn the lesson.

## Symptoms

1. **Arrow keys spilled as literal text** into the TUI prompt — typing `↑`
   produced `[A` instead of scrolling history. The prompt ended up with gibberish
   like `/ex[A`.
2. **Keys needed two or three presses to register.** Normal input seemed to be
   half-swallowed.

Both happen only inside tmux. Running Claude Code directly (no tmux) is fine.

## Root cause

The old `~/.tmux.conf` had:

```tmux
set -g default-terminal "screen-256color"
```

…and nothing else about keys. That setting combined two problems:

- `screen-256color`'s terminfo doesn't describe modern function-key sequences.
  Arrow keys got emitted as raw `ESC [ A` bytes, and the inner TUI never saw
  a proper "up arrow" event.
- tmux by default **does not forward CSI-u extended key sequences** — the
  modern encoding Claude Code (and other current TUIs like Helix, Kakoune,
  Zed's terminal) relies on for unambiguous key reporting. Without being told
  "your outer terminal supports extkeys," tmux silently drops them. That's
  what made keys feel swallowed.

## Fix (what's in `tmux.conf`)

```tmux
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",xterm-256color:RGB"
set -g xterm-keys on
set -s extended-keys on
set -as terminal-features 'tmux-256color:extkeys'
set -sg escape-time 10
set -g mouse on
```

What each line is doing:

| Line | Job |
|------|-----|
| `default-terminal tmux-256color` | Use the terminfo that actually describes modern keys. macOS ships it in `/usr/share/terminfo/74/tmux-256color`; check with `infocmp tmux-256color`. |
| `terminal-overrides …:RGB` | Truecolor passthrough for terminals that advertise xterm-256color outside tmux. |
| `xterm-keys on` | Emit xterm-style function-key sequences instead of dumb `ESC[A`. |
| `extended-keys on` | Accept CSI-u extended key sequences. This is the "keys needed 2 presses" fix. |
| `terminal-features …:extkeys` | Tell tmux the outer terminal speaks extkeys, so tmux is willing to forward them. |
| `escape-time 10` | Old default (500ms) can eat real keypresses that arrive close to an ESC. 10ms is fine. |
| `mouse on` | Quality of life, uncontroversial. |

## Why this file is so short

Vanilla on purpose. The previous config had a custom `C-z` prefix, vim-style
pane nav, custom split keys, and copy-mode bindings. None of those caused
today's bug, but they made the bug harder to see and easier to attribute to
the wrong thing. If you want any of that back, add it — just don't remove the
six lines above.

## Verifying on a fresh machine

```bash
tmux -V                  # needs 3.2+ for extended-keys
infocmp tmux-256color    # terminfo present?
# start a new pane after install:
echo $TERM               # should be tmux-256color
tmux show -sv extended-keys   # should print: on
```

If arrow keys still print `[A`, your **outer** terminal emulator (iTerm2 /
Ghostty / Terminal.app / VS Code terminal / etc.) probably doesn't have
"Report modifiers with CSI u" enabled. Run `/terminal-setup` inside Claude
Code — it auto-configures the common ones.

## The shape of the bug, for next time

Terminals, tmux, and TUIs negotiate keys through a chain. Any link that lies
or drops data corrupts the whole thing. When debugging "input doesn't work
right in tmux," the question is always: **which layer is lying?**

- outer emulator → tmux: does it report CSI-u? (`/terminal-setup` handles this)
- tmux → inner TUI: does it forward extkeys? (this config)
- inner TUI: does it read CSI-u at all? (Claude Code does)

All three need to line up. This repo nails the middle link.
