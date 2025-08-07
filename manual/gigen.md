# GitIgnore Generator (`gigen`)

Generate and manage `.gitignore` files with template support.

## Usage

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

## Supported Templates

`node`, `python`, `go`, `rust`, `java`, `cpp`, `macos`, `linux`, `windows`, `vscode`, `idea`, `ai`, `ms`

## Configuration

- `AUTHOR_NAME` - Your name for generated files
- `AUTHOR_EMAIL` - Your email for generated files
- `GIGEN_AUTO_INIT` - Auto-initialize .gigenwhitelist on first use (default: true)
- `GIGEN_BACKUP_COUNT` - Number of .gitignore backups to keep (default: 5)

## Installation

```bash
ms install gigen
```