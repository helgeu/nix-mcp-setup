# Azure DevOps MCP server configuration (multi-instance support)
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.claude-code.mcp.azure-devops;
  containerCmd = config.programs.claude-code.containerCommand;

  # Generate pre-pull script for a specific instance
  mkPullScript = name: instanceCfg: pkgs.writeShellScript "pull-ado-mcp-image-${name}" ''
    set -e
    IMAGE="${instanceCfg.image}"

    # Check if container runtime is available
    if ! command -v ${containerCmd} &> /dev/null; then
      echo "Warning: ${containerCmd} not found, skipping image pull for ${name}"
      exit 0
    fi

    # Check if image already exists
    if ${containerCmd} image inspect "$IMAGE" &> /dev/null; then
      echo "Image $IMAGE already present (${name})"
    else
      echo "Pulling $IMAGE for ${name}..."
      ${containerCmd} pull "$IMAGE"
      echo "Done"
    fi
  '';

  # Instance submodule options
  instanceModule = types.submodule ({ name, ... }: {
    options = {
      enable = mkEnableOption "this Azure DevOps MCP server instance";

      organization = mkOption {
        type = types.str;
        example = "myorg";
        description = "Azure DevOps organization name";
      };

      image = mkOption {
        type = types.str;
        default = "ghcr.io/helgeu/ado-mcp-docker-img:latest";
        description = "Docker image for the ADO MCP server.";
      };

      patEnvVar = mkOption {
        type = types.str;
        default = "AZURE_DEVOPS_PAT_${strings.toUpper (replaceStrings ["-"] ["_"] name)}";
        defaultText = literalExpression ''"AZURE_DEVOPS_PAT_''${toUpper instanceName}"'';
        example = "ADO_PAT_WORK";
        description = "Environment variable name containing the PAT for this instance";
      };

      prePull = mkOption {
        type = types.bool;
        default = true;
        description = "Pre-pull the Docker image during home-manager activation";
      };
    };
  });

  # Filter to only enabled instances
  enabledInstances = filterAttrs (name: inst: inst.enable) cfg;

in
{
  options.programs.claude-code.mcp.azure-devops = mkOption {
    type = types.attrsOf instanceModule;
    default = { };
    example = literalExpression ''
      {
        work = {
          enable = true;
          organization = "work-org";
        };
        client-acme = {
          enable = true;
          organization = "acme-corp";
          patEnvVar = "ADO_PAT_ACME";
        };
      }
    '';
    description = ''
      Azure DevOps MCP server instances. Each attribute defines a separate
      MCP server instance with its own organization and PAT.
      The attribute name becomes part of the MCP server name (e.g., "work" -> "ado-mcp-work").
    '';
  };

  config = mkIf (enabledInstances != { }) {
    # MCP server config fragments - one per enabled instance
    programs.claude-code._mcpServers = mapAttrs' (name: instanceCfg:
      nameValuePair "ado-mcp-${name}" {
        type = "stdio";
        command = containerCmd;
        args = [
          "run"
          "-i"
          "--rm"
          "-e"
          "ADO_ORG"
          "-e"
          "ADO_MCP_AUTH_TOKEN"
          instanceCfg.image
        ];
        env = {
          ADO_ORG = instanceCfg.organization;
          ADO_MCP_AUTH_TOKEN = "\${${instanceCfg.patEnvVar}}";
        };
      }
    ) enabledInstances;

    # Pre-pull images during activation - one script per enabled instance that wants pre-pull
    home.activation = mapAttrs' (name: instanceCfg:
      nameValuePair "pullAdoMcpImage-${name}" (
        mkIf instanceCfg.prePull (
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            $DRY_RUN_CMD ${mkPullScript name instanceCfg}
          ''
        )
      )
    ) enabledInstances;
  };
}
