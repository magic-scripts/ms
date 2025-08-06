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
# Install via curl (recommended)
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/core/installer/install.sh | sh

# Or via wget
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

### GitIgnore Generator (`gigen`)

Generate and manage `.gitignore` files with template support.

```bash
# Initialize with basic templates
gigen init

# Add templates
gigen add node python

# Remove templates
gigen remove python

# Update templates to latest version
gigen update

# Whitelist patterns
gigen allow "*.log" ".env"

# Remove from whitelist
gigen disallow "*.log"

# Show current status
gigen status
```

**Supported Templates:**
`node`, `python`, `go`, `rust`, `java`, `cpp`, `macos`, `linux`, `windows`, `vscode`, `idea`, `ai`, `ms`

### License Generator (`licgen`)

Generate license files for various open source licenses.

```bash
# Generate MIT license
licgen mit

# Generate with custom author
licgen -a "John Doe" apache

# Generate to custom file
licgen -o LICENSE.txt gpl3
```

**License Types:**
`mit`, `apache`, `gpl3`, `bsd3`, `bsd2`, `unlicense`, `lgpl`, `mpl`, `cc0`, `agpl`

### PostgreSQL User Manager (`pgadduser`)

Create PostgreSQL users and databases with proper permissions.

```bash
# Configure database connection
ms config set POSTGRES_HOST "production.db.com"
ms config set POSTGRES_ADMIN "admin"
ms config set POSTGRES_PASSWORD "admin_password"

# Create user with database
pgadduser -u john -p pass123
pgadduser -u john -p pass123 -d myapp_db
```

### Docker Compose Initializer (`dcwinit`)

Generate Docker Compose configurations for development.

```bash
# Basic web + database setup
dcwinit

# Custom services and port
dcwinit -s "web,db,redis" -p 8080

# With custom network
dcwinit --network --network-name mynet
```

### Dockerfile Generator (`dockergen`)

Generate optimized Dockerfiles for various runtimes.

```bash
# Generate for specific runtime
dockergen node
dockergen python
dockergen go
```

### Project Initializer (`projinit`)

Initialize new projects with common frameworks.

```bash
# Initialize various project types
projinit node myapp
projinit react frontend
projinit python myservice
projinit express api
```

**Project Types:**
`node`, `python`, `go`, `react`, `next`, `express`, `fastapi`

### Registry Manager (`msreg`)

Manage Magic Scripts registry files with automatic checksum calculation.

```bash
# Calculate file checksum
msreg checksum scripts/my-script.sh

# Add script to registry  
msreg add myscript:1.0.0 https://example.com/myscript.sh

# Remove script from registry
msreg remove myscript:1.0.0

# Show version
msreg --version
```

**Features:**
- Automatic SHA256 checksum calculation
- Duplicate prevention (command:version combinations)
- Interactive prompts for metadata
- Registry file validation

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

### Repository Structure Considerations

**Current approach (Monorepo):**
- ✅ Unified version management (0.0.1 for all scripts)
- ✅ Simple registry updates
- ✅ Integrated development workflow
- ❌ All scripts share same version

**Alternative approach (Separate repositories):**
- ✅ Independent versioning per script
- ✅ Focused development and releases
- ✅ Independent CI/CD pipelines
- ❌ Complex registry management
- ❌ Cross-script dependency management

**Recommendation:** Continue with monorepo approach during initial development, consider separation as scripts mature and require independent versioning.

## 📝 License

MIT License - see LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Add your script to `scripts/` directory with proper version info:
   ```bash
   VERSION="0.0.1"
   # Add --version/-v flag handling
   ```
4. Calculate checksum and update registry:
   ```bash
   msreg checksum scripts/your-script.sh
   # Update core/ms.msreg with new entry including checksum
   ```
5. Test with the Magic Scripts system:
   ```bash
   ms install yourcommand
   ms versions yourcommand
   yourcommand --version
   ```
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## 📊 Architecture

```
magicscripts/
├── core/
│   ├── config.sh        # Configuration system
│   ├── registry.sh      # Registry management
│   ├── ms.sh           # Main CLI interface
│   ├── ms.msreg        # Default registry
│   └── installer/      # Installation system
│       ├── install.sh  # Installation script
│       └── uninstall.sh # Uninstallation script
├── scripts/
│   └── *.sh            # Individual command scripts
└── README.md           # This file
```

### Directory Structure (Installed)

```
~/.local/bin/ms/                    # Executable wrappers
~/.local/share/magicscripts/        # Core scripts and libraries
├── scripts/                        # Downloaded scripts
│   ├── ms.sh                      # Main Magic Scripts interface
│   └── *.sh                       # Individual command scripts
├── core/                          # Core system files
│   ├── config.sh                  # Configuration system
│   └── registry.sh                # Registry management
├── installed/                     # Installation metadata
│   ├── ms.msmeta                  # Magic Scripts metadata
│   └── *.msmeta                   # Command metadata files
└── reg/                           # Registry system
    ├── reglist                    # Registry sources
    └── *.msreg                    # Downloaded registries
~/.magicscripts/                    # User configuration
└── config                         # User config file
```

## 🌟 Features

- **Smart Installation System**: Automatic duplicate detection and version comparison
- **Comprehensive Metadata Tracking**: Complete installation history with .msmeta files
- **URL-based Registry System**: Distribute and manage commands via HTTP/HTTPS
- **Registry Duplicate Handling**: Interactive selection when commands exist in multiple registries
- **Unified Configuration**: Single config system for all scripts with security validation
- **System Health Monitoring**: Built-in doctor command with auto-repair capabilities
- **Checksum Verification**: SHA256 integrity checks for all installed scripts
- **Extensible Architecture**: Easy to add new commands and registries
- **Permission Management**: Robust file permission handling (755 for executables)
- **No Git Required**: Install and use without cloning repository
- **Multi-source Support**: Add unlimited custom registries with -r option support

---

**Magic Scripts v0.0.1** - Streamlining development workflows, one script at a time.

For issues or suggestions, visit: https://github.com/magic-scripts/ms