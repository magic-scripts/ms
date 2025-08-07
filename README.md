# Magic Scripts v0.0.1

A comprehensive collection of developer automation tools for streamlined project setup, configuration management, and development workflows.

## 📖 Key Concepts

### Repository vs Registry vs Command

- **Repository**: A Git repository containing the actual script files and source code
  - Example: `https://github.com/magic-scripts/ms` (main repository)
  - Example: `https://github.com/magic-scripts/ms-template` (template repository)

- **Registry**: A metadata file (`.msreg`) that describes available commands and their locations
  - Contains command definitions, download URLs, versions, and checksums
  - Can point to scripts from multiple repositories
  - Example: `https://raw.githubusercontent.com/magic-scripts/ms/main/core/ms.msreg`

- **Command**: An individual executable script that provides specific functionality
  - Examples: `gigen` (gitignore generator), `licgen` (license generator)
  - Installed from registries, downloaded from repositories
  - Managed through the Magic Scripts system

### How It Works

1. **Registry** defines what commands are available and where to find them
2. **Repository** hosts the actual script files
3. **Magic Scripts** downloads scripts from repositories based on registry information
4. **Commands** are installed locally and become available in your PATH

## 🚀 Quick Start

### Installation

```bash
# Install latest stable version (recommended)
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/core/installer/install.sh | sh

# Install specific version
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/core/installer/install.sh | sh -s -- -v 0.0.1

# Install development version
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/core/installer/install.sh | sh -s -- -v dev -d

# Using wget instead of curl
wget -qO- https://raw.githubusercontent.com/magic-scripts/ms/main/core/installer/install.sh | sh
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
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/core/installer/uninstall.sh | sh
```

## 📖 Core System

### Magic Scripts CLI (`ms`)

The main interface for managing all Magic Scripts commands and configuration.

**Core Commands:**
- `ms help` - Show help and list installed commands
- `ms version` - Show version information  
- `ms status` - Show installation status
- `ms doctor` - Diagnose and repair system issues
- `ms upgrade` - Update all registries to latest version

**Search & Install:**
- `ms search [query]` - Search for available commands (shows versions)
- `ms install <commands...>` - Install specific commands (skips if same version)
- `ms install -r <registry>` - Install entire registry
- `ms install -r <registry> <commands...>` - Install from specific registry
- `ms reinstall <commands...>` - Complete reinstall (uninstall + fresh install)
- `ms uninstall <commands...>` - Remove installed commands
- `ms update [commands...]` - Update commands (checks versions)
- `ms versions [command|--all]` - Show version information

**Configuration:**
- `ms config list` - List current configuration values
- `ms config list -r` - Show available configuration keys
- `ms config set <key> <value>` - Set a configuration value
- `ms config set -g <key> <value>` - Set global configuration
- `ms config get <key>` - Get a configuration value
- `ms config remove <key>` - Remove a configuration value

**Registry Management:**
- `ms reg list` - List all registries
- `ms reg add <name> <url>` - Add external registry
- `ms reg remove <name>` - Remove a registry

## ⚙️ Configuration System

Magic Scripts uses a unified configuration system where each script can define its required keys.

### Configuration Files

- **User Config**: `~/.magicscripts/config`
- **Global Config**: `~/.local/share/magicscripts/global-config`
- **Registry List**: `~/.local/share/magicscripts/reg/reglist`


### Interactive Configuration

```bash
# Configure all settings interactively
ms config set

# Configure settings for specific command
ms config set pgadduser

# Configure specific key interactively
ms config set AUTHOR_NAME
```

## 📦 Registry System

Magic Scripts uses a URL-based registry system for managing and distributing commands.

### Default Registry

The default registry (`ms`) is automatically configured and points to:
```
https://raw.githubusercontent.com/magic-scripts/ms/main/core/ms.msreg
```

### Managing Registries

```bash
# List all registries and their status
ms reg list

# Add a custom registry
ms reg add mycompany https://example.com/registry/custom.msreg

# Remove a registry (default 'ms' registry cannot be removed)
ms reg remove mycompany

# Update all registries to latest version
ms upgrade
```

### Registry File Format

Registry files (`.msreg`) use a pipe-delimited format with clear prefixes for commands and configuration:

```
# Commands (pipe-delimited with command| prefix)
command|name|script_uri|description|category|version|checksum

# Configuration keys (pipe-delimited with config| prefix)
config|key|default_value|description|category|scripts

# Examples
command|gigen|https://raw.githubusercontent.com/example/gigen.sh|.gitignore template generator|development|0.0.1|37dd0f2b
command|licgen|https://raw.githubusercontent.com/example/licgen.sh|License generator for various licenses|development|0.0.1|310df49d
config|AUTHOR_NAME||Your name for generated files|global|gigen,licgen,projinit
```

