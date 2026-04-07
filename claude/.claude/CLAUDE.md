Do NOT add co-aithored by Claude in any commit message

## Codex Review Workflow
When you receive feedback from Codex review hooks (via stderr):
- Address legitimate correctness and edge case concerns
- Push back on pedantic or overengineering complaints — explain your reasoning
- If you see "ESCALATE TO USER:", present BOTH your position and Codex's feedback to the user and ask them to decide
- Do not blindly accept all feedback — use your judgment

@RTK.md

## Codebase Navigation — MANDATORY

You MUST use token-savior MCP tools FIRST.

- ALWAYS start with: find_symbol, get_function_source, get_class_source,
  get_edit_context, search_codebase, get_dependencies, get_dependents, get_change_impact
- For frontend projects: get_routes, get_components, get_feature_files, get_env_usage
- Use annotate_discovery to persist non-obvious insights for future sessions
- Only fall back to Read/Grep when token-savior tools genuinely don't cover it
- If you catch yourself reaching for grep to find code, STOP
- If token-savior returns "project not found" or similar, tell the user to run `/init-token-savior` to register this project
