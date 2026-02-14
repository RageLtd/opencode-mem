# opencode-mem

Persistent memory system for OpenCode - context compression and recall across sessions.

Automatically captures tool executions, processes them through AI to extract semantic meaning, and stores structured observations in SQLite with full-text search. Relevant context is automatically injected back into new sessions.

## Features

- **Automatic Context Injection**: Past observations are injected into the system prompt once per session via `experimental.chat.system.transform`
- **Tool Observation Capture**: Saves tool executions via `tool.execute.after` (fire-and-forget, non-blocking)
- **Session Compaction Context**: Injects memory summaries during session compaction via `experimental.session.compacting`
- **Memory Search Tool**: Custom `memory` tool for searching past observations, decisions, and session history
- **Memory Search Skill**: `mem-search` skill with progressive disclosure for token-efficient context loading
- **Shared Backend**: Uses the same database as [claude-mem](https://github.com/RageLtd/claude-mem) for Claude Code compatibility
- **Auto-Updates**: Binary version is checked in the background on first use

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

Re-running the install script will overwrite an existing installation with the latest version.

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

### Binary Communication Protocol

The `claude-mem` binary expects **JSON piped via stdin** and writes JSON to stdout. All hook invocations follow this pattern:

```bash
echo '{"cwd":"/path/to/project"}' | claude-mem hook:context
```

The binary also manages a background HTTP worker service that handles database operations. The worker is started automatically on first hook invocation.

### Hooks

| Hook | Binary Command | Frequency | Blocking? |
|------|---------------|-----------|-----------|
| `experimental.chat.system.transform` | `hook:context` | Once per session (first message only) | Yes (first call), then cached |
| `tool.execute.after` | `hook:save` | After each tool use | No (fire-and-forget) |
| `experimental.session.compacting` | `hook:summary` | On session compaction | Yes |

**Performance design**: The plugin does zero work at initialization. All operations are deferred to when hooks actually fire. Context is fetched once and cached for the session. Tool observations are saved without blocking the UI.

### Hook Mapping (Claude Code -> OpenCode)

| Claude Code Hook | OpenCode Equivalent | Notes |
|---|---|---|
| `SessionStart` -> `hook:context` | `system.transform` (first call) | Context injected once per session |
| `UserPromptSubmit` -> `hook:new` | Not mapped | No equivalent hook in OpenCode |
| `PostToolUse` -> `hook:save` | `tool.execute.after` | Fire-and-forget |
| `Stop` -> `hook:summary` | `session.compacting` | Fires on compaction |
| `SessionEnd` -> `hook:cleanup` | Not mapped | No equivalent hook in OpenCode |

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
  |           +-- system.transform  --[stdin JSON]--> claude-mem hook:context  (once, cached)
  |           +-- tool.execute.after --[stdin JSON]--> claude-mem hook:save    (fire-and-forget)
  |           +-- session.compacting --[stdin JSON]--> claude-mem hook:summary
  |           +-- tool: memory       --[stdin JSON]--> claude-mem hook:context
  |
  +-- Skill Discovery (skills/mem-search/SKILL.md)
  |
  +-- claude-mem binary (plugins/opencode-mem/bin/claude-mem)
        |
        +-- Worker HTTP service (localhost:3456)
        +-- SQLite DB (shared with claude-mem for Claude Code)
```

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
