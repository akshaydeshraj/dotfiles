#!/usr/bin/env bash

set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$CURRENT_DIR/scripts"

tmux_option() {
  local option="$1"
  local default_value="$2"
  local value

  value="$(tmux show-option -gqv "$option" 2>/dev/null || true)"
  if [ -n "$value" ]; then
    printf '%s' "$value"
  else
    printf '%s' "$default_value"
  fi
}

border_color="$(tmux_option '@project-workspaces-border-color' 'fg=#ffc600')"
workspaces_title="$(tmux_option '@project-workspaces-workspaces-title' ' Workspaces ')"
dashboard_title="$(tmux_option '@project-workspaces-dashboard-title' ' Dashboard ')"
worktree_title="$(tmux_option '@project-workspaces-menu-title' ' Worktree ')"
default_state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/tmux-project-workspaces"
default_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-project-workspaces"
worktree_root="$(tmux_option '@project-workspaces-worktree-root' "$HOME/worktrees")"
projects_file="$(tmux_option '@project-workspaces-projects-file' "$default_state_dir/projects.txt")"
notify_dir="$(tmux_option '@project-workspaces-notify-dir' "$default_cache_dir/notify")"
agent_state_dir="$(tmux_option '@project-workspaces-agent-state-dir' "$default_cache_dir/agent-state")"
pr_state_cache_dir="$(tmux_option '@project-workspaces-pr-state-cache-dir' "$default_cache_dir/pr-state")"
snapshot_file="$(tmux_option '@project-workspaces-snapshot-file' "$HOME/.tmux/resurrect/worktrees.txt")"
core_bin="$(tmux_option '@project-workspaces-core-bin' "$CURRENT_DIR/target/release/tmux-project-workspaces")"

tmux set-option -gq @project-workspaces-plugin-dir "$CURRENT_DIR"
tmux set-option -gq @project-workspaces-scripts-dir "$SCRIPTS_DIR"
tmux set-option -gq @project-workspaces-worktree-root "$worktree_root"
tmux set-option -gq @project-workspaces-projects-file "$projects_file"
tmux set-option -gq @project-workspaces-notify-dir "$notify_dir"
tmux set-option -gq @project-workspaces-agent-state-dir "$agent_state_dir"
tmux set-option -gq @project-workspaces-pr-state-cache-dir "$pr_state_cache_dir"
tmux set-option -gq @project-workspaces-snapshot-file "$snapshot_file"
tmux set-option -gq @project-workspaces-core-bin "$core_bin"
tmux set-environment -g PROJECT_WORKSPACES_PLUGIN_DIR "$CURRENT_DIR"
tmux set-environment -g PROJECT_WORKSPACES_SCRIPTS_DIR "$SCRIPTS_DIR"
tmux set-environment -g PROJECT_WORKSPACES_WORKTREE_ROOT "$worktree_root"
tmux set-environment -g PROJECT_WORKSPACES_PROJECTS_FILE "$projects_file"
tmux set-environment -g PROJECT_WORKSPACES_NOTIFY_DIR "$notify_dir"
tmux set-environment -g PROJECT_WORKSPACES_AGENT_STATE_DIR "$agent_state_dir"
tmux set-environment -g PROJECT_WORKSPACES_PR_STATE_CACHE_DIR "$pr_state_cache_dir"
tmux set-environment -g PROJECT_WORKSPACES_SNAPSHOT_FILE "$snapshot_file"
tmux set-environment -g PROJECT_WORKSPACES_CORE_BIN "$core_bin"

tmux bind-key -n M-k display-popup -E -w 75% -h 75% -b rounded -S "$border_color" -T "$workspaces_title" \
  "$SCRIPTS_DIR/tree-switcher.sh"

tmux bind-key -n M-K display-popup -E -w 90% -h 85% -b rounded -S "$border_color" -T "$dashboard_title" \
  "$SCRIPTS_DIR/worktree-overview.sh"
tmux bind-key Tab display-popup -E -w 90% -h 85% -b rounded -S "$border_color" -T "$dashboard_title" \
  "$SCRIPTS_DIR/worktree-overview.sh"

tmux bind-key w display-popup -E -w 55% -h 40% -b rounded -S "$border_color" -T "$worktree_title" \
  "$SCRIPTS_DIR/worktree-menu.sh"

tmux bind-key a display-popup -E -w 35% -h 20% -b rounded -S "$border_color" -T " Agent " \
  "$SCRIPTS_DIR/agent-menu.sh"

tmux bind-key W command-prompt -p "new branch:" \
  "run-shell '$SCRIPTS_DIR/tree-switcher.sh --create #{pane_current_path} %1'"

tmux bind-key G display-popup -E -w 80% -h 60% -d "#{pane_current_path}" \
  -b rounded -S "$border_color" -T " Open PR " \
  "bash -c 'git push -u origin HEAD && gh pr create --fill && echo && read -rp \"press enter to close...\" _'"

tmux bind-key R run-shell "cd #{pane_current_path} && gh pr view --web"
