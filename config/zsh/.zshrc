# ═══════════════════════════════════════════════════════════════════════════════
# GALYARDEROS ZSH CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

# --- 1. Oh My Zsh & Visual Theme ---
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnosterzak"

plugins=(
    git
    archlinux
    zsh-autosuggestions
    zsh-syntax-highlighting
)

[ -f "$ZSH/oh-my-zsh.sh" ] && source "$ZSH/oh-my-zsh.sh"

# Pokemon Colorscript + Fastfetch Header
if [ -n "$DISPLAY" ] || [ -n "$WAYLAND_DISPLAY" ]; then
    pokemon-colorscripts --no-title -s -r 2>/dev/null | fastfetch -c "$HOME/.config/fastfetch/config-pokemon.jsonc" --logo-type file-raw --logo-height 10 --logo-width 5 --logo - 2>/dev/null || fastfetch 2>/dev/null || true
fi

# LSD (LSDeluxe) File Icons & Shortcuts
alias ls='lsd'
alias lla='ls -la'
alias lt='ls --tree'
alias ll="ls -la"
alias la="ls -A"
alias l="ls -CF"
alias ..="cd .."
alias ...="cd ../.."
alias reload="source ~/.zshrc"

# --- 2. Shell Integrations & FZF ---
source <(fzf --zsh)
[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

# --- 3. History & Locale ---
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export PREFERRED_TERMINAL="ghostty"
export TMPDIR=~/.cache/tmp

# Dark mode for Hyprland only
if [ "$XDG_SESSION_DESKTOP" = "hyprland" ] || [ "$XDG_CURRENT_DESKTOP" = "Hyprland" ]; then
    export GTK_THEME="WhiteSur-Dark"
    export GTK_APPLICATION_PREFER_DARK_THEME=1
fi

# --- 4. PATH Management (Clean & Unified) ---
typeset -U path
path=(
  $HOME/.local/bin
  $HOME/.opencode/bin
  $HOME/.grok/bin
  $HOME/.resend/bin
  $HOME/.bun/bin
  $HOME/.cargo/bin
  $HOME/.local/share/pnpm/bin
  /home/linuxbrew/.linuxbrew/bin
  $path
)
export PATH

# Homebrew environment
if [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
fi

# --- 5. Package Managers & Runtimes (NVM, PNPM, Bun, Cargo) ---
# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/nvm.sh" ] && nvm use --silent default >/dev/null 2>&1
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# PNPM
export PNPM_HOME="/home/galyarder/.local/share/pnpm"

# Cargo
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# --- 6. Autocompletions (Fast Init) ---
fpath=(~/.grok/completions/zsh ~/.zfunc $fpath)
zstyle ':completion:*' menu select
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# --- 7. Environment Variables & API Keys ---
# Place your private API keys in ~/.secrets (which is not tracked in git)
[[ -f "$HOME/.secrets" ]] && source "$HOME/.secrets"

# OmniRoute Local Gateway Configuration
export OPENAI_API_BASE="http://127.0.0.1:20128/v1"
export OPENAI_API_KEY="${OPENAI_API_KEY:-sk-local-gateway}"

# GBrain Embeddings
export GBRAIN_EMBED_BASE_URL="http://localhost:20128/v1"
export GBRAIN_EMBED_MODEL="nebius/Qwen/Qwen3-Embedding-8B"
export GBRAIN_EMBED_DIMENSIONS="4096"
export GBRAIN_EMBED_API_KEY="${GBRAIN_EMBED_API_KEY:-sk-local-gateway}"

# --- 8. Aliases & Functions ---
# Git
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gp="git push"

# AI Tools & Agents
alias gpt='codex'
alias forge='FORG_KEY=sk-fg-v1-f60d3f5a5d6f3a95304380fbc839b077f77167fc0d0fd2ba537dd634d8130598 npx forgecode@latest'
alias claude-help='claude-setup-guide'
alias claude-mem='bun "/home/galyarder/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"'
alias hp='/home/galyarder/.local/bin/galyarder-phone'

# Updaters & System Maintenance
alias update="update-all"
alias update-proxy="$HOME/.local/bin/update-proxy"
alias update-orca="$HOME/.local/bin/update-orca"
alias update-codex="$HOME/.local/bin/update-codex"
alias update-openwebui="/home/galyarder/.local/bin/update-openwebui"
alias openwebui-status="update-openwebui --check"
alias cleanup="clear-cache"
alias fix-gnome-exts="$HOME/.local/bin/fix-gnome-exts"
alias snapshots="/home/galyarder/.local/bin/snapshots"
alias refresh-apps="refresh-desktop"
alias fix-apps="sudo /usr/local/bin/galyarder-desktop-app-patches"
alias sysinfo="fastfetch 2>/dev/null || neofetch 2>/dev/null || echo System info tool not found"

# Hardware / Mode Switcher
alias desktop-mode='bash ~/scripts/desktop-mode.sh'
alias laptop-mode='bash ~/scripts/laptop-mode.sh'
alias check-mode='bash ~/scripts/check-mode.sh'

# Spicetify Fixer
spfix() {
  spicetify backup apply || (spicetify restore && spicetify backup apply)
}

# Composio CLI
export PATH="$HOME/.local/bin:$PATH"
