# Publishing Magic Scripts Commands

Complete reference for the `ms pub pack` developer toolchain.

## Overview

The `ms pub pack` command groups all developer/publishing tools:
- `init` — Scaffold new project
- `checksum` — Calculate SHA256 checksums
- `verify` — Validate registry files
- `version` — Manage version entries
- `reg` — Manage registry entries
- `release` — Automated release workflow

## Commands

### `ms pub pack init <name> [options]`

Create a new command project scaffold with git initialization.

**Usage:**
```bash
ms pub pack init <name> [options]
```

**Options:**
- `--author <name>` — Author name (default: config `MS_AUTHOR_NAME`)
- `--email <email>` — Author email (default: config `MS_AUTHOR_EMAIL`)
- `--license <type>` — License type (default: `MIT`)
- `--description <text>` — Project description (default: project name)
- `--category <cat>` — Category (default: `utility`)
- `--remote <url>` — Remote repository URL (optional)
- `-y, --yes` — Skip interactive prompts, use defaults

**Behavior:**
- **Parameter mode**: Options provided via flags are used directly
- **Interactive mode**: Missing values prompt interactively (unless `-y` is set)
- **Default values**: Author/email use config values as defaults

**What it creates:**
```
mycommand/
├── scripts/mycommand.sh          # Main script (executable)
├── registry/mycommand.mspack     # Package manifest (with provided metadata)
├── registry/mycommand.msver      # Version tree
├── installer/install.sh          # Install hook (executable)
├── installer/uninstall.sh        # Uninstall hook (executable)
├── man/                          # Man pages directory
└── .gitignore                    # Git ignore file
```

**Git setup:**
- Initializes git repository
- Creates `main` branch with initial commit
- Creates and switches to `develop` branch
- URLs in `.msver` point to `develop` branch
- If `--remote` is provided, adds remote and pushes both branches

**Examples:**

**Interactive mode (prompts for metadata):**
```bash
$ ms pub pack init mycommand
Author name [Your Name]: John Doe
Author email [your@email.com]: john@example.com
License [MIT]:
Description [mycommand]: My awesome command
Category [utility]: development
Remote repository URL (optional, press enter to skip):

Creating project 'mycommand'...
```

**Non-interactive mode (all defaults):**
```bash
$ ms pub pack init mycommand -y
```

**Parameter mode (no prompts):**
```bash
$ ms pub pack init mycommand \
  --author "John Doe" \
  --email "john@example.com" \
  --description "My awesome command" \
  --category development \
  -y
```

**With remote (auto-push to GitHub):**
```bash
$ ms pub pack init mycommand \
  --remote https://github.com/user/mycommand.git \
  -y

Git initialized with branches and remote:
  main     <- initial commit
  develop  <- current branch (active development)
  origin   <- https://github.com/user/mycommand.git

Pushing to remote...
Successfully pushed to remote!
```

**Next steps:**
```bash
cd mycommand
# Edit scripts/mycommand.sh with your command logic
ms pub pack verify registry/
ms pub pack release registry/ 0.1.0
```

---

### `ms pub pack checksum <file>`

Calculate 8-character SHA256 checksum for a file.

**Usage:**
```bash
ms pub pack checksum <file>
```

**Example:**
```bash
$ ms pub pack checksum scripts/mycommand.sh
File:     scripts/mycommand.sh
Checksum: a1b2c3d4
```

---

### `ms pub pack verify <directory>`

Validate registry files in a directory.

**Usage:**
```bash
ms pub pack verify <directory>
```

**Checks:**
- `.mspack` format and required fields
- `.msver` format and version entries
- URL formats (HTTPS-only)
- Field consistency

**Example:**
```bash
$ ms pub pack verify registry/
Verifying registry files in: registry/

Checking: mycommand.mspack (package manifest)
  OK
Checking: mycommand.msver (version file)
  Found 1 version(s)
  OK

Files checked: 2
All checks passed
```

---

### `ms pub pack version add`

