# Magic Scripts Command Handler Modules

This directory contains command handler modules for Magic Scripts. These modules implement the core commands (`install`, `uninstall`, `update`, `info`, `doctor`, etc.) and are loaded at startup.

## Module Overview

### install.sh (811 lines)
**Installation Operations**

Core installation logic including script downloads, hook execution, and registry-wide installations.

**Functions:**
- `execute_hook(hook_url, [args...])` - Execute install/uninstall/update hooks
- `install_script(cmd, script_uri, registry_name, version, [force_flag], [install_hook], [uninstall_hook], [update_hook], [man_url])` - Core installation (262 lines)
- `install_registry_all(registry_name)` - Install all commands from a registry
- `install_commands_with_detection(commands...)` - Install with multi-registry detection
- `handle_install([options] [commands...])` - Main install command handler

**Dependencies:**
- registry.sh: `get_command_info()`, `get_registry_commands()`, `download_file()`
- metadata.sh: `metadata_set()`, `metadata_remove()`
- version.sh: `version_get_installed()`, `version_get_registry()`, `version_calculate_checksum()`, `version_verify_checksum()`
- ms.sh: colors, `ms_error()`, `format_version()`

**Usage:**
```sh
ms install pgadduser
ms install -r ms
ms install gigen:1.0.0
```

### uninstall.sh (303 lines)
**Uninstall Operations**

Command removal including hook execution and metadata cleanup.

**Functions:**
- `handle_uninstall(commands...)` - Main uninstall command handler (284 lines)

**Special cases:**
- `ms uninstall ms` - Interactive core removal with safety prompts
- `ms uninstall --all` - Remove entire Magic Scripts installation

**Dependencies:**
- install.sh: `execute_hook()`
- metadata.sh: `metadata_get()`, `metadata_remove()`
- registry.sh: `get_all_commands()`, `ms_internal_get_script_info()`
- ms.sh: colors, `ms_error()`

**Usage:**
```sh
ms uninstall pgadduser
ms uninstall ms
ms uninstall --all
```

### update.sh (393 lines)
**Update Operations**

Command updates, bulk updates, and Magic Scripts core updates.

**Functions:**
- `handle_update([commands...])` - Main update command handler
- `handle_ms_force_reinstall()` - Reinstall Magic Scripts core

**Features:**
- Single command update: `ms update pgadduser`
- All commands update: `ms update` (no args)
- Core self-update: `ms update ms`
- Version comparison and skip if up-to-date

**Dependencies:**
- install.sh: `install_script()`
- metadata.sh: `metadata_get()`, `metadata_set()`
- version.sh: `version_get_installed()`, `version_get_registry()`, `version_compare()`
- registry.sh: `download_file()`, `ms_internal_get_script_info()`, `get_script_info()`
- ms.sh: colors, `ms_error()`, `format_version()`

**Usage:**
```sh
ms update              # Update all
ms update pgadduser    # Update specific command
ms update ms           # Update core
```

### query.sh (442 lines)
**Query and Information Commands**

Command information, location, version history, and outdated detection.

**Functions:**
- `handle_info(cmd)` - Show detailed command information (90 lines)
- `handle_which(cmd)` - Show command location (62 lines)
- `handle_outdated()` - List outdated commands (78 lines)
- `handle_versions(cmd|--all|-r registry)` - Show version history (187 lines)

**Dependencies:**
- metadata.sh: `metadata_get()`
- version.sh: `version_get_installed()`, `version_get_registry()`, `version_compare()`
- registry.sh: `get_command_info()`, `get_all_commands()`
- ms.sh: colors, `ms_error()`, `format_version()`

**Usage:**
```sh
ms info pgadduser
ms which pgadduser
ms outdated
ms versions pgadduser
ms versions --all
```

### maintenance.sh (672 lines)
**Maintenance and Utility Operations**

System maintenance, diagnostics, pinning, and import/export.

**Functions:**
- `handle_pin(cmd)` - Pin command to prevent updates (81 lines)
- `handle_unpin(cmd)` - Unpin command (39 lines)
- `handle_doctor()` - System diagnostics (296 lines)
- `handle_clean()` - Clean caches and temp files (84 lines)
- `handle_export([--file file])` - Export installed commands (47 lines)
- `handle_import(file)` - Import and install from export (97 lines)

**Dependencies:**
- metadata.sh: `metadata_get()`, `metadata_update_key()`
- version.sh: `version_get_installed()`, `version_verify_checksum()`
- registry.sh: `get_all_commands()`
- ms.sh: colors, `ms_error()`, `format_version()`

**Usage:**
```sh
ms pin pgadduser       # Prevent updates
ms unpin pgadduser     # Allow updates
ms doctor              # Run diagnostics
ms clean               # Clean caches
ms export backup.txt   # Export installed commands
ms import backup.txt   # Import and install
```

## Loading Order

All lib modules are loaded eagerly at startup by ms.sh:

