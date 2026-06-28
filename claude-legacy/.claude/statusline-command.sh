#!/usr/bin/env bash
# Claude Code statusLine — Tokyo Night Storm aesthetic.
# Palette source-of-truth: ~/Code/personal/dotfiles/themes/tokyo-night-storm/palette.sh
# Colors: path=#7aa2f7  git=#9ece6a/dirty=#f7768e  model=#e0af68  context=#7dcfff

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
      git_color="\033[38;2;247;118;142m"   # #f7768e (dirty)
    else
      git_color="\033[38;2;158;206;106m"   # #9ece6a (clean)
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
    ctx_color="\033[38;2;247;118;142m"   # #f7768e warn
  else
    ctx_color="\033[38;2;125;207;255m"   # #7dcfff normal
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
    vim_color="\033[38;2;224;175;104m"   # #e0af68
  else
    vim_color="\033[38;2;158;206;106m"   # #9ece6a
  fi
  vim_info=$(printf " ${vim_color}[${vim_mode}]\033[0m")
fi

# ── Assemble ──────────────────────────────────────────────────────────────────
path_part=$(printf "\033[38;2;122;162;247m%s\033[0m" "$dir_display")    # #7aa2f7
model_part=$(printf "\033[38;2;224;175;104m%s\033[0m" "$model")         # #e0af68

printf "%s%s %s%s%s" "$path_part" "$git_info" "$model_part" "$ctx_info" "$vim_info"
