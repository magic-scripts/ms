# System Architecture

This document describes the local installation structure and architecture of Magic Scripts.

## Directory Structure

```
$HOME/.local/
├── bin/ms/                           # Executable wrappers
│   ├── ms                           # Main Magic Scripts CLI
│   └── [command-wrappers]           # Individual command wrappers
└── share/magicscripts/              # Data and configuration directory
    ├── core/                        # Core system files
    │   ├── config.sh                # Configuration system
    │   └── registry.sh              # Registry system
    ├── scripts/                     # Actual script files
    │   └── [command].sh             # Downloaded script files
    ├── installed/                   # Installation metadata
    │   └── [command].msmeta         # Per-command metadata files
    └── reg/                         # Registry management
        ├── reglist                  # List of available registries
        └── [registry].msreg         # Cached registry data
```

## Component Architecture

### Wrapper System
Each installed command gets a lightweight wrapper in `$HOME/.local/bin/ms/[command]`:

```bash
#!/bin/sh
MAGIC_SCRIPT_DIR="/path/to/magicscripts"
exec "$MAGIC_SCRIPT_DIR/scripts/[command].sh" "$@"
```

**Benefits:**
- Consistent execution environment
- Easy PATH management
- Development/production mode switching

### Metadata System
Installation metadata stored in `.msmeta` files:

```ini
version=1.0.0
registry_name=default
registry_url=https://example.com/registry.msreg
checksum=sha256:abc123...
script_path=/path/to/script.sh
uninstall_script_url=https://example.com/uninstall.sh
```

**Purpose:**
- Version tracking
- Integrity verification
- Uninstallation support
- Registry association

### Registry System

#### 2-Tier Architecture
1. **Master Registry** (`.msreg`) → Lists commands and their version file URLs
2. **Version Files** (`.msver`) → Contains version history and download URLs

#### Registry List Format
```
# Format: name:url
default:https://raw.githubusercontent.com/magic-scripts/ms/main/ms.msreg
custom:https://example.com/custom.msreg
```

#### Registry Data Format
```
# Format: command|msver_url|description|category
gigen|https://raw.githubusercontent.com/magic-scripts/gigen/main/gigen.msver|.gitignore generator|development
```

## Configuration Architecture

### Configuration Sources (Priority Order)
1. **Local Project Config**: `$PWD/.msconfig`
2. **Global User Config**: `$HOME/.local/share/magicscripts/config`
3. **Registry Defaults**: Defined in `.msver` files

### Configuration Registry
Registry-defined configuration keys stored in:
`$HOME/.local/share/magicscripts/reg/config_registry`

Format: `key:default:description:category:scripts`

## Command Execution Flow

```
User Command → Wrapper Script → Environment Setup → Actual Script
     ↓              ↓               ↓                 ↓
   gigen    → ~/.local/bin/ms/ → Set MAGIC_SCRIPT_ → ~/.local/share/
             gigen              DIR environment      magicscripts/
                                                    scripts/gigen.sh
```

## Environment Variables

### Core Variables
- `MAGIC_SCRIPT_DIR`: Base data directory
- `INSTALL_DIR`: Wrapper directory (`$HOME/.local/bin/ms`)
- `REG_DIR`: Registry cache directory
- `MS_SCRIPT_ID`: Current script identifier (for config access)

### Mode Detection
- **Development**: `MAGIC_SCRIPT_DIR` points to source directory
- **Production**: `MAGIC_SCRIPT_DIR` points to `$HOME/.local/share/magicscripts`

## Security Model

### Download Security
- HTTPS-only URLs
- SHA256 checksum verification
- URL format validation

### Execution Security
- Wrapper-based execution isolation
- Controlled environment variable passing
- Script identity validation for config access

### Configuration Security
- Script-specific configuration access controls
- Registry-based key validation
- Local project config isolation

## Path Management

Magic Scripts integrates with the shell PATH by:
1. Adding `$HOME/.local/bin/ms` to PATH during installation
2. Creating executable wrappers for each command
3. Maintaining wrapper permissions and executability

This design enables:
- Global command accessibility
- Consistent command execution
- Easy installation/uninstallation
- Development workflow support

