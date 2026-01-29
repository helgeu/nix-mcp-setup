# nix-mcp-setup Roadmap

High-level plan for implementing MCP servers as a Nix module with Docker containers.

---

## Target Environment

### Current (Phase 1)
- **OS:** macOS
- **Container runtime:** Rancher Desktop (Docker CLI compatible)
- **Nix:** nix-darwin + Home Manager

### Future Expansion
| Platform | Container Runtime | Nix Integration |
|----------|------------------|-----------------|
| Linux | Docker, Podman | NixOS modules, Home Manager |
| Windows | WSL2 + Docker/Rancher | Home Manager via WSL |

### Design Decision
Focus on macOS + Rancher Desktop first. Abstract container runtime behind a configurable option to ease future expansion:

```nix
services.mcp = {
  containerCommand = "docker";  # or "podman", "nerdctl", etc.
};
```

---

## MCP Servers to Implement

### 1. GitHub MCP Server
**Docker:** `ghcr.io/github/github-mcp-server`
**Source:** [github/github-mcp-server](https://github.com/github/github-mcp-server)
**Purpose:** Interact with GitHub - repositories, issues, PRs, code analysis, workflow automation
**Environment:**
- `GITHUB_TOKEN` - Personal Access Token

### 2. Context7 MCP Server
**Docker:** Available on [Docker MCP Catalog](https://hub.docker.com/mcp/server/context7/overview)
**Source:** [upstash/context7](https://github.com/upstash/context7)
**Purpose:** Provides up-to-date, version-specific documentation and code examples for libraries/frameworks directly to LLMs
**Environment:**
- API key recommended (free at context7.com/dashboard)

### 3. Azure DevOps MCP Server
**Docker:** `ghcr.io/metorial/mcp-container--vortiago--mcp-azure-devops--mcp-azure-devops`
**Alternative:** `acuvity/mcp-server-azure-devops`
**Source:** [Vortiago/mcp-azure-devops](https://github.com/Vortiago/mcp-azure-devops) (containerized by [Metorial](https://github.com/metorial/mcp-containers))
**Purpose:** ADO integration - work items, projects, teams, queries
**Environment:**
- `AZURE_DEVOPS_PAT` - Personal Access Token
- `AZURE_DEVOPS_ORGANIZATION_URL` - e.g., `https://dev.azure.com/myorg`

**Note:** The official Microsoft ADO MCP (`@azure-devops/mcp`) has more features but no Docker image. Using community containers first - if insufficient, consider wrapping official package later.

### 4. Docker Hub MCP Server (Optional)
**Docker:** `mcp/azure` on [Docker MCP Catalog](https://hub.docker.com/mcp/server/dockerhub/overview)
**Purpose:** Docker Hub operations - image discovery, repository management
**Decision:** Lower priority. Include if needed for Docker workflows.

---

## Nix Module Architecture

### Design Principles
- Declarative configuration via Nix module options
- Each MCP server runs in its own Docker container
- No software installed on host (Docker images only)
- Secrets managed via environment variables

### Proposed Module Structure
```
nix-mcp-setup/
├── flake.nix              # Entry point, minimal
├── flake.lock             # Pinned inputs
├── modules/
│   ├── default.nix        # Main module, imports all servers
│   ├── github.nix         # GitHub MCP options
│   ├── context7.nix       # Context7 MCP options
│   └── azure-devops.nix   # ADO MCP options
├── lib/
│   └── mkMcpServer.nix    # Helper to generate MCP server configs
└── docs/
    └── ROADMAP.md         # This file
```

### Module Options Pattern
```nix
# Example: modules/github.nix
{ config, lib, pkgs, ... }:

with lib;

{
  options.services.mcp.github = {
    enable = mkEnableOption "GitHub MCP server";

    tokenEnvVar = mkOption {
      type = types.str;
      default = "GITHUB_TOKEN";
      description = "Environment variable containing the GitHub PAT";
    };

    image = mkOption {
      type = types.str;
      default = "ghcr.io/github/github-mcp-server:latest";
      description = "Docker image to use";
    };
  };

  config = mkIf config.services.mcp.github.enable {
    # Generate Claude Code MCP config
  };
}
```

### Output: Claude Code Configuration
The module should generate MCP config (location TBD):
```json
{
  "mcpServers": {
    "github": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "-e", "GITHUB_TOKEN", "ghcr.io/github/github-mcp-server"]
    },
    "context7": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "mcp/context7"]
    },
    "azure-devops": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "-e", "AZURE_DEVOPS_PAT", "-e", "AZURE_DEVOPS_ORGANIZATION_URL", "ghcr.io/metorial/mcp-container--vortiago--mcp-azure-devops--mcp-azure-devops", "mcp-azure-devops"]
    }
  }
}
```

---

## Implementation Phases

### Phase 1: Foundation
- [ ] Set up flake.nix with basic structure
- [ ] Create module skeleton with shared helpers
- [ ] Document Nix configuration patterns

### Phase 2: Core MCP Servers
- [ ] Implement GitHub MCP module
- [ ] Implement Context7 MCP module
- [ ] Implement Azure DevOps MCP module
- [ ] Test with Claude Code

### Phase 3: Integration
- [ ] Home Manager integration example
- [ ] Secrets management documentation
- [ ] Example configurations

### Phase 4: Optional
- [ ] Evaluate Docker Hub MCP necessity
- [ ] Add if needed

---

## Open Questions

1. **MCP config location** - Where does Claude Code expect the config?
2. **Secret storage** - Where to store generated PAT securely?

---

## References

### Nix
- [NixOS & Flakes Book - Module System](https://nixos-and-flakes.thiscute.world/other-usage-of-flakes/module-system)
- [flake-parts](https://github.com/hercules-ci/flake-parts)

### MCP Servers
- [GitHub MCP Server](https://github.com/github/github-mcp-server)
- [Context7](https://github.com/upstash/context7)
- [Metorial MCP Containers](https://github.com/metorial/mcp-containers)
- [Docker MCP Catalog](https://hub.docker.com/mcp)
- [MCP Specification](https://modelcontextprotocol.io/)

---

*Last updated: 2026-01-29*
