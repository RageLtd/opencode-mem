# Fancy Agents

A reusable configuration template for Claude Code that enforces behavioral rules, quality gates, and safety constraints across any project.

## Quick Start

### Option 1: Use as GitHub Template

1. Click **"Use this template"** on GitHub to create a new repository
2. Clone your new repository
3. Run the setup script:
   ```bash
   # macOS/Linux — install rules globally
   ./scripts/setup.sh

   # macOS/Linux — install rules to a specific project
   ./scripts/setup.sh /path/to/my-project

   # Windows (PowerShell)
   .\scripts\setup.ps1
   .\scripts\setup.ps1 -TargetPath C:\path\to\my-project
   ```
4. Restart Claude Code to pick up the new rules and plugins

### Option 2: Download and Extract

1. Download the repository as a ZIP file
2. Extract the contents
3. Run the setup script (see above)
4. Restart Claude Code

## What's Inside

### Behavioral Rules

`.claude/rules/` contains categorized rule files that Claude Code loads automatically:

| Category | Rules | Purpose |
|---|---|---|
| **coding** | `functional-style.md`, `error-handling.md` | Functional programming (CRITICAL), Result pattern for errors |
| **quality** | `quality-gates.md`, `tdd.md`, `code-changes.md` | Security review, test coverage, minimal changes |
| **safety** | `git-restrictions.md`, `security.md` | No agent commits/pushes, secrets protection |
| **workflow** | `plan-first.md`, `stop-conditions.md` | Plan-Approval-Execute flow, escalation triggers |
| **communication** | `output-format.md`, `response-style.md` | Structured responses, concise style |
| **documentation** | `best-practices.md`, `decision-records.md` | Pattern recording, decision tracking |
| **tooling** | `tool-usage.md`, `biome.md`, `bun.md`, `rust-tooling.md` | Tool use principles, Biome linting/formatting, Bun over Node, rustfmt + clippy |

`rule-priority.md` defines conflict resolution: **Safety > Quality > Workflow > Code style**.

### Agent Identity

**AGENTS.md** defines a minimal agent identity. `CLAUDE.md` is a symlink to `AGENTS.md` so both Claude Code and other tools that look for either filename will find it. Customize this per-project after setup.

### Claude Code Plugins

**`.claude/settings.json`** enables 11 plugins from the official marketplace:

- **context7** - Documentation lookup
- **feature-dev** - Guided feature development
- **code-review** - Multi-aspect code review
- **pr-review-toolkit** - PR review agents
- **typescript-lsp** - TypeScript language server
- **rust-analyzer-lsp** - Rust language server
- **code-simplifier** - Code clarity
- **security-guidance** - Security best practices
- **plugin-dev** - Plugin development tools
- **atlassian** - Jira/Confluence integration
- **Notion** - Notion workspace integration

### Setup Scripts

**`scripts/setup.sh`** (macOS/Linux) and **`scripts/setup.ps1`** (Windows):

- Install TypeScript language server
- Install Rust Analyzer
- Copy `.claude/rules/` to the target project or `~/.claude/rules/` (global)
- Optionally install the [RageLtd/claude-mem](https://github.com/RageLtd/claude-mem) plugin marketplace

#### Flags

| Flag | Bash | PowerShell | Description |
|---|---|---|---|
| Target path | `./setup.sh /path` | `.\setup.ps1 -TargetPath C:\path` | Install rules to a specific project (default: global) |
| Install memory | `./setup.sh --install-memory` | `.\setup.ps1 -InstallMemory` | Include the RageLtd/claude-mem marketplace |

Flags can be combined: `./scripts/setup.sh --install-memory /path/to/project`

## Structure

```
.
├── .claude/
│   ├── settings.json          # Plugin configuration
│   └── rules/                 # Behavioral rules (18 files, 7 categories)
│       ├── rule-priority.md   # Conflict resolution hierarchy
│       ├── coding/            # Functional style, error handling
│       ├── communication/     # Output format, response style
│       ├── documentation/     # Best practices, decision records
│       ├── quality/           # Quality gates, TDD, code changes
│       ├── safety/            # Git restrictions, security
│       ├── tooling/           # Tool usage, Biome, Bun, Rust tooling
│       └── workflow/          # Plan-first, stop conditions
├── docs/
│   └── BEST_PRACTICES.md     # Template for capturing verified patterns
├── scripts/
│   ├── setup.sh              # macOS/Linux setup
│   └── setup.ps1             # Windows setup
├── AGENTS.md                 # Agent identity (customize per-project)
├── CLAUDE.md                 # Symlink → AGENTS.md
└── README.md
```

## Requirements

- [Claude Code](https://claude.ai/code) CLI installed
- Node.js (for TypeScript LSP)
- Rust toolchain (optional, for Rust Analyzer)
- Git (for marketplace installation, if using `--install-memory`)

## Post-Setup

After running the setup script:

1. **Restart Claude Code** to load the rules and plugins
2. **Customize `AGENTS.md`** with your project-specific identity and context
3. Rules in `.claude/rules/` will be active immediately

If you used `--install-memory`:
4. **Run `/plugins`** to see available plugins from RageLtd/claude-mem
5. **Enable additional plugins** as needed via Claude Code settings

Some plugins require additional configuration:
- **atlassian** - Requires Atlassian account authentication
- **Notion** - Requires Notion workspace authorization

---

Built for reliable, auditable, and safe agent operations.
