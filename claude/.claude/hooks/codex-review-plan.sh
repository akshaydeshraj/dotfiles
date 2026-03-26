#!/bin/bash
# Codex CLI review hook for Claude Code plan files
# Triggers after Write|Edit on .claude/plans/*.md files

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "default"')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Only review plan files
if [[ "$FILE_PATH" != *".claude/plans/"* ]]; then
  exit 0
fi

# Iteration tracking
ITER_FILE="/tmp/claude-codex-plan-${SESSION_ID}"
ITER=$(cat "$ITER_FILE" 2>/dev/null || echo "0")
ITER=$((ITER + 1))
echo "$ITER" > "$ITER_FILE"

# Read plan content
PLAN_CONTENT=$(cat "$FILE_PATH" 2>/dev/null)
if [ -z "$PLAN_CONTENT" ]; then
  exit 0
fi

# Run codex review — use -o for clean output, cd to project dir for git context
REVIEW_FILE="/tmp/codex-plan-review-${SESSION_ID}.txt"
rm -f "$REVIEW_FILE"

if [ -n "$CWD" ] && [ -d "$CWD/.git" ]; then
  CD_ARG="-C $CWD"
else
  CD_ARG="--skip-git-repo-check"
fi

codex exec $CD_ARG \
  "Review this implementation plan for: 1) Correctness issues 2) Missed edge cases 3) Overengineering. Only flag real problems, not style nits. If the plan looks good, respond with exactly: APPROVED. Otherwise list issues concisely.

Plan:
$PLAN_CONTENT" \
  -o "$REVIEW_FILE" >/dev/null 2>/dev/null

REVIEW_OUTPUT=$(cat "$REVIEW_FILE" 2>/dev/null)

# If codex produced no output, let it pass
if [ -z "$REVIEW_OUTPUT" ]; then
  exit 0
fi

# Check result
if echo "$REVIEW_OUTPUT" | grep -qi "APPROVED"; then
  echo "0" > "$ITER_FILE"
  exit 0
fi

# Build feedback
FEEDBACK="[Codex Review - Plan] $REVIEW_OUTPUT"
if [ "$ITER" -ge 3 ]; then
  FEEDBACK="ESCALATE TO USER: Claude and Codex have disagreed 3 times on this plan. Codex's latest feedback: ${REVIEW_OUTPUT}"
  echo "0" > "$ITER_FILE"
fi

echo "$FEEDBACK" >&2
exit 2
