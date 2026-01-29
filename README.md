# nix-mcp-setup

Nix module for running MCP (Model Context Protocol) servers as Docker containers.

## Overview

This project provides a Nix module to manage and run MCP servers. Instead of installing MCP servers directly on the host machine, each server runs in its own Docker container.

## Design Principles

- **Docker-based**: All MCP servers run as Docker containers
- **Isolated**: Each MCP server has its own dedicated Docker image
- **Declarative**: Configured via Nix module system
- **No host installation**: MCP servers are not installed on the host computer

## MCP Servers

| Server | Docker Image | Status |
|--------|--------------|--------|
| Azure DevOps | `ghcr.io/metorial/mcp-container--vortiago--mcp-azure-devops--mcp-azure-devops` | Tested |
| GitHub | `ghcr.io/github/github-mcp-server` | Planned |
| Context7 | Docker MCP Catalog | Planned |

## Quick Start

### Prerequisites

- Docker (or Rancher Desktop with Docker CLI)
- PowerShell (`pwsh`)
- Azure CLI (`az`)

### 1. Generate ADO PAT

Login to Azure and generate a scoped PAT:

```bash
az login
./scripts/create-ado-pat.ps1
```

PAT settings:
- Scopes: `vso.work vso.code vso.build`
- Expiry: 7 days

### 2. Test MCP Server

```bash
docker run -i --rm \
  -e AZURE_DEVOPS_PAT="<your-pat>" \
  -e AZURE_DEVOPS_ORGANIZATION_URL="https://dev.azure.com/<your-org>" \
  ghcr.io/metorial/mcp-container--vortiago--mcp-azure-devops--mcp-azure-devops \
  mcp-azure-devops
```

### 3. Configure Claude Code

Add to `~/.claude.json` under the `mcpServers` key:

```json
{
  "mcpServers": {
    "ado-mcp": {
      "type": "stdio",
      "command": "docker",
      "args": [
        "run", "-i", "--rm",
        "-e", "AZURE_DEVOPS_PAT",
        "-e", "AZURE_DEVOPS_ORGANIZATION_URL",
        "ghcr.io/metorial/mcp-container--vortiago--mcp-azure-devops--mcp-azure-devops",
        "mcp-azure-devops"
      ],
      "env": {
        "AZURE_DEVOPS_PAT": "<your-pat>",
        "AZURE_DEVOPS_ORGANIZATION_URL": "https://dev.azure.com/<your-org>"
      }
    }
  }
}
```

Verify with:

```bash
claude mcp list
```

**Note:** Restart Claude Code after config changes.

## Target Environment

**Current:** macOS + Rancher Desktop (Docker CLI)

**Future:** Linux (Docker/Podman), Windows (WSL2)

## Project Structure

```
nix-mcp-setup/
├── README.md
├── scripts/
│   └── create-ado-pat.ps1    # Generate scoped PAT via az cli
└── docs/
    └── ROADMAP.md            # Implementation phases
```

## Roadmap

See [docs/ROADMAP.md](docs/ROADMAP.md) for implementation phases.

## License

MIT
