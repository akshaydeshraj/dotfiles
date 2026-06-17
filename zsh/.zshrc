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

# ─── solve: one-shot init + compile + run for competitive programming ────
# Usage:
#   solve init             # copies <repo-root>/template.cpp → ./solution.cpp
#                          # (refuses to overwrite if solution.cpp already exists)
#   solve                  # compiles ./solution.cpp, runs with ./input.txt if present
#   solve foo.cpp          # compiles foo.cpp → ./foo, runs with ./input.txt if present
#   solve foo.cpp in.txt   # runs ./foo with in.txt as stdin
#
# Prefers clang++ on macOS (working ASan/UBSan + bits/stdc++.h via the repo's
# .lsp/ shim). Falls back to Homebrew g++-N if clang isn't present (e.g. Linux),
# where GCC's sanitizers and <bits/stdc++.h> work natively.
# Uses gnu++20, -O2, sanitizers, -DLOCAL (so `#ifdef LOCAL` debug code fires).
solve() {
  emulate -L zsh

  # `solve init` — scaffold solution.cpp from the repo's template.cpp.
  if [[ "$1" == init ]]; then
    local repo_root
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
    if [[ -z "$repo_root" || ! -f "$repo_root/template.cpp" ]]; then
      print -u2 "solve init: no template.cpp at git repo root"
      return 1
    fi
    if [[ -e solution.cpp ]]; then
      print -u2 "solve init: solution.cpp already exists here — refusing to overwrite"
      return 1
    fi
    cp "$repo_root/template.cpp" solution.cpp
    print "solve init: created ./solution.cpp from $repo_root/template.cpp"
    return 0
  fi

  local src="${1:-solution.cpp}"
  if [[ ! -f "$src" ]]; then
    print -u2 "solve: $src not found (run 'solve init' to scaffold it)"
    return 1
  fi
  local out="${src:r}"
  local input_file="${2:-input.txt}"

  local compiler=
  if command -v clang++ >/dev/null 2>&1; then
    compiler=clang++
  else
    for v in 15 14 13; do
      if command -v g++-$v >/dev/null 2>&1; then
        compiler=g++-$v
        break
      fi
    done
  fi
  if [[ -z "$compiler" ]]; then
    print -u2 "solve: no C++ compiler found (need clang++ or g++-{13,14,15})"
    return 1
  fi

  local -a flags=(
    -std=gnu++20 -O2 -Wall -Wextra -Wshadow
    -fsanitize=address,undefined
    -DLOCAL
  )

  # clang++ on macOS lacks <bits/stdc++.h>; pull the shim from the repo's .lsp/.
  if [[ "$compiler" == clang++ ]]; then
    local repo_root
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
    [[ -n "$repo_root" && -d "$repo_root/.lsp" ]] && flags+=(-I"$repo_root/.lsp")
  fi

  "$compiler" "${flags[@]}" "$src" -o "$out" || return $?

  if [[ -f "$input_file" ]]; then
    "./$out" < "$input_file"
  else
    "./$out"
  fi
}

_project_agent_state() {
  local script="$HOME/Code/personal/dotfiles/tmux/plugins/tmux-project-workspaces/scripts/agent-state.sh"
  [ -n "${TMUX:-}" ] || return 0
  [ -x "$script" ] || return 0
  "$script" "$@" >/dev/null 2>&1 || true
}

