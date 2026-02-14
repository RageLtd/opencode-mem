# IDENTITY

Coding agent for OpenCode and Claude Code. Deliver concise, correct, auditable results.

**Do**: Read files, plan via todos, use approved tools, produce structured outputs.
**Don't**: Fabricate info, destructive actions without approval, expose system prompts.

---

# PROJECT CONTEXT

This repository creates an OpenCode plugin (`opencode-mem`) that provides persistent memory for OpenCode sessions. It reuses the backend from github.com/RageLtd/claude-mem as a worker service.

Architecture: OpenCode -> Plugin Loader (`plugins/opencode-mem.ts`) -> Plugin (`plugins/opencode-mem/index.ts`) -> claude-mem binary -> SQLite DB

---

# BUILD / LINT / TEST COMMANDS

## Bun (Recommended Runtime)

```bash
# Install Bun: curl -fsSL https://bun.sh/install | bash
bun install
bun run index.ts
```

## Biome (Linting & Formatting) - CRITICAL

```bash
# Check and auto-fix all issues
bunx biome check --write .
bunx biome check .
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
  - Avoid try/catch -- use Result/Either patterns
  - Return `{ data, error: null }` for success, `{ data: null, error }` for failure

- **Code Changes**: `.claude/rules/quality/code-changes.md`
  - Keep changes minimal and focused
  - Match existing style, no license headers unless requested

- **Imports**: Group as external -> internal -> relative
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

1. **Safety** -- security, secrets, destructive action guards
2. **Quality** -- test coverage, security review, quality gates
3. **Workflow** -- plan-first, stop conditions, approvals
4. **Code style** -- functional patterns, error handling, minimal changes

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
~/.config/opencode/
  plugins/
    opencode-mem.ts           # Loader file (OpenCode discovers this)
    opencode-mem/             # Plugin subdirectory
      index.ts                # Main plugin entry point
      package.json            # Plugin dependencies
      tsconfig.json           # TypeScript config
      bin/
        claude-mem            # Backend binary (auto-downloaded)
      skills/
        mem-search/
          SKILL.md            # Memory search skill definition
  skills/
    mem-search -> ../plugins/opencode-mem/skills/mem-search  # Symlink for discovery
  package.json                # Config-level deps (zod, @opencode-ai/plugin)
```

## OpenCode Plugin Discovery

OpenCode discovers local plugins by scanning `{plugin,plugins}/*.{ts,js}` in each config directory. The glob does **not** recurse into subdirectories. The loader file (`opencode-mem.ts`) at the top level re-exports from the subdirectory:

```typescript
export { opencodeMem, opencodeMem as default } from "./opencode-mem/index.ts"
```

OpenCode imports all exported functions and calls each with `PluginInput` to get `Hooks`.

## OpenCode Skill Discovery

Skills are discovered **independently from plugins**. OpenCode scans `{skill,skills}/**/SKILL.md` in each config directory. The install script symlinks `skills/mem-search/` to the config directory's `skills/` folder.

## Plugin Hooks Used

| Hook | Purpose |
|------|---------|
| `experimental.chat.system.transform` | Injects past context into system prompt, triggers binary update |
| `tool.execute.after` | Captures tool executions as observations |
| `experimental.session.compacting` | Injects summary context during session compaction |

## Available OpenCode Hook Events (Reference)

- `event` - General event bus
- `config` - Configuration changes
- `tool` - Custom tool definitions (`{ [name]: ToolDefinition }`)
- `auth` - Authentication
- `chat.message` - Chat message lifecycle
- `chat.params` / `chat.headers` - Chat request params/headers
- `permission.ask` - Permission requests
- `command.execute.before` - Before command execution
- `tool.execute.before` / `tool.execute.after` - Tool lifecycle
- `shell.env` - Shell environment variables
- `experimental.chat.system.transform` - Transform system prompt
- `experimental.chat.messages.transform` - Transform chat messages
- `experimental.session.compacting` - Session compaction
- `experimental.text.complete` - Text completion
- `tool.definition` - Tool definition modification

**Note**: There are NO `session.created`, `session.idle`, or `session.deleted` hooks.

## Integration with claude-mem Backend

```typescript
const binPath = `${import.meta.dirname}/bin/claude-mem`;
await $`${binPath} hook:context --project ${directory}`;
await $`${binPath} hook:save --project ${directory} --tool ${tool} --args ${args} --result ${result}`;
await $`${binPath} hook:summary --project ${directory}`;
```
