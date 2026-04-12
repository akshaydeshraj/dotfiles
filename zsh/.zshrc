# ─── Source machine-specific secrets ──────────────────────────────
[[ -f "$HOME/.env" ]] && source "$HOME/.env"

# ─── Auto-reload zshrc when modified ──────────────────────────────
_ZSHRC_MTIME=$(stat -f %m ~/.zshrc 2>/dev/null)
_check_zshrc_reload() {
  local mtime=$(stat -f %m ~/.zshrc 2>/dev/null)
  if [[ "$mtime" != "$_ZSHRC_MTIME" ]]; then
    _ZSHRC_MTIME=$mtime
    source ~/.zshrc
  fi
}
precmd_functions+=(_check_zshrc_reload)

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
_cached_eval oh-my-posh oh-my-posh 'oh-my-posh init zsh --config ~/.config/oh-my-posh/cobalt2.omp.json'

# ─── Lazy-load mise (manages Python, Node, and more) ────────────
if [[ -o interactive ]]; then
  _mise_lazy_load() {
    unset -f mise python python3 pip pip3 node npm npx _mise_lazy_load
    eval "$(~/.local/bin/mise activate zsh)"
    _sfw_wrap  # re-define sfw wrappers now that real binaries are on PATH
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
export FZF_DEFAULT_OPTS="
  --color=bg+:#0050A4,bg:#122738,fg:#ffffff,fg+:#ffffff
  --color=hl:#ffc600,hl+:#ffc600,info:#80fcff,marker:#3ad900
  --color=prompt:#ffc600,spinner:#fb94ff,pointer:#ff628c,header:#0088ff
  --color=border:#0d3a58,separator:#0d3a58,scrollbar:#0d3a58
  --color=label:#80fcff,query:#ffffff
"
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

export BAT_THEME="TwoDark"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# ─── eza colors (Cobalt2) ─────────────────────────────────────────
export EZA_COLORS="da=36:di=34;1:ln=35:ex=32;1:ur=33:uw=33:ux=33:gr=36:gw=36:gx=36:tr=35:tw=35:tx=35:sn=33:sb=33:uu=36:gu=36"

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
unalias claude 2>/dev/null
claude() {
  local args=(--dangerously-skip-permissions --chrome)
  if [ -d .claude ] && ls .claude/conversations/ >/dev/null 2>&1; then
    args+=(--continue)
  fi
  command claude "${args[@]}" "$@"
}
alias hetz='TERM=xterm-256color mosh akshay@${HETZNER_IP} -- tmux new -A -s main'
alias hetz-c='TERM=xterm-256color mosh akshay@${HETZNER_IP} -- tmux new-session -A -s claude \; send-keys "cd ~/sysadmin && claude" Enter'
alias hetz-o='TERM=xterm-256color mosh akshay@${HETZNER_IP} -- tmux new-session -A -s openclaw \; send-keys "cd ~/sysadmin && openclaw" Enter'
alias ssh-nas='ssh akshaydeshraj@${NAS_IP}'
alias addpath='echo "export PATH=\"$PWD:\$PATH\"" >> ~/.zshrc && source ~/.zshrc'
alias serena-work='docker run --rm -i --network host -v ~/Code/work:/workspaces/projects ghcr.io/oraios/serena:latest serena'
alias serena-personal='docker run --rm -i --network host -v ~/Code/personal:/workspaces/projects ghcr.io/oraios/serena:latest serena'

# ─── Zsh Plugins (must be at end) ─────────────────────────────────
# Autosuggestions: fish-like suggestions as you type (Cobalt2 dim blue)
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#0050A4"
source /opt/homebrew/opt/zsh-autosuggestions/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Syntax highlighting: colors commands (Cobalt2 palette)
source /opt/homebrew/opt/zsh-syntax-highlighting/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZSH_HIGHLIGHT_STYLES[command]='fg=#3ad900,bold'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#3ad900,bold'
ZSH_HIGHLIGHT_STYLES[alias]='fg=#3ad900,bold'
ZSH_HIGHLIGHT_STYLES[function]='fg=#3ad900,bold'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#ff628c'
ZSH_HIGHLIGHT_STYLES[path]='fg=#80fcff,underline'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=#fb94ff'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#ffc600'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#ffc600'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#ffc600'
ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#ff9d00'
ZSH_HIGHLIGHT_STYLES[redirection]='fg=#fb94ff'
ZSH_HIGHLIGHT_STYLES[comment]='fg=#0050A4'
ZSH_HIGHLIGHT_STYLES[arg0]='fg=#0088ff'

# OpenClaw Completion
_cached_eval openclaw openclaw 'openclaw completion --shell zsh'

# bun completions
[ -s "/Users/akshaydeshraj/.bun/_bun" ] && source "/Users/akshaydeshraj/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

alias gam="/Users/akshaydeshraj/bin/gam7/gam"

# ─── sfw — safe package install wrappers ─────────────────────────
# Routes install/add commands through sfw; passthrough for everything else.
# _sfw_wrap is called after mise lazy-load so it can override the real binaries.
_sfw_wrap() {
  for _cmd in npm yarn pnpm pip pip3 uv cargo; do
    eval "
      ${_cmd}() {
        case \"\$1\" in
          install|add|i) command sfw ${_cmd} \"\$@\" ;;
          *)             command ${_cmd} \"\$@\" ;;
        esac
      }
    "
  done
  unset _cmd
}
_sfw_wrap  # define now for non-mise tools (cargo, uv, yarn, pnpm)

# SmartClip — auto-fix multi-line commands on paste
source /Users/akshaydeshraj/Code/personal/smartclip/integrations/smartclip.zsh

export BW_SESSION="${BW_SESSION}"

export SENTRY_AUTH_TOKEN="${SENTRY_AUTH_TOKEN}"
export SENTRY_ACCESS_TOKEN=$SENTRY_AUTH_TOKEN

export METAMCP_BEARER_KEY="${METAMCP_BEARER_KEY}"

export LLM_API_KEY="${LLM_API_KEY}"
export LLM_MODEL="claude-opus-4-6"
export LLM_BASE_URL="https://claude.akshaydeshraj.me/v1"

export PATH="$HOME/.cargo/bin:$PATH"
