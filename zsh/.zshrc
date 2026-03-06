# ─── Machine-specific secrets (never committed) ──────────────────
[[ -f "$HOME/.env" ]] && source "$HOME/.env"

# ─── History Configuration ──────────────────────────────────────
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=1000000000
export SAVEHIST=$HISTSIZE
setopt EXTENDED_HISTORY          # Timestamps in history
setopt HIST_IGNORE_ALL_DUPS      # No duplicate entries
setopt HIST_FIND_NO_DUPS         # Skip duplicates in search
setopt SHARE_HISTORY             # Share history across sessions (implies INC_APPEND_HISTORY)
setopt HIST_IGNORE_SPACE         # Commands starting with space aren't recorded
setopt HIST_REDUCE_BLANKS        # Remove extra whitespace

# ─── Useful Shell Options ───────────────────────────────────────
setopt autocd                    # cd by typing directory name
setopt correct                   # Spelling correction for commands
setopt interactive_comments      # Allow comments in interactive shell
setopt no_beep                   # Disable terminal beep

# ─── PATH Configuration (consolidated, deduped) ─────────────────
path=(
  $HOME/.amp/bin
  $HOME/.antigravity/antigravity/bin
  $HOME/.opencode/bin
  $HOME/Code/sonar-scanner/bin
  /opt/homebrew/opt/openjdk/bin
  $HOME/.npm-global/bin
  $HOME/.local/bin
  /usr/local/bin
  $path
)
typeset -U path  # Remove duplicates

# ─── Cached eval helper ────────────────────────────────────────
# Caches output of slow "tool init zsh" commands. Auto-invalidates when the
# binary is newer than the cache (e.g. after brew upgrade). Usage:
#   _cached_eval <name> <binary> <command to generate shell code...>
_zsh_cache_dir="$HOME/.zsh/cache"
[[ -d "$_zsh_cache_dir" ]] || mkdir -p "$_zsh_cache_dir"
_cached_eval() {
  local name="$1" bin_path="${commands[$2]:-}"; shift 2
  [[ -z "$bin_path" ]] && return 1
  local cache_file="$_zsh_cache_dir/$name.zsh"
  if [[ ! -f "$cache_file" || "$bin_path" -nt "$cache_file" ]]; then
    eval "$@" > "$cache_file" 2>/dev/null
  fi
  source "$cache_file"
}

# ─── Completion System (with caching) ────────────────────────────
fpath=(~/.zsh/completion $fpath)
autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C  # Use cached completions (much faster)
fi

# ─── Prompt ───────────────────────────────────────────────────────
_cached_eval oh-my-posh oh-my-posh 'oh-my-posh init zsh --config ~/.config/oh-my-posh/solarized-dark.omp.json'

# ─── Lazy-load mise (manages Python, Node, and more) ────────────
if [[ -o interactive ]]; then
  _mise_lazy_load() {
    unset -f mise python python3 pip pip3 node npm npx _mise_lazy_load
    eval "$(~/.local/bin/mise activate zsh)"
  }
  mise() { _mise_lazy_load && mise "$@"; }
  python() { _mise_lazy_load && python "$@"; }
  python3() { _mise_lazy_load && python3 "$@"; }
  pip() { _mise_lazy_load && pip "$@"; }
  pip3() { _mise_lazy_load && pip3 "$@"; }
  # Node.js via mise (replaces nvm - run: mise use node@lts)
  node() { _mise_lazy_load && node "$@"; }
  npm() { _mise_lazy_load && npm "$@"; }
  npx() { _mise_lazy_load && npx "$@"; }
fi

# ─── Lazy-load direnv (loads on first cd) ────────────────────────
_direnv_hook() {
  unset -f _direnv_hook
  eval "$(direnv hook zsh)"
  _direnv_hook
}
typeset -ag precmd_functions
precmd_functions+=(_direnv_hook)

# ─── fzf Fuzzy Finder Integration ────────────────────────────────
# Ctrl+R: fuzzy history search | Ctrl+T: fuzzy file search | Alt+C: fuzzy cd
_cached_eval fzf fzf 'fzf --zsh'

# Keep arrow keys for simple prefix search (works alongside fzf)
autoload -U history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^[[A" history-beginning-search-backward-end
bindkey "^[[B" history-beginning-search-forward-end

# ─── Modern CLI Replacements ──────────────────────────────────────
# Zoxide - smarter cd that learns your habits
_cached_eval zoxide zoxide 'zoxide init zsh'

export BAT_THEME="Dracula"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# ─── Atuin - Better Shell History ─────────────────────────────────
# Syncs history across devices, better search UI (Ctrl+R)
_cached_eval atuin atuin 'atuin init zsh --disable-up-arrow'

# ─── Aliases ─────────────────────────────────────────────────────
alias ls='eza --header --group --git --long'
alias ls.tree='eza --header --group --tree --level=2 --git --long --icons'
alias ll='eza --header --group --long --all'
alias ll.tree='eza --header --group --tree --level=2 --git --long --icons --all'
alias cat='bat --paging=never'
alias grep='rg'
alias du='dust'
alias top='btop'
alias diff='delta'
alias rm='rm -i'            # Prompt before each removal
alias claude='claude --dangerously-skip-permissions --chrome'
alias hetz='TERM=xterm-256color mosh akshay@${HETZNER_IP} -- tmux new -A -s main'
alias hetz-c='TERM=xterm-256color mosh akshay@${HETZNER_IP} -- tmux new-session -A -s claude \; send-keys "cd ~/sysadmin && claude" Enter'
alias hetz-o='TERM=xterm-256color mosh akshay@${HETZNER_IP} -- tmux new-session -A -s openclaw \; send-keys "cd ~/sysadmin && openclaw" Enter'
alias ssh-nas='ssh akshaydeshraj@${NAS_IP}'
alias addpath='echo "export PATH=\"$PWD:\$PATH\"" >> ~/.zshrc && source ~/.zshrc'
alias serena-work='docker run --rm -i --network host -v ~/Code/work:/workspaces/projects ghcr.io/oraios/serena:latest serena'
alias serena-personal='docker run --rm -i --network host -v ~/Code/personal:/workspaces/projects ghcr.io/oraios/serena:latest serena'

# ─── Zsh Plugins (must be at end) ─────────────────────────────────
# Autosuggestions: fish-like suggestions as you type
source /opt/homebrew/opt/zsh-autosuggestions/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Syntax highlighting: colors commands (green=valid, red=invalid)
source /opt/homebrew/opt/zsh-syntax-highlighting/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# OpenClaw Completion
_cached_eval openclaw openclaw 'openclaw completion --shell zsh'

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Tirith
[[ -x "$(command -v tirith)" ]] && eval "$(tirith init)"

# GAM
[[ -f "$HOME/bin/gam7/gam" ]] && alias gam="$HOME/bin/gam7/gam"

# SmartClip
[[ -f "$HOME/Code/personal/smartclip/integrations/smartclip.zsh" ]] && source "$HOME/Code/personal/smartclip/integrations/smartclip.zsh"

# Bitwarden session
[[ -n "$BW_SESSION" ]] && export BW_SESSION
