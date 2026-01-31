# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Nix Flake that declaratively configures Claude Code CLI with MCP servers and plugins via Home Manager. It manages `~/.claude.json` configuration and Docker image lifecycle through activation scripts.

## Development Commands

```bash
# Enter dev shell (provides bun, uv, nodejs)
nix develop

# Show available flake outputs
nix flake show

# Test build without applying
home-manager build --flake .#<config-name>

# Apply configuration
home-manager switch --flake .#<config-name>

# Verify installation
claude --version
claude mcp list
cat ~/.claude.json | jq '.mcpServers'
```

## Architecture

```
flake.nix                           # Exposes 3 outputs: homeManagerModules,
                                    # homeManagerModulesWithPackage, packages
    │
    └── modules/
        ├── home-manager.nix        # Main orchestrator - imports submodules,
        │                           # manages packages, runs activation scripts
        │
        ├── mcp-servers/
        │   ├── azure-devops-mcp.nix   # ADO MCP server config (multi-instance)
        │   ├── github-mcp.nix         # GitHub MCP server config (GHE support)
        │   └── context7-mcp.nix       # Context7 MCP server config
        │
        └── plugins/
            └── claude-mem.nix      # Optional plugin (enable explicitly)
```

**Key Design Patterns:**

1. **Module Composition**: Each MCP server is a separate module that contributes to the internal `_mcpServers` option
2. **Configuration Merging**: Activation script merges MCP configs into existing `~/.claude.json` using `jq -s '.[0] * .[1]'`
3. **Reproducibility**: Docker images pinned to SHA256 digests, not tags
4. **Container Abstraction**: `containerCommand` option supports docker/podman/nerdctl

**Activation Order (DAG):**
```
writeBoundary → validateContainerRuntime → [image pre-pulls] → mergeMcpServers
```

## Module Option Patterns

**Simple module** (single instance):
```nix
{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.programs.claude-code.<component>;
in
{
  options.programs.claude-code.<component> = {
    enable = mkEnableOption "description";
    # ... other options with type, default, description
  };

  config = mkIf cfg.enable {
    # Contribute to _mcpServers, add activation scripts, etc.
  };
}
```

**Multi-instance module** (e.g., azure-devops-mcp.nix):
```nix
# Uses types.attrsOf (types.submodule {...}) for named instances
options.programs.claude-code.mcp.azure-devops = mkOption {
  type = types.attrsOf instanceModule;  # Each attr is an instance
  default = { };
};

# Filter enabled instances, generate config per instance
enabledInstances = filterAttrs (name: inst: inst.enable) cfg;
programs.claude-code._mcpServers = mapAttrs' (name: instanceCfg:
  nameValuePair "ado-mcp-${name}" { ... }
) enabledInstances;
```

## Git Workflow

- **Main branch**: `master`
- **Branch naming**: `feat/*`, `fix/*`
- **Commit style**: Conventional commits (`feat:`, `fix:`, `docs:`)

## Environment Variables

MCP servers expect PATs from environment (not config):
- `AZURE_DEVOPS_PAT_<INSTANCE>` - Azure DevOps PAT (e.g., `AZURE_DEVOPS_PAT_WORK` for instance "work")
- `GITHUB_PERSONAL_ACCESS_TOKEN` - GitHub PAT

Helper scripts in `scripts/` guide PAT setup:
- `./scripts/create-ado-pat.sh` - Interactive multi-instance ADO PAT setup
- `./scripts/create-github-pat.sh` - GitHub PAT setup
