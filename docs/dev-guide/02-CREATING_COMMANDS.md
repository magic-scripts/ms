# Creating Magic Scripts Commands

This guide walks through creating a new Magic Scripts command from scratch.

## Quick Start with `ms pub pack init`

The fastest way to start is with the scaffolding tool:

**Interactive mode (prompts for metadata):**
```bash
ms pub pack init mycommand
# Prompts for: author, email, license, description, category, remote URL
cd mycommand
```

**Non-interactive mode (uses defaults):**
```bash
ms pub pack init mycommand -y
cd mycommand
```

**With parameters (no prompts):**
```bash
ms pub pack init mycommand \
  --author "Your Name" \
  --email "you@example.com" \
  --description "My command description" \
  --category utilities \
  --remote https://github.com/you/mycommand.git \
  -y
cd mycommand
```

This creates a complete project structure with:
- `scripts/mycommand.sh` — Main command script
- `registry/mycommand.mspack` — Package manifest (with your metadata)
- `registry/mycommand.msver` — Version tree
- `installer/install.sh` — Install hook
- `installer/uninstall.sh` — Uninstall hook
- `man/` — Man pages directory
- `.gitignore` — Git ignore file

It also:
- Initializes git with `main` (initial commit) and `develop` (current branch)
- If `--remote` is provided, configures the remote and pushes both branches

## Project Structure

### scripts/mycommand.sh

The main executable script. Must be POSIX shell (`#!/bin/sh`) and support `--version` and `--help` flags.

### registry/mycommand.mspack

Package manifest containing metadata and configuration keys:

```
name|mycommand
description|My command description
author|Your Name <you@example.com>
license|MIT
license_url|https://github.com/you/mycommand/blob/main/LICENSE
repo_url|https://github.com/you/mycommand
issues_url|https://github.com/you/mycommand/issues
stability|stable
min_ms_version|0.0.1
msver_url|https://raw.githubusercontent.com/you/mycommand/develop/registry/mycommand.msver
config|MYCOMMAND_TIMEOUT|30|Command timeout in seconds|network|mycommand
```

### registry/mycommand.msver

Version tree with download URLs, checksums, and hooks:

```
# Format: version|ver_name|download_url|checksum|install_script|uninstall_script|update_script|man_url
version|dev|https://raw.githubusercontent.com/you/mycommand/develop/scripts/mycommand.sh|dev|https://raw.githubusercontent.com/you/mycommand/develop/installer/install.sh|https://raw.githubusercontent.com/you/mycommand/develop/installer/uninstall.sh||https://raw.githubusercontent.com/you/mycommand/develop/man/mycommand.1
```

Note: URLs point to `develop` branch during development. `ms pub pack release` will rewrite them to point to `release/v<version>` branches.

## Script Requirements

### Basic Template

```bash
#!/bin/sh

# Script identity for config access
export MS_SCRIPT_ID="mycommand"

VERSION="1.0.0"

# Load config system if available
if [ -f "$HOME/.local/share/magicscripts/core/config.sh" ]; then
    . "$HOME/.local/share/magicscripts/core/config.sh"
fi

show_help() {
    echo "mycommand v$VERSION"
    echo "Description of what this command does"
    echo ""
    echo "Usage: mycommand [options] <arguments>"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --version  Show version information"
}

show_version() {
    echo "mycommand v$VERSION"
}

# Handle flags
case "$1" in
    -h|--help|help)
        show_help
        exit 0
        ;;
    -v|--version|version)
        show_version
        exit 0
        ;;
esac

# Main logic
main() {
    # Access configuration with fallback
    if command -v get_config_value >/dev/null 2>&1; then
        timeout=$(get_config_value "MYCOMMAND_TIMEOUT" "30" 2>/dev/null)
    else
        timeout="30"
    fi

    echo "Running mycommand with timeout: $timeout"
    # Your command logic here
}

main "$@"
```

### POSIX Shell Compliance

- Use `#!/bin/sh` shebang
- No bashisms (no `[[`, `source`, arrays, etc.)
- Use POSIX-compliant parameter expansion
- Test with `sh -n script.sh`

### Required Flags

All commands must support:
- `--version` / `-v` / `version` — Show version
- `--help` / `-h` / `help` — Show usage

## Configuration Integration

### Registering Configuration Keys

Add to your `.mspack` file:

```
config|KEY_NAME|default_value|Description of the key|category|mycommand
```

Format: `config|KEY|default|description|category|script_name`

Categories: `author`, `database`, `network`, `filesystem`, `project`, `settings`

### Accessing Configuration in Scripts

```bash
# Get config value with fallback
if command -v get_config_value >/dev/null 2>&1; then
    value=$(get_config_value "KEY_NAME" "default" 2>/dev/null)
else
    value="default"
fi
```

The config system enforces access control: scripts can only access keys they've registered.

## Install/Uninstall Hooks

### Install Hook (installer/install.sh)

```bash
#!/bin/sh

command_name="$1"
version="$2"
script_path="$3"
install_dir="$4"
registry_name="$5"

echo "Setting up $command_name v$version..."

# Create directories, download resources, set defaults, etc.
mkdir -p "$HOME/.config/$command_name"

echo "$command_name installation complete"
```

### Uninstall Hook (installer/uninstall.sh)

```bash
#!/bin/sh

command_name="$1"
version="$2"
script_path="$3"
install_dir="$4"
registry_name="$5"

echo "Cleaning up $command_name v$version..."

# Remove directories, clean up resources, etc.
rm -rf "$HOME/.config/$command_name"

echo "$command_name cleanup complete"
```

## Testing Locally

### Development Mode

```bash
export MAGIC_SCRIPT_DIR="/path/to/your/ms"
./ms/scripts/ms.sh pack verify registry/
./scripts/mycommand.sh --version
./scripts/mycommand.sh --help
```

### Checksum Calculation

```bash
ms pub pack checksum scripts/mycommand.sh
```

### Validation

```bash
ms pub pack verify registry/
```

## Next Steps

Once your command is working locally:
1. Use `ms pub pack verify registry/` to validate
2. Use `ms pub pack release registry/ 0.1.0` to create your first release
3. See [PUBLISHING.md](PUBLISHING.md) for the complete release workflow
