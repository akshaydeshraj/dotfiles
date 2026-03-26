#!/usr/bin/env bash
# Claude Code statusLine — mirrors Cobalt2 oh-my-posh aesthetic
# Colors: path=#0088ff  git=#3ad900/dirty=#ff628c  model=#ffc600  context=#80fcff

input=$(cat)

# ── Path ─────────────────────────────────────────────────────────────────────
dir=$(echo "$input" | jq -r '.workspace.current_dir')
dir_display="${dir/#$HOME/~}"

# ── Git ──────────────────────────────────────────────────────────────────────
git_info=""
if git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || git -C "$dir" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    # Check for dirty working tree or staging area
    if git -C "$dir" status --porcelain 2>/dev/null | grep -q .; then
      git_color="\033[38;2;255;98;140m"   # #ff628c (dirty)
    else
      git_color="\033[38;2;58;217;0m"     # #3ad900 (clean)
    fi
    git_info=" $(printf "${git_color} ${branch}\033[0m")"
  fi
fi

# ── Model ─────────────────────────────────────────────────────────────────────
model=$(echo "$input" | jq -r '.model.display_name')

# ── Context window ────────────────────────────────────────────────────────────
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$used_pct" ]; then
  used_int=${used_pct%.*}
  if [ "${used_int:-0}" -ge 80 ]; then
    ctx_color="\033[38;2;255;98;140m"   # #ff628c warn
  else
    ctx_color="\033[38;2;128;252;255m"  # #80fcff normal
  fi
  ctx_info=$(printf " ${ctx_color}ctx:${used_pct}%%\033[0m")
else
  ctx_info=""
fi

# ── Vim mode ──────────────────────────────────────────────────────────────────
vim_info=""
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')
if [ -n "$vim_mode" ]; then
  if [ "$vim_mode" = "NORMAL" ]; then
    vim_color="\033[38;2;255;198;0m"   # #ffc600
  else
    vim_color="\033[38;2;58;217;0m"    # #3ad900
  fi
  vim_info=$(printf " ${vim_color}[${vim_mode}]\033[0m")
fi

# ── Assemble ──────────────────────────────────────────────────────────────────
path_part=$(printf "\033[38;2;0;136;255m%s\033[0m" "$dir_display")
model_part=$(printf "\033[38;2;255;198;0m%s\033[0m" "$model")

printf "%s%s %s%s%s" "$path_part" "$git_info" "$model_part" "$ctx_info" "$vim_info"
