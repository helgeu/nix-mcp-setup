{
  description = "Nix module for Claude Code with MCP servers and plugins";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, claude-code-nix, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      # Home Manager module
      homeManagerModules = {
        default = self.homeManagerModules.claude-code;
        claude-code = import ./modules/home-manager.nix {
          inherit claude-code-nix;
        };
      };

      # Packages (for standalone use: nix profile install)
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = claude-code-nix.packages.${system}.default;
          claude-code = claude-code-nix.packages.${system}.default;
        }
      );

      # Dev shell for working on this repo
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              bun
              uv
              nodejs_20
            ];
          };
        }
      );
    };
}