**Command Fields:**
- `command`: Literal prefix "command"
- `name`: Command name (e.g., `gigen`, `licgen`)
- `script_uri`: Full HTTP/HTTPS URL to script file
- `description`: Human-readable description
- `category`: Category for organization (`development`, `docker`, `database`, etc.)
- `version`: Semantic version (e.g., `0.0.1`)
- `checksum`: SHA256 checksum (first 8 characters)

**Configuration Fields:**
- `config`: Literal prefix "config"
- `key`: Configuration key name
- `default_value`: Default value (can be empty)
- `description`: Human-readable description
- `category`: Category for organization
- `scripts`: Comma-separated list of scripts that use this config

## 📦 Installation & Version Management System

Magic Scripts includes a comprehensive installation and version management system with metadata tracking.

### Installation Commands

```bash
# Install specific commands
ms install gigen licgen                    # Install multiple commands from any registry
ms install -r ms                          # Install entire registry
ms install -r template gigen              # Install from specific registry

# Examples of installation output:
$ ms install gigen
Magic Scripts Installer
====================

  Installing gigen from ms... done

Installation complete!
Installed: 1 commands

# Already installed commands are detected:
$ ms install gigen
Magic Scripts Installer
====================

  Installing gigen from ms... already installed

Installation complete!
Installed: 0 commands
```

### Version Commands

```bash
# Check specific script version
ms versions gigen
# Output:
# Version information for gigen:
#   Installed: 0.0.1
#   Registry:  0.0.1
# ✓ Up to date

# List all versions
ms versions --all
# Output:
# Command      Installed    Registry    
# -------      ---------    --------    
# gigen        0.0.1        0.0.1       
# licgen       0.0.1        0.0.1       

# Update commands (checks versions and skips if up-to-date)
ms update                    # Update all installed commands
ms update gigen             # Update specific command
```

### Installation Metadata System

- **Storage**: `~/.local/share/magicscripts/installed/` (*.msmeta files)
- **Content**: Each .msmeta file contains:
  - Command name and version
  - Registry name and URL
  - SHA256 checksum (first 8 characters)
  - Installation date (ISO 8601 format)
  - Script path

**Example .msmeta file:**
```
command=gigen
version=0.0.1
registry_name=ms
registry_url=https://raw.githubusercontent.com/magic-scripts/ms/main/core/ms.msreg
checksum=37dd0f2b
installed_date=2025-08-06T17:11:14Z
script_path=/Users/user/.local/share/magicscripts/scripts/gitignore-gen.sh
```

### Smart Installation Features

- **Duplicate detection**: Already installed commands are skipped with clear indication
- **Version comparison**: Automatic version checking before installation/updates
- **Checksum verification**: Integrity verification after installation
- **Registry tracking**: Metadata tracks which registry provided each command
- **Atomic installation**: Either fully succeeds or cleanly fails

## 🔧 Registry Management with msreg

The `msreg` tool helps manage registry files with automatic checksum calculation.

### Installation

```bash
# msreg is included with Magic Scripts
ms install msreg
```

### Commands

```bash
# Add a script to registry (downloads and calculates checksum)
msreg add gigen:0.0.1 https://raw.githubusercontent.com/example/gigen.sh

# Remove a script version
msreg remove gigen:0.0.1

# Calculate checksum for a file
msreg checksum ./scripts/gigen.sh

# Show version
msreg --version
```

### Adding Scripts to Registry

When using `msreg add`, the tool will:

1. **Download** the script from the provided URL
2. **Calculate** SHA256 checksum  
3. **Prompt** for description, category, and script path
4. **Add** entry to the registry file
5. **Prevent** duplicates (same command:version combinations)

**Example workflow:**
```bash
$ msreg add gigen:2.0.0 https://example.com/gigen.sh
Downloading https://example.com/gigen.sh...
Description: Advanced gitignore generator
Category: development  
Script path (relative to MAGIC_SCRIPT_DIR): scripts/gitignore-gen.sh
✓ Added gigen:2.0.0 to registry
  Checksum: a1b2c3d4
  Entry: gigen:scripts/gitignore-gen.sh:Advanced gitignore generator:development:2.0.0:a1b2c3d4
```

### Checksum Calculation

Magic Scripts uses SHA256 checksums for integrity verification:

- **Algorithm**: SHA256  
- **Format**: First 8 characters of hex digest
- **Purpose**: Verify script integrity during installation
- **Tools**: Uses `sha256sum`, `shasum`, or `openssl` (in order of preference)

