# System Architecture

Technical overview of the Magic Scripts system architecture.

## Directory Structure

Local installation structure under `$HOME/.local/`:

```
$HOME/.local/
├── bin/ms/                           # Executable wrappers
│   ├── ms                           # Main CLI command
│   └── [command-wrappers]           # Per-command wrappers
└── share/magicscripts/              # Data directory
    ├── core/                        # Core libraries
    │   ├── config.sh               # Configuration system
    │   └── registry.sh             # Registry system
    ├── scripts/                    # Downloaded command scripts
    │   ├── ms.sh                  # Main CLI script
    │   └── [command].sh           # Individual command scripts
    ├── installed/                  # Installation metadata
    │   └── [command].msmeta       # Per-command metadata
    ├── man/                        # Man pages
    │   └── [command].1            # Man page files
    └── reg/                        # Registry cache
        ├── reglist                # Registry sources list
        ├── config_registry        # Config key registry
        └── [registry].msreg      # Cached registry files
```

---

## Wrapper System

Each installed command gets a lightweight wrapper in `~/.local/bin/ms/[command]`.

**Wrapper structure:**
```bash
#!/bin/sh
MAGIC_SCRIPT_DIR="/home/user/.local/share/magicscripts"
export MAGIC_SCRIPT_DIR
exec "$MAGIC_SCRIPT_DIR/scripts/[command].sh" "$@"
```

**Benefits:**
- Consistent execution environment
- Easy PATH management (one directory: `~/.local/bin/ms`)
- Development/production mode switching via `MAGIC_SCRIPT_DIR`
- Separation of wrapper (small, stable) from script (large, updateable)

---

## Metadata System

Installation metadata stored in `.msmeta` files under `~/.local/share/magicscripts/installed/`.

**Format:** Key=value pairs

**Example (`pgadduser.msmeta`):**
```
version=1.0.0
registry_name=ms
registry_url=https://raw.githubusercontent.com/magic-scripts/ms/main/registry/ms.msreg
checksum=a1b2c3d4
script_path=/home/user/.local/share/magicscripts/scripts/pgadduser.sh
uninstall_script_url=https://raw.githubusercontent.com/magic-scripts/pgadduser/release/v1.0.0/installer/uninstall.sh
pinned=false
```

**Fields:**
- `version` — Installed version
- `registry_name` — Source registry
- `registry_url` — Registry URL
- `checksum` — 8-char SHA256 checksum
- `script_path` — Path to installed script
- `uninstall_script_url` — URL to uninstall hook
- `pinned` — Version pin status (`true` or `false`)

**Purpose:**
- Version tracking for `ms update`
- Integrity verification for `ms doctor`
- Uninstallation support
- Registry association
- Pin management

---

## Command Execution Flow

```
User runs command:  pgadduser
         ↓
Wrapper script:     ~/.local/bin/ms/pgadduser
         ↓
Sets environment:   MAGIC_SCRIPT_DIR
         ↓
Execs main script:  ~/.local/share/magicscripts/scripts/pgadduser.sh
         ↓
Loads libraries:    config.sh, registry.sh (if needed)
         ↓
Accesses config:    get_config_value (with MS_SCRIPT_ID)
         ↓
Runs command logic
```

---

## Configuration Architecture

### Three-Tier Precedence

Configuration values are resolved in this order (highest to lowest):

1. **Local project config** — `$PWD/.msconfig` (highest priority)
2. **Global user config** — `~/.local/share/magicscripts/config`
3. **Registry defaults** — Defined in `.mspack` files (lowest priority)

### Config Registry

Available configuration keys tracked in:
```
~/.local/share/magicscripts/reg/config_registry
```

**Format:** `key:default:description:category:scripts`

**Example:**
```
DB_HOST:localhost:Database host:database:pgadduser
AUTHOR_NAME::Author's full name:author:pgadduser,mschecksum
```

### Access Control

Scripts declare identity via `MS_SCRIPT_ID`:
```bash
export MS_SCRIPT_ID="pgadduser"
```

The config system enforces:
- Scripts can only access keys they've registered
- The `ms` command has full access to all keys
- Unregistered keys are rejected

---

## Environment Variables

### Core Variables

