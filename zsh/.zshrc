# ─── Source machine-specific secrets ──────────────────────────────
[[ -f "$HOME/.env" ]] && source "$HOME/.env"

# ─── Tokyo Night Storm palette (single source of truth) ───────────
# Exports $TN_BG, $TN_FG, $TN_RED, etc. Used below for fzf, syntax
# highlighting, autosuggestions. App-side configs (ghostty, tmux,
# btop, sketchybar, etc.) hardcode the same hex with a comment
# pointing back to palette.sh.
[[ -f "$HOME/Code/personal/dotfiles/themes/tokyo-night-storm/palette.sh" ]] && \
  source "$HOME/Code/personal/dotfiles/themes/tokyo-night-storm/palette.sh"

# ─── Dedupe key arrays (must come before any appends) ─────────────
# Auto-reload below re-sources this file, so anything mutated additively
# (path/fpath/precmd_functions) would accumulate without these.
typeset -U path fpath
typeset -aU precmd_functions

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
fpath=($HOME/.zsh/completion $fpath)
autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C  # Use cached completions (much faster)
fi

# ─── Prompt ───────────────────────────────────────────────────────
# Starship reads ~/.config/starship.toml (Tokyo Night Storm).
_cached_eval starship starship 'starship init zsh'

# ─── Eager-load mise (manages Python, Node, and more) ───────────
# Eagerly activated so shebang scripts (e.g. #!/usr/bin/env node) resolve
# through mise shims via raw PATH — lazy-load wouldn't fire for those.
# _sfw_wrap runs later (below) and overlays sfw on top of mise's shims.
if [[ -o interactive ]]; then
  eval "$(~/.local/bin/mise activate zsh)"
fi

# ─── Lazy-load direnv (loads on first cd) ────────────────────────
_direnv_hook() {
  unset -f _direnv_hook
  eval "$(direnv hook zsh)"
  _direnv_hook
}
precmd_functions+=(_direnv_hook)

# ─── fzf Fuzzy Finder Integration ────────────────────────────────
# Ctrl+R: fuzzy history search | Ctrl+T: fuzzy file search | Alt+C: fuzzy cd
# Colors derived from $TN_* via tn_fzf_colors helper (palette.sh).
export FZF_DEFAULT_OPTS="--color=$(tn_fzf_colors)"
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

# bat: TN Storm tmTheme lives in dotfiles bat/ stow package. Rebuild after
# tmTheme edits with: bat cache --build
export BAT_THEME="tokyo-night-storm"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# ─── eza colors ───────────────────────────────────────────────────
# Truecolor (24-bit) RGB derived from $TN_* via tn_eza_colors helper
# (palette.sh). Covers files, perms, ownership, sizes, dates, and git.
export EZA_COLORS="$(tn_eza_colors)"

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

alias cpp='g++-15 -std=gnu++20 -O2 -Wall -DLOCAL'

_project_agent_state() {
  local script="$HOME/Code/personal/dotfiles/tmux/plugins/tmux-project-workspaces/scripts/agent-state.sh"
  [ -n "${TMUX:-}" ] || return 0
  [ -x "$script" ] || return 0
  "$script" "$@" >/dev/null 2>&1 || true
}

_run_project_agent() {
  setopt local_options local_traps
  local tool="$1"
  shift
  local heartbeat_pid=""
  _project_agent_state touch "$tool"
  (
    while true; do
      sleep 30
      _project_agent_state touch "$tool"
    done
  ) >/dev/null 2>&1 &!
  heartbeat_pid=$!
  trap '[ -n "$heartbeat_pid" ] && kill "$heartbeat_pid" 2>/dev/null; _project_agent_state clear' INT TERM HUP
  infisical run --projectId=0ab0efb3-526b-4309-8df9-8ef147476dc0 --env=prod --silent -- "$(whence -p "$tool")" "$@"
  local rc=$?
  [ -n "$heartbeat_pid" ] && kill "$heartbeat_pid" >/dev/null 2>&1 || true
  _project_agent_state clear
  return $rc
}

unalias claude 2>/dev/null
claude() {
  local args=(--dangerously-skip-permissions --chrome)
  if [ -d .claude/conversations ]; then
    args+=(--continue)
  fi
  _run_project_agent claude "${args[@]}" "$@"
}

unalias codex 2>/dev/null
codex() {
  _run_project_agent codex "$@"
}

unalias pi 2>/dev/null
pi() {
  _run_project_agent pi "$@"
}

# AWS CLI — credentials injected from Infisical (project: skit-ai, env: prod)
unalias aws 2>/dev/null
aws() {
  infisical run --projectId=c137d757-de63-40df-a30c-16bf28c5466f --env=prod --silent --log-level=warn -- command aws "$@"
}

agent-wait() { _project_agent_state set wait "${1:-agent}"; }
agent-done() { _project_agent_state set done "${1:-agent}"; }
agent-off()  { _project_agent_state set off  "${1:-agent}"; }
alias donna='claude --append-system-prompt-file ~/Code/personal/dot-claw.pre-migration/donna-system-prompt.md'
alias hetz='TERM=xterm-256color mosh akshay@${HETZNER_IP} -- tmux new -A -s main'
alias hetz-c='TERM=xterm-256color mosh akshay@${HETZNER_IP} -- tmux new-session -A -s claude \; send-keys "cd ~/sysadmin && claude" Enter'
alias hetz-o='TERM=xterm-256color mosh akshay@${HETZNER_IP} -- tmux new-session -A -s openclaw \; send-keys "cd ~/sysadmin && openclaw" Enter'
alias ssh-nas='ssh akshaydeshraj@${NAS_IP}'
alias addpath='echo "export PATH=\"$PWD:\$PATH\"" >> ~/.zshrc && source ~/.zshrc'
alias serena-work='docker run --rm -i --network host -v ~/Code/work:/workspaces/projects ghcr.io/oraios/serena:latest serena'
alias serena-personal='docker run --rm -i --network host -v ~/Code/personal:/workspaces/projects ghcr.io/oraios/serena:latest serena'

