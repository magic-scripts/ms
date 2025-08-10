# Development Guide

This guide covers how to create custom Magic Scripts, integrate with the configuration system, and contribute to the project.

## Creating a Magic Script

### Basic Script Template

```bash
#!/bin/sh

# Set script identity for config access
export MS_SCRIPT_ID="mycommand"

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load config system
if [ -f "$SCRIPT_DIR/../config.sh" ]; then
    . "$SCRIPT_DIR/../config.sh"
elif [ -f "$HOME/.local/share/magicscripts/config.sh" ]; then
    . "$HOME/.local/share/magicscripts/config.sh"
fi

# Script metadata
usage() {
    echo "mycommand v$VERSION"
    echo "Description of what this command does"
    echo ""
    echo "Usage: mycommand [options] <arguments>"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --version  Show version information"
    echo ""
    echo "Examples:"
    echo "  mycommand example"
}

# Get configuration values with fallbacks
get_author_name() {
    if command -v get_config_value >/dev/null 2>&1; then
        get_config_value "AUTHOR_NAME" "Anonymous" 2>/dev/null
    else
        echo "Anonymous"
    fi
}

# Handle common flags
case "$1" in
    -v|--version) 
        echo "mycommand v$VERSION"
        exit 0 
        ;;
    -h|--help) 
        usage
        exit 0 
        ;;
esac

# Main script logic
main() {
    local author=$(get_author_name)
    echo "Hello from mycommand v$VERSION"
    echo "Author: $author"
    
    # Your script logic here
    for arg in "$@"; do
        echo "Processing: $arg"
    done
}

# Run main function with all arguments
main "$@"
```

## Configuration Integration

### Registering Configuration Keys

Create a `.msver` file for your command with configuration definitions:

```bash
# mycommand.msver
version|1.0.0|https://example.com/mycommand-1.0.0.sh|sha256:abc123...
config|MYCOMMAND_TIMEOUT|30|Timeout in seconds|network|mycommand
config|MYCOMMAND_OUTPUT_DIR|./output|Output directory|filesystem|mycommand  
config|AUTHOR_NAME||Author name for generated files|author|mycommand
```

### Using Configuration in Scripts

```bash
# Get config value with fallback
timeout=$(get_config_value "MYCOMMAND_TIMEOUT" "30" 2>/dev/null)

# Check if config value exists
if ! get_config_value "AUTHOR_NAME" >/dev/null 2>&1; then
    echo "Warning: AUTHOR_NAME not configured"
    echo "Set it with: ms config set AUTHOR_NAME 'Your Name'"
fi

# Use config value in script logic
output_dir=$(get_config_value "MYCOMMAND_OUTPUT_DIR" "./output" 2>/dev/null)
mkdir -p "$output_dir"
```

## Install/Uninstall Hooks

### Install Hook Script

Create an install hook to run setup tasks:

```bash
#!/bin/sh
# mycommand-install.sh

command_name="$1"
version="$2" 
script_path="$3"
install_dir="$4"
registry_name="$5"

echo "Setting up $command_name v$version..."

# Create necessary directories
mkdir -p "$HOME/.config/mycommand"

# Set default configuration if not exists
if ! ms config get MYCOMMAND_TIMEOUT >/dev/null 2>&1; then
    ms config set MYCOMMAND_TIMEOUT "60"
fi

# Download additional resources
curl -fsSL "https://example.com/mycommand-data.json" > "$HOME/.config/mycommand/data.json"

echo "✅ $command_name installation complete!"
```

### Uninstall Hook Script

```bash
#!/bin/sh  
# mycommand-uninstall.sh

command_name="$1"
version="$2"
script_path="$3" 
install_dir="$4"
registry_name="$5"

echo "Cleaning up $command_name v$version..."

# Remove configuration directory
rm -rf "$HOME/.config/mycommand"

# Remove configuration values (optional)
read -p "Remove $command_name configuration? [y/N] " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ms config remove MYCOMMAND_TIMEOUT
    ms config remove MYCOMMAND_OUTPUT_DIR
fi

echo "✅ $command_name cleanup complete!"
```

### Register Hooks in .msver

```bash
# mycommand.msver
version|1.0.0|https://example.com/mycommand-1.0.0.sh|sha256:abc123...
install|https://example.com/mycommand-install.sh|sha256:def456...
uninstall|https://example.com/mycommand-uninstall.sh|sha256:789abc...
config|MYCOMMAND_TIMEOUT|30|Timeout in seconds|network|mycommand
```

## Testing Your Script

### Development Setup

```bash
# Clone the Magic Scripts repository
git clone https://github.com/magic-scripts/ms.git
cd ms

# Set development environment
export MAGIC_SCRIPT_DIR="$(pwd)"

# Test your script
./ms.sh install /path/to/your/script.sh
```

### Testing Configuration

```bash
# Test config registration
./ms.sh config list -c mycommand

# Test config setting/getting
./ms.sh config set MYCOMMAND_TIMEOUT 45
./ms.sh config get MYCOMMAND_TIMEOUT

# Test in your script
mycommand --test
```

## Publishing Your Script

### 1. Create Registry Files

Create `mytools.msreg`:
```bash
mycommand|https://example.com/mycommand.msver|My awesome command|utilities
```

Create `mycommand.msver`:
```bash
version|1.0.0|https://example.com/mycommand-1.0.0.sh|sha256:checksum...
config|MYCOMMAND_TIMEOUT|30|Command timeout|network|mycommand
install|https://example.com/mycommand-install.sh|sha256:installchecksum...
uninstall|https://example.com/mycommand-uninstall.sh|sha256:uninstallchecksum...
```

### 2. Generate Checksums

```bash
# Generate SHA256 checksums
sha256sum mycommand-1.0.0.sh
sha256sum mycommand-install.sh  
sha256sum mycommand-uninstall.sh
```

### 3. Host Files

Upload all files to a web server with HTTPS support:
- `mytools.msreg`
- `mycommand.msver`  
- `mycommand-1.0.0.sh`
- `mycommand-install.sh`
- `mycommand-uninstall.sh`

### 4. Test Installation

```bash
# Add your registry
ms reg add mytools https://example.com/mytools.msreg

# Install your command
ms install mycommand

# Test it works
mycommand --help
```

## Contributing to Magic Scripts

### Development Workflow

1. Fork the repository
2. Create a feature branch from `develop`
3. Make your changes following existing patterns
4. Test thoroughly in development mode
5. Update documentation
6. Submit pull request to `develop` branch

### Code Standards

- Use POSIX shell (`#!/bin/sh`) for maximum compatibility
- Include proper error handling and user feedback
- Follow existing code style and patterns
- Add appropriate comments and documentation
- Include version information and help text

### Testing Checklist

- [ ] Script runs in development mode (`MAGIC_SCRIPT_DIR` set)
- [ ] Script works after installation (`ms install`)
- [ ] Configuration integration works correctly
- [ ] Install/uninstall hooks work properly
- [ ] Help and version flags work
- [ ] Error handling provides clear messages
- [ ] Script follows security best practices