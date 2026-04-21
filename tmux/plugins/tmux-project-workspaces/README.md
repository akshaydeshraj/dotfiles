# tmux-project-workspaces

Local tmux plugin for project, worktree, and session navigation.

This plugin owns the tmux UX around:
- `Cmd+K` / `M-k`: workspace picker
- `Cmd+Shift+K` / `M-K`: dashboard
- `prefix + Tab`: dashboard
- `prefix + w`: worktree menu
- `prefix + W`: fast worktree create
- `prefix + G`: open PR flow
- `prefix + R`: open current PR in browser

## What It Is

This started as a collection of shell scripts under `tmux/.config/tmux/` and was later extracted into a local plugin so the behavior, bindings, and state model could live in one place.

The current implementation is hybrid:
- tmux integration, prompts, popups, and `fzf` wiring stay in shell
- render, repo/worktree resolution, session/worktree actions, and policy decisions live in a Rust core binary

That split exists for a reason:
- tmux popup and prompt UX is still easiest to express in shell
- row modeling, exact action routing, git checks, and performance-sensitive list generation are much safer and faster in Rust

## Directory Layout

```text
tmux/plugins/tmux-project-workspaces/
├── tmux-project-workspaces.tmux   # plugin entrypoint and tmux bindings
├── Cargo.toml                     # Rust core crate
├── src/main.rs                    # Rust command dispatcher and core logic
├── scripts/
│   ├── tree-switcher.sh           # Cmd+K picker
│   ├── worktree-overview.sh       # dashboard
│   ├── worktree-menu.sh           # per-worktree menu
│   ├── worktree-remove.sh         # delete/remove orchestration
│   ├── confirm-delete.sh          # delete confirmation prompt
│   ├── pr-state.sh                # PR status helpers
│   ├── prune-orphans.sh           # cleanup helpers
│   └── snapshot-worktrees.sh      # resurrect snapshot helper
└── target/release/tmux-project-workspaces
```

The old scripts in `tmux/.config/tmux/` are compatibility shims. The plugin scripts are the real source of truth now.

## How It Works

### 1. tmux entrypoint

[`tmux-project-workspaces.tmux`](./tmux-project-workspaces.tmux) does three things:
- reads tmux options
- exports those values back into tmux options and environment variables
- binds the plugin scripts to tmux keys

The plugin is designed to be configurable entirely through tmux options.

### 2. shell UX layer

The shell scripts are responsible for:
- opening popups
- launching `fzf`
- showing `command-prompt`
- translating key presses into actions
- calling the Rust binary for all expensive or policy-heavy work

The most important shell entrypoint is [`scripts/tree-switcher.sh`](./scripts/tree-switcher.sh).

### 3. Rust core

[`src/main.rs`](./src/main.rs) is the state and action engine. It currently owns:
- picker row rendering
- row metadata and status tags
- repo resolution
- untracked repo discovery
- delete target resolution
- worktree creation
- worktree removal
- project untracking
- kill/remove policy for `Ctrl+K`
- plain session open/switch
- worktree session open/switch

The point of the Rust core is to keep row semantics and action routing deterministic. Shell was too fragile once the picker started handling:
- tracked repos
- worktrees
- primary checkouts
- plain tmux sessions
- create/delete/kill semantics
- merged vs disposable worktree logic

## Picker Model

The `Cmd+K` picker has four row classes:
- action rows
- project rows
- worktree rows
- plain session rows

Current visible structure:
- one global `+ new worktree` row
- `Projects`
- per-project grouped worktree rows
- `Sessions`

Important UX decisions:
- branch rows show only the branch name, not `repo/branch`
- metadata is tag-based, for example `[live] [primary] [dirty] 20 hours ago`
- plain tmux sessions are visible in the same picker
- `:name` explicitly opens or switches to a plain session named `name`
- search matches only the name field, not metadata

## Key Behaviors

### Workspace picker

`M-k` opens the main picker.

Behavior summary:
- `Enter` on a worktree row: switch/open that worktree session
- `Enter` on a plain session row: switch/open that plain session
- `Enter` on a project row: prompt for a new worktree in that repo
- `Enter` on `+ new worktree`: choose a project, then prompt for a branch
- typing `repo/branch`: creates or opens that worktree if the repo resolves
- typing unknown text: opens a plain tmux session
- typing `:name`: always opens or switches the plain session `name`

### `Ctrl+K` policy

`Ctrl+K` is intentionally not a blind kill for every row.

Current behavior:
- plain session: kill session
- primary checkout: blocked
- worktree with branch equal to local `main` or `master`: remove worktree
- worktree already merged into local `main` or `master`: remove worktree
- non-merged worktree: blocked

That policy lives in Rust so it can make git-aware decisions reliably.

### Delete vs kill

