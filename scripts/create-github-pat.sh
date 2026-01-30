#!/usr/bin/env bash
set -euo pipefail

# GitHub PAT helper for MCP server
# Creates or retrieves a GitHub Personal Access Token

echo "GitHub PAT Setup for MCP Server"
echo "================================"
echo

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "GitHub CLI (gh) not found."
    echo
    echo "Option 1: Install gh CLI"
    echo "  brew install gh  # macOS"
    echo "  nix-env -iA nixpkgs.gh  # Nix"
    echo
    echo "Option 2: Create PAT manually"
    echo "  https://github.com/settings/tokens?type=beta"
    echo
    echo "Required scopes for MCP server:"
    echo "  - repo (Full control of private repositories)"
    echo "  - read:org (Read org membership)"
    echo "  - read:user (Read user profile)"
    exit 1
fi

# Check if already authenticated
if ! gh auth status &> /dev/null; then
    echo "Not authenticated with GitHub CLI."
    echo "Run: gh auth login"
    exit 1
fi

echo "GitHub CLI authenticated."
echo

# Check current token scopes
echo "Current authentication:"
gh auth status
echo

# Option to get existing token or create new one
echo "Options:"
echo "  1) Use existing gh auth token (may have limited scopes)"
echo "  2) Create new fine-grained PAT via browser"
echo "  3) Show required scopes only"
echo
read -rp "Choose option [1-3]: " choice

case "$choice" in
    1)
        echo
        echo "Getting current token..."
        TOKEN=$(gh auth token)
        echo
        echo "Token retrieved. Add to your shell config:"
        echo
        echo "  export GITHUB_PERSONAL_ACCESS_TOKEN=\"$TOKEN\""
        echo
        echo "Or add to .envrc:"
        echo
        echo "  echo 'export GITHUB_PERSONAL_ACCESS_TOKEN=\"$TOKEN\"' >> .envrc"
        echo "  direnv allow"
        ;;
    2)
        echo
        echo "Opening GitHub to create a fine-grained PAT..."
        echo
        echo "Recommended settings:"
        echo "  - Token name: mcp-server-$(date +%Y%m%d)"
        echo "  - Expiration: 30 days (or custom)"
        echo "  - Repository access: All repositories (or select specific)"
        echo "  - Permissions:"
        echo "      Contents: Read and write"
        echo "      Issues: Read and write"
        echo "      Pull requests: Read and write"
        echo "      Metadata: Read-only (auto-selected)"
        echo
        # Open browser to PAT creation page
        if command -v open &> /dev/null; then
            open "https://github.com/settings/personal-access-tokens/new"
        elif command -v xdg-open &> /dev/null; then
            xdg-open "https://github.com/settings/personal-access-tokens/new"
        else
            echo "Open this URL: https://github.com/settings/personal-access-tokens/new"
        fi
        echo
        echo "After creating the token, add it to your shell:"
        echo
        echo "  export GITHUB_PERSONAL_ACCESS_TOKEN=\"ghp_...\""
        ;;
    3)
        echo
        echo "Required scopes for GitHub MCP server:"
        echo
        echo "Classic token (https://github.com/settings/tokens):"
        echo "  - repo (Full control)"
        echo "  - read:org"
        echo "  - read:user"
        echo
        echo "Fine-grained token (https://github.com/settings/personal-access-tokens/new):"
        echo "  - Contents: Read and write"
        echo "  - Issues: Read and write"
        echo "  - Pull requests: Read and write"
        echo "  - Actions: Read-only (optional)"
        echo "  - Metadata: Read-only (auto)"
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac
