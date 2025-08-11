# Installation Guide

## Installation Methods

### 1. Quick Installation (Recommended)

```bash
# Latest stable version
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh

# Specific version
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh -s -- -v 0.0.1

# Development version (latest features)
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh -s -- -v dev
```

This will:
- Download and install the Magic Scripts core system
- Set up the CLI interface (`ms` command)
- Configure PATH and MANPATH
- Initialize the registry system

### 2. Manual Installation

If you prefer to review the setup script first:

```bash
# Download the setup script
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh > setup.sh

# Review the script
cat setup.sh

# Run the installation
chmod +x setup.sh
./setup.sh
```

### 3. Development Installation

For contributing or testing:

```bash
git clone https://github.com/magic-scripts/ms.git
cd ms
./setup.sh
```

## Installation Structure

Magic Scripts uses a clean, organized installation structure:

### User Installation Locations
- **Executables**: `~/.local/bin/ms/` - Command wrappers
- **Data**: `~/.local/share/magicscripts/` - Core system and scripts
- **Config**: `~/.local/share/magicscripts/config` - User configuration
- **Man Pages**: `~/.local/share/man/man1/` - Documentation

### Core System Structure
```
~/.local/share/magicscripts/
├── core/                     # Core system files
│   ├── config.sh            # Configuration management
│   └── registry.sh          # Registry system
├── scripts/                 # Downloaded command scripts
│   └── ms.sh               # Main CLI script
├── installed/              # Installation metadata
│   └── *.msmeta           # Per-command metadata
└── reg/                    # Registry cache
    ├── reglist            # Registry sources
    └── *.msreg           # Cached registry files
```

## Post-Installation

### 1. Reload Shell Configuration
```bash
# Reload your shell to use the new PATH
source ~/.bashrc    # or ~/.zshrc, ~/.profile
# or restart your terminal
```

### 2. Verify Installation
```bash
ms --version
ms status
```

### 3. Install Commands
```bash
# Update registries
ms upgrade

# Install all available commands
ms install -r default

# Or install specific commands
ms install gigen licgen pgadduser
```

### 4. Configure Settings
```bash
# Set up basic configuration
ms config set AUTHOR_NAME "Your Name"
ms config set AUTHOR_EMAIL "your@email.com"

# View available configuration
ms config list -r
```

## Updates

### Self-Update
Magic Scripts can update its core system:

```bash
ms self-update
```

Or manually:
```bash
ms reinstall ms
```

### Update Individual Commands
```bash
ms update <command>
ms update --all
```

## Uninstallation

### Normal Uninstallation
```bash
ms uninstall ms
```

This will:
- Remove all installed commands
- Delete all configuration and data
- Clean up PATH modifications from shell configs
- Remove man pages

### Emergency Cleanup

If Magic Scripts is corrupted or the `ms` command is not working:

```bash
# Download and run cleanup script
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/cleanup.sh | sh

# Or download first to review
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/cleanup.sh > cleanup.sh
chmod +x cleanup.sh
./cleanup.sh
```

The cleanup script will:
- Remove all Magic Scripts executables
- Delete all data and configuration files  
- Remove man pages
- Clean PATH modifications from shell configs
- Provide verification of complete removal

### Selective Removal
```bash
# Remove specific commands
ms uninstall gigen licgen

# Remove all commands but keep ms core
ms uninstall --all
```

## Troubleshooting

### Permission Issues
If you get permission errors:

```bash
# Ensure directories exist and have correct permissions
mkdir -p ~/.local/bin ~/.local/share
chmod 755 ~/.local/bin ~/.local/share
```

### PATH Issues
If `ms` command is not found after installation:

```bash
# Check if the directory is in PATH
echo $PATH | grep -q "$HOME/.local/bin/ms" && echo "Found" || echo "Not found"

# Manually add to PATH (temporary)
export PATH="$HOME/.local/bin/ms:$PATH"

# Check shell configuration files
ls -la ~/.bashrc ~/.zshrc ~/.profile
```

### Network Issues
If downloads fail:

```bash
# Test connectivity
curl -I https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh

# Use wget instead of curl
wget -q --spider https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh
```

For more troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).