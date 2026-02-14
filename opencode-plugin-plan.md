# OpenCode Memory Plugin Plan

## Overview

Create an OpenCode plugin (`opencode-mem`) that provides persistent memory for OpenCode sessions, reusing the existing `claude-mem` binary as the backend worker service.

## Architecture (Resolved)

```
OpenCode
  |
  +-- Plugin Loader (plugins/opencode-mem.ts)
  |     |
  |     +-- Plugin (plugins/opencode-mem/index.ts)
  |           |
  |           +-- experimental.chat.system.transform --> claude-mem hook:context
  |           +-- tool.execute.after                 --> claude-mem hook:save
  |           +-- experimental.session.compacting    --> claude-mem hook:summary
  |           +-- tool: memory                       --> claude-mem search/list
  |
  +-- Skill Discovery (skills/mem-search/SKILL.md)  [independent from plugin]
  |
  +-- claude-mem binary (plugins/opencode-mem/bin/claude-mem)
        |
        +-- SQLite DB (shared with claude-mem for Claude Code)
```

## Key Design Decisions (Resolved)

1. **Backend reuse**: The existing `claude-mem` binary handles all storage/processing
2. **Plugin role**: OpenCode plugin acts as a thin layer -- translates OpenCode hook events to CLI commands
3. **Shared database**: Same SQLite DB as claude-mem for Claude Code compatibility
4. **Loader file pattern**: OpenCode only discovers `{plugin,plugins}/*.{ts,js}` files (no subdirectory recursion), so we use a top-level `opencode-mem.ts` loader that re-exports from the subdirectory
5. **Skill independence**: Skills are discovered independently from plugins via `{skill,skills}/**/SKILL.md` globs -- the install script symlinks from the plugin's `skills/` directory into the config directory's `skills/` folder
6. **Binary auto-update**: Binary is downloaded on first run via `ensureBinaryUpToDate()` in the `experimental.chat.system.transform` hook, and is also downloaded during installation by the install script

## Plugin Discovery

OpenCode scans `{plugin,plugins}/*.{ts,js}` in each config directory (`~/.config/opencode/`, `.opencode/`, `~/.opencode/`, `$OPENCODE_CONFIG_DIR`). The glob uses a single `*` -- it does **not** recurse into subdirectories and does **not** consult `package.json` `main` fields.

**Implication**: The plugin code lives in a subdirectory (`plugins/opencode-mem/`) but OpenCode can't discover it directly. A loader file at `plugins/opencode-mem.ts` re-exports from the subdirectory:

```typescript
export { opencodeMem, opencodeMem as default } from "./opencode-mem/index.ts"
```

OpenCode imports all exported functions and calls each with `PluginInput` (`{ client, project, directory, worktree, serverUrl, $ }`). The returned `Hooks` object registers the plugin's behavior.

## Hook Implementations (Resolved)

| OpenCode Hook | claude-mem Command | Purpose |
|---|---|---|
| `experimental.chat.system.transform` | `hook:context --project <dir>` | Inject past context into system prompt at session start |
| `tool.execute.after` | `hook:save --project <dir> --tool <name> --args <json> --result <json>` | Capture tool executions as observations |
| `experimental.session.compacting` | `hook:summary --project <dir>` | Inject summary context during session compaction |

**Note**: The following hooks do **NOT** exist in OpenCode's plugin API:
- ~~`session.created`~~ -- use `experimental.chat.system.transform` instead
- ~~`session.idle`~~ -- use `experimental.session.compacting` instead
- ~~`session.deleted`~~ -- no equivalent; not needed
- ~~`server.connected`~~ -- no equivalent; binary management is handled in hooks

## Skill Discovery

Skills are discovered **entirely independently from plugins** via filesystem glob scanning. OpenCode scans:

1. `~/.claude/skills/**/SKILL.md` and `~/.agents/skills/**/SKILL.md` (external compat)
2. `.claude/skills/**/SKILL.md` and `.agents/skills/**/SKILL.md` (walking up from project to worktree root)
3. `{skill,skills}/**/SKILL.md` in each OpenCode config directory
4. Custom paths from `opencode.json` `skills.paths`
5. Remote URLs from `opencode.json` `skills.urls`

**Implication**: The plugin's `skills/` directory is NOT scanned. The install script creates a symlink: `~/.config/opencode/skills/mem-search` -> `~/.config/opencode/plugins/opencode-mem/skills/mem-search`

## Dependency Management

OpenCode automatically:
1. Adds `@opencode-ai/plugin` to each config directory's `package.json`
2. Runs `bun install` in each config directory at startup

Additional dependencies (like `zod`) must be added to the config directory's `package.json` by the install script.

## Install Structure (Resolved)

```
~/.config/opencode/
  plugins/
    opencode-mem.ts             # Loader file (OpenCode discovers this)
    opencode-mem/               # Plugin subdirectory
      index.ts                  # Main plugin entry point
      package.json              # Plugin metadata
      tsconfig.json             # TypeScript config
      bin/
        claude-mem              # Backend binary (downloaded by install script + auto-updated)
      skills/
        mem-search/
          SKILL.md              # Memory search skill definition
  skills/
    mem-search -> ../plugins/opencode-mem/skills/mem-search  # Symlink for discovery
  package.json                  # Config-level deps (zod, @opencode-ai/plugin)
```

## Available OpenCode Hook Events (Reference)

- `event` - General event bus
- `config` - Configuration changes
- `tool` - Custom tool definitions (`{ [name]: ToolDefinition }`)
- `auth` - Authentication
- `chat.message` - Chat message lifecycle (`{sessionID, agent?, model?, messageID?, variant?}`)
- `chat.params` / `chat.headers` - Chat request params/headers
- `permission.ask` - Permission requests
- `command.execute.before` - Before command execution
- `tool.execute.before` / `tool.execute.after` - Tool lifecycle
- `shell.env` - Shell environment variables
- `experimental.chat.system.transform` - Transform system prompt (`output.system: string[]`)
- `experimental.chat.messages.transform` - Transform chat messages
- `experimental.session.compacting` - Session compaction (`output.context: string[]`, `output.prompt?`)
- `experimental.text.complete` - Text completion
- `tool.definition` - Tool definition modification

## Status

- [x] Phase 1: Plugin structure
- [x] Phase 2: Hook implementations
- [x] Phase 3: Binary integration (auto-download + auto-update)
- [x] Phase 4: Memory search skill
- [x] Install script with binary download and skill symlinking
