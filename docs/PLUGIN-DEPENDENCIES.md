# Claude Code Plugin Dependencies for Nix

Claude Code plugins often auto-install dependencies to paths like `~/.bun/bin` or `~/.local/bin`. These paths are not in nix-managed PATH, causing plugins to fail.

**Solution:** Pre-install dependencies via nix. Plugins detect them in PATH and skip auto-install.

## Plugin Installation

### claude-mem

Get plugin from marketplace:
```bash
claude plugin marketplace add thedotmack/claude-mem
```

Install it in Claude:
```bash
claude plugin install claude-mem
```

## Required Packages (Nix)

### claude-mem

Source: https://github.com/thedotmack/claude-mem

```nix
home.packages = with pkgs; [
  bun        # runs worker-service.cjs and hooks
  uv         # provides uvx for Chroma vector DB
  nodejs_20  # runs smart-install.js
];
```

## Verification

After `home-manager switch`:

```bash
which bun && bun --version
which uvx && uvx --version
which node && node --version
```

Then restart Claude Code.
