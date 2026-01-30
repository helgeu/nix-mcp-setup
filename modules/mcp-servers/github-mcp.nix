# GitHub MCP server configuration
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.claude-code.mcp.github;
  containerCmd = config.programs.claude-code.containerCommand;

  # Build args list
  containerArgs = [
    "run"
    "-i"
    "--rm"
    "-e"
    cfg.patEnvVar
  ] ++ optionals (cfg.host != null) [
    "-e"
    "GITHUB_HOST=${cfg.host}"
  ] ++ [
    cfg.image
  ] ++ optionals (cfg.toolsets != []) [
    "--toolsets"
    (concatStringsSep "," cfg.toolsets)
  ];

  # Pre-pull script
  pullScript = pkgs.writeShellScript "pull-github-mcp-image" ''
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
  options.programs.claude-code.mcp.github = {
    enable = mkEnableOption "GitHub MCP server";

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
      default = "GITHUB_PERSONAL_ACCESS_TOKEN";
      description = "Environment variable name containing the PAT";
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

    serverName = mkOption {
      type = types.str;
      default = "github-mcp";
      description = "Name for this MCP server in Claude config";
    };

    prePull = mkOption {
      type = types.bool;
      default = true;
      description = "Pre-pull the Docker image during home-manager activation";
    };

    installGhCli = mkOption {
      type = types.bool;
      default = true;
      description = "Install GitHub CLI (gh) for PAT management";
    };
  };

  config = mkIf cfg.enable {
    # Install gh CLI if requested
    home.packages = mkIf cfg.installGhCli [ pkgs.gh ];
    # MCP server config fragment - consumed by home-manager.nix
    programs.claude-code._mcpServers.${cfg.serverName} = {
      type = "stdio";
      command = containerCmd;
      args = containerArgs;
      env = { };
    };

    # Pre-pull image during activation
    home.activation.pullGithubMcpImage = mkIf cfg.prePull (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ${pullScript}
      ''
    );
  };
}
