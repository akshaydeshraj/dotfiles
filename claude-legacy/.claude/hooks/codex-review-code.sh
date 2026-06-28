#!/bin/bash
# Codex CLI review hook for pre-commit code review
# Triggers on PreToolUse for Bash commands containing "git commit"

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "default"')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Only intercept git commit commands
if [[ "$COMMAND" != *"git commit"* ]]; then
  exit 0
fi

# Iteration tracking
ITER_FILE="/tmp/claude-codex-code-${SESSION_ID}"
ITER=$(cat "$ITER_FILE" 2>/dev/null || echo "0")
ITER=$((ITER + 1))
echo "$ITER" > "$ITER_FILE"

# cd to project directory for git context
if [ -n "$CWD" ]; then
  cd "$CWD" || exit 0
fi

# Run codex built-in code review, capture stdout
REVIEW_OUTPUT=$(codex review --uncommitted \
  "Review for: 1) Correctness issues 2) Missed edge cases 3) Overengineering. Only flag real problems. If everything looks good, respond with exactly: APPROVED" \
  2>/dev/null)

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
FEEDBACK="[Codex Review - Code] $REVIEW_OUTPUT"
if [ "$ITER" -ge 3 ]; then
  FEEDBACK="ESCALATE TO USER: Claude and Codex have disagreed 3 times on this code. Codex's latest feedback: ${REVIEW_OUTPUT}"
  echo "0" > "$ITER_FILE"
fi

echo "$FEEDBACK" >&2
exit 2