There are two different destructive actions:
- `Ctrl+D`: explicit delete/remove flow for a worktree row
- `Ctrl+K`: policy-driven kill/remove

`Ctrl+K` is for quick cleanup.

`Ctrl+D` is the explicit “remove this worktree” path.

### Session creation

Plain sessions:
- are created at `$HOME`
- are named from the typed query after sanitization

Worktree sessions:
- are named `repo/branch`
- start with windows:
  - `work`
  - `git`
  - `free`
- export tmux session environment:
  - `WORKTREE_PATH`
  - `REPO_ROOT`
  - `WORKTREE_BRANCH`

If a repo contains `.worktree-init.sh`, that script is run before creating the tmux session.

## Configuration

Plugin behavior is controlled through tmux options.

Supported options:

```tmux
set -g @project-workspaces-border-color 'fg=#ffc600'
set -g @project-workspaces-workspaces-title ' Workspaces '
set -g @project-workspaces-dashboard-title ' Dashboard '
set -g @project-workspaces-menu-title ' Worktree '
set -g @project-workspaces-worktree-root "$HOME/worktrees"
set -g @project-workspaces-projects-file "${XDG_STATE_HOME:-$HOME/.local/state}/tmux-project-workspaces/projects.txt"
set -g @project-workspaces-notify-dir "${XDG_CACHE_HOME:-$HOME/.cache}/tmux-project-workspaces/notify"
set -g @project-workspaces-pr-state-cache-dir "${XDG_CACHE_HOME:-$HOME/.cache}/tmux-project-workspaces/pr-state"
set -g @project-workspaces-snapshot-file "$HOME/.tmux/resurrect/worktrees.txt"
set -g @project-workspaces-core-bin "#{@project-workspaces-plugin-dir}/target/release/tmux-project-workspaces"
```

Default storage:
- state: `${XDG_STATE_HOME:-$HOME/.local/state}/tmux-project-workspaces`
- cache: `${XDG_CACHE_HOME:-$HOME/.cache}/tmux-project-workspaces`

This dotfiles repo pins its own paths in `.tmux.conf` so the live setup keeps using existing data.

## Installation

Local install from this repo:

```tmux
run-shell "#{HOME}/Code/personal/dotfiles/tmux/plugins/tmux-project-workspaces/tmux-project-workspaces.tmux"
```

Build the Rust core:

```bash
cd ~/Code/personal/dotfiles/tmux/plugins/tmux-project-workspaces
cargo build --release
```

Reload tmux:

```bash
tmux source-file ~/.tmux.conf
```

## Development Workflow

Common edit loop:

```bash
cd ~/Code/personal/dotfiles

cargo fmt --manifest-path tmux/plugins/tmux-project-workspaces/Cargo.toml
cargo build --release --manifest-path tmux/plugins/tmux-project-workspaces/Cargo.toml
cargo check --release --manifest-path tmux/plugins/tmux-project-workspaces/Cargo.toml

bash -n tmux/plugins/tmux-project-workspaces/scripts/tree-switcher.sh
shellcheck tmux/plugins/tmux-project-workspaces/scripts/tree-switcher.sh

tmux source-file ~/.tmux.conf
```

Useful direct commands during debugging:

```bash
BIN=tmux/plugins/tmux-project-workspaces/target/release/tmux-project-workspaces

"$BIN" render
"$BIN" describe-row "dotfiles/master" "/Users/me/Code/dotfiles" "/Users/me/Code/dotfiles" "primary"
"$BIN" resolve-repo dotfiles
"$BIN" kill-policy "SESSION:main"
tmux/plugins/tmux-project-workspaces/scripts/tree-switcher.sh --header "SESSION:main" "plain"
```

## Design Constraints

These are intentional and should not be changed casually:

- Primary checkouts must be protected from delete/remove.
- Exact plain-session escapes via `:name` must keep working.
- Search should match names, not metadata.
- Repo/worktree semantics and plain-session semantics must stay distinct.
- `Ctrl+K` should stay policy-driven, not a blind tmux kill.
- The shell layer should remain thin; new stateful logic belongs in Rust unless there is a strong reason otherwise.

## Known Tradeoffs

- The plugin still uses `fzf` through shell instead of a full compiled TUI.
- tmux popup and prompt behavior still depends on shell wrappers.
- Some older scripts under `tmux/.config/tmux/` still exist as shims for compatibility.

That is deliberate. The goal is not “no shell,” it is “shell only where tmux UX demands it.”

## Recommended Next Steps

If a future engineer wants to keep pushing this forward, the highest-value follow-ups are:
- move any remaining session routing or tmux command assembly into the Rust core
- add snapshot or cache support for even faster dashboard/picker startup
- add tests around row rendering and kill/remove policy decisions
- trim legacy compatibility shims once no callers depend on them
