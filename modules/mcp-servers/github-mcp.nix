# GitHub MCP server configuration (multi-instance support)
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.claude-code.mcp.github;
  containerCmd = config.programs.claude-code.containerCommand;

  # Build args list for a specific instance
  mkContainerArgs = instanceCfg: [
    "run"
    "-i"
    "--rm"
    "-e"
    instanceCfg.patEnvVar
  ] ++ optionals (instanceCfg.host != null) [
    "-e"
    "GITHUB_HOST=${instanceCfg.host}"
  ] ++ [
    instanceCfg.image
  ] ++ optionals (instanceCfg.toolsets != []) [
    "--toolsets"
    (concatStringsSep "," instanceCfg.toolsets)
  ];

  # Generate pre-pull script for a specific instance
  mkPullScript = name: instanceCfg: pkgs.writeShellScript "pull-github-mcp-image-${name}" ''
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
      enable = mkEnableOption "this GitHub MCP server instance";

      image = mkOption {
        type = types.str;
        default = "ghcr.io/github/github-mcp-server@sha256:1687680e9297b465b398c0143a0072bbd96e3d6fd466cc04638943c8a439c0c9";
        description = ''
          Docker image for the GitHub MCP server.
          Pinned to a specific digest for reproducibility.
        '';
      };

      patEnvVar = mkOption {
        type = types.str;
        default = "GITHUB_PAT_${strings.toUpper (replaceStrings ["-"] ["_"] name)}";
        defaultText = literalExpression ''"GITHUB_PAT_''${toUpper instanceName}"'';
        example = "GITHUB_PAT_WORK";
        description = "Environment variable name containing the PAT for this instance";
      };

      host = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "https://github.mycompany.com";
        description = ''
          GitHub host URL for GitHub Enterprise Server.
          Leave null for github.com.
        '';
      };

      toolsets = mkOption {
        type = types.listOf (types.enum [
          "repos"
          "issues"
          "pull_requests"
          "actions"
          "code_security"
          "experiments"
          "users"
        ]);
        default = [];
        example = [ "repos" "issues" "pull_requests" ];
        description = ''
          Limit available toolsets. Empty list means all tools.
          Available: repos, issues, pull_requests, actions, code_security, experiments, users
        '';
      };

      prePull = mkOption {
        type = types.bool;
        default = true;
        description = "Pre-pull the Docker image during home-manager activation";
      };
    };
  });

  # Filter to only enabled instances
  enabledInstances = filterAttrs (name: inst: inst.enable) cfg.instances;
  hasEnabledInstances = enabledInstances != { };

in
{
  options.programs.claude-code.mcp.github = {
    instances = mkOption {
      type = types.attrsOf instanceModule;
      default = { };
      example = literalExpression ''
        {
          personal = {
            enable = true;
            # patEnvVar defaults to "GITHUB_PAT_PERSONAL"
          };
          work-ghe = {
            enable = true;
            host = "https://github.mycompany.com";
            patEnvVar = "GH_PAT_WORK";
            toolsets = [ "repos" "issues" "pull_requests" ];
          };
        }
      '';
      description = ''
        GitHub MCP server instances. Each attribute defines a separate
        MCP server instance with its own host and PAT.
        The attribute name becomes part of the MCP server name (e.g., "personal" -> "github-mcp-personal").
      '';
    };

    installGhCli = mkOption {
      type = types.bool;
      default = true;
      description = "Install GitHub CLI (gh) for PAT management";
    };
  };

  config = mkIf hasEnabledInstances {
    # Install gh CLI if requested (global, not per-instance)
    home.packages = mkIf cfg.installGhCli [ pkgs.gh ];

    # MCP server config fragments - one per enabled instance
    programs.claude-code._mcpServers = mapAttrs' (name: instanceCfg:
      nameValuePair "github-mcp-${name}" {
        type = "stdio";
        command = containerCmd;
        args = mkContainerArgs instanceCfg;
        env = { };
      }
    ) enabledInstances;

    # Pre-pull images during activation - one script per enabled instance that wants pre-pull
    home.activation = mapAttrs' (name: instanceCfg:
      nameValuePair "pullGithubMcpImage-${name}" (
        mkIf instanceCfg.prePull (
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            $DRY_RUN_CMD ${mkPullScript name instanceCfg}
          ''
        )
      )
    ) enabledInstances;
  };
}