**Example:**
```bash
$ msreg checksum scripts/gigen.sh
File: scripts/gigen.sh  
SHA256 (first 8 chars): 37dd0f2b
```

### Duplicate Prevention

`msreg add` prevents duplicate entries by checking for existing command:version combinations:

```bash
$ msreg add gigen:0.0.1 https://example.com/script.sh
Error: Command 'gigen' version '0.0.1' already exists in registry
Use 'remove' first if you want to update it
```

## 🛠️ Available Commands

| Command | Description | Manual |
|---------|-------------|---------|
| `gigen` | .gitignore template generator | [manual/gigen.md](manual/gigen.md) |
| `licgen` | License generator for various licenses | [manual/licgen.md](manual/licgen.md) |
| `pgadduser` | PostgreSQL user and database setup | [manual/pgadduser.md](manual/pgadduser.md) |
| `dcwinit` | Docker Compose wireframe generator | [manual/dcwinit.md](manual/dcwinit.md) |
| `dockergen` | Optimized Dockerfile generator for various runtimes | [manual/dockergen.md](manual/dockergen.md) |
| `projinit` | Project initializer for various frameworks | [manual/projinit.md](manual/projinit.md) |
| `msreg` | Registry management and checksum calculator | [manual/msreg.md](manual/msreg.md) |

## Install Commands

```bash
# Install all commands from default registry  
ms install -r ms

# Install specific commands
ms install gigen licgen projinit

# Browse available commands
ms search
```

## 🔧 Development

### Creating Custom Scripts

1. **Create your script** in `scripts/` directory
2. **Add to registry** in `core/ms.msreg`:
   ```
   command|mycommand|https://example.com/my-script.sh|Description of my command|category|0.0.1|checksum
   ```
3. **Define configuration keys** if needed:
   ```
   config|MY_KEY|default_value|Key description|category|mycommand
   ```

### Script Template

