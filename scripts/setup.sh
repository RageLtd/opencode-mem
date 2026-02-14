#!/bin/bash
# Setup script for fancy-agents Claude Code environment (macOS/Linux)
# Installs dependencies, configures the RageLtd/claude-mem marketplace,
# and installs Claude Code rules to the target project or globally.
#
# Usage: ./scripts/setup.sh [--install-memory] [project-path]
#   --install-memory: install the RageLtd/claude-mem marketplace
#   project-path:     optional path to a project directory
#                     rules install to <project-path>/.claude/rules/
#                     if omitted, rules install to ~/.claude/rules/ (global)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_MEMORY=false
TARGET_PATH=""

for arg in "$@"; do
    case "$arg" in
        --install-memory) INSTALL_MEMORY=true ;;
        *) TARGET_PATH="$arg" ;;
    esac
done

echo "=== Fancy Agents - Claude Code Setup ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Detect OS
OS="$(uname -s)"
case "$OS" in
    Linux*)     PLATFORM="linux";;
    Darwin*)    PLATFORM="macos";;
    *)          error "Unsupported OS: $OS"; exit 1;;
esac
info "Detected platform: $PLATFORM"

# Check for required tools
check_command() {
    if command -v "$1" &> /dev/null; then
        info "$1 is installed"
        return 0
    else
        warn "$1 is not installed"
        return 1
    fi
}

# Install TypeScript LSP (typescript-language-server)
install_typescript_lsp() {
    info "Checking TypeScript LSP..."
    if check_command typescript-language-server; then
        return 0
    fi

    if check_command npm; then
        info "Installing typescript-language-server via npm..."
        npm install -g typescript-language-server typescript
    elif check_command pnpm; then
        info "Installing typescript-language-server via pnpm..."
        pnpm add -g typescript-language-server typescript
    elif check_command yarn; then
        info "Installing typescript-language-server via yarn..."
        yarn global add typescript-language-server typescript
    else
        error "No package manager (npm/pnpm/yarn) found. Please install Node.js first."
        return 1
    fi
}

# Install Rust Analyzer
install_rust_analyzer() {
    info "Checking Rust Analyzer..."
    if check_command rust-analyzer; then
        return 0
    fi

    if check_command rustup; then
        info "Installing rust-analyzer via rustup..."
        rustup component add rust-analyzer
    elif [ "$PLATFORM" = "macos" ] && check_command brew; then
        info "Installing rust-analyzer via Homebrew..."
        brew install rust-analyzer
    elif [ "$PLATFORM" = "linux" ]; then
        warn "Please install rust-analyzer manually:"
        warn "  - Via rustup: rustup component add rust-analyzer"
        warn "  - Or download from: https://github.com/rust-lang/rust-analyzer/releases"
        return 1
    else
        error "Could not install rust-analyzer automatically."
        return 1
    fi
}

# Add RageLtd/claude-mem marketplace
add_claude_mem_marketplace() {
    info "Adding RageLtd/claude-mem marketplace..."

    CLAUDE_DIR="$HOME/.claude"
    PLUGINS_DIR="$CLAUDE_DIR/plugins"
    MARKETPLACES_FILE="$PLUGINS_DIR/known_marketplaces.json"
    MARKETPLACE_INSTALL_DIR="$PLUGINS_DIR/marketplaces/rageltd"

    # Create directories if they don't exist
    mkdir -p "$PLUGINS_DIR/marketplaces"

    # Clone or update the marketplace
    if [ -d "$MARKETPLACE_INSTALL_DIR" ]; then
        info "Marketplace already cloned, updating..."
        cd "$MARKETPLACE_INSTALL_DIR"
        git pull origin main || git pull origin master || true
        cd - > /dev/null
    else
        info "Cloning RageLtd/claude-mem marketplace..."
        git clone https://github.com/RageLtd/claude-mem.git "$MARKETPLACE_INSTALL_DIR"
    fi

    # Update known_marketplaces.json
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

    if [ -f "$MARKETPLACES_FILE" ]; then
        # Check if rageltd entry already exists
        if grep -q '"rageltd"' "$MARKETPLACES_FILE"; then
            info "Marketplace entry already exists in known_marketplaces.json"
        else
            # Add rageltd entry to existing file
            info "Adding marketplace entry to known_marketplaces.json..."
            # Use a temp file for safe editing
            TEMP_FILE=$(mktemp)
            # Remove the closing brace, add comma and new entry
            sed '$ d' "$MARKETPLACES_FILE" > "$TEMP_FILE"
            cat >> "$TEMP_FILE" << EOF
  },
  "rageltd": {
    "source": {
      "source": "git",
      "url": "https://github.com/RageLtd/claude-mem.git"
    },
    "installLocation": "$MARKETPLACE_INSTALL_DIR",
    "lastUpdated": "$TIMESTAMP"
  }
}
EOF
            mv "$TEMP_FILE" "$MARKETPLACES_FILE"
        fi
    else
        # Create new file
        info "Creating known_marketplaces.json..."
        cat > "$MARKETPLACES_FILE" << EOF
{
  "rageltd": {
    "source": {
      "source": "git",
      "url": "https://github.com/RageLtd/claude-mem.git"
    },
    "installLocation": "$MARKETPLACE_INSTALL_DIR",
    "lastUpdated": "$TIMESTAMP"
  }
}
EOF
    fi

    info "Marketplace configured successfully!"
}

# Install Claude Code rules
install_rules() {
    local source_rules="$REPO_ROOT/.claude/rules"

    if [ ! -d "$source_rules" ]; then
        error "Rules directory not found at $source_rules"
        return 1
    fi

    if [ -n "$TARGET_PATH" ]; then
        local dest="$TARGET_PATH/.claude/rules"
        info "Installing rules to project: $dest"
    else
        local dest="$HOME/.claude/rules"
        info "Installing rules globally: $dest"
    fi

    mkdir -p "$dest"
    cp -R "$source_rules"/ "$dest"/
    info "Rules installed successfully!"
}

# Main setup
echo ""
info "Installing dependencies..."
echo ""

# Track failures
FAILURES=0

install_typescript_lsp || ((FAILURES++))
echo ""

install_rust_analyzer || ((FAILURES++))
echo ""

if [ "$INSTALL_MEMORY" = true ]; then
    add_claude_mem_marketplace || ((FAILURES++))
    echo ""
else
    info "Skipping claude-mem marketplace (use --install-memory to include)"
fi
echo ""

install_rules || ((FAILURES++))
echo ""

# Summary
echo "=== Setup Complete ==="
if [ $FAILURES -eq 0 ]; then
    info "All dependencies installed successfully!"
else
    warn "$FAILURES component(s) could not be installed automatically."
    warn "Please install them manually and re-run this script."
fi

echo ""
info "Next steps:"
echo "  1. Restart Claude Code to pick up the new marketplace"
echo "  2. Run '/plugins' to see available plugins from RageLtd/claude-mem"
echo "  3. Enable desired plugins in Claude Code settings"
echo ""
