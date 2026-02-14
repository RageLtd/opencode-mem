# OpenCode Memory Plugin Plan

## Overview

Create an OpenCode plugin (`opencode-mem`) that provides persistent memory for OpenCode sessions, reusing the existing `claude-mem` binary as the backend worker service.

## Architecture

```
OpenCode ──► Plugin Hooks ──► claude-mem binary (worker) ──► SQLite DB
                                    │
                                    └─────► Context Injection
```

## Key Design Decisions

1. **Backend reuse**: The existing `claude-mem` binary handles all storage/processing
2. **Plugin role**: OpenCode plugin acts as a thin layer - translates OpenCode events to CLI commands
3. **Shared database**: Same SQLite DB as claude-mem for Claude Code compatibility

## Implementation Plan

### Phase 1: Plugin Structure

Create `.opencode/plugins/opencode-mem/` with corrected structure:

```
.opencode/
├── plugins/
│   └── opencode-mem/
│       ├── index.ts          # Main plugin entry point
│       └── bin/
│           └── claude-mem    # Binary (cloned from github.com/RageLtd/claude-mem)
├── package.json              # Dependencies for all plugins
└── opencode.json            # Plugin config (if needed)
```

**Notes**:
- Directory is `plugins/` (not `plugin/`) per OpenCode docs
- Binary lives in plugin's `bin/` directory
- Use `.opencode/package.json` for shared dependencies

### Phase 2: Hook Implementations

| OpenCode Event | claude-mem Hook | Action |
|----------------|-----------------|--------|
| `session.created` | `hook:context` | Inject past context at session start |
| `tool.execute.after` | `hook:save` | Capture tool observations |
| `session.idle` | `hook:summary` | Generate session summary |

### Phase 3: Binary Integration

The plugin invokes the binary from its own bin directory:

```typescript
// Binary path: resolved relative to plugin location
const binPath = import.meta.dirname + "/bin/claude-mem"
await $`${binPath} hook:context --project ${projectName}`;
```

**Worker Service**: Use `server.connected` hook to ensure worker is running:

```typescript
export const MemoryPlugin: Plugin = async ({ $ }) => {
  let workerPid: number | null = null

  const startWorker = async () => {
    const proc = $`${binPath} worker`.spawn()
    workerPid = proc.pid
  }

  return {
    "server.connected": async () => {
      if (!workerPid) await startWorker()
    },
  }
}
```

### Phase 4: Memory Search Skill

Port the existing `plugin/skills/mem-search/SKILL.md` to `.opencode/skill/mem-search/SKILL.md` (worker API unchanged).

## OpenCode Events Available

- `session.created` - New session started
- `session.idle` - Agent finished responding
- `session.deleted` - Session ended
- `tool.execute.before` / `tool.execute.after` - Tool lifecycle
- `message.updated` - Message changes
- `server.connected` - Server connection established

## OpenCode Configuration

For local plugins, place in `.opencode/plugins/` - no `opencode.json` entry needed.

For npm plugins, add to `opencode.json`:

```json
{
  "plugin": ["opencode-mem"]
}
```

## Resolved Open Questions

1. **Binary path**: Store in `.opencode/plugins/opencode-mem/bin/claude-mem` - clone from github.com/RageLtd/claude-mem
2. **Worker startup**: Plugin uses `server.connected` hook to spawn worker if not running
3. **Shared DB**: Both Claude Code and OpenCode use same SQLite DB for unified memory

## Timeline Estimate

- Phase 1: 1 hour
- Phase 2: 2 hours  
- Phase 3: 2 hours
- Phase 4: 30 minutes
