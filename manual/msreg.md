# Registry Manager (`msreg`)

Manage Magic Scripts registry files with automatic checksum calculation.

## Usage

```bash
# Calculate file checksum
msreg checksum scripts/my-script.sh

# Add script to registry  
msreg -f core/ms.msreg add myscript:1.0.0 https://example.com/myscript.sh

# Add dev version with dev checksum (skips download)
msreg -f core/ms.msreg add myscript:dev https://example.com/myscript.sh --dev-checksum

# Remove script from registry
msreg -f core/ms.msreg remove myscript:1.0.0

# Show version
msreg --version
```

## Commands

### `checksum <file>`
Calculate SHA256 checksum for a file (first 8 characters)

### `add <name:version> <url> [--dev-checksum]`
Add a script to the registry with automatic checksum calculation:
1. Downloads the script from the provided URL (unless `--dev-checksum` is used)
2. Calculates SHA256 checksum or uses "dev" checksum
3. Prompts for description, category, and script path
4. Adds entry to the registry file
5. Prevents duplicates (same command:version combinations)

**Options:**
- `--dev-checksum`: Use "dev" as checksum (skips download and verification, for development versions)

### `remove <name:version>`
Remove a specific script version from the registry

## Features

- **Automatic SHA256 checksum calculation**
- **Duplicate prevention** (command:version combinations)
- **Interactive prompts** for metadata
- **Registry file validation**
- **URL downloading** and verification

## Example Workflow

### Adding release version
```bash
$ msreg -f core/ms.msreg add gigen:2.0.0 https://example.com/gigen.sh
Downloading https://example.com/gigen.sh...
Description: Advanced gitignore generator
Category: development  
Script path (relative to MAGIC_SCRIPT_DIR): scripts/gitignore-gen.sh
✓ Added gigen:2.0.0 to registry
  Checksum: a1b2c3d4
  Entry: gigen|scripts/gitignore-gen.sh|Advanced gitignore generator|development|2.0.0|a1b2c3d4
```

### Adding dev version
```bash
$ msreg -f core/ms.msreg add gigen:dev https://example.com/gigen.sh --dev-checksum
Using dev checksum (skipping download and verification)
Description: Advanced gitignore generator (dev)
Category: development  
Script path (relative to MAGIC_SCRIPT_DIR): scripts/gitignore-gen.sh
✓ Added gigen:dev to registry
  Checksum: dev
  Entry: gigen|scripts/gitignore-gen.sh|Advanced gitignore generator (dev)|development|dev|dev
```

## Checksum Calculation

Magic Scripts uses SHA256 checksums for integrity verification:
- **Algorithm**: SHA256  
- **Format**: First 8 characters of hex digest
- **Purpose**: Verify script integrity during installation
- **Tools**: Uses `sha256sum`, `shasum`, or `openssl` (in order of preference)

## Registry File Format

Registry files (`.msreg`) use pipe-delimited format:

```
command|name|script_uri|description|category|version|checksum
config|key|default_value|description|category|scripts
```

## Installation

```bash
ms install msreg
```