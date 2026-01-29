# nix-mcp-setup

Nix flake for Claude Code with MCP servers and plugins.

## What This Does

- Installs Claude Code CLI via [claude-code-nix](https://github.com/sadjow/claude-code-nix)
- Installs dependencies: bun, uv, nodejs
- Configures MCP servers (Azure DevOps)
- Installs plugins (claude-mem)

## Prerequisites

- **Nix** with flakes enabled
- **Docker** CLI available (`docker` command)
  - Docker Desktop, Rancher Desktop, Colima, or Podman with Docker CLI

## Quick Start

### Option 1: Home Manager Module

Add to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    nix-mcp-setup.url = "github:helgeu/nix-mcp-setup";
  };

  outputs = { nixpkgs, home-manager, nix-mcp-setup, ... }: {
    homeConfigurations."youruser" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
      modules = [
        nix-mcp-setup.homeManagerModules.default
        {
          programs.claude-code = {
            enable = true;
            mcp.azure-devops = {
              enable = true;
              organizationUrl = "https://dev.azure.com/myorg";
            };
            plugins.claude-mem.enable = true;
          };
        }
      ];
    };
  };
}
```

Then run:

```bash
home-manager switch
```

### Option 2: Standalone Installation

Install Claude Code only:

```bash
nix profile install github:helgeu/nix-mcp-setup
```

Then manually configure MCP servers and plugins.

## Configuration

### Azure DevOps MCP

The module generates `~/.claude.json` with MCP server config. You need to set the PAT as an environment variable:

```bash
export AZURE_DEVOPS_PAT="your-pat-here"
```

Generate a PAT with:

```bash
az login
./scripts/create-ado-pat.ps1
```

### claude-mem Plugin

When `plugins.claude-mem.enable = true`, the plugin is installed automatically on `home-manager switch`.

To install manually:

```bash
./scripts/setup-claude-plugins.sh claude-mem
```

## MCP Servers

| Server | Docker Image | Status |
|--------|--------------|--------|
| Azure DevOps | `ghcr.io/metorial/mcp-container--vortiago--mcp-azure-devops--mcp-azure-devops` | ✅ Implemented |
| GitHub | `ghcr.io/github/github-mcp-server` | Planned |
| Context7 | Docker MCP Catalog | Planned |

## Project Structure

```
nix-mcp-setup/
├── flake.nix                    # Main entry point
├── modules/
│   ├── home-manager.nix         # Home Manager module
│   ├── mcp-servers/
│   │   └── azure-devops.nix     # ADO MCP config
│   └── plugins/
│       └── claude-mem.nix       # claude-mem plugin
├── scripts/
│   ├── create-ado-pat.ps1       # Generate ADO PAT
│   └── setup-claude-plugins.sh  # Manual plugin install
├── examples/
│   └── claude.json              # Example config
└── docs/
    ├── ROADMAP.md
    ├── PLAN-NIX-MODULE.md
    └── PLUGIN-DEPENDENCIES.md
```

## Verification

After setup:

```bash
# Check Claude Code
claude --version

# Check MCP servers
claude mcp list

# Check plugins
claude plugin list
```

## License

MIT
