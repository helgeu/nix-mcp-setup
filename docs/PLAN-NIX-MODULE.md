# Plan: Nix Module for MCP Servers + Claude Code

## Goal

Create a Nix flake that:
1. Installs Claude Code and all dependencies (bun, uv, nodejs)
2. Configures ADO MCP server (Docker-based)
3. Installs and configures claude-mem plugin
4. Exposes as both standalone flake and Home Manager module

## Scope (Phase 1)

| Component | Included |
|-----------|----------|
| Claude Code CLI | ✅ |
| Dependencies (bun, uv, nodejs) | ✅ |
| ADO MCP server | ✅ |
| claude-mem plugin | ✅ |
| GitHub MCP | ❌ Later |
| Context7 MCP | ❌ Later |

## Prerequisites

**Docker is required.** This module assumes the user has a working Docker CLI (`docker` command available). Compatible runtimes:
- Docker Desktop
- Rancher Desktop (Docker CLI mode)
- Podman with Docker CLI compatibility
- Colima

> **Note:** Future versions may add a `containerCommand` option to support alternative CLIs (podman, nerdctl). For now, we use `docker` directly.

## Claude Code Installation

We use [sadjow/claude-code-nix](https://github.com/sadjow/claude-code-nix) as an input:
- Hourly updates to latest Claude Code version
- Native binary (~180MB, no runtime deps)
- Cachix binary cache for fast installs

```nix
inputs.claude-code-nix.url = "github:sadjow/claude-code-nix";
```

## File Structure

```
nix-mcp-setup/
├── flake.nix                    # Main entry point
├── flake.lock
├── modules/
│   ├── home-manager.nix         # Home Manager module (main)
│   ├── claude-code.nix          # Claude Code + dependencies
│   ├── mcp-servers/
│   │   ├── default.nix          # MCP server base
│   │   └── azure-devops.nix     # ADO MCP config
│   └── plugins/
│       └── claude-mem.nix       # claude-mem plugin
├── lib/
│   └── mk-mcp-config.nix        # Helper to generate mcpServers JSON
├── scripts/
│   ├── create-ado-pat.ps1       # (existing) Generate ADO PAT
│   └── setup-claude-plugins.sh  # Plugin install script
├── examples/
│   └── claude.json              # Example mcpServers config
└── docs/
    └── ...
```

## Module Options

### Top-level: `programs.claude-code`

```nix
programs.claude-code = {
  enable = true;

  # MCP Servers
  mcp.azure-devops = {
    enable = true;
    organizationUrl = "https://dev.azure.com/myorg";
    # PAT via AZURE_DEVOPS_PAT env var
  };

  # Plugins
  plugins.claude-mem = {
    enable = true;
  };
};
```

### What Gets Installed

When `programs.claude-code.enable = true`:

| Package | Source | Purpose |
|---------|--------|---------|
| `claude-code` | nixpkgs or overlay | Claude Code CLI |
| `bun` | nixpkgs | claude-mem runtime |
| `uv` | nixpkgs | Chroma vector DB (uvx) |
| `nodejs_20` | nixpkgs | Plugin scripts |
| `docker` | (user provides) | MCP container runtime |

### What Gets Generated

1. **`~/.claude.json`** - MCP server configuration:
   ```json
   {
     "mcpServers": {
       "ado-mcp": {
         "type": "stdio",
         "command": "docker",
         "args": ["run", "-i", "--rm", "-e", "AZURE_DEVOPS_PAT", "-e", "AZURE_DEVOPS_ORGANIZATION_URL", "ghcr.io/metorial/mcp-container--vortiago--mcp-azure-devops--mcp-azure-devops", "mcp-azure-devops"],
         "env": {
           "AZURE_DEVOPS_ORGANIZATION_URL": "<configured-url>"
         }
       }
     }
   }
   ```

2. **Activation script** - Runs on `home-manager switch`:
   ```bash
   # Install claude-mem plugin if not present
   if ! claude plugin list | grep -q claude-mem; then
     claude plugin marketplace add thedotmack/claude-mem
     claude plugin install claude-mem
   fi
   ```

## Implementation Steps

### Step 1: Create flake.nix
- Define inputs (nixpkgs, home-manager)
- Expose `homeManagerModules.default`
- Expose `packages.x86_64-darwin.default` (for standalone use)

### Step 2: Create modules/claude-code.nix
- Package installation (claude, bun, uv, nodejs)
- Option definitions

### Step 3: Create modules/mcp-servers/azure-devops.nix
- ADO-specific options
- Generate mcpServers config fragment

### Step 4: Create modules/plugins/claude-mem.nix
- Plugin options
- Activation script for plugin install

### Step 5: Create modules/home-manager.nix
- Import all submodules
- Merge MCP configs into `~/.claude.json`
- Register activation scripts

### Step 6: Create scripts/setup-claude-plugins.sh
- Idempotent plugin installation
- Called by activation script

## Usage Examples

### As Home Manager Module

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager";
    nix-mcp-setup.url = "github:youruser/nix-mcp-setup";
  };

  outputs = { self, nixpkgs, home-manager, nix-mcp-setup, ... }: {
    homeConfigurations."user" = home-manager.lib.homeManagerConfiguration {
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

### Standalone (just packages)

```bash
nix profile install github:youruser/nix-mcp-setup
```

## Decisions Made

| Question | Decision |
|----------|----------|
| Claude Code source | Use `sadjow/claude-code-nix` flake input |
| Config merge | Phase 1: Generate full `~/.claude.json` with mcpServers only. User's other settings managed separately. |
| Docker dependency | Assume user has Docker CLI. Document requirement. |

## Open Questions

1. **Config merge strategy** - For Phase 2: How to merge mcpServers into existing `~/.claude.json` without clobbering user settings?

## Next Steps

1. [ ] Create flake.nix with claude-code-nix input
2. [ ] Implement claude-code.nix module (packages only)
3. [ ] Implement azure-devops.nix module (hardcoded for now)
4. [ ] Implement claude-mem.nix module (hardcoded for now)
5. [ ] Create setup-claude-plugins.sh script
6. [ ] Test with home-manager switch
7. [ ] Document usage

---

*Created: 2025-01-29*
