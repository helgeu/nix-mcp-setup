# Main Home Manager module for Claude Code
{ claude-code-nix }:

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.claude-code;

  # Convert attrset to JSON for ~/.claude.json
  claudeConfig = {
    mcpServers = cfg._mcpServers;
  };

  claudeConfigJson = pkgs.writeText "claude.json" (builtins.toJSON claudeConfig);
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
      default = claude-code-nix.packages.${pkgs.system}.default;
      description = "The Claude Code package to install";
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
    ];

    # Generate ~/.claude.json with MCP servers
    home.file.".claude.json" = mkIf (cfg._mcpServers != { }) {
      source = claudeConfigJson;
    };
  };
}
