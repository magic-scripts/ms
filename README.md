# Magic Scripts v0.0.1

A comprehensive collection of developer automation tools for streamlined project setup, configuration management, and development workflows.

## 🚀 Quick Start

### Installation

```bash
# Install latest stable version (recommended)
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/installer/install.sh | sh

# Install specific version
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/installer/install.sh | sh -s -- -v 0.0.1

# Install development version
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/installer/install.sh | sh -s -- -v dev -d

# Using wget instead of curl
wget -qO- https://raw.githubusercontent.com/magic-scripts/ms/main/installer/install.sh | sh
```

### First Steps

```bash
# Update registries to latest version
ms upgrade

# Browse available commands
ms search

# Install all commands from default registry  
ms install -r ms

# Configure your settings
ms config set AUTHOR_NAME "Your Name"
ms config set AUTHOR_EMAIL "your@email.com"
```

### Uninstallation

```bash
# Uninstall Magic Scripts
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/installer/uninstall.sh | sh
```

## 📖 Documentation

### Core System

- **Magic Scripts CLI (`ms`)** - Main interface for managing all commands
- **2-Tier Registry System** - .msreg (master registry) → .msver (version trees) → scripts
- **Configuration System** - Unified config at `~/.local/share/magicscripts/config`

### Available Commands

| Command | Description | Manual |
|---------|-------------|---------|
| `gigen` | .gitignore template generator | [manual/gigen.md](manual/gigen.md) |
| `licgen` | License generator for various licenses | [manual/licgen.md](manual/licgen.md) |
| `pgadduser` | PostgreSQL user and database setup | [manual/pgadduser.md](manual/pgadduser.md) |
| `dcwinit` | Docker Compose wireframe generator | [manual/dcwinit.md](manual/dcwinit.md) |
| `dockergen` | Optimized Dockerfile generator for various runtimes | [manual/dockergen.md](manual/dockergen.md) |
| `projinit` | Project initializer for various frameworks | [manual/projinit.md](manual/projinit.md) |
| `mschecksum` | SHA256 checksum calculator | [manual/mschecksum.md](manual/mschecksum.md) |

## ⚙️ Configuration

Magic Scripts uses a unified configuration system:

```bash
# List current configuration
ms config list

# Set configuration values
ms config set AUTHOR_NAME "Your Name"
ms config set AUTHOR_EMAIL "your@email.com"

# Interactive configuration
ms config set
```

**Configuration File**: `~/.local/share/magicscripts/config`

## 📦 Registry System

Magic Scripts uses a 2-tier registry system for command distribution:

1. **Master Registry** (`.msreg`) - Points to version files for each command
2. **Version Registry** (`.msver`) - Contains version history and download URLs

```bash
# List all registries
ms reg list

# Add external registry
ms reg add mycompany https://example.com/registry/custom.msreg

# Update all registries
ms upgrade
```

## 🌿 Branch Strategy

- **main** - Latest stable release, used for production installations
- **develop** - Development branch with latest features
- **staging** - Pre-release testing and checksum verification
- **release/v0.0.0** - Immutable version snapshots

## 🛠️ Development

### Script Template

```bash
#!/bin/sh

# Set script identity for config access
export MS_SCRIPT_ID="mycommand"

VERSION="0.0.1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load config system
if [ -f "$SCRIPT_DIR/../config.sh" ]; then
    . "$SCRIPT_DIR/../config.sh"
elif [ -f "$HOME/.local/share/magicscripts/config.sh" ]; then
    . "$HOME/.local/share/magicscripts/config.sh"
fi

# Get configuration values
if command -v get_config_value >/dev/null 2>&1; then
    MY_VALUE=$(get_config_value "MY_KEY" "default" 2>/dev/null)
else
    MY_VALUE="fallback_value"
fi

# Handle version flag
case "$1" in
    -v|--version) echo "mycommand v$VERSION"; exit 0 ;;
    -h|--help) usage; exit 0 ;;
esac

# Your script logic here
echo "Running with MY_VALUE: $MY_VALUE"
```

## 🐛 Troubleshooting

### Common Issues

**Command not found after installation:**
```bash
# Add to shell profile
echo 'export PATH="$HOME/.local/bin/ms:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**Registry update failures:**
```bash
# Run diagnostics
ms doctor

# Manual update
ms upgrade
```

**Configuration not working:**
```bash
# Check config files
ms config list

# Verify registry
ms config list -r
```

## 📝 License

MIT License - see LICENSE file for details.

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository and create a feature branch from `develop`
2. Follow existing code patterns and include proper version info
3. Test your changes and update documentation
4. Submit a pull request targeting the `develop` branch

For detailed guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md).

---

**Magic Scripts v0.0.1** - Streamlining development workflows, one script at a time.