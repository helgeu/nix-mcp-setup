# Azure DevOps MCP server configuration
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.claude-code.mcp.azure-devops;
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
      default = "ghcr.io/metorial/mcp-container--vortiago--mcp-azure-devops--mcp-azure-devops";
      description = "Docker image for the ADO MCP server";
    };

    patEnvVar = mkOption {
      type = types.str;
      default = "AZURE_DEVOPS_PAT";
      description = "Environment variable name containing the PAT";
    };
  };

  config = mkIf cfg.enable {
    # MCP server config fragment - consumed by home-manager.nix
    programs.claude-code._mcpServers.ado-mcp = {
      type = "stdio";
      command = "docker";
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
  };
}
