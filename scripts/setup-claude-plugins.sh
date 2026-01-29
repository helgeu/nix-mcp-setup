#!/usr/bin/env bash
# Setup Claude Code plugins
# Usage: ./setup-claude-plugins.sh [plugin-name]
# If no plugin specified, installs all supported plugins

set -e

# Check if claude is available
if ! command -v claude &> /dev/null; then
  echo "Error: claude command not found"
  echo "Install Claude Code first: nix profile install github:sadjow/claude-code-nix"
  exit 1
fi

install_plugin() {
  local plugin_name="$1"
  local marketplace_id="$2"

  if claude plugin list 2>/dev/null | grep -q "$plugin_name"; then
    echo "✓ $plugin_name already installed"
    return 0
  fi

  echo "Installing $plugin_name..."
  claude plugin marketplace add "$marketplace_id"
  claude plugin install "$plugin_name"
  echo "✓ $plugin_name installed"
}

# Supported plugins
declare -A PLUGINS=(
  ["claude-mem"]="thedotmack/claude-mem"
)

if [ $# -eq 0 ]; then
  # Install all plugins
  echo "Installing all supported plugins..."
  for plugin in "${!PLUGINS[@]}"; do
    install_plugin "$plugin" "${PLUGINS[$plugin]}"
  done
else
  # Install specific plugin
  plugin="$1"
  if [ -z "${PLUGINS[$plugin]}" ]; then
    echo "Error: Unknown plugin '$plugin'"
    echo "Supported plugins: ${!PLUGINS[*]}"
    exit 1
  fi
  install_plugin "$plugin" "${PLUGINS[$plugin]}"
fi

echo ""
echo "Done! Restart Claude Code to apply changes."
