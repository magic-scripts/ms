# Registry System Deep Dive

Technical documentation for the Magic Scripts 3-tier registry system.

## Architecture Overview

Magic Scripts uses a 3-tier registry system for command distribution:

1. **Tier 1 — Master Registry (`.msreg`)**: Index of available commands with pointers to package manifests
2. **Tier 2 — Package Manifest (`.mspack`)**: Package metadata, configuration keys, and link to version file
3. **Tier 3 — Version Files (`.msver`)**: Version history, download URLs, checksums, and hooks

## File Formats

### .msreg Format

Master registry file listing available commands.

**Format:** `name|mspack_url|description|category`

**Example:**
```
pgadduser|https://raw.githubusercontent.com/magic-scripts/pgadduser/release/v1.0.0/registry/pgadduser.mspack|PostgreSQL user/database setup|database
mschecksum|https://raw.githubusercontent.com/magic-scripts/mschecksum/release/v1.0.0/registry/mschecksum.mspack|SHA256 checksum calculator|utilities
```

**Fields:**
1. `name` — Command name (must match package name)
2. `mspack_url` — HTTPS URL to `.mspack` file
3. `description` — One-line description
4. `category` — Category (e.g., `database`, `utilities`, `development`)

---

### .mspack Format

Package manifest containing metadata and configuration.

**Format:** Pipe-delimited `type|field1|field2|...`

**Required fields:**
```
name|mycommand
description|Command description
author|Your Name <you@example.com>
license|MIT
msver_url|https://raw.githubusercontent.com/you/mycommand/main/registry/mycommand.msver
```

**Optional fields:**
```
license_url|https://github.com/you/mycommand/blob/main/LICENSE
repo_url|https://github.com/you/mycommand
issues_url|https://github.com/you/mycommand/issues
stability|stable
min_ms_version|0.0.1
```

**Configuration keys:**
```
config|KEY_NAME|default_value|Description text|category|script_name
```

**Complete example:**
```
name|mycommand
description|My awesome command
author|Developer Name <dev@example.com>
license|MIT
license_url|https://github.com/magic-scripts/mycommand/blob/main/LICENSE
repo_url|https://github.com/magic-scripts/mycommand
issues_url|https://github.com/magic-scripts/mycommand/issues
stability|stable
min_ms_version|0.0.1
msver_url|https://raw.githubusercontent.com/magic-scripts/mycommand/release/v1.0.0/registry/mycommand.msver
config|MYCOMMAND_TIMEOUT|30|Command timeout in seconds|network|mycommand
config|MYCOMMAND_OUTPUT_DIR|./output|Output directory path|filesystem|mycommand
```

**Field details:**

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Package name |
| `description` | Yes | One-line description |
| `author` | Yes | Author name and email |
| `license` | Yes | License type (MIT, Apache, GPL, etc.) |
| `msver_url` | Yes | URL to `.msver` file |
| `license_url` | No | URL to full license text |
| `repo_url` | No | Repository URL |
| `issues_url` | No | Issue tracker URL |
| `stability` | No | `stable`, `beta`, `alpha`, `experimental` |
| `min_ms_version` | No | Minimum Magic Scripts version required |

**Config line format:**
```
config|KEY|default|description|category|script_name
```

- `KEY` — Configuration key name (UPPER_CASE)
- `default` — Default value (empty string if none)
- `description` — Human-readable description
- `category` — `author`, `database`, `network`, `filesystem`, `project`, `settings`
- `script_name` — Script that can access this key

---

### .msver Format

Version file containing version history and download information.

**Format:** `version|ver_name|download_url|checksum|install_script|uninstall_script|update_script|man_url`

**All 8 fields are pipe-delimited on a single line.**

**Field details:**

| Position | Field | Description |
|----------|-------|-------------|
| 1 | `version` | Literal string "version" |
| 2 | `ver_name` | Version name (e.g., `1.0.0`, `dev`) |
| 3 | `download_url` | HTTPS URL to script file |
| 4 | `checksum` | 8-char SHA256 prefix or `dev` |
| 5 | `install_script` | HTTPS URL to install hook (optional) |
| 6 | `uninstall_script` | HTTPS URL to uninstall hook (optional) |
| 7 | `update_script` | HTTPS URL to update hook (optional) |
| 8 | `man_url` | HTTPS URL to man page (optional) |

**Example:**
```
# mycommand Version Tree
# Format: version|ver_name|download_url|checksum|install_script|uninstall_script|update_script|man_url
version|1.0.0|https://raw.githubusercontent.com/you/mycommand/release/v1.0.0/scripts/mycommand.sh|a1b2c3d4|https://raw.githubusercontent.com/you/mycommand/release/v1.0.0/installer/install.sh|https://raw.githubusercontent.com/you/mycommand/release/v1.0.0/installer/uninstall.sh||https://raw.githubusercontent.com/you/mycommand/release/v1.0.0/man/mycommand.1
version|dev|https://raw.githubusercontent.com/you/mycommand/develop/scripts/mycommand.sh|dev|https://raw.githubusercontent.com/you/mycommand/develop/installer/install.sh|https://raw.githubusercontent.com/you/mycommand/develop/installer/uninstall.sh||
```

