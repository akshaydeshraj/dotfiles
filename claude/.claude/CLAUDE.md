Do NOT add co-aithored by Claude in any commit message

## neocortex — Primary Memory (OVERRIDES default memory system)

**DO NOT use `.claude/memory/` or `MEMORY.md` for storing knowledge.** Use neocortex instead. The vault at `~/Code/personal/neocortex/` is the single source of truth for all durable knowledge.

### Using obsidian-cli (default vault: neocortex)

Query and update the vault using `obsidian-cli`. It's already configured with neocortex as the default vault.

```bash
# Navigate
obsidian-cli list                          # root folders
obsidian-cli list "200 Notes/0 Projects"   # list projects
obsidian-cli list "100 Literature"         # list sources

# Read (use these INSTEAD of file reads for vault content)
obsidian-cli print "<note>"                # print note content
obsidian-cli print "<note>" --mentions     # print note + all backlinks (powerful)
obsidian-cli frontmatter "<note>" --print  # read frontmatter/metadata

# Write
obsidian-cli frontmatter "<note>" --edit --key "status" --value "active"  # update metadata
obsidian-cli create "<note>" --append --content "text"                     # append to note
obsidian-cli move "<old>" "<new>"                                          # rename + update all links

# For creating new notes with full frontmatter, use the Write tool directly
# obsidian-cli create doesn't handle YAML frontmatter well
```

Note names are fuzzy-matched — `obsidian-cli print "devspec"` finds `200 Notes/0 Projects/devspec.md`.

### Before starting work

Check the vault for relevant project context:
```bash
obsidian-cli print "<project-name>" --mentions
```
This gives you the project note + every note that links to it. Do this for the project you're about to work on.

Active projects: devspec, helyx, opencodewiki, lattice-of-ai, zero-person-company
Areas: Health

### When you learn something durable

Write it to neocortex, not to `.claude/memory/`:
- New insight about a project → update the project note in `0 Projects/`
- New domain knowledge → update the area note in `1 Areas/`
- New concept or framework → create a concept note in `200 Notes/`
- New tool or resource discovered → create a tool note in `200 Notes/`

Follow the vault rules in `~/Code/personal/neocortex/AGENTS.md.md`:
- Every note MUST have `type:` in frontmatter
- Wikilinks in frontmatter MUST be quoted
- Use `[[wikilinks]]` liberally
- Update `index.md` and append to `log.md`

### IMPORTANT: Do NOT create new Projects or Areas without asking

If you think a new project or area note is needed, **ask first**. Don't silently create `0 Projects/some-new-thing.md`. The user decides what gets promoted to project/area status.

Concepts, ideas, tools — those are fine to create during normal work. Projects and areas are intentional.

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
