# opencode-mem

Persistent memory system for OpenCode - context compression and recall across sessions.

Automatically captures tool executions, processes them through AI to extract semantic meaning, and stores structured observations in SQLite with full-text search. Relevant context is automatically injected back into new sessions.

## Features

- **Automatic Context Injection**: Past observations are injected into the system prompt via `experimental.chat.system.transform`
- **Tool Observation Capture**: Saves all tool executions via `tool.execute.after`
- **Session Compaction Context**: Injects memory summaries during session compaction via `experimental.session.compacting`
- **Memory Search Tool**: Custom `memory` tool for searching past observations, decisions, and session history
- **Memory Search Skill**: `mem-search` skill with progressive disclosure for token-efficient context loading
- **Shared Backend**: Uses the same database as [claude-mem](https://github.com/RageLtd/claude-mem) for Claude Code compatibility
- **Auto-Updates**: Binary is automatically downloaded/updated on startup

## Requirements

- [OpenCode](https://opencode.ai) CLI installed
- [Bun](https://bun.sh) runtime (used by OpenCode for plugin dependency installation)

## Installation

```bash
curl -sL https://raw.githubusercontent.com/RageLtd/opencode-mem/main/scripts/install.sh | bash
```

The install script:

1. Downloads the plugin to `~/.config/opencode/plugins/opencode-mem/`
2. Creates a **loader file** at `~/.config/opencode/plugins/opencode-mem.ts` (OpenCode discovers plugins by scanning `plugins/*.{ts,js}` -- it does not recurse into subdirectories)
3. Downloads the `claude-mem` binary for your platform
4. Symlinks skills into `~/.config/opencode/skills/` (OpenCode discovers skills from `{skill,skills}/**/SKILL.md` in each config directory, independently from plugins)
5. Adds `zod` to `~/.config/opencode/package.json` (OpenCode auto-adds `@opencode-ai/plugin` and runs `bun install` at startup)

Restart OpenCode after installation.

### Manual / Project-Level Installation

For project-specific installation, you need to replicate what the install script does:

```bash
# 1. Clone or copy the plugin into a subdirectory
mkdir -p /your/project/.opencode/plugins
cp -r /path/to/opencode-mem /your/project/.opencode/plugins/opencode-mem

# 2. Create the loader file (required -- OpenCode only scans for top-level .ts/.js files)
echo 'export { opencodeMem, opencodeMem as default } from "./opencode-mem/index.ts"' \
  > /your/project/.opencode/plugins/opencode-mem.ts

# 3. Symlink skills into the config's skills directory
mkdir -p /your/project/.opencode/skills
ln -s ../plugins/opencode-mem/skills/mem-search /your/project/.opencode/skills/mem-search

# 4. Ensure zod is in the project's .opencode/package.json
```

### Uninstalling

```bash
rm -rf ~/.config/opencode/plugins/opencode-mem
rm -f ~/.config/opencode/plugins/opencode-mem.ts
rm -f ~/.config/opencode/skills/mem-search
```

## How It Works

### Plugin Loading

OpenCode discovers local plugins by scanning `{plugin,plugins}/*.{ts,js}` in each config directory. The glob uses a single `*` -- it does **not** recurse into subdirectories. That's why the install script creates a loader file (`opencode-mem.ts`) at the top level that re-exports from the subdirectory:

```typescript
export { opencodeMem, opencodeMem as default } from "./opencode-mem/index.ts"
```

OpenCode imports all exported functions from discovered plugin files and calls each with a `PluginInput` context (`{ client, project, directory, worktree, serverUrl, $ }`). The returned `Hooks` object registers the plugin's behavior.

### Hooks

| Hook | Purpose |
|------|---------|
| `experimental.chat.system.transform` | Injects past context into the system prompt at session start. Also triggers binary download/update on first run. |
| `tool.execute.after` | Captures tool executions and saves them as observations via `claude-mem hook:save`. |
| `experimental.session.compacting` | Injects session summary context during compaction via `claude-mem hook:summary`. |

### Skills

Skills are discovered **independently from plugins** via filesystem scanning. OpenCode scans `{skill,skills}/**/SKILL.md` in each config directory. The install script creates a symlink from `~/.config/opencode/skills/mem-search` to the plugin's `skills/mem-search/` directory.

The `mem-search` skill provides progressive disclosure for token-efficient memory loading. See `skills/mem-search/SKILL.md` for full API documentation.

### Custom Tool

The plugin registers a `memory` tool:

```
# Search memory
memory search "authentication"

# List recent memories
memory list
```

## Architecture

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
  +-- Skill Discovery (skills/mem-search/SKILL.md)
  |
  +-- claude-mem binary (plugins/opencode-mem/bin/claude-mem)
        |
        +-- SQLite DB (shared with claude-mem for Claude Code)
```

### API (via worker service)

The backend worker runs on `http://localhost:3456`:

```bash
# Get recent context
curl "http://localhost:3456/context?project=myproject&limit=10"

# Search observations
curl "http://localhost:3456/search?query=api&concept=decision"

# Get decisions
curl "http://localhost:3456/decisions?since=7d"
```

See `skills/mem-search/SKILL.md` for full API documentation.

## Supported Platforms

- macOS ARM64 (M1/M2/M3/M4)
- macOS x64 (Intel)
- Linux x64
- Linux ARM64

## Sharing Memory with Claude Code

This plugin shares the same database with [claude-mem](https://github.com/RageLtd/claude-mem), so your memory is accessible from both OpenCode and Claude Code without duplication.

## Development

```bash
bun install
bun tsc --noEmit     # Type check
bunx biome check .   # Lint and format
```

## License

This is free and unencumbered software released into the public domain. See [LICENSE](./LICENSE) for details.