**Trailing fields can be empty** — just include the pipe delimiter.

---

## Format Auto-Detection

The parser distinguishes between 3-tier (`.mspack`) and legacy 2-tier (`.msver`) formats:

**Detection logic:**
- If a file contains an `msver_url|` line, it's treated as a `.mspack` (3-tier)
- Otherwise, it's treated as a legacy `.msver` (2-tier)

This provides backward compatibility with older registries.

---

## URL Branch Strategy

### Development Phase

- Work on `develop` branch
- URLs point to `/develop/` paths
- Use `dev` as checksum (skips verification)

```
version|dev|https://raw.githubusercontent.com/you/mycommand/develop/scripts/mycommand.sh|dev|...
```

### Release Phase

- `ms pub pack release` creates `release/v<version>` branch
- URLs are automatically rewritten to `/release/v<version>/` paths
- Checksum is calculated and included

```
version|1.0.0|https://raw.githubusercontent.com/you/mycommand/release/v1.0.0/scripts/mycommand.sh|a1b2c3d4|...
```

### Why Immutable Branches?

**Problem:** `main` and `develop` branches are mutable (they change over time).

**Solution:** Release branches like `release/v1.0.0` are immutable snapshots.

**Benefit:** Users installing `mycommand:1.0.0` six months from now get exactly the same files as users installing it today.

---

## Checksum Format

Magic Scripts uses **8-character SHA256 prefixes** for checksums.

**Calculate with `ms pub pack checksum`:**
```bash
$ ms pub pack checksum scripts/mycommand.sh
File:     scripts/mycommand.sh
Checksum: a1b2c3d4
```

**Special value:** `dev` skips checksum verification (for development).

**Full SHA256 to 8-char:**
```
Full:   a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6
Prefix: a1b2c3d4
```

---

## Creating a Custom Registry

### Step 1: Create Files

Create the 3-tier file structure:

**mytools.msreg:**
```
mytool|https://example.com/mytool/mytool.mspack|My custom tool|utilities
```

**mytool.mspack:**
```
name|mytool
description|My custom tool description
author|Your Name <you@example.com>
license|MIT
repo_url|https://github.com/you/mytool
stability|stable
min_ms_version|0.0.1
msver_url|https://example.com/mytool/mytool.msver
config|MYTOOL_CONFIG|default|Configuration for mytool|settings|mytool
```

**mytool.msver:**
```
version|1.0.0|https://example.com/mytool-1.0.0.sh|a1b2c3d4|https://example.com/mytool-install.sh|https://example.com/mytool-uninstall.sh||
```

### Step 2: Host Files

Upload to a web server with HTTPS support:
- `mytools.msreg`
- `mytool.mspack`
- `mytool.msver`
- `mytool-1.0.0.sh`
- `mytool-install.sh`
- `mytool-uninstall.sh`

### Step 3: Register

```bash
ms reg add mytools https://example.com/mytools.msreg
ms upgrade
ms install mytool
```

---

## Registry Management

### Local Cache

Registries are cached at:
```
$HOME/.local/share/magicscripts/reg/
├── reglist                    # Registry sources
├── config_registry            # Config key registry
└── [registry_name].msreg     # Cached registry files
```

### Refresh Cache

```bash
ms upgrade
```

### Development Mode

When `MAGIC_SCRIPT_DIR` is set, uses local registry files instead of remote:

```bash
export MAGIC_SCRIPT_DIR="/path/to/dev/ms"
ms search  # Uses local ms.msreg file
```

---

## Security

### HTTPS-Only

All URLs must use HTTPS. HTTP URLs are rejected.

### Checksum Verification

All downloads are verified against SHA256 checksums (8-char prefix).

**Exception:** Development versions using `dev` checksum skip verification.

### URL Validation

- Protocol must be `https://`
- URLs must be well-formed
- No local file paths allowed in production registries

---

## Backward Compatibility

### Legacy 2-Tier Format

Older registries used a 2-tier format where `.msreg` pointed directly to `.msver` files that contained both config keys and version entries.

**Still supported:** The parser auto-detects and handles legacy format transparently.

**Migration:** Not required. Old registries continue to work.

---

## Best Practices

1. **Use release branches** for immutable version references
2. **Calculate checksums** for all release versions (no `dev`)
3. **Validate files** with `ms pub pack verify` before publishing
4. **Use HTTPS** for all URLs
5. **Document config keys** with clear descriptions
6. **Set stability** appropriately (`stable` for production-ready)
7. **Test locally** before publishing to registry
