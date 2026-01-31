#!/usr/bin/env bash
set -euo pipefail

# GitHub PAT helper for MCP server (multi-instance support)
# Creates or retrieves a GitHub Personal Access Token

show_help() {
    cat << 'EOF'
GitHub PAT Setup for MCP Server

Usage:
  ./create-github-pat.sh [OPTIONS]

Options:
  -i, --instance NAME    Instance name (e.g., "personal", "work-ghe")
  -h, --host URL         GitHub host URL (for GitHub Enterprise)
  --help                 Show this help message

Examples:
  # Interactive mode
  ./create-github-pat.sh

  # Set up PAT for specific instance (github.com)
  ./create-github-pat.sh --instance personal

  # Set up PAT for GitHub Enterprise instance
  ./create-github-pat.sh --instance work-ghe --host "https://github.mycompany.com"
EOF
}

# Convert to uppercase and replace dashes with underscores
to_env_name() {
    echo "$1" | tr '[:lower:]' '[:upper:]' | tr '-' '_'
}

# Get env var name for instance
get_env_var_name() {
    local instance="$1"
    echo "GITHUB_PAT_$(to_env_name "$instance")"
}

setup_instance() {
    local instance="$1"
    local host="${2:-}"
    local env_var
    env_var=$(get_env_var_name "$instance")

    local host_display="github.com"
    local token_url="https://github.com/settings/personal-access-tokens/new"
    local classic_url="https://github.com/settings/tokens"

    if [[ -n "$host" ]]; then
        host_display="$host"
        token_url="${host}/settings/personal-access-tokens/new"
        classic_url="${host}/settings/tokens"
    fi

    echo
    echo "Setting up PAT for instance: $instance"
    echo "GitHub host: $host_display"
    echo "Environment variable: $env_var"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo

    # Check if gh CLI is available and can help
    if command -v gh &> /dev/null; then
        echo "GitHub CLI (gh) detected."
        echo
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
                if TOKEN=$(gh auth token 2>/dev/null); then
                    echo
                    echo "Token retrieved. Add to your shell config:"
                    echo
                    echo "  export $env_var=\"$TOKEN\""
                    echo
                    return
                else
                    echo "Could not get token. You may need to run: gh auth login"
                fi
                ;;
            2)
                open_pat_page "$token_url"
                ;;
            3)
                show_scopes
                return
                ;;
            *)
                echo "Invalid option"
                return 1
                ;;
        esac
    else
        echo "GitHub CLI (gh) not found. Creating PAT manually."
        echo
        open_pat_page "$token_url"
    fi

    echo
    echo "After creating the token, add to your shell config (~/.zshrc or ~/.bashrc):"
    echo
    echo "  export $env_var=\"ghp_...\""
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

open_pat_page() {
    local url="$1"

    echo "Opening GitHub to create a fine-grained PAT..."
    echo
    echo "Recommended settings:"
    echo "  - Token name: mcp-server-${INSTANCE:-default}-$(date +%Y%m%d)"
    echo "  - Expiration: 30 days (or custom)"
    echo "  - Repository access: All repositories (or select specific)"
    echo "  - Permissions:"
    echo "      Contents: Read and write"
    echo "      Issues: Read and write"
    echo "      Pull requests: Read and write"
    echo "      Metadata: Read-only (auto-selected)"
    echo

    if command -v open &> /dev/null; then
        open "$url"
    elif command -v xdg-open &> /dev/null; then
        xdg-open "$url"
    else
        echo "Open this URL: $url"
    fi
}

show_scopes() {
    echo
    echo "Required scopes for GitHub MCP server:"
    echo
    echo "Classic token:"
    echo "  - repo (Full control)"
    echo "  - read:org"
    echo "  - read:user"
    echo
    echo "Fine-grained token:"
    echo "  - Contents: Read and write"
    echo "  - Issues: Read and write"
    echo "  - Pull requests: Read and write"
    echo "  - Actions: Read-only (optional)"
    echo "  - Metadata: Read-only (auto)"
}

interactive_mode() {
    echo "GitHub PAT Setup for MCP Server"
    echo "================================"
    echo
    echo "This script helps you set up PATs for GitHub MCP server instances."
    echo

    while true; do
        echo
        read -rp "Instance name (e.g., personal, work-ghe) [or 'q' to quit]: " instance

        if [[ "$instance" == "q" || "$instance" == "quit" ]]; then
            echo "Done!"
            exit 0
        fi

        if [[ -z "$instance" ]]; then
            echo "Instance name cannot be empty"
            continue
        fi

        read -rp "GitHub host URL (leave empty for github.com): " host

        setup_instance "$instance" "$host"

        echo
        read -rp "Set up another instance? [y/N]: " another
        if [[ ! "${another:-N}" =~ ^[Yy]$ ]]; then
            break
        fi
    done

    echo
    echo "Summary"
    echo "======="
    echo
    echo "After adding PATs to your shell config, reload it:"
    echo "  source ~/.zshrc  # or ~/.bashrc"
    echo
    echo "Then rebuild home-manager:"
    echo "  home-manager switch --flake .#your-config"
    echo
    echo "Verify MCP servers:"
    echo "  claude mcp list"
}

# Parse arguments
INSTANCE=""
HOST=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--instance)
            INSTANCE="$2"
            shift 2
            ;;
        -h|--host)
            HOST="$2"
            shift 2
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run appropriate mode
if [[ -n "$INSTANCE" ]]; then
    setup_instance "$INSTANCE" "$HOST"
else
    interactive_mode
fi
