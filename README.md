# Magic Scripts

A POSIX shell-based CLI tool for distributing and managing developer automation scripts. Uses a 3-tier registry system to discover, install, update, and configure commands from remote repositories.

## Quick Start

### Installation

```bash
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh
```

After installation, reload your shell and verify:

```bash
ms --version
ms status
```

### First Steps

```bash
ms upgrade                                    # Update registries
ms install -r default                         # Install all commands
ms config set AUTHOR_NAME "Your Name"         # Configure settings
```

## Documentation

### User Guides

- [Getting Started](docs/user-guide/GETTING_STARTED.md) — Installation and first steps
- [Command Reference](docs/user-guide/COMMANDS.md) — Complete command documentation
- [Configuration](docs/user-guide/CONFIGURATION.md) — Managing settings
- [Troubleshooting](docs/user-guide/TROUBLESHOOTING.md) — Resolving common issues

### Developer Guides

- [Creating Commands](docs/dev-guide/CREATING_COMMANDS.md) — Build your own Magic Scripts commands
- [Publishing](docs/dev-guide/PUBLISHING.md) — The `ms pub pack` toolchain
- [Registry System](docs/dev-guide/REGISTRY.md) — Deep dive into the 3-tier registry
- [Architecture](docs/dev-guide/ARCHITECTURE.md) — System design and internals

## Common Usage

```bash
# Search and install
ms search postgres
ms install pgadduser mschecksum

# Update and maintain
ms update
ms outdated
ms doctor

# Pin versions
ms pin pgadduser
ms unpin pgadduser

# Configuration
ms config set DB_HOST localhost
ms config list

# Developer tools
ms pub pack init mycommand
ms pub pack release registry/ 1.0.0
```

## Available Commands

| Command | Description |
|---------|-------------|
| `pgadduser` | PostgreSQL user and database setup |
| `mschecksum` | SHA256 checksum calculator |
| `envdiff` | Environment file comparison |

Search for more commands: `ms search`

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development workflow, branch strategy, and coding conventions.

## License

MIT License — see [LICENSE](LICENSE) file for details.