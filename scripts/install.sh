#!/bin/bash
set -e

PLUGIN_NAME="opencode-mem"
REPO="RageLtd/opencode-mem"
INSTALL_DIR="${HOME}/.config/opencode/plugins/${PLUGIN_NAME}"

echo "Installing ${PLUGIN_NAME}..."

# Create plugins directory if it doesn't exist
mkdir -p "${HOME}/.config/opencode/plugins"
mkdir -p "${INSTALL_DIR}"

# Check if already installed
if [ -d "${INSTALL_DIR}" ]; then
    echo "Plugin already installed at ${INSTALL_DIR}"
    echo "To update, run: rm -rf ${INSTALL_DIR} && $0"
    exit 0
fi

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

echo "Installed to ${INSTALL_DIR}"
echo ""
echo "Restart OpenCode to use the plugin."
