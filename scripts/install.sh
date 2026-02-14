#!/bin/bash
set -e

PLUGIN_NAME="opencode-mem"
REPO="RageLtd/opencode-mem"
CONFIG_DIR="${OPENCODE_CONFIG_DIR:-${HOME}/.config/opencode}"
PLUGINS_DIR="${CONFIG_DIR}/plugins"
INSTALL_DIR="${PLUGINS_DIR}/${PLUGIN_NAME}"
LOADER_FILE="${PLUGINS_DIR}/${PLUGIN_NAME}.ts"

echo "Installing ${PLUGIN_NAME}..."

# Create plugins directory if it doesn't exist
mkdir -p "${PLUGINS_DIR}"

# Check if already installed (but allow fresh install)
if [ -d "${INSTALL_DIR}" ] && [ "$(ls -A "${INSTALL_DIR}")" ]; then
    echo "Plugin already installed at ${INSTALL_DIR}"
    echo "To update, run: rm -rf ${INSTALL_DIR} ${LOADER_FILE} && $0"
    exit 0
fi

# Create fresh install directory
rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"

# Download the repository as a zip
TEMP_DIR=$(mktemp -d)
cd "${TEMP_DIR}"

echo "Downloading from GitHub..."
curl -sL "https://github.com/${REPO}/archive/refs/heads/main.zip" -o repo.zip

unzip -q repo.zip
cd "${PLUGIN_NAME}-main"

# Move to install location
mv * "${INSTALL_DIR}/"
cd ..
rm -rf "${TEMP_DIR}"

# Create loader file that OpenCode will discover.
# OpenCode scans plugins/*.{ts,js} — it does not recurse into subdirectories.
echo "Creating plugin loader..."
cat > "${LOADER_FILE}" << 'LOADER'
export { opencodeMem, opencodeMem as default } from "./opencode-mem/index.ts"
LOADER

# Ensure zod is available in the config directory's package.json.
# OpenCode automatically adds @opencode-ai/plugin and runs bun install,
# but additional dependencies must be declared here.
CONFIG_PKG="${CONFIG_DIR}/package.json"
if [ -f "${CONFIG_PKG}" ]; then
    # Add zod if not already present
    if ! grep -q '"zod"' "${CONFIG_PKG}"; then
        echo "Adding zod dependency to ${CONFIG_PKG}..."
        # Use a temp file for portable sed
        if command -v bun &> /dev/null; then
            bun -e "
                const pkg = JSON.parse(await Bun.file('${CONFIG_PKG}').text());
                pkg.dependencies = pkg.dependencies || {};
                pkg.dependencies.zod = '>=4.0.0';
                await Bun.write('${CONFIG_PKG}', JSON.stringify(pkg, null, 2));
            "
        else
            # Fallback: just note it
            echo "Warning: Could not add zod dependency. Please add it manually to ${CONFIG_PKG}"
        fi
    fi
else
    echo '{ "dependencies": { "zod": ">=4.0.0" } }' > "${CONFIG_PKG}"
fi

# Download the claude-mem binary for the current platform
echo "Downloading claude-mem binary..."
BINARY_REPO="RageLtd/claude-mem"
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

if [ "${OS}" = "darwin" ]; then
    if [ "${ARCH}" = "arm64" ]; then
        BINARY_NAME="claude-mem-darwin-arm64"
    else
        BINARY_NAME="claude-mem-darwin-x64"
    fi
elif [ "${OS}" = "linux" ]; then
    if [ "${ARCH}" = "aarch64" ] || [ "${ARCH}" = "arm64" ]; then
        BINARY_NAME="claude-mem-linux-arm64"
    else
        BINARY_NAME="claude-mem-linux-x64"
    fi
else
    echo "Warning: Unsupported platform ${OS} ${ARCH}. Skipping binary download."
    BINARY_NAME=""
fi

if [ -n "${BINARY_NAME}" ]; then
    TAG_NAME=$(curl -s "https://api.github.com/repos/${BINARY_REPO}/releases/latest" \
        -H "User-Agent: opencode-mem" \
        | grep -o '"tag_name":"[^"]*"' \
        | cut -d '"' -f 4)
    RELEASE_URL="https://github.com/${BINARY_REPO}/releases/download/${TAG_NAME}/${BINARY_NAME}"

    if [ -n "${TAG_NAME}" ]; then
        mkdir -p "${INSTALL_DIR}/bin"
        curl -sL "${RELEASE_URL}" -o "${INSTALL_DIR}/bin/claude-mem"
        chmod +x "${INSTALL_DIR}/bin/claude-mem"
        echo "Binary installed: ${INSTALL_DIR}/bin/claude-mem"
        "${INSTALL_DIR}/bin/claude-mem" version 2>/dev/null || true
    else
        echo "Warning: Could not find binary download URL. The plugin will attempt to download it at runtime."
    fi
fi

# Install skills — OpenCode discovers skills from {skill,skills}/**/SKILL.md
# in each config directory, NOT from plugin subdirectories.
SKILLS_DIR="${CONFIG_DIR}/skills"
if [ -d "${INSTALL_DIR}/skills" ]; then
    echo "Installing skills..."
    for SKILL_DIR in "${INSTALL_DIR}/skills"/*/; do
        SKILL_NAME=$(basename "${SKILL_DIR}")
        TARGET="${SKILLS_DIR}/${SKILL_NAME}"
        mkdir -p "${SKILLS_DIR}"
        # Symlink so skill stays in sync with plugin updates
        rm -rf "${TARGET}"
        ln -s "${SKILL_DIR}" "${TARGET}"
        echo "  Skill linked: ${SKILL_NAME} -> ${TARGET}"
    done
fi

echo ""
echo "Installed to ${INSTALL_DIR}"
echo "Loader created at ${LOADER_FILE}"
echo ""
echo "Restart OpenCode to use the plugin."