```sh
for lib in install.sh uninstall.sh update.sh query.sh maintenance.sh; do
    if [ -f "$MAGIC_SCRIPT_DIR/lib/$lib" ]; then
        . "$MAGIC_SCRIPT_DIR/lib/$lib"
    elif [ -f "$SCRIPT_DIR/../lib/$lib" ]; then
        . "$SCRIPT_DIR/../lib/$lib"
    fi
done
```

**Why eager loading:**
- All modules are frequently used
- Total overhead is acceptable (~70ms)
- Simplifies code - all functions always available

## Module Dependencies Graph

```
install.sh (foundational)
    ├─ execute_hook() ──> used by uninstall.sh, update.sh
    └─ install_script() ──> used by update.sh

uninstall.sh
    └─ uses execute_hook() from install.sh

update.sh
    └─ uses install_script() from install.sh

query.sh (independent)

maintenance.sh (independent)
```

**Key insight:** install.sh is foundational and must be loaded first.

## Handler Function Pattern

All handlers follow a consistent pattern:

```sh
handle_command() {
    # 1. Parse arguments and options
    case "$1" in
        -h|--help|help)
            # Show help and return
            return 0
            ;;
        # ... other options
    esac

    # 2. Validate inputs
    if [ -z "$required_arg" ]; then
        ms_error "Error message" "Hint"
        return 1
    fi

    # 3. Check dependencies
    if ! command -v required_function >/dev/null 2>&1; then
        ms_error "Dependency not available"
        return 1
    fi

    # 4. Execute main logic
    # ... implementation ...

    # 5. Report results
    echo "${GREEN}Success${NC}"
    return 0
}
```

## Return Code Conventions

```sh
0   # Success
1   # Error (general)
2   # Special case (e.g., already installed, skip)
3+  # Module-specific codes (documented in function)
```

## Error Handling

Consistent error handling across all modules:

```sh
# Check and report errors explicitly
if ! some_operation; then
    ms_error "Operation failed" "Try this instead"
    return 1
fi

# Use cleanup traps
local temp_file=$(mktemp) || return 1
trap 'rm -f "$temp_file"' EXIT INT TERM

# Never use set -e (breaks in sourced files)
```

## Adding New Command Handlers

To add a new command handler:

1. **Create the handler file:** `ms/lib/newcmd.sh`
   ```sh
   #!/bin/sh
   # Magic Scripts - New Command Module
   #
   # Description
   #
   # Dependencies:
   #   - List all dependencies
   #
   # Functions:
   #   - handle_newcmd() Main handler

   handle_newcmd() {
       # Implementation
   }
   ```

2. **Add to lib loading in ms.sh:**
   ```sh
   for lib in install.sh uninstall.sh update.sh query.sh maintenance.sh newcmd.sh; do
       # ... loading code
   done
   ```

3. **Add dispatcher case in ms.sh:**
   ```sh
   case "$1" in
       # ... existing cases
       newcmd)
           shift
           handle_newcmd "$@"
           ;;
   esac
   ```

4. **Update help text in ms.sh**

5. **Test thoroughly:**
   ```sh
   export MAGIC_SCRIPT_DIR="$(pwd)/ms"
   ./ms/scripts/ms.sh newcmd --help
   ./ms/scripts/ms.sh newcmd arg1 arg2
   ```

## Testing Command Handlers

```sh
# Source all dependencies
export MAGIC_SCRIPT_DIR="$(pwd)/ms"
. ms/core/config.sh
. ms/core/registry.sh
. ms/core/metadata.sh
. ms/core/version.sh
. ms/lib/install.sh

# Test individual functions
handle_install pgadduser
handle_info pgadduser
```

## Performance

Command handler loading time:
- install.sh: ~12ms
- uninstall.sh: ~5ms
- update.sh: ~6ms
- query.sh: ~7ms
- maintenance.sh: ~10ms
- **Total: ~40ms** (acceptable overhead)

## Special Considerations

### execute_hook() Placement

`execute_hook()` is in install.sh (not a separate utils module) because:
1. Most commonly used during installation
2. Also needed by uninstall and update (they source install.sh)
3. Keeps module count manageable

### Reinstall Mode

When updating Magic Scripts core, `MS_REINSTALL_MODE=true` is set to prevent early exit during uninstall hooks.

### Interactive Prompts

Handlers that need user input (uninstall, import) use:
```sh
read -r var < /dev/tty
```

This ensures prompts work even when stdin is redirected.

## Common Patterns

### Multi-registry Detection

When installing without specifying a registry, install.sh searches all registries and handles duplicates:

```sh
install_commands_with_detection pgadduser gigen
# Searches all registries
# Shows selection menu if found in multiple registries
```

### Version Pinning

Pinned commands are marked in metadata and skipped during bulk updates:

```sh
ms pin pgadduser          # metadata: pinned=true
ms update                 # Skips pgadduser
ms update pgadduser       # Fails with "pinned" message
ms unpin pgadduser        # Remove pin
```

### Hook Execution

Hooks are optional shell scripts executed during install/uninstall/update:

```sh
# install_hook URL is called after installation
# uninstall_hook URL is called before removal
# update_hook URL is called after version change
```

All hooks receive command context as arguments.