Add a new version entry to a `.msver` file.

**Usage:**
```bash
ms pub pack version add <msver_file> <version> <script_url> [options]
```

**Options:**
- `--checksum-from <file>` — Calculate checksum from local file
- `--install <url>` — Install hook script URL
- `--uninstall <url>` — Uninstall hook script URL
- `--update <url>` — Update hook script URL
- `--man <url>` — Man page URL

**Behavior:**
- If `<script_url>` is a local file, checksum is auto-calculated
- For remote URLs, `--checksum-from` is required

**Examples:**
```bash
# Local file (checksum auto-calculated)
ms pub pack version add registry/mycommand.msver 1.0.0 scripts/mycommand.sh

# Remote URL (requires --checksum-from)
ms pub pack version add registry/mycommand.msver 1.0.0 \
  https://example.com/mycommand.sh \
  --checksum-from scripts/mycommand.sh

# With hooks
ms pub pack version add registry/mycommand.msver 1.0.0 scripts/mycommand.sh \
  --install installer/install.sh \
  --uninstall installer/uninstall.sh
```

---

### `ms pub pack version update`

Update the checksum for an existing version entry.

**Usage:**
```bash
ms pub pack version update <msver_file> <version> --checksum-from <file>
```

**Example:**
```bash
ms pub pack version update registry/mycommand.msver 1.0.0 --checksum-from scripts/mycommand.sh
```

---

### `ms pub reg add`

Add an entry to a `.msreg` master registry file.

**Usage:**
```bash
ms pub reg add <msreg_file> <name> <mspack_url> <description> <category>
```

**Format:** `name|mspack_url|description|category`

**Example:**
```bash
ms pub reg add registry/ms.msreg mycommand \
  https://raw.githubusercontent.com/you/mycommand/release/v1.0.0/registry/mycommand.mspack \
  'My awesome command' \
  utilities
```

---

### `ms pub reg remove`

Remove an entry from a `.msreg` file.

**Usage:**
```bash
ms pub reg remove <msreg_file> <name>
```

**Example:**
```bash
ms pub reg remove registry/ms.msreg mycommand
```

---

### `ms pub pack release <dir> <version>`

Automated version release workflow with full git-flow integration.

**Usage:**
```bash
ms pub pack release <registry_dir> <version> [options]
```

**Options:**
- `--checksum-from <file>` — Script file path (auto-detects from `../scripts/` if not specified)
- `--push` — Push all branches to origin (release, main, develop)
- `--no-git` — Skip all git operations, only update `.msver`

**Requirements:**
- Must be on `develop` branch (unless `--no-git`)
- Git must be installed (unless `--no-git`)

**Full Git Workflow (default):**
1. Verify registry files (`pack_verify`)
2. Calculate checksum (auto-detects script in `../scripts/`)
3. **Rewrite URLs**: `/develop/` or `/main/` → `/release/v<version>/`
4. Register version in `.msver` file
5. Create `release/v<version>` branch and commit
6. Checkout `main` and merge release branch
7. Return to `develop` and sync from main
8. [if `--push`] Push release, main, develop branches to origin

**URL Rewriting:**

The release process automatically rewrites URLs to point to immutable release branches:

Before (develop):
```
version|dev|https://raw.githubusercontent.com/you/mycommand/develop/scripts/mycommand.sh|dev|...
```

After release 1.0.0:
```
version|1.0.0|https://raw.githubusercontent.com/you/mycommand/release/v1.0.0/scripts/mycommand.sh|a1b2c3d4|...
```

**Examples:**
```bash
# Full release workflow (from develop branch)
ms pub pack release registry/ 1.0.0

# With push to remote
ms pub pack release registry/ 1.0.0 --push

# Skip git operations
ms pub pack release registry/ 1.0.0 --no-git

# Custom script location
ms pub pack release registry/ 1.0.0 --checksum-from scripts/custom.sh
```

**Branch State After Release:**

