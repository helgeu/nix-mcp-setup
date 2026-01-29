# Main Home Manager module for Claude Code
{ config, lib, pkgs, nix-mcp-setup ? null, ... }:

with lib;

let
  cfg = config.programs.claude-code;
  hasMcpServers = cfg._mcpServers != { };

  # Build the mcpServers JSON fragment
  mcpServersJson = builtins.toJSON { mcpServers = cfg._mcpServers; };

  # Script to merge MCP servers into existing ~/.claude.json
  mergeScript = pkgs.writeShellScript "merge-claude-config" ''
    set -e
    CLAUDE_JSON="$HOME/.claude.json"
    MCP_FRAGMENT='${mcpServersJson}'

    if [ -f "$CLAUDE_JSON" ]; then
      # Merge: existing config + our mcpServers (our mcpServers take precedence)
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$CLAUDE_JSON" <(echo "$MCP_FRAGMENT") > "$CLAUDE_JSON.tmp"
      mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
      echo "Merged MCP servers into $CLAUDE_JSON"
    else
      # No existing file, create new one
      echo "$MCP_FRAGMENT" | ${pkgs.jq}/bin/jq '.' > "$CLAUDE_JSON"
      echo "Created $CLAUDE_JSON"
    fi
  '';

  # Script to validate container runtime
  validateContainerScript = pkgs.writeShellScript "validate-container-runtime" ''
    if ! command -v ${cfg.containerCommand} &> /dev/null; then
      echo ""
      echo "WARNING: Container runtime '${cfg.containerCommand}' not found!"
      echo "MCP servers require a container runtime to function."
      echo ""
      echo "Install one of:"
      echo "  - Docker Desktop: https://www.docker.com/products/docker-desktop"
      echo "  - Rancher Desktop: https://rancherdesktop.io"
      echo "  - Colima: brew install colima && colima start"
      echo "  - Podman: set containerCommand = \"podman\""
      echo ""
    else
      echo "Container runtime '${cfg.containerCommand}' found: $(command -v ${cfg.containerCommand})"
    fi
  '';
in
{
  imports = [
    ./mcp-servers/azure-devops.nix
    ./plugins/claude-mem.nix
  ];

  options.programs.claude-code = {
    enable = mkEnableOption "Claude Code CLI with MCP servers and plugins";

    package = mkOption {
      type = types.package;
      default =
        if nix-mcp-setup != null
        then nix-mcp-setup.packages.${pkgs.system}.default
        else throw "programs.claude-code.package must be set, or pass nix-mcp-setup via extraSpecialArgs";
      defaultText = literalExpression "nix-mcp-setup.packages.\${pkgs.system}.default";
      description = "The Claude Code package to install";
    };

    containerCommand = mkOption {
      type = types.str;
      default = "docker";
      example = "podman";
      description = "Container runtime command for MCP servers";
    };

    validateContainerRuntime = mkOption {
      type = types.bool;
      default = true;
      description = "Check if container runtime is available during activation";
    };

    # Internal option to collect MCP server configs from submodules
    _mcpServers = mkOption {
      type = types.attrsOf types.attrs;
      default = { };
      internal = true;
      description = "Internal: collected MCP server configurations";
    };
  };

  config = mkIf cfg.enable {
    # Install Claude Code and dependencies
    home.packages = [
      cfg.package
      pkgs.bun       # Required for claude-mem plugin
      pkgs.uv        # Required for claude-mem (uvx for Chroma)
      pkgs.nodejs_20 # Required for plugin scripts
      pkgs.jq        # Required for config merging
    ];

    # Validate container runtime during activation
    home.activation.validateContainerRuntime = mkIf (hasMcpServers && cfg.validateContainerRuntime) (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ${validateContainerScript}
      ''
    );

    # Merge MCP servers into ~/.claude.json on activation
    home.activation.mergeMcpServers = mkIf hasMcpServers (
      lib.hm.dag.entryAfter [ "writeBoundary" "validateContainerRuntime" ] ''
        $DRY_RUN_CMD ${mergeScript}
      ''
    );
  };
}
