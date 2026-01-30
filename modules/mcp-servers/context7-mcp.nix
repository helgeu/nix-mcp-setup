# Context7 MCP server configuration
# Provides up-to-date documentation for libraries and frameworks
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.claude-code.mcp.context7;
  containerCmd = config.programs.claude-code.containerCommand;

  # Pre-pull script
  pullScript = pkgs.writeShellScript "pull-context7-mcp-image" ''
    set -e
    IMAGE="${cfg.image}"

    # Check if container runtime is available
    if ! command -v ${containerCmd} &> /dev/null; then
      echo "Warning: ${containerCmd} not found, skipping image pull"
      exit 0
    fi

    # Check if image already exists
    if ${containerCmd} image inspect "$IMAGE" &> /dev/null; then
      echo "Image $IMAGE already present"
    else
      echo "Pulling $IMAGE..."
      ${containerCmd} pull "$IMAGE"
      echo "Done"
    fi
  '';
in
{
  options.programs.claude-code.mcp.context7 = {
    enable = mkEnableOption "Context7 MCP server for library documentation";

    image = mkOption {
      type = types.str;
      default = "mcp/context7@sha256:1174e6a29634a83b2be93ac1fefabf63265f498c02c72201fe3464e687dd8836";
      description = ''
        Docker image for the Context7 MCP server.
        Pinned to a specific digest for reproducibility.
      '';
    };

    serverName = mkOption {
      type = types.str;
      default = "context7-mcp";
      description = "Name for this MCP server in Claude config";
    };

    prePull = mkOption {
      type = types.bool;
      default = true;
      description = "Pre-pull the Docker image during home-manager activation";
    };
  };

  config = mkIf cfg.enable {
    # MCP server config fragment - consumed by home-manager.nix
    programs.claude-code._mcpServers.${cfg.serverName} = {
      type = "stdio";
      command = containerCmd;
      args = [
        "run"
        "-i"
        "--rm"
        "-e"
        "MCP_TRANSPORT=stdio"
        cfg.image
      ];
      env = { };
    };

    # Pre-pull image during activation
    home.activation.pullContext7McpImage = mkIf cfg.prePull (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ${pullScript}
      ''
    );
  };
}