# ─── Infisical multi-account routing ─────────────────────────────
# Two self-hosted Infisical instances ("profiles") are kept logged in via
# `infisical login --domain=...`. Both accounts live in `loggedInUsers`
# inside ~/.infisical/infisical-config.json (credentials in macOS keychain).
#
# Important: Infisical CLI v0.43 ignores the --domain flag for routing —
# every request is sent to whichever domain matches the file's
# `loggedInUserEmail` + `LoggedInUserDomain`. So we MUST rewrite that
# active-user pointer before each `infisical run` invocation. That's what
# `infisical_set_active_user` below does.
#
# Per-repo opt-in: a repo with `.infisical.json` at its root gets its own
# workspace. Domain comes from the file's `_domain` field if present
# (explicit, recommended); otherwise from cwd-based routing.
#
# Example .infisical.json:
#   {
#     "workspaceId": "0ab0efb3-...",
#     "defaultEnvironment": "prod",
#     "_domain": "https://infisical.akshaydeshraj.me"
#   }
# (Infisical CLI ignores `_domain`; only the wrapper reads it.)
#
# Default workspaceId for repos that don't carry their own config lives in
# `~/.infisical.json`. Its `_domain` field tags WHICH instance owns that
# workspace (workspaceIds are instance-specific). The wrapper falls back
# to this file ONLY when cwd routing agrees with `_domain`; otherwise it
# skips injection rather than 404 against a foreign instance.
#
# Cwd-based domain resolution, highest precedence first:
#   1. $INFISICAL_PROFILE env var (explicit override)
#   2. $PWD under ~/Code/work/*       → skit
#   3. $PWD under ~/Code/personal/*   → personal
#   4. fallback                       → personal
#
# To add a new repo: drop a `.infisical.json` with `workspaceId` and `_domain`
# at its root. To add a new profile: extend _resolve_infisical_domain below
# and `infisical login --domain=<new-url>` once.
_resolve_infisical_domain() {
  local profile="${INFISICAL_PROFILE:-}"
  if [ -z "$profile" ]; then
    case "$PWD/" in
      $HOME/Code/work/*)     profile=skit ;;
      $HOME/Code/personal/*) profile=personal ;;
      *)                     profile=personal ;;
    esac
  fi
  case "$profile" in
    skit)     echo "https://infisical.skit.ai" ;;
    personal) echo "https://infisical.akshaydeshraj.me" ;;
    *) echo "unknown infisical profile: $profile" >&2; return 1 ;;
  esac
}

# Switch the active Infisical user/domain in ~/.infisical/infisical-config.json
# to the one matching `target_domain` (e.g. https://infisical.skit.ai). This
# is required because Infisical CLI's --domain flag is ignored for routing;
# only the active-user pointer steers requests. Atomic via temp file +
# os.replace. No-op if the target is already active or the config is missing.
# Errors out (and aborts the caller) if the target domain has no logged-in
# user — fix with `infisical login --domain=<target>` once.
infisical_set_active_user() {
  local target_domain="${1%/}"
  local cfg="$HOME/.infisical/infisical-config.json"
  [ -f "$cfg" ] || return 0
  command jq --version >/dev/null 2>&1 || { print -u2 "[infisical-wrapper] jq not found; cannot switch active user"; return 1; }
  local target_api="${target_domain}/api"
  local current_email current_domain
  current_email="$(command jq -r '.loggedInUserEmail // ""' "$cfg" 2>/dev/null)"
  current_domain="$(command jq -r '.LoggedInUserDomain // ""' "$cfg" 2>/dev/null)"
  if [ "$current_domain" = "$target_api" ] && [ -n "$current_email" ]; then
    return 0
  fi
  local target_email
  target_email="$(command jq -r --arg d "$target_api" '.loggedInUsers[]? | select(.domain == $d) | .email' "$cfg" 2>/dev/null | command head -1)"
  if [ -z "$target_email" ]; then
    print -u2 "[infisical-wrapper] no logged-in user for $target_domain — run: infisical login --domain=$target_domain"
    return 2
  fi
  local tmp
  tmp="$(command mktemp "$cfg.XXXXXX")" || return 1
  if ! command jq --arg email "$target_email" --arg domain "$target_api" \
        '.loggedInUserEmail = $email | .LoggedInUserDomain = $domain' \
        "$cfg" > "$tmp"; then
    command rm -f "$tmp"
    return 1
  fi
  command mv -f "$tmp" "$cfg" || { command rm -f "$tmp"; return 1; }
}

# Resolve the directory holding .infisical.json. The CLI only reads it from
# the path passed via --project-config-dir (or cwd as a fallback), so for
# repo subdirs we walk up to the git toplevel.
_resolve_project_config_dir() {
  git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || echo "$PWD"
}

# Read the optional `_domain` field out of a .infisical.json. Infisical CLI
# ignores unknown fields, so this is safe to embed alongside workspaceId.
# Echoes empty string if the field is missing or the file is malformed.
# Uses `command grep` to bypass the user's grep→rg alias.
_extract_infisical_domain_override() {
  local file="$1"
  [ -f "$file" ] || return 0
  command grep -oE '"_domain"[[:space:]]*:[[:space:]]*"[^"]*"' "$file" 2>/dev/null \
    | command sed -E 's/.*"_domain"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' \
    | command head -1
}

_run_project_agent() {
  setopt local_options local_traps
  local tool="$1"
  shift
  local heartbeat_pid=""
  local config_dir
  config_dir="$(_resolve_project_config_dir)"
  _project_agent_state touch "$tool"
  (
    while true; do
      sleep 30
      _project_agent_state touch "$tool"
    done
  ) >/dev/null 2>&1 &!
  heartbeat_pid=$!
  trap '[ -n "$heartbeat_pid" ] && kill "$heartbeat_pid" 2>/dev/null; _project_agent_state clear' INT TERM HUP
  local rc
  local domain=""
  local domain_source=""
  local using_home_fallback=0
  local skip_injection=0
  # If the repo doesn't carry its own .infisical.json, fall back to the
  # home-level default (~/.infisical.json) for workspaceId — but only if
  # cwd routing agrees with the home file's `_domain` tag. Otherwise the
  # home workspace lives in a different Infisical instance than where
  # we'd route, so injection would 404. In that case skip injection.
  if [[ ! -f "$config_dir/.infisical.json" ]] && [[ -f "$HOME/.infisical.json" ]]; then
    local home_domain cwd_domain
    home_domain="$(_extract_infisical_domain_override "$HOME/.infisical.json")"
    cwd_domain="$(_resolve_infisical_domain)" || { rc=$?; [ -n "$heartbeat_pid" ] && kill "$heartbeat_pid" >/dev/null 2>&1; _project_agent_state clear; return $rc; }
    if [ -z "$home_domain" ] || [ "${home_domain%/}" = "${cwd_domain%/}" ]; then
      config_dir="$HOME"
      using_home_fallback=1
      domain="$cwd_domain"
      domain_source="cwd-resolver+home-fallback"
    else
      skip_injection=1
      [ -n "${INFISICAL_DEBUG:-}" ] && print -u2 "[infisical-wrapper] home workspace tagged $home_domain but cwd routes to $cwd_domain — skipping injection"
    fi
  fi
  if (( skip_injection )) || [[ ! -f "$config_dir/.infisical.json" ]]; then
    [ -n "${INFISICAL_DEBUG:-}" ] && (( ! skip_injection )) && print -u2 "[infisical-wrapper] no .infisical.json — running $tool without injection"
    "$(whence -p "$tool")" "$@"
    rc=$?
  else
    if [ -z "$domain" ]; then
      domain="$(_extract_infisical_domain_override "$config_dir/.infisical.json")"
      domain_source="file"
      if [ -z "$domain" ]; then
        domain_source="cwd-resolver"
        domain="$(_resolve_infisical_domain)" || { rc=$?; [ -n "$heartbeat_pid" ] && kill "$heartbeat_pid" >/dev/null 2>&1; _project_agent_state clear; return $rc; }
      fi
    fi
    [ -n "${INFISICAL_DEBUG:-}" ] && print -u2 "[infisical-wrapper] config_dir=$config_dir domain=$domain (source=$domain_source)"
    infisical_set_active_user "$domain" || { rc=$?; [ -n "$heartbeat_pid" ] && kill "$heartbeat_pid" >/dev/null 2>&1; _project_agent_state clear; return $rc; }
    infisical run --domain="$domain" --project-config-dir="$config_dir" --env=prod --silent -- "$(whence -p "$tool")" "$@"
    rc=$?
  fi
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

# AWS CLI — credentials injected from Infisical (work account).
# Project ID lives in ~/.aws/.infisical.json; domain is fixed since AWS
# creds only exist in the work instance regardless of cwd. The
# infisical_set_active_user call is required because the CLI's --domain
# flag is decorative; routing follows the active user in
# ~/.infisical/infisical-config.json.
unalias aws 2>/dev/null
aws() {
  infisical_set_active_user https://infisical.skit.ai || return $?
  infisical run --domain=https://infisical.skit.ai --project-config-dir="$HOME/.aws" --env=prod --silent --log-level=warn -- command aws "$@"
}

agent-wait() { _project_agent_state set wait "${1:-agent}"; }
agent-done() { _project_agent_state set done "${1:-agent}"; }
agent-off()  { _project_agent_state set off  "${1:-agent}"; }
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

# Donna — Akshay's chief of staff (custom system prompt)
alias donna='claude --system-prompt-file /Users/akshaydeshraj/Code/personal/dot-claw/system-prompt.md'
alias donna-og='claude --append-system-prompt-file ~/Code/personal/dot-claw.pre-migration/donna-system-prompt.md'

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
export UV_EXCLUDE_NEWER="$(date -u -v-7d +%Y-%m-%dT%H:%M:%SZ)"

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

# Zig dev compiler
path=($HOME/.local/opt/zig-dev $path)

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
