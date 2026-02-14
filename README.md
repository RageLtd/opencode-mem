# opencode-mem

Persistent memory system for OpenCode - context compression and recall across sessions.

Automatically captures tool executions, processes them through AI to extract semantic meaning, and stores structured observations in SQLite with full-text search. Relevant context is automatically injected back into new sessions.

## Features

- **Automatic Context Injection**: Past observations are injected when a new session starts
- **Tool Observation Capture**: Saves all tool executions for future reference
- **Session Summaries**: Generates summaries when sessions complete
- **Memory Search**: Search past observations, decisions, and session history
- **Shared Backend**: Uses the same database as [claude-mem](https://github.com/RageLtd/claude-mem) for Claude Code compatibility
- **Auto-Updates**: Binary is automatically downloaded/updated on startup

## Requirements

- [OpenCode](https://opencode.ai) CLI installed
- [Bun](https://bun.sh) runtime

## Installation

```bash
curl -sL https://raw.githubusercontent.com/RageLtd/opencode-mem/main/scripts/install.sh | bash
```

This will install the plugin to `~/.config/opencode/plugins/opencode-mem`.

For project-specific installation, create a symlink manually:

```bash
ln -s /path/to/opencode-mem /your/project/.opencode/plugins/opencode-mem
```

## Usage

The plugin works automatically:

- **Session Start**: Past context is injected automatically
- **Tool Use**: Observations are saved automatically
- **Session End**: Summary is generated automatically

### Memory Commands

Use the `/memory` tool for manual searches:

```bash
# Search memory
/memory search "authentication"

# List recent memories
/memory list
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

## Architecture

```
OpenCode ──► Plugin Hooks ──► claude-mem binary (worker) ──► SQLite DB
                                    │
                                    └─────► Context Injection
```

## Supported Platforms

- macOS ARM64 (M1/M2/M3)
- macOS x64 (Intel)
- Linux x64
- Linux ARM64

## Sharing Memory with Claude Code

This plugin shares the same database with [claude-mem](https://github.com/RageLtd/claude-mem), so your memory is accessible from both OpenCode and Claude Code without duplication.

## License

This is free and unencumbered software released into the public domain. See [LICENSE](./LICENSE) for details.