```
main           ← merged with release/v1.0.0
develop        ← current branch, synced with main
release/v1.0.0 ← immutable snapshot
```

---

## Typical Development Workflow

End-to-end example:

```bash
# 1. Create project
ms pub pack init mycommand
cd mycommand

# 2. Develop on develop branch (git already set up)
# Edit scripts/mycommand.sh
# Edit registry/mycommand.mspack

# 3. Verify before releasing
ms pub pack verify registry/

# 4. Release version 0.1.0
ms pub pack release registry/ 0.1.0

# 5. Push to GitHub (creates immutable release branch)
ms pub pack release registry/ 0.1.0 --push

# Continue development
git checkout develop
# Edit scripts/mycommand.sh

# Release 0.2.0
ms pub pack release registry/ 0.2.0 --push
```

## Registry URLs and Branches

**During Development:**
- Work on `develop` branch
- URLs in `.msver` point to `/develop/`
- Use `version|dev|url|dev` for development version

**For Releases:**
- `ms pub pack release` creates `release/v<version>` branch
- URLs are rewritten to `/release/v<version>/`
- Release branches are immutable references
- `main` branch tracks latest stable release

**Why this matters:**
- `develop` and `main` branches are mutable (change over time)
- `release/v<version>` branches are immutable (frozen snapshots)
- Registry URLs must point to immutable references to ensure reproducible installs

---

## Registry File Management (`ms pub reg`)

The `ms pub reg` command set provides tools for creating and managing `.msreg` master registry files.

### `ms pub reg init <name> [options]`

Create a new .msreg registry file with proper header and format.

**Usage:**
```bash
ms pub reg init <name> [--description <text>] [-y]
```

**Options:**
- `--description <text>` — Registry description (default: "<name> registry")
- `-y, --yes` — Skip interactive prompts

**Behavior:**
- Creates file in `registry/` if directory exists, otherwise in current directory
- Adds proper header comments and format documentation
- Interactive mode prompts for description

**Examples:**
```bash
# Interactive mode
ms pub reg init custom
Registry description [custom registry]: My custom registry
Created registry file: registry/custom.msreg

# Non-interactive
ms pub reg init custom --description "My custom registry" -y
```

---

### `ms pub reg add <name> [options]`

Add an entry to a .msreg registry file.

**Usage:**
```bash
ms pub reg add <name> [options]
```

**Options:**
- `--file <path>` — Specific .msreg file (auto-detected if omitted)
- `--url <mspack_url>` — Package manifest URL (required)
- `--description <text>` — Command description (default: command name)
- `--category <cat>` — Category (default: utilities)
- `-y, --yes` — Skip interactive prompts

**File Auto-Detection:**
1. Searches `registry/*.msreg`
2. Falls back to `./*.msreg`
3. If multiple found, prompts for selection
4. Use `--file` to override

**Interactive Mode:**
- Prompts for: URL (required), description, category
- Use `-y` to accept defaults

**Examples:**
```bash
# Interactive mode (auto-detect file)
ms pub reg add mycommand
Using registry file: registry/custom.msreg
Package URL (mspack): https://example.com/mycommand.mspack
Description [mycommand]: My awesome command
Category [utilities]: development

# Parameter mode
ms pub reg add mycommand \
  --file registry/custom.msreg \
  --url https://example.com/mycommand.mspack \
  --description "My awesome command" \
  --category development \
  -y

# With auto-detection
ms pub reg add mycommand \
  --url https://example.com/mycommand.mspack \
  -y
```

---

### `ms pub reg remove <name> [options]`

Remove an entry from a .msreg file.

**Usage:**
```bash
ms pub reg remove <name> [--file <path>]
```

**Options:**
- `--file <path>` — Specific .msreg file (auto-detected if omitted)

**Examples:**
```bash
# Auto-detect file
ms pub reg remove mycommand

# Specific file
ms pub reg remove mycommand --file registry/custom.msreg
```

---

## Help

Run `ms pub pack <command> --help` for detailed help on any subcommand.
