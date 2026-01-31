#!/usr/bin/env bash
set -euo pipefail

# Azure DevOps PAT helper for MCP server (multi-instance support)
# Creates or guides PAT setup for one or more ADO instances

show_help() {
    cat << 'EOF'
Azure DevOps PAT Setup for MCP Server

Usage:
  ./create-ado-pat.sh [OPTIONS]

Options:
  -i, --instance NAME    Instance name (e.g., "work", "client-acme")
  -o, --org URL          Organization URL (e.g., "https://dev.azure.com/myorg")
  -h, --help             Show this help message

Examples:
  # Interactive mode
  ./create-ado-pat.sh

  # Set up PAT for specific instance
  ./create-ado-pat.sh --instance work --org "https://dev.azure.com/myorg"

  # Multiple instances (run multiple times)
  ./create-ado-pat.sh -i work -o "https://dev.azure.com/work-org"
  ./create-ado-pat.sh -i client -o "https://dev.azure.com/client-org"
EOF
}

# Convert to uppercase and replace dashes with underscores
to_env_name() {
    echo "$1" | tr '[:lower:]' '[:upper:]' | tr '-' '_'
}

# Get env var name for instance
get_env_var_name() {
    local instance="$1"
    echo "AZURE_DEVOPS_PAT_$(to_env_name "$instance")"
}

setup_instance() {
    local instance="$1"
    local org_url="$2"
    local env_var
    env_var=$(get_env_var_name "$instance")

    echo
    echo "Setting up PAT for instance: $instance"
    echo "Organization: $org_url"
    echo "Environment variable: $env_var"
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "Step 1: Create a PAT in Azure DevOps"
    echo
    echo "  Open: ${org_url}/_usersSettings/tokens"
    echo
    echo "  Or navigate: User Settings (gear icon) → Personal Access Tokens"
    echo
    echo "Step 2: Configure the token"
    echo
    echo "  Name:         mcp-server-${instance}-$(date +%Y%m%d)"
    echo "  Organization: $(basename "$org_url")"
    echo "  Expiration:   30-90 days (recommended)"
    echo
    echo "  Required Scopes:"
    echo "    ✓ Work Items    - Read & Write"
    echo "    ✓ Code          - Read & Write (for repo operations)"
    echo "    ✓ Build         - Read & Execute (for pipelines)"
    echo
    echo "Step 3: Add to your shell config (~/.zshrc or ~/.bashrc)"
    echo
    echo "  export $env_var=\"your-pat-token-here\""
    echo
    echo "Or use direnv (.envrc in project root):"
    echo
    echo "  export $env_var=\"your-pat-token-here\""
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Try to open browser
    local token_url="${org_url}/_usersSettings/tokens"
    echo
    read -rp "Open PAT page in browser? [Y/n]: " open_browser
    if [[ "${open_browser:-Y}" =~ ^[Yy]?$ ]]; then
        if command -v open &> /dev/null; then
            open "$token_url"
        elif command -v xdg-open &> /dev/null; then
            xdg-open "$token_url"
        else
            echo "Could not open browser. Visit: $token_url"
        fi
    fi
}

interactive_mode() {
    echo "Azure DevOps PAT Setup for MCP Server"
    echo "======================================"
    echo
    echo "This script helps you set up PATs for Azure DevOps MCP server instances."
    echo

    while true; do
        echo
        read -rp "Instance name (e.g., work, client-acme) [or 'q' to quit]: " instance

        if [[ "$instance" == "q" || "$instance" == "quit" ]]; then
            echo "Done!"
            exit 0
        fi

        if [[ -z "$instance" ]]; then
            echo "Instance name cannot be empty"
            continue
        fi

        read -rp "Organization URL (e.g., https://dev.azure.com/myorg): " org_url

        if [[ -z "$org_url" ]]; then
            echo "Organization URL cannot be empty"
            continue
        fi

        setup_instance "$instance" "$org_url"

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
ORG_URL=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--instance)
            INSTANCE="$2"
            shift 2
            ;;
        -o|--org)
            ORG_URL="$2"
            shift 2
            ;;
        -h|--help)
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
if [[ -n "$INSTANCE" && -n "$ORG_URL" ]]; then
    setup_instance "$INSTANCE" "$ORG_URL"
elif [[ -n "$INSTANCE" || -n "$ORG_URL" ]]; then
    echo "Error: Both --instance and --org are required when using arguments"
    echo
    show_help
    exit 1
else
    interactive_mode
fi
