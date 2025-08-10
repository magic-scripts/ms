# Magic Scripts v0.0.1

A comprehensive collection of developer automation tools for streamlined project setup, configuration management, and development workflows.

## 🚀 Quick Start

### Installation
```bash
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/installer/install.sh | sh
```

### First Steps
```bash
ms upgrade                                    # Update registries
ms install -r default                        # Install all commands
ms config set AUTHOR_NAME "Your Name"        # Configure settings
```

### Uninstallation
```bash
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/installer/uninstall.sh | sh
```

## 📖 Documentation

### System Overview
- **Magic Scripts CLI (`ms`)** - Main interface for managing all commands
- **2-Tier Registry System** - Secure, versioned command distribution
- **Unified Configuration** - Shared settings across all commands

### Available Commands
| Command | Description |
|---------|-------------|
| `gigen` | .gitignore template generator |
| `licgen` | License generator for various licenses |
| `pgadduser` | PostgreSQL user and database setup |
| `dcwinit` | Docker Compose wireframe generator |
| `dockergen` | Optimized Dockerfile generator |
| `projinit` | Project initializer for various frameworks |
| `mschecksum` | SHA256 checksum calculator |

### Detailed Guides
- 📋 [Configuration System](docs/CONFIGURATION.md) - Settings and config management
- 🏪 [Registry System](docs/REGISTRY.md) - Command distribution and versioning  
- 🛠️ [Development Guide](docs/DEVELOPMENT.md) - Creating custom scripts
- 🔧 [System Architecture](LOCAL_INSTALLATION_STRUCTURE.md) - Local installation structure
- 🚨 [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions

## 🚀 Common Usage

```bash
# Configuration
ms config set AUTHOR_NAME "Your Name"        # Set configuration
ms config list                               # View all config

# Registry Management  
ms reg list                                   # List registries
ms reg add custom https://example.com/reg    # Add registry
ms upgrade                                    # Update all registries

# Command Installation
ms search docker                              # Search commands
ms install gigen licgen                       # Install specific commands
ms install -r default                         # Install from registry
ms status                                     # Check installation status

# System Maintenance
ms doctor                                     # Run diagnostics
ms update                                     # Update all commands
```

## 📝 License

MIT License - see LICENSE file for details.

## 🤝 Contributing

1. Fork and create feature branch from `develop`
2. Follow existing patterns and test thoroughly  
3. Submit PR to `develop` branch

See [Development Guide](docs/DEVELOPMENT.md) for detailed information.

---

**Magic Scripts v0.0.1** - Streamlining development workflows, one script at a time.