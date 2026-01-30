# Azure DevOps MCP server configuration
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.claude-code.mcp.azure-devops;
  containerCmd = config.programs.claude-code.containerCommand;

  # Pre-pull script
  pullScript = pkgs.writeShellScript "pull-ado-mcp-image" ''
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
  options.programs.claude-code.mcp.azure-devops = {
    enable = mkEnableOption "Azure DevOps MCP server";

    organizationUrl = mkOption {
      type = types.str;
      example = "https://dev.azure.com/myorg";
      description = "Azure DevOps organization URL";
    };

    image = mkOption {
      type = types.str;
      default = "ghcr.io/metorial/mcp-container--vortiago--mcp-azure-devops--mcp-azure-devops@sha256:ee151edb4beefea283d0aa42634dedde24953f56aa5fc006896c5b4e6a25b739";
      description = ''
        Docker image for the ADO MCP server.
        Pinned to a specific digest for reproducibility.
        Use `docker pull <image>:latest && docker inspect <image>:latest --format='{{index .RepoDigests 0}}'` to get the latest digest.
      '';
    };

    patEnvVar = mkOption {
      type = types.str;
      default = "AZURE_DEVOPS_PAT";
      description = "Environment variable name containing the PAT";
    };

    serverName = mkOption {
      type = types.str;
      default = "ado-mcp";
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
        cfg.patEnvVar
        "-e"
        "AZURE_DEVOPS_ORGANIZATION_URL"
        cfg.image
        "mcp-azure-devops"
      ];
      env = {
        AZURE_DEVOPS_ORGANIZATION_URL = cfg.organizationUrl;
      };
    };

    # Pre-pull image during activation
    home.activation.pullAdoMcpImage = mkIf cfg.prePull (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ${pullScript}
      ''
    );
  };
}
