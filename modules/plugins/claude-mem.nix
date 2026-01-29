# claude-mem plugin configuration
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.claude-code.plugins.claude-mem;

  setupScript = pkgs.writeShellScript "setup-claude-mem" ''
    set -e

    # Check if claude is available
    if ! command -v claude &> /dev/null; then
      echo "Error: claude command not found"
      exit 1
    fi

    # Check if plugin is already installed
    if claude plugin list 2>/dev/null | grep -q "claude-mem"; then
      echo "claude-mem plugin already installed"
      exit 0
    fi

    echo "Installing claude-mem plugin..."

    # Add from marketplace
    claude plugin marketplace add thedotmack/claude-mem

    # Install the plugin
    claude plugin install claude-mem

    echo "claude-mem plugin installed successfully"
  '';
in
{
  options.programs.claude-code.plugins.claude-mem = {
    enable = mkEnableOption "claude-mem plugin for persistent memory";
  };

  config = mkIf cfg.enable {
    # Run plugin setup on activation
    home.activation.setupClaudeMem = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${setupScript}
    '';
  };
}
