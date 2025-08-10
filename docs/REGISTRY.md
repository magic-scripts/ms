# Registry System

Magic Scripts uses a 2-tier registry system for command distribution that enables version management, dependency tracking, and secure command delivery.

## Registry Architecture

### Tier 1: Master Registry (`.msreg`)
Contains command listings pointing to their version files:

```
# Format: name|msver_url|description|category
gigen|https://raw.githubusercontent.com/magic-scripts/gigen/main/registry/gigen.msver|.gitignore generator|development
licgen|https://raw.githubusercontent.com/magic-scripts/licgen/main/registry/licgen.msver|License generator|development
```

### Tier 2: Version Files (`.msver`) 
Contains version history, download URLs, and metadata:

```
version|1.0.0|https://example.com/gigen-1.0.0.sh|sha256:abc123...
version|0.9.0|https://example.com/gigen-0.9.0.sh|sha256:def456...
config|AUTHOR_NAME||Author's full name|author|gigen
config|DEFAULT_LICENSE|mit|Default license type|project|gigen
```

## Registry Management

### Viewing Registries

```bash
# List all configured registries
ms reg list

# Update all registries to latest version
ms upgrade

# Show available commands across all registries
ms search
```

### Adding Custom Registries

```bash
# Add a custom registry
ms reg add mycompany https://example.com/custom.msreg

# Add with specific name
ms reg add internal https://internal.company.com/tools.msreg
```

### Removing Registries

```bash
# Remove a registry
ms reg remove mycompany

# Remove default registry (not recommended)
ms reg remove default
```

## Registry File Locations

- **Registry List**: `$HOME/.local/share/magicscripts/reg/reglist`
- **Cached Registries**: `$HOME/.local/share/magicscripts/reg/[name].msreg`
- **Development Registry**: Uses local `ms.msreg` file when `MAGIC_SCRIPT_DIR` is set

## Installation from Registries

### Install All Commands from Registry
```bash
# Install everything from default registry
ms install -r default

# Install everything from custom registry
ms install -r mycompany
```

### Install Specific Commands
```bash
# Install from any available registry
ms install gigen licgen

# Install from specific registry
ms install -r mycompany internal-tool

# Install specific versions
ms install gigen:1.0.0 licgen:2.1.0
```

## Creating Custom Registries

### 1. Create Master Registry File

```bash
# mytools.msreg
mytool|https://example.com/mytool/mytool.msver|My custom tool|utilities
anothertool|https://example.com/another/another.msver|Another tool|development
```

### 2. Create Version Files

```bash
# mytool.msver
version|1.0.0|https://example.com/mytool-1.0.0.sh|sha256:abc123def456...
version|0.9.0|https://example.com/mytool-0.9.0.sh|sha256:789abc012def...
config|MYTOOL_CONFIG|default|Configuration for mytool|tools|mytool
install|https://example.com/mytool-install.sh
uninstall|https://example.com/mytool-uninstall.sh
```

### 3. Host Files
Host your `.msreg` and `.msver` files on a web server with HTTPS support.

### 4. Register Your Registry
```bash
ms reg add mytools https://example.com/mytools.msreg
```

## Registry Security

### URL Validation
- Only HTTPS URLs are accepted for security
- HTTP URLs are automatically upgraded to HTTPS
- Malformed URLs are rejected

### Checksum Verification
- All scripts must include SHA256 checksums in version files
- Downloads are verified against checksums before installation
- Mismatched checksums result in installation failure

### Registry Authentication
- Currently uses public HTTPS endpoints
- Future versions may support authentication tokens
- Private registries require HTTPS with valid certificates

## Default Registry

The default registry is hosted at:
- **URL**: `https://raw.githubusercontent.com/magic-scripts/ms/main/registry/ms.msreg`  
- **Name**: `default`
- **Contents**: Official Magic Scripts tools

## Advanced Features

### Registry Mirroring
```bash
# Add mirror registry with same content
ms reg add mirror https://mirror.example.com/ms.msreg
```

### Development Registries
For development, set `MAGIC_SCRIPT_DIR` to use local registry files:
```bash
export MAGIC_SCRIPT_DIR="/path/to/dev/magicscripts"
ms search  # Uses local ms.msreg file
```

### Registry Priority
Registries are searched in the order they were added. Use specific registry flags (`-r`) for precise control.