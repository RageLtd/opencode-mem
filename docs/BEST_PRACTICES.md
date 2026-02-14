# Best Practices

This document captures verified patterns, API usage, and best practices discovered during development. All entries must include source documentation and date.

## Format

Each entry should follow this structure:

```
### [Library/Tool Name] - [Topic]
**Date**: YYYY-MM-DD
**Source**: [Official documentation URL or reference]
**Summary**: Brief description of the pattern or practice
**Decision**: How/when to use this pattern
**Example**: (optional) Code snippet or usage example
```

## Entries

### OpenCode Plugin - Discovery Mechanism
**Date**: 2026-02-13
**Source**: `packages/opencode/src/config/config.ts` (OpenCode source)
**Summary**: OpenCode discovers local plugins using the glob `{plugin,plugins}/*.{ts,js}` in each config directory. The glob uses a single `*` -- it does NOT recurse into subdirectories.
**Decision**: Plugins that live in a subdirectory (e.g., `plugins/opencode-mem/`) must have a loader file at the top level (e.g., `plugins/opencode-mem.ts`) that re-exports from the subdirectory.
**Example**:
```typescript
// ~/.config/opencode/plugins/opencode-mem.ts (loader file -- discovered by glob)
export { opencodeMem, opencodeMem as default } from "./opencode-mem/index.ts"
```

### OpenCode Plugin - Available Hooks
**Date**: 2026-02-13
**Source**: `@opencode-ai/plugin@1.1.65` type definitions, `packages/opencode/src/plugin/index.ts`
**Summary**: The following hooks exist and are supported. There are NO `session.created`, `session.idle`, or `session.deleted` hooks.
**Decision**: Use these hook mappings for common patterns:
- **Inject context at session start**: `experimental.chat.system.transform` (fires on every LLM call, push to `output.system`)
- **Save tool observations**: `tool.execute.after`
- **Inject context during compaction**: `experimental.session.compacting` (push to `output.context`)
- **Register custom tools**: `tool` property in returned Hooks object

### OpenCode Plugin - Dependency Management
**Date**: 2026-02-13
**Source**: `packages/opencode/src/config/config.ts` (`installDependencies` function)
**Summary**: OpenCode automatically adds `@opencode-ai/plugin` to the config directory's `package.json` and runs `bun install`. Additional dependencies (e.g., `zod`) must be added to the config directory's `package.json` (e.g., `~/.config/opencode/package.json`), NOT to the plugin subdirectory's `package.json`.
**Decision**: The install script must merge any extra dependencies into the config-level `package.json`. Node module resolution walks up from the plugin subdirectory to find them.

### OpenCode Plugin - Skill Discovery
**Date**: 2026-02-13
**Source**: `packages/opencode/src/skill/skill.ts`
**Summary**: Skills are discovered independently from plugins via filesystem scanning. The glob is `{skill,skills}/**/SKILL.md` in each config directory. Plugins cannot programmatically register skills -- there is no hook for it.
**Decision**: To ship skills with a plugin, symlink or copy them to a discovered location:
```bash
ln -sf ~/.config/opencode/plugins/opencode-mem/skills/mem-search \
       ~/.config/opencode/skills/mem-search
```

### OpenCode Plugin - Binary Management
**Date**: 2026-02-13
**Source**: Development experience with `claude-mem` binary
**Summary**: When a plugin depends on an external binary, the binary should be downloaded during installation AND verified at runtime. Runtime download should track success/failure to avoid marking the binary as "ready" when the download failed.
**Decision**: Use a two-layer approach:
1. Install script downloads the binary during `install.sh`
2. Runtime `ensureBinary()` checks for updates but only sets `isBinaryReady = true` on confirmed success
3. Hooks that depend on the binary should check the ready state and gracefully degrade

### OpenCode Plugin - Module Loading
**Date**: 2026-02-13
**Source**: `packages/opencode/src/plugin/index.ts`
**Summary**: After `import()`, OpenCode iterates all exported functions via `Object.entries(mod)` and calls each with `PluginInput`. A `Set` prevents duplicate initialization when the same function is both a named and default export.
**Decision**: Always export the plugin function as both named and default:
```typescript
export const opencodeMem: Plugin = async (ctx) => { /* ... */ }
export default opencodeMem
```

## Index

- **Plugin Discovery**: [Discovery Mechanism](#opencode-plugin---discovery-mechanism)
- **Plugin Hooks**: [Available Hooks](#opencode-plugin---available-hooks)
- **Plugin Deps**: [Dependency Management](#opencode-plugin---dependency-management)
- **Skills**: [Skill Discovery](#opencode-plugin---skill-discovery)
- **Binary**: [Binary Management](#opencode-plugin---binary-management)
- **Module Loading**: [Module Loading](#opencode-plugin---module-loading)
