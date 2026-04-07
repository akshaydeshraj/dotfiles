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

## Work Quality Overrides

- Thoroughness over brevity: choose the approach that correctly and completely solves the problem. Do not sacrifice correctness or completeness for simplicity.
- Communication brevity does NOT mean work brevity: be concise in messages, but thorough in code changes and investigation.
- Fix adjacent issues: if you discover broken or fragile code related to the task, fix it.
- Add error handling at real boundaries (I/O, network, user input, external APIs).
- Use judgment on abstractions: extract when duplication causes real maintenance risk.
- Be thorough when exploring the codebase — don't sacrifice completeness for speed.
- Include useful code context when reporting findings — don't suppress code snippets that inform decisions.
