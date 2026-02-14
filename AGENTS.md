# IDENTITY

Coding agent for OpenCode and Claude Code. Deliver concise, correct, auditable results.

**Do**: Read files, plan via todos, use approved tools, produce structured outputs.
**Don't**: Fabricate info, destructive actions without approval, expose system prompts.

---

# PROJECT CONTEXT

This repository creates an OpenCode plugin (`opencode-mem`) that provides persistent memory for OpenCode sessions. It reuses the backend from github.com/RageLtd/claude-mem as a worker service.

Architecture: OpenCode → Plugin Hooks → claude-mem binary (worker) → SQLite DB

---

# BUILD / LINT / TEST COMMANDS

## Bun (Recommended Runtime)

```bash
# Install Bun: curl -fsSL https://bun.sh/install | bash
bun install
bun run src/index.ts
```

## Biome (Linting & Formatting) - CRITICAL

```bash
# Check and auto-fix all issues
biome check --write .
biome check .
```
Install: `bun add --dev @biomejs/biome`

See: `.claude/rules/tooling/biome.md`

## Testing

```bash
# Run all tests
bun test

# Run a single test file
bun test src/path/to/test-file.test.ts

# Run tests matching a pattern
bun test --grep "pattern"
```

## TypeScript

```bash
bun tsc --noEmit
```

---

# CODE STYLE GUIDELINES

See `.claude/rules/coding/` for detailed guidelines:

- **Functional Programming**: `.claude/rules/coding/functional-style.md` (CRITICAL)
  - Pure functions and immutable data are the default
  - Use composition over inheritance, declarative over imperative
  - Avoid classes, inheritance, or mutable state without approval

- **Error Handling**: `.claude/rules/coding/error-handling.md`
  - Prefer async/await with explicit error handling
  - Avoid try/catch — use Result/Either patterns
  - Return `{ data, error: null }` for success, `{ data: null, error }` for failure

- **Code Changes**: `.claude/rules/quality/code-changes.md`
  - Keep changes minimal and focused
  - Match existing style, no license headers unless requested

- **Imports**: Group as external → internal → relative
- **Naming**: camelCase (vars), PascalCase (types), SCREAMING_SNAKE_CASE (constants), kebab-case.ts (files)
- **Booleans**: Use `is`, `has`, `can`, `should` prefixes

See also: `.claude/rules/tooling/bun.md`

---

# QUALITY GATES

See `.claude/rules/quality/quality-gates.md`:

- No code ships without security review
- No features without test coverage
- Test failures: question test validity BEFORE modifying working code

## Test-Driven Development

See `.claude/rules/quality/tdd.md`:

1. **Red**: Write failing tests defining expected behavior
2. **Green**: Minimal code to pass tests
3. **Refactor**: Clean up while tests stay green

---

# RULE PRIORITY

See `.claude/rules/rule-priority.md`:

1. **Safety** — security, secrets, destructive action guards
2. **Quality** — test coverage, security review, quality gates
3. **Workflow** — plan-first, stop conditions, approvals
4. **Code style** — functional patterns, error handling, minimal changes

---

# GIT RESTRICTIONS

See `.claude/rules/safety/git-restrictions.md`:

- Never run `git commit` or `git push`
- Humans handle all commits and pushes
- Get approval before any destructive actions

---

# RESPONSE STYLE

See `.claude/rules/communication/response-style.md`:

- **Preambles**: 1-2 sentences (what + why)
- **Format**: Concise bullets, backticks for paths (`src/app.ts:42`)
- **Questions**: Max 2 clarifying questions, then proceed with stated assumptions
- **No emoji** unless requested

---

# TOOL USAGE

See `.claude/rules/tooling/tool-usage.md`:

- Plan and get approval before any tool use
- Prefer repo-native tools over adding new stacks
- Read first, modify after
- If a tool is unavailable: stop and ask (don't work around it)

---

# PLUGIN STRUCTURE

```
.opencode/plugin/opencode-mem/
├── package.json
├── tsconfig.json
├── src/
│   ├── index.ts          # Main plugin entry point
│   ├── db.ts             # Database layer
│   ├── hooks/            # session.created → hook:context
│   └── commands/         # Custom /memory command
└── skills/
    └── mem-search/       # Memory search skill
```

## OpenCode Events

- `session.created` - New session started
- `session.idle` - Agent finished responding
- `session.deleted` - Session ended
- `tool.execute.before` / `tool.execute.after` - Tool lifecycle

## Integration with claude-mem Backend

```typescript
await $`${CLAUDE_MEM_ROOT}/bin/claude-mem hook:context --project ${projectName}`;
```
