# nix-mcp-setup

Nix flake for Claude Code with MCP servers and plugins.

## What This Does

- Installs Claude Code CLI via [claude-code-nix](https://github.com/sadjow/claude-code-nix)
- Installs dependencies: bun, uv, nodejs, jq
- Configures MCP servers (Azure DevOps) - merges into existing `~/.claude.json`
- Installs plugins (claude-mem)

## Prerequisites

- **Nix** with flakes enabled
- **Docker** CLI available (`docker` command)
  - Docker Desktop, Rancher Desktop, Colima, or Podman with Docker CLI

## Quick Start

### Option 1: Simple (Recommended)

Use the pre-configured module that includes the Claude Code package:

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
        # Use system-specific module with package included
        nix-mcp-setup.homeManagerModulesWithPackage.aarch64-darwin.default
        {
          programs.claude-code = {
            enable = true;
            mcp.azure-devops.work = {
              enable = true;
              organizationUrl = "https://dev.azure.com/myorg";
            };
            # plugins.claude-mem.enable = true;  # Optional
          };
        }
      ];
    };
  };
}
```

### Option 2: With extraSpecialArgs

For more control, pass the flake via `extraSpecialArgs`:

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
      extraSpecialArgs = {
        inherit nix-mcp-setup;
      };
      modules = [
        nix-mcp-setup.homeManagerModules.default
        {
          programs.claude-code = {
            enable = true;
            mcp.azure-devops.work = {
              enable = true;
              organizationUrl = "https://dev.azure.com/myorg";
            };
            # plugins.claude-mem.enable = true;  # Optional
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

### Option 3: Standalone Installation

Install Claude Code only (no MCP config):

```bash
nix profile install github:helgeu/nix-mcp-setup
```

## Module Options

### `programs.claude-code`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable Claude Code |
| `package` | package | claude-code | Claude Code package |
| `containerCommand` | string | `"docker"` | Container runtime (`docker`, `podman`, etc.) |
| `validateContainerRuntime` | bool | `true` | Warn if container runtime not found |

### `programs.claude-code.mcp.azure-devops.<name>`

Multiple Azure DevOps instances can be configured. Each `<name>` becomes part of the MCP server name (e.g., `work` → `ado-mcp-work`).

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable this ADO MCP server instance |
| `organizationUrl` | string | required | ADO organization URL |
| `image` | string | pinned digest | Docker image (pinned for reproducibility) |
| `patEnvVar` | string | `"AZURE_DEVOPS_PAT_<NAME>"` | PAT environment variable (auto-generated from instance name) |
| `prePull` | bool | `true` | Pre-pull image during activation |

Example with multiple instances:

```nix
programs.claude-code.mcp.azure-devops = {
  work = {
    enable = true;
    organizationUrl = "https://dev.azure.com/work-org";
    # patEnvVar defaults to "AZURE_DEVOPS_PAT_WORK"
  };
  client-acme = {
    enable = true;
    organizationUrl = "https://dev.azure.com/acme-corp";
    patEnvVar = "ADO_PAT_ACME";  # Override default
  };
};
```

### `programs.claude-code.mcp.github`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable GitHub MCP server |
| `image` | string | pinned digest | Docker image (pinned for reproducibility) |
| `patEnvVar` | string | `"GITHUB_PERSONAL_ACCESS_TOKEN"` | PAT environment variable |
| `host` | string | `null` | GitHub Enterprise host URL (null for github.com) |
| `toolsets` | list | `[]` | Limit tools: repos, issues, pull_requests, actions, etc. |
| `serverName` | string | `"github-mcp"` | MCP server name in config |
| `prePull` | bool | `true` | Pre-pull image during activation |
| `installGhCli` | bool | `true` | Install GitHub CLI (gh) for PAT management |

### `programs.claude-code.mcp.context7`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable Context7 MCP server |
| `image` | string | pinned digest | Docker image (pinned for reproducibility) |
| `serverName` | string | `"context7-mcp"` | MCP server name in config |
| `prePull` | bool | `true` | Pre-pull image during activation |

### `programs.claude-code.plugins.claude-mem`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable claude-mem plugin |
| `autoInstall` | bool | `true` | Auto-install on activation |

## Configuration

### Azure DevOps PAT

Set PATs as environment variables (one per instance):

```bash
# For instance "work" → env var AZURE_DEVOPS_PAT_WORK
export AZURE_DEVOPS_PAT_WORK="your-work-pat"
export AZURE_DEVOPS_PAT_CLIENT_ACME="your-acme-pat"
```

Use the helper script to set up PATs:

```bash
# Interactive mode
./scripts/create-ado-pat.sh

