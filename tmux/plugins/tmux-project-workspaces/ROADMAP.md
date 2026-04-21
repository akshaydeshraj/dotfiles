# Roadmap

Feature gaps vs [`raine/workmux`](https://github.com/raine/workmux), captured as a reference for future work. Not a commitment — some of this is out of scope by design.

Overlapping features already covered by this plugin are omitted: picker, dashboard, delete/kill policy, PR browser helpers, `.worktree-init.sh`, primary-checkout protection, resurrect/snapshot.

## AI agent orchestration

The largest category workmux covers that we don't touch at all.

- **Agent status tracking** — pane state (working / waiting / done) surfaces in window names, `list`, dashboard, and a persistent sidebar.
- **Prompt injection** — auto-injects `-p <text>`, `-P <file>`, or `-e` (editor) into the configured agent command in the new pane.
- **`--auto-name`** — LLM generates the branch name from the prompt.
- **`--fork`** — forks the last agent conversation from the current worktree into the new one, preserving context.
- **Coordinator commands** — `send`, `capture`, `status`, `wait`, `run` for scripting multi-agent flows.
- **Sandbox backends** — run agents inside containers / VMs via `workmux sandbox`.

## Multi-worktree generation

- `-a agent1,agent2` — one worktree per agent.
- `-n N` — N copies.
- `--foreach` — matrix expansion.
- Stdin piping for batched creation.
- `--max-concurrent` — concurrency limit.
- MiniJinja templating in branch names (`--branch-template` with `{{base_name}} {{agent}} {{num}} {{index}}`) and prompts.
- YAML frontmatter matrices inside prompt files.

## Worktree lifecycle beyond create/delete

- **`merge [branch]`** — merges into `main`, then cleans up worktree + window + local branch in one shot. We have the inverse (delete when merged) but not the merge-and-cleanup.
- **`--gone` on remove** — sweep worktrees whose remote branch was deleted.
- **File ops** — auto-copies `.env` and symlinks `node_modules` (togglable with `--no-file-ops`). Our `.worktree-init.sh` can do this but it's DIY per-repo.
- **`post_create` hooks in config** — not just a shell script; config-declared.
- **`--with-changes` / `--patch` / `--include-untracked`** — move uncommitted work into the new worktree.
- **`--pr <number>`** — checkout a GitHub PR directly into a new worktree. We have "open PR" but not "check out PR as worktree".

## Add / open ergonomics

- **`-o / --open-if-exists`** — idempotent add.
- **`-b / --background`** — create without switching.
- **`--wait`** — block until the window closes (scripting).
- **`--session`** — dedicated session mode per worktree.

## Config & introspection

- **Hierarchical YAML config** — global + project-specific, nested for monorepos.
- **`list --json`** — machine-readable output (unlocks external tooling, status bar, agent wrappers).
- **`path <name>`** — resolve worktree path for scripts.
- **`workmux docs`** + shell completions.

## Multiplexer abstraction

workmux targets tmux, WezTerm, Kitty, and Zellij behind a `Multiplexer` trait. Intentionally out of scope here — this plugin is tmux-only by design.

---

## Priority — worth stealing

Ranked by value-for-effort against the current plugin:

1. **`merge` command** — closes a real gap. `Ctrl+K` removes merged worktrees but doesn't do the merge itself.
2. **`--gone` cleanup** — trivial to add via `git branch -vv | grep gone`.
3. **`--pr <number>` to create a worktree from a PR** — natural extension of the existing `prefix+G` PR flow.
4. **`--with-changes`** — "oh wait, I'm on the wrong branch" is a daily problem.
5. **`list --json`** — unlocks everything else (status bar, external scripts, agent wrappers).
6. **File-ops config** (copy `.env`, symlink `node_modules`) — declarative beats per-repo `.worktree-init.sh`.

Agent integration and multi-worktree generation are a different product category — only worth pursuing if tmux-native agent orchestration becomes a goal.
