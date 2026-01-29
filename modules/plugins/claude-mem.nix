# claude-mem plugin configuration
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.claude-code.plugins.claude-mem;

  setupScript = pkgs.writeShellScript "setup-claude-mem" ''
    set -e

    # Check if claude is available
    if ! command -v claude &> /dev/null; then
      echo "Warning: claude command not found, skipping plugin install"
      exit 0
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

    autoInstall = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Automatically install the plugin on home-manager activation.
        Set to false to install manually with: ./scripts/setup-claude-plugins.sh claude-mem
      '';
    };
  };

  config = mkIf cfg.enable {
    # Run plugin setup on activation (if autoInstall is enabled)
    home.activation.setupClaudeMem = mkIf cfg.autoInstall (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ${setupScript}
      ''
    );
  };
}
