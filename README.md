# nix-mcp-setup

Nix module for running MCP (Model Context Protocol) servers as Docker containers.

## Overview

This project provides a Nix module to manage and run MCP servers. Instead of installing MCP servers directly on the host machine, each server runs in its own Docker container.

## Design Principles

- **Docker-based**: All MCP servers run as Docker containers
- **Isolated**: Each MCP server has its own dedicated Docker image
- **Declarative**: Configured via Nix module system
- **No host installation**: MCP servers are not installed on the host computer

## Planned MCP Servers

- Azure DevOps MCP (`@azure-devops/mcp`)
- Additional servers TBD

## Requirements

- Nix with flakes enabled
- Docker

## Status

**Work in Progress** - Initial setup phase.

## License

MIT