# ─── Zsh Plugins (must be at end) ─────────────────────────────────
# Autosuggestions: fish-like suggestions as you type (TN dim border).
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=${TN_DIM}"
source /opt/homebrew/opt/zsh-autosuggestions/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Syntax highlighting: colors commands (Tokyo Night Storm palette).
source /opt/homebrew/opt/zsh-syntax-highlighting/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
ZSH_HIGHLIGHT_STYLES[command]="fg=${TN_GREEN},bold"
ZSH_HIGHLIGHT_STYLES[builtin]="fg=${TN_GREEN},bold"
ZSH_HIGHLIGHT_STYLES[alias]="fg=${TN_GREEN},bold"
ZSH_HIGHLIGHT_STYLES[function]="fg=${TN_GREEN},bold"
ZSH_HIGHLIGHT_STYLES[unknown-token]="fg=${TN_RED}"
ZSH_HIGHLIGHT_STYLES[path]="fg=${TN_CYAN},underline"
ZSH_HIGHLIGHT_STYLES[globbing]="fg=${TN_MAGENTA}"
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]="fg=${TN_YELLOW}"
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]="fg=${TN_YELLOW}"
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]="fg=${TN_YELLOW}"
ZSH_HIGHLIGHT_STYLES[commandseparator]="fg=${TN_ORANGE}"
ZSH_HIGHLIGHT_STYLES[redirection]="fg=${TN_MAGENTA}"
ZSH_HIGHLIGHT_STYLES[comment]="fg=${TN_DIM}"
ZSH_HIGHLIGHT_STYLES[arg0]="fg=${TN_BLUE}"

# OpenClaw Completion
_cached_eval openclaw openclaw 'openclaw completion --shell zsh'

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
path=($BUN_INSTALL/bin $path)

alias gam="$HOME/bin/gam7/gam"

# ─── Supply chain: 7-day release cooldown ────────────────────────
# Blocks any package version published <7d ago. Most malicious releases
# are caught within 24-48h (axios, litellm, pytorch-lightning attacks
# would all have been blocked). Pairs with sfw (socket malware scan)
# below for defense in depth.
#   - uv:   reads UV_EXCLUDE_NEWER env var (this line)
#   - npm:  ~/.npmrc            min-release-age=7
#   - pnpm: ~/.config/pnpm/rc   minimumReleaseAge=10080
#   - pip:  --uploaded-prior-to flag injected by _sfw_wrap below
#   - cargo: no clean integration with sfw; install cargo-cooldown
#     manually if needed (`cargo install cargo-cooldown`).
# Override for urgent CVE patches: UV_EXCLUDE_NEWER= cmd ...
export UV_EXCLUDE_NEWER="7 days"

# ─── sfw — safe package install wrappers ─────────────────────────
# Routes install/add commands through sfw; passthrough for everything else.
# _sfw_wrap is called after mise lazy-load so it can override the real binaries.
_sfw_wrap() {
  # Most tools: just route install/add through sfw. Cooldown is enforced
  # via env var (uv) or per-tool config files (npm/pnpm).
  for _cmd in npm yarn pnpm uv cargo; do
    eval "
      ${_cmd}() {
        case \"\$1\" in
          install|add|i) command sfw ${_cmd} \"\$@\" ;;
          *)             command ${_cmd} \"\$@\" ;;
        esac
      }
    "
  done
  # pip lacks a config-file equivalent for relative durations, so inject
  # --uploaded-prior-to on each install call (recomputed dynamically).
  for _cmd in pip pip3; do
    eval "
      ${_cmd}() {
        case \"\$1\" in
          install)
            local _cd=\$(date -v-7d +%Y-%m-%d 2>/dev/null || date -d '7 days ago' +%Y-%m-%d)
            command sfw ${_cmd} \"\$@\" --uploaded-prior-to \"\$_cd\"
            ;;
          *) command ${_cmd} \"\$@\" ;;
        esac
      }
    "
  done
  unset _cmd
}
_sfw_wrap  # define now for non-mise tools (cargo, uv, yarn, pnpm)

# SmartClip — auto-fix multi-line commands on paste
source "$HOME/Code/personal/smartclip/integrations/smartclip.zsh"

path=($HOME/.cargo/bin $path)

# Darkbloom
path=($HOME/.darkbloom/bin $path)

# Go binaries (gopls, gomodifytags, gotests, gore, etc.)
path=($HOME/go/bin $path)


# BEGIN opam configuration
# This is useful if you're using opam as it adds:
#   - the correct directories to the PATH
#   - auto-completion for the opam binary
# This section can be safely removed at any time if needed.
[[ ! -r "$HOME/.opam/opam-init/init.zsh" ]] || source "$HOME/.opam/opam-init/init.zsh" > /dev/null 2> /dev/null
# END opam configuration

# Ensure .zshrc itself sources successfully — opam's variables.sh has a buggy
# guard (`test -z … || return`) that returns 1 on re-source, which would
# otherwise show as [x] in the prompt after `source ~/.zshrc`.
true