# Or specify instance directly
./scripts/create-ado-pat.sh --instance work --org "https://dev.azure.com/work-org"
```

### GitHub PAT

Set the PAT as an environment variable:

```bash
export GITHUB_PERSONAL_ACCESS_TOKEN="your-pat-here"
```

Generate a PAT with the helper script:

```bash
./scripts/create-github-pat.sh
```

Or create manually at: https://github.com/settings/tokens

### Existing ~/.claude.json

The module **merges** MCP servers into your existing `~/.claude.json`. It won't overwrite your other settings.

### Manual Plugin Install

If `autoInstall = false`, install manually:

```bash
./scripts/setup-claude-plugins.sh claude-mem
```

### Updating Docker Images

Docker images are pinned by digest for reproducibility. To update to latest:

```bash
# Pull latest and get new digest
docker pull ghcr.io/metorial/mcp-container--vortiago--mcp-azure-devops--mcp-azure-devops:latest
docker inspect ghcr.io/metorial/mcp-container--vortiago--mcp-azure-devops--mcp-azure-devops:latest \
  --format='{{index .RepoDigests 0}}'

# Use the output in your config:
mcp.azure-devops.image = "ghcr.io/...@sha256:abc123...";
```

## MCP Servers

| Server | Docker Image | Status |
|--------|--------------|--------|
| Azure DevOps | `ghcr.io/metorial/mcp-container--vortiago--mcp-azure-devops--mcp-azure-devops` | ✅ Implemented |
| GitHub | `ghcr.io/github/github-mcp-server` | ✅ Implemented |
| Context7 | `mcp/context7` | ✅ Implemented |

## Project Structure

```
nix-mcp-setup/
├── flake.nix                    # Main entry point
├── modules/
│   ├── home-manager.nix         # Home Manager module
│   ├── mcp-servers/
│   │   ├── azure-devops-mcp.nix # ADO MCP config
│   │   ├── github-mcp.nix       # GitHub MCP config
│   │   └── context7-mcp.nix     # Context7 MCP config
│   └── plugins/
│       └── claude-mem.nix       # claude-mem plugin
├── scripts/
│   ├── create-ado-pat.sh        # Generate ADO PAT (multi-instance)
│   ├── create-ado-pat.ps1       # Generate ADO PAT (PowerShell, legacy)
│   ├── create-github-pat.sh     # Generate GitHub PAT
│   └── setup-claude-plugins.sh  # Manual plugin install
├── examples/
│   └── claude.json              # Example config
└── docs/
    ├── ROADMAP.md
    ├── PLAN-NIX-MODULE.md
    └── PLUGIN-DEPENDENCIES.md
```

## Testing

Create a test directory and flake:

```bash
mkdir /tmp/nix-mcp-test && cd /tmp/nix-mcp-test
```

Create `flake.nix` (see examples/test-flake.nix), then:

```bash
# Dry run - see what would be generated
home-manager build --flake .#test

# Check generated config
cat result/home-path/etc/profile.d/hm-session-vars.sh

# Actually apply (modifies your home)
home-manager switch --flake .#test
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

# Check config was merged
cat ~/.claude.json | jq '.mcpServers'
```

## License

MIT
