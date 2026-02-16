# Getting Started with Magic Scripts

Magic Scripts (`ms`) is a POSIX shell CLI tool for distributing and managing developer automation scripts. This guide covers installation, initial setup, and day-to-day usage.

## Quick Install

Install the latest stable version with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh
```

To review the script before running it:

```bash
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh > setup.sh
cat setup.sh
chmod +x setup.sh
./setup.sh
```

### Installing a Specific Version

```bash
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh -s -- -v 0.0.1
```

### Installing the Development Version

```bash
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh -s -- -v dev
```

## Post-Install Setup

### 1. Reload Your Shell

The installer adds `~/.local/bin/ms` to your PATH. Reload your shell configuration for it to take effect:

```bash
source ~/.bashrc    # or ~/.zshrc, ~/.profile depending on your shell
```

Alternatively, restart your terminal.

### 2. Verify the Installation

```bash
ms --version
ms status
```

Both commands should produce output without errors. If `ms` is not found, see the [Troubleshooting Guide](../TROUBLESHOOTING.md).

## First Steps

### Update Registries

Fetch the latest command listings from all configured registries:

```bash
ms upgrade
```

### Install Commands

Install all commands from the default registry:

```bash
ms install -r default
```

Or install specific commands:

```bash
ms install pgadduser mschecksum
```

### Configure Your Identity

Set your name and email so that commands which need author information can use them:

```bash
ms config set AUTHOR_NAME "Your Name"
ms config set AUTHOR_EMAIL "your@email.com"
```

View all available configuration keys (including registry defaults):

```bash
ms config list -r
```

For more on configuration, see the [Configuration Guide](../CONFIGURATION.md).

## Installation Structure

Magic Scripts keeps everything under `~/.local/`:

| Location | Purpose |
|---|---|
| `~/.local/bin/ms/` | Executable wrappers (the `ms` command and installed commands) |
| `~/.local/share/magicscripts/scripts/` | Downloaded command scripts |
| `~/.local/share/magicscripts/core/` | Core libraries (`config.sh`, `registry.sh`) |
| `~/.local/share/magicscripts/installed/` | Installation metadata (`.msmeta` files) |
| `~/.local/share/magicscripts/reg/` | Registry cache |
| `~/.local/share/magicscripts/config` | User configuration file |
| `~/.local/share/man/man1/` | Man pages |

Each installed command is a lightweight wrapper in `~/.local/bin/ms/` that sets up the environment and delegates to the actual script in `~/.local/share/magicscripts/scripts/`.

## Updating

### Update Installed Commands

Check for and apply updates to all installed commands:

```bash
ms update
```

Update a specific command:

```bash
ms update pgadduser
```

### Reinstall the Core System

If you need to repair or update the `ms` core itself:

```bash
ms reinstall ms
```

### Refresh Registries

To pull the latest command listings without updating installed commands:

```bash
ms upgrade
```

## Uninstallation

### Normal Uninstallation

Remove Magic Scripts and all installed commands:

```bash
ms uninstall ms
```

This removes all installed commands, configuration, data, man pages, and PATH modifications from your shell configuration files.

### Removing Individual Commands

```bash
ms uninstall pgadduser
```

### Emergency Cleanup

If the `ms` command is broken or corrupted, use the standalone cleanup script:

```bash
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/cleanup.sh | sh
```

To review the cleanup script before running it:

```bash
curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/cleanup.sh > cleanup.sh
chmod +x cleanup.sh
./cleanup.sh
```

After cleanup, you can perform a fresh install using the Quick Install command above.

## Useful Commands at a Glance

| Command | Description |
|---|---|
| `ms status` | Show installation status and installed commands |
| `ms search <term>` | Search for available commands |
| `ms install <command>` | Install a command |
| `ms uninstall <command>` | Remove a command |
| `ms update` | Update all installed commands |
| `ms upgrade` | Refresh registry listings |
| `ms config list` | View current configuration |
| `ms doctor` | Run diagnostics on the installation |
| `ms info <command>` | Show detailed information about a command |
| `ms versions <command>` | List available versions of a command |

## Next Steps

- [Configuration Guide](../CONFIGURATION.md) -- Managing settings across commands
- [Registry System](../REGISTRY.md) -- How command distribution works
- [Troubleshooting](../TROUBLESHOOTING.md) -- Resolving common issues
