# Oh My Zsh + tmux bootstrap

One-shot setup for a new machine: installs **Oh My Zsh**, the two plugins
worth having (autosuggestions + syntax highlighting), and a minimal
**tmux config** tuned for modern TUIs like Claude Code.

Runs on **macOS** (via Homebrew) and **Debian/Ubuntu** (via apt).

## Features

- Installs Zsh, tmux, git, curl via the right package manager for your OS.
- Installs Oh My Zsh unattended (no mid-install prompts).
- Installs `zsh-autosuggestions` and `zsh-syntax-highlighting`, and enables
  both in `~/.zshrc`.
- Drops a vanilla `~/.tmux.conf` that fixes the usual input-eating issues
  inside tmux (arrow keys spilling as `[A`, keys needing two presses, etc.).
  See [TMUX-NOTES.md](TMUX-NOTES.md) for the debugging story.
- Optional: set Zsh as the default shell.
- Safe to re-run: everything is idempotent, and any existing `~/.tmux.conf`
  is backed up with a timestamp suffix before being replaced.

## Prerequisites

- **macOS:** [Homebrew](https://brew.sh) installed.
- **Debian/Ubuntu:** `sudo` access (for `apt-get`).

## Install

```bash
git clone https://github.com/luutuankiet/oh-my-zsh-installer.git
cd oh-my-zsh-installer
chmod +x install_oh_my_zsh.sh
./install_oh_my_zsh.sh          # install, leave default shell alone
./install_oh_my_zsh.sh yes      # install AND chsh to zsh
```

Then open a new terminal (or `exec zsh`) to pick up Oh My Zsh + plugins,
and open a new tmux pane to pick up the tmux config.

## License

MIT — see [LICENSE](LICENSE).
