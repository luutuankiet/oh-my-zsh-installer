#!/usr/bin/env bash
# Install Oh My Zsh + zsh-autosuggestions + zsh-syntax-highlighting, plus
# a modern-terminal-friendly tmux config. Works on macOS (Homebrew) and
# Debian/Ubuntu (apt).
#
# Usage:
#   ./install_oh_my_zsh.sh          # install, leave default shell alone
#   ./install_oh_my_zsh.sh yes      # install and chsh -s $(which zsh)

set -euo pipefail

log()  { printf '\033[32m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*" >&2; }
die()  { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

MAKE_DEFAULT_SHELL="${1:-no}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------- OS detection ----------
case "$(uname -s)" in
  Darwin) OS="macos" ;;
  Linux)
    if command -v apt-get >/dev/null 2>&1; then
      OS="debian"
    else
      die "Unsupported Linux distro (no apt-get found). Install zsh/tmux/git/curl manually and re-run."
    fi
    ;;
  *) die "Unsupported OS: $(uname -s)" ;;
esac
log "Detected OS: $OS"
log "Make Zsh default shell: $MAKE_DEFAULT_SHELL"

# ---------- Package installation ----------
install_packages() {
  case "$OS" in
    macos)
      if ! command -v brew >/dev/null 2>&1; then
        die "Homebrew not found. Install from https://brew.sh and re-run."
      fi
      log "Installing zsh, tmux, git, curl via Homebrew..."
      brew install zsh tmux git curl
      ;;
    debian)
      log "Installing zsh, tmux, git, curl via apt..."
      sudo apt-get update
      sudo apt-get install -y zsh tmux git curl
      ;;
  esac
}

install_packages

# ---------- Oh My Zsh ----------
if [ -d "$HOME/.oh-my-zsh" ]; then
  log "Oh My Zsh already installed — skipping."
else
  log "Installing Oh My Zsh..."
  RUNZSH=no CHSH=no sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    "" --unattended
fi

OMZ_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# ---------- Plugins ----------
clone_if_missing() {
  local url="$1" dest="$2" name="$3"
  if [ -d "$dest" ]; then
    log "$name already installed — skipping."
  else
    log "Installing $name..."
    git clone --depth=1 "$url" "$dest"
  fi
}

clone_if_missing \
  https://github.com/zsh-users/zsh-autosuggestions \
  "$OMZ_CUSTOM/plugins/zsh-autosuggestions" \
  "zsh-autosuggestions"

clone_if_missing \
  https://github.com/zsh-users/zsh-syntax-highlighting \
  "$OMZ_CUSTOM/plugins/zsh-syntax-highlighting" \
  "zsh-syntax-highlighting"

# ---------- .zshrc plugin wiring ----------
# Use awk (portable) instead of sed -i (GNU/BSD flag differences).
ZSHRC="$HOME/.zshrc"
DESIRED_PLUGINS="git zsh-autosuggestions zsh-syntax-highlighting"

if [ ! -f "$ZSHRC" ]; then
  warn ".zshrc not found — OMZ install may not have completed. Skipping plugin wiring."
elif grep -Eq '^plugins=\(' "$ZSHRC"; then
  awk -v new="plugins=($DESIRED_PLUGINS)" '
    BEGIN { done = 0 }
    /^plugins=\(/ && !done { print new; done = 1; next }
    { print }
  ' "$ZSHRC" > "$ZSHRC.tmp" && mv "$ZSHRC.tmp" "$ZSHRC"
  log "Updated plugins line in .zshrc: $DESIRED_PLUGINS"
else
  printf '\nplugins=(%s)\n' "$DESIRED_PLUGINS" >> "$ZSHRC"
  log "Appended plugins line to .zshrc: $DESIRED_PLUGINS"
fi

# ---------- tmux config ----------
TMUX_CONF_SRC="$REPO_DIR/tmux.conf"
TMUX_CONF_DEST="$HOME/.tmux.conf"
if [ -f "$TMUX_CONF_SRC" ]; then
  if [ -f "$TMUX_CONF_DEST" ] && ! cmp -s "$TMUX_CONF_SRC" "$TMUX_CONF_DEST"; then
    BACKUP="$TMUX_CONF_DEST.backup.$(date +%Y%m%d%H%M%S)"
    log "Backing up existing ~/.tmux.conf to $BACKUP"
    cp "$TMUX_CONF_DEST" "$BACKUP"
  fi
  cp "$TMUX_CONF_SRC" "$TMUX_CONF_DEST"
  log "Installed tmux config to $TMUX_CONF_DEST"
else
  warn "tmux.conf not found next to this script — tmux config NOT installed."
fi

# ---------- Default shell ----------
if [ "$MAKE_DEFAULT_SHELL" = "yes" ]; then
  ZSH_PATH="$(command -v zsh)"
  log "Setting Zsh ($ZSH_PATH) as default shell..."
  if ! grep -qx "$ZSH_PATH" /etc/shells; then
    log "Adding $ZSH_PATH to /etc/shells (sudo required)."
    echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
  fi
  chsh -s "$ZSH_PATH"
else
  log "Leaving default shell unchanged (pass 'yes' to change it)."
fi

log "Done."
log "  Open a new terminal or run 'exec zsh' to pick up Oh My Zsh + plugins."
log "  Open a new tmux pane to pick up the new tmux config."
