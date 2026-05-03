#!/bin/bash
# Clear notification marker when Claude resumes work or session ends
# Called from: UserPromptSubmit, SessionEnd hooks

SESSION=$(tmux display-message -p '#S' 2>/dev/null || echo "unknown")
rm -f "/tmp/claude-notify/${SESSION}"
