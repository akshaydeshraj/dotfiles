#!/usr/bin/env bash
# Return a short PR-state string for the given session (repo/branch).
# Output examples: " PASS"  " FAIL"  " PENDING"  "" (no PR).
# Caches per-session for 30s to avoid hammering the GitHub API.

set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
DEFAULT_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmux-project-workspaces"
SESSION="${1:-}"
[ -z "$SESSION" ] && exit 0
[[ "$SESSION" != */* ]] && exit 0

CACHE_DIR="${PROJECT_WORKSPACES_PR_STATE_CACHE_DIR:-${PR_STATE_CACHE_DIR:-$DEFAULT_CACHE_DIR/pr-state}}"
mkdir -p "$CACHE_DIR"
safe=$(printf '%s' "$SESSION" | tr '/' '__')
cache="$CACHE_DIR/$safe"

# Fresh enough? Use cached value.
if [ -f "$cache" ]; then
  age=$(( $(date +%s) - $(stat -f %m "$cache" 2>/dev/null || echo 0) ))
  if [ "$age" -lt 30 ]; then
    cat "$cache"
    exit 0
  fi
fi

REPO_NAME="${SESSION%%/*}"
BRANCH="${SESSION#*/}"
WT="${PROJECT_WORKSPACES_WORKTREE_ROOT:-${WORKTREE_ROOT:-$HOME/worktrees}}/$REPO_NAME/$BRANCH"
[ -d "$WT" ] || { : > "$cache"; exit 0; }

# Don't block statusline — background-refresh this in the background.
(
  state=$(cd "$WT" && gh pr view --json state,statusCheckRollup 2>/dev/null)
  out=""
  if [ -n "$state" ]; then
    pr_state=$(printf '%s' "$state" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("state",""))' 2>/dev/null)
    checks=$(printf '%s' "$state" | python3 -c '
import json,sys
d=json.load(sys.stdin)
rolls=d.get("statusCheckRollup") or []
if not rolls:
  print("")
  sys.exit()
states = {r.get("conclusion") or r.get("status") for r in rolls}
if "FAILURE" in states or "TIMED_OUT" in states or "CANCELLED" in states:
  print("FAIL")
elif "IN_PROGRESS" in states or "QUEUED" in states or "PENDING" in states:
  print("PENDING")
elif all(s in ("SUCCESS","COMPLETED","NEUTRAL","SKIPPED") for s in states):
  print("PASS")
else:
  print("")
' 2>/dev/null)
    case "$pr_state:$checks" in
      OPEN:PASS)    out=" PASS" ;;
      OPEN:FAIL)    out=" FAIL" ;;
      OPEN:PENDING) out=" ⋯"    ;;
      OPEN:)        out=""      ;;
      MERGED:*)     out=" merged" ;;
      CLOSED:*)     out=" closed" ;;
    esac
  fi
  printf '%s' "$out" > "$cache"
) &

# Return whatever's cached right now (may be empty first call).
[ -f "$cache" ] && cat "$cache" || printf ''
