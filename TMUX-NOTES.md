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

---

# Part 2 — Copy-mode vi + macOS clipboard (Apr 2026)

Second round of debugging, second set of lessons. This one is about the
copy-mode / clipboard side of the config, which is now also in `tmux.conf`.

## TL;DR

- `source-file` **never unsets** a previously-set option or binding — it only
  applies what's in the file. Commenting out a line has no effect on a
  running server until you explicitly revert the value.
- Vi and emacs copy-mode bindings live in **two separate key tables**
  (`copy-mode-vi` vs `copy-mode`). A binding in the wrong table is silently
  inert. Always check `tmux show-window-options -g | grep mode-keys` first.
- In vi mode, `v` is `rectangle-toggle` by default (not `begin-selection`
  like vim). `Space` is what starts selection. `y` is unbound out of the box.
- `copy-pipe-and-cancel "<cmd>"` runs the command via `/bin/sh -c` with a
  **minimal PATH** (`/usr/bin:/bin:/usr/sbin:/sbin`). On macOS that excludes
  `/opt/homebrew/bin` — bare `reattach-to-user-namespace` fails silently.
  Always full-path the binaries inside `copy-pipe-and-cancel`.
- On macOS, if tmux was spawned by a non-Aqua process (LaunchAgent, daemon),
  `pbcopy` runs but writes to a nothing-namespace. Wrap it with
  `reattach-to-user-namespace` (Homebrew package) to force it back into the
  user's Mach bootstrap namespace.
- On Linux / remote SSH boxes there is no GUI clipboard to reach. If you
  want copied text on your Mac clipboard, enable `set -s set-clipboard on`
  and trust the outer terminal emulator (iTerm2 etc.) to catch the OSC 52
  escape tmux emits. Otherwise selections just live in tmux's own buffer.

## Sticky-options trap

Symptom: you commented out `set-window-option -g mode-keys vi` and reloaded,
but `tmux show-window-options -g | grep mode-keys` still shows `vi`. Your
shiny new emacs-table bindings for `Enter` are dead.

Cause: `source-file` is additive only. The running server keeps whatever
value was last set until either (a) another `set` overrides it, (b) the
server is restarted (`tmux kill-server`), or (c) you manually reset it.

Rule: **always explicitly set the value you want**, never "remove the line
and expect the default." This applies to `mode-keys`, and to any specific
key binding you change your mind about. The current `tmux.conf` does this
at the bottom:

```tmux
bind-key -T copy-mode-vi v send -X rectangle-toggle
unbind-key -T copy-mode-vi y
unbind-key -T copy-mode-vi C-v
```

That's a defensive reset, in case an older session left overrides in the
table from a previous revision of this file.

## Two copy-mode key tables

| Table | Used when | Default flavour |
|---|---|---|
| `copy-mode`    | `mode-keys emacs` | Space = page-down, Ctrl-Space = begin-selection |
| `copy-mode-vi` | `mode-keys vi`    | Space = begin-selection, v = rectangle-toggle (!) |

These are **independent** — a `bind-key -T copy-mode Enter ...` has zero
effect while `mode-keys` is `vi`. Debugging always starts with `tmux
show-window-options -g | grep mode-keys` to figure out which table is live,
then `tmux list-keys -T <that-table>` to see what Enter actually does.

## /bin/sh minimal PATH inside copy-pipe-and-cancel

Symptom: clipboard silently fails. `tmux run-shell 'echo x | pbcopy'` works
from the same server, but copy-mode Enter doesn't.

Cause: `copy-pipe-and-cancel` runs its command via `popen()` → `/bin/sh -c`.
`/bin/sh -c` inherits a **minimal** PATH — typically
`/usr/bin:/bin:/usr/sbin:/sbin` — regardless of your shell's PATH.
`reattach-to-user-namespace` lives in `/opt/homebrew/bin`. Not on the
minimal PATH. Silent failure.

Fix: always full-path both the wrapper and the binary it invokes:

```tmux
bind-key -T copy-mode-vi Enter send -X copy-pipe-and-cancel \
  "/opt/homebrew/bin/reattach-to-user-namespace /usr/bin/pbcopy"
```

## reattach-to-user-namespace on macOS

Background: `pbcopy` talks to the macOS pasteboard via a Mach bootstrap
port. The pasteboard service runs in the user's Aqua session's bootstrap
namespace. A process that doesn't have a path to that namespace can
still call `pbcopy` — the binary runs, exits 0, and writes nothing.

This happens when tmux is spawned from:

- `launchd` user agents outside of an Aqua login (common for headless
  dev servers, like cc-web or ttyd bridges)
- `ssh user@localhost` sessions (sshd spawns in a different namespace)
- A persistent `nohup` / `disown`'d background process

Fix: `brew install reattach-to-user-namespace`, then wrap pbcopy with it
inside tmux's `copy-pipe-and-cancel`. The wrapper calls
`reboot_user_bootstrap_port(bootstrap_port)` before exec'ing pbcopy, which
rejoins the current-user Aqua session.

On modern macOS (10.12+) the workaround is still needed because of how
tmux servers get their bootstrap port at spawn time — whatever was true
when the *server* (not the client) started is what pbcopy inherits.

## OSC 52 vs pbcopy

Two different paths for "copy into the local GUI clipboard":

1. **Pipe to `pbcopy`** (macOS only). Runs a subprocess inside the tmux
   host, talks to the Aqua pasteboard directly. Works whether or not the
   outer terminal supports anything special.
2. **OSC 52 escape sequence** (cross-platform). tmux emits a special
   escape sequence containing the selection (base64-encoded) into the
   terminal. The outer terminal emulator — iTerm2, Wezterm, Alacritty,
   Kitty, Ghostty, modern VS Code — reads it and writes to the system
   clipboard of whichever machine the emulator runs on.

OSC 52 is the only option for remote / Linux tmux where you want the
selection on *your* Mac's clipboard. Enable with `set -s set-clipboard on`
and make sure the outer terminal has the feature on (in iTerm2: Preferences
→ General → Selection → "Applications in terminal may access clipboard").

The current config uses OSC 52 as belt-and-suspenders alongside pbcopy on
macOS. On Linux it's optional; this config keeps it off because the user
doesn't paste into the Mac clipboard from thinkpad.

## Mouse drag: lift ≠ commit

Default `bind-key -T copy-mode-vi MouseDragEnd1Pane send -X
copy-selection-and-cancel` means the *instant* you release the mouse
button, tmux copies and exits copy mode. That makes adjusting the
selection after drag impossible — every mouse blink is committed.

Preferred flow: drag selects and leaves you in copy mode with the
selection live. Refine with keyboard, then hit `Enter` to commit via the
real clipboard binding.

Fix: unbind both tables.

```tmux
unbind-key -T copy-mode    MouseDragEnd1Pane
unbind-key -T copy-mode-vi MouseDragEnd1Pane
```

## Debugging workflow — what worked

1. **Verify the binding is in the right table.** `tmux
   show-window-options -g | grep mode-keys` → use that table for
   `list-keys -T`.
2. **Log what's actually piped.** Replace the pbcopy target with a wrapper
   script that tees to `/tmp/copy.log` before invoking pbcopy. If the log
   is empty after a copy gesture, the pipe didn't fire — the binding isn't
   wired to the key you pressed. If the log has content, the pipe ran and
   the failure is downstream (namespace, path, etc).
3. **Compare tmux buffer vs clipboard side by side.** `tmux show-buffer`
   and `pbpaste`. If they disagree, the pipe target is broken.
4. **Full-path everything** inside `copy-pipe-and-cancel` before blaming
   anything else. The minimal PATH trap costs hours.