| Variable | Description | Set By |
|----------|-------------|--------|
| `MAGIC_SCRIPT_DIR` | Base data directory or source directory | Wrapper or user |
| `INSTALL_DIR` | Wrapper directory (`~/.local/bin/ms`) | Core scripts |
| `REG_DIR` | Registry cache directory | Core scripts |
| `MS_SCRIPT_ID` | Current script identifier | Command scripts |

### Mode Detection

**Production Mode:**
```bash
MAGIC_SCRIPT_DIR="$HOME/.local/share/magicscripts"
```

**Development Mode:**
```bash
export MAGIC_SCRIPT_DIR="/path/to/dev/ms"
./ms/scripts/ms.sh <command>
```

When `MAGIC_SCRIPT_DIR` points to a source directory:
- Uses local files instead of installed files
- Skips checksum verification for development
- Allows testing without installation

---

## Core Libraries

### ms.sh

Main CLI entry point (~4500 lines).

**Location:** `~/.local/share/magicscripts/scripts/ms.sh`

**Handles all subcommands:**
- Core: `help`, `version`, `status`, `doctor`
- Registry: `upgrade`, `search`, `reg`
- Package: `install`, `uninstall`, `update`, `reinstall`, `versions`, `info`
- Maintenance: `outdated`, `which`, `pin`, `unpin`, `clean`, `run`
- Data: `export`, `import`
- Config: `config list/set/get/remove`
- Pack (dev): `pack init/checksum/verify/version/reg/release`

### config.sh

Configuration management library.

**Location:** `~/.local/share/magicscripts/core/config.sh`

**Key functions:**
- `get_config_value(key, default)` — Retrieve config with fallback
- Precedence resolution (local > global > registry)
- Access control enforcement (via `MS_SCRIPT_ID`)
- Config registry management

### registry.sh

Registry system library.

**Location:** `~/.local/share/magicscripts/core/registry.sh`

**Key functions:**
- Registry list management
- Downloading and caching registry files
- Parsing `.msreg`, `.mspack`, `.msver` files
- URL validation (HTTPS-only)
- Checksum verification (SHA256)
- Format auto-detection (3-tier vs 2-tier)

---

## Security Model

### Download Security

**HTTPS-only URLs:**
- All downloads require HTTPS
- HTTP URLs are rejected
- URL format validation

**Checksum verification:**
- SHA256 checksums (8-char prefix)
- All downloads verified before use
- Mismatched checksums abort installation
- Development versions (`dev`) skip verification
- **Exception:** The `ms` core itself skips file-level checksum verification and relies on HTTPS transport security instead (same trust model as `ms update ms` self-update flow)

### Execution Security

**Wrapper-based isolation:**
- Controlled environment variable passing
- Consistent execution context
- No direct shell sourcing of downloaded scripts

**Script identity:**
- Scripts declare `MS_SCRIPT_ID`
- Config access validated against registry
- Prevents unauthorized config access

### Configuration Security

**Access control:**
- Script-specific configuration access
- Registry-based key validation
- Local project config isolation

---

## Branch Strategy for Releases

### Branch Roles

| Branch | Purpose | Mutability |
|--------|---------|------------|
| `develop` | Active development | Mutable |
| `main` | Latest stable release | Mutable |
| `release/vX.X.X` | Immutable version snapshots | Immutable |

### Release Workflow

1. Develop on `develop` branch
2. `ms pub pack release` creates `release/v<version>` branch
3. Release branch merged to `main`
4. `develop` synced with `main`
5. Registry URLs point to `release/v<version>` (immutable)

**Why immutable release branches?**
- Reproducible installations
- Version consistency
- Long-term stability

---

## Path Management

Magic Scripts integrates with the shell PATH by:

1. Adding `~/.local/bin/ms` to PATH during installation
2. Creating executable wrappers for each command
3. Maintaining wrapper permissions (755)

**Shell integration:**
```bash
export PATH="$HOME/.local/bin/ms:$PATH"
```

**Benefits:**
- Global command accessibility
- Consistent command execution
- Easy installation/uninstallation
- Development workflow support

---

## Design Principles

1. **POSIX compliance** — All scripts use `#!/bin/sh` for maximum compatibility
2. **No build step** — All code is production-ready shell script
3. **Minimal dependencies** — Only requires basic POSIX tools
4. **Secure by default** — HTTPS-only, checksum verification
5. **User-friendly** — Clear error messages, helpful hints
6. **Developer-friendly** — Local testing support, clear conventions
7. **Backwards compatible** — Legacy format support, graceful degradation