```bash
#!/bin/sh

# Set script identity for config access
export MS_SCRIPT_ID="mycommand"

VERSION="0.0.1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load config system
if [ -f "$SCRIPT_DIR/../core/config.sh" ]; then
    . "$SCRIPT_DIR/../core/config.sh"
elif [ -f "$HOME/.local/share/magicscripts/core/config.sh" ]; then
    . "$HOME/.local/share/magicscripts/core/config.sh"
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

### Creating Custom Registry

1. **Create registry file** (`myregistry.msreg`):
   ```
   # My Custom Registry
   command|tool1|https://example.com/tool1.sh|First tool|utilities|1.0.0|checksum1
   command|tool2|https://example.com/tool2.sh|Second tool|utilities|1.0.0|checksum2
   config|TOOL_SETTING|default|Tool configuration|utilities|tool1,tool2
   ```

2. **Host the file** on a web server (GitHub, GitLab, etc.)

3. **Add to Magic Scripts**:
   ```bash
   ms reg add myregistry https://example.com/myregistry.msreg
   ms upgrade
   ms install myregistry
   ```

## 🔒 Security Features

### Script Identity Validation

- Each script must set `MS_SCRIPT_ID` to access configuration
- Scripts can only access configuration keys they're authorized for
- Empty or missing `MS_SCRIPT_ID` blocks all config access
- `ms.sh` has privileged access to all registered keys

### Registry Protection

- Default `ms` registry cannot be removed
- Registry URLs must be valid HTTP/HTTPS
- Downloaded registries are validated before use
- Local cache prevents repeated downloads

## 🌿 Branch Strategy

Magic Scripts follows a structured branching model to ensure stable releases and smooth development workflow:

### **Branch Structure**

#### `main` - Latest Release
- Contains the **latest stable release**
- Used for production installations
- All releases are tagged (e.g., `v0.0.1`, `v0.0.2`)
- Protected branch - only accepts merges from `release/*` branches

#### `develop` - Development Branch  
- Contains **current development work**
- Features and fixes are merged here first
- Used for dev version installations (`install.sh -v dev -d`)
- Always ahead of `main` (next release candidate)

#### `release/v0.0.0` - Release Snapshots
- **Immutable snapshots** of deployed versions
- Created when deploying to production
- Format: `release/v{major}.{minor}.{patch}`
- Used for version-specific installations and rollbacks

### **Registry Branch Mapping**

```bash
# Latest stable release (main branch)
command|ms|https://raw.githubusercontent.com/magic-scripts/ms/main/core/ms.sh|...|0.0.2|checksum

# Development version (develop branch)  
command|ms|https://raw.githubusercontent.com/magic-scripts/ms/develop/core/ms.sh|...|dev|dev

# Specific version snapshot (release branch)
command|ms|https://raw.githubusercontent.com/magic-scripts/ms/release/v0.0.1/core/ms.sh|...|0.0.1|checksum
```

### **Version Installation Examples**

```bash
# Install latest stable version (from main branch)
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/core/installer/install.sh | sh

# Install development version (from develop branch)
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/core/installer/install.sh | sh -s -- -v dev -d

# Install specific version (from release branch)
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/core/installer/install.sh | sh -s -- -v 0.0.1

# Alternative installation methods
wget -qO- https://raw.githubusercontent.com/magic-scripts/ms/main/core/installer/install.sh | sh -s -- -v 0.0.2
```

### **Development Workflow**

1. **Feature Development**: Create feature branches from `develop`
2. **Integration**: Merge features into `develop`
3. **Release Preparation**: Create release branch from `develop`
4. **Release**: Merge release branch to `main` and tag
5. **Snapshot**: Create `release/v0.0.0` branch for the deployed version
6. **Rollback Support**: Reference specific `release/v0.0.0` for rollbacks

### **Benefits**

- ✅ **Stable Releases**: `main` always represents latest stable version
- ✅ **Development Testing**: `develop` allows testing unreleased features
- ✅ **Version Rollback**: `release/*` branches enable precise rollbacks
- ✅ **Clear History**: Each version has its own immutable snapshot
- ✅ **Hotfix Support**: Critical fixes can target specific release branches

## 🐛 Troubleshooting

### Common Issues

**Command not found after installation:**
```bash
# Check PATH
echo $PATH | grep ~/.local/bin

# Add to shell profile if missing
echo 'export PATH="$HOME/.local/bin/ms:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**Registry update failures:**
```bash
# Check network connectivity
curl -I https://raw.githubusercontent.com

# Verify registry URL
ms reg list

# Try manual update
ms upgrade
```

**Configuration not working:**
```bash
# Run diagnostics
ms doctor

# Check config files
ms config list

# Verify registry has config keys
ms config list -r
```

**Installation shows "already installed" but command doesn't work:**
```bash
# Run system diagnosis
ms doctor

# Check if command exists but with wrong permissions
ls -la ~/.local/bin/ms/command_name

# Reinstall with automatic fix
ms doctor --fix

# Force reinstall specific command (if needed)
ms uninstall command_name
ms install command_name
```

**Permission denied errors:**
```bash
# Check directory permissions
ls -la ~/.local/bin/ms/
ls -la ~/.local/share/magicscripts/

# Fix permissions automatically
ms doctor --fix

# Manual permission fix (if needed)
chmod 755 ~/.local/bin/ms/*
chmod -R 755 ~/.local/share/magicscripts/scripts/
```

### Getting Help

- Run `ms help` for command overview
- Use `man ms` to view the complete manual page
- Use `<command> --help` for specific command help
- Run `ms doctor` for system diagnostics
- Check `ms status` for installation status

### Script Development Guidelines

When creating or updating scripts, follow these guidelines:

1. **Version Management:**
   - Always define `VERSION="x.y.z"` near the top of your script
   - Support both `-v` and `--version` flags for version display
   - Use semantic versioning (MAJOR.MINOR.PATCH)

2. **Registry Updates:**
   - Calculate checksum after making changes: `msreg checksum scripts/yourscript.sh`
   - Update registry entry with new checksum
   - Use `msreg add` for new scripts with automatic checksum calculation

3. **Script Identity:**
   - Set `export MS_SCRIPT_ID="scriptname"` for config system access
   - Use consistent naming conventions

4. **Documentation:**
   - Include version flag in usage/help documentation
   - Document any configuration keys your script uses
   - Provide clear usage examples

5. **Testing:**
   - Test version flag functionality: `yourscript --version`
   - Test integration with Magic Scripts system
   - Verify checksum matches: `msreg checksum scripts/yourscript.sh`


## 📝 License

MIT License - see LICENSE file for details.

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository and create a feature branch from `develop`
2. Follow existing code patterns and include proper version info
3. Test your changes and update documentation
4. Submit a pull request targeting the `develop` branch

For detailed guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md).

## 📊 Key Directories

- `~/.local/bin/ms/` - Executable wrappers
- `~/.local/share/magicscripts/` - Core scripts and libraries  
- `~/.magicscripts/` - User configuration

## 🌟 Key Features

- **Smart Installation**: Version management, duplicate detection, checksum verification
- **Unified Configuration**: Single config system for all scripts  
- **Registry System**: URL-based distribution with multi-source support
- **Health Monitoring**: Built-in doctor command with auto-repair
- **No Dependencies**: Install and use without Git or complex setup

---

**Magic Scripts v0.0.1** - Streamlining development workflows, one script at a time.

For issues or suggestions, visit: https://github.com/magic-scripts/ms