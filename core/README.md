# Magic Scripts Core Modules

This directory contains the core infrastructure libraries for Magic Scripts. These modules are loaded at startup and provide foundational functionality.

## Module Overview

### config.sh (726 lines)
**Configuration System**
- Three-tier configuration precedence: local `.msconfig` > global user config > registry defaults
- Functions: `get_config_value()`, `set_config_value()`, `remove_config_value()`, `ms_internal_list_config_values()`, `ms_internal_interactive_config_setup()`
- Access control via `MS_SCRIPT_ID` environment variable

**Dependencies:** None (foundational)

### registry.sh (637 lines)
**Registry Management System**
- Manages 3-tier registry system (`.msreg` → `.mspack` → `.msver`)
- HTTPS-only downloads with checksum verification
- Functions: `get_script_info()`, `get_command_info()`, `download_file()`, `list_registries()`, `add_registry()`, `remove_registry()`
- Caching system at `$HOME/.local/share/magicscripts/reg/`

**Dependencies:** None (foundational)

### metadata.sh (97 lines)
**Installation Metadata Management**
- Manages `.msmeta` files for installed commands
- Storage: `$HOME/.local/share/magicscripts/installed/<cmd>.msmeta`
- Functions:
  - `metadata_get(cmd, [key])` - Get metadata value(s)
  - `metadata_set(cmd, version, registry_name, registry_url, checksum, script_path, [install_script], [uninstall_script])` - Set metadata
  - `metadata_update_key(cmd, key, value)` - Update single key
  - `metadata_remove(cmd)` - Remove metadata

**Dependencies:** ms.sh (`ms_error()`)

**Namespace:** `metadata_*`

### version.sh (147 lines)
**Version Management and Checksum Utilities**
- Version comparison, checksum calculation, verification
- Functions:
  - `version_get_installed(cmd)` - Get installed version
  - `version_set_installed(cmd, version)` - Set version (preserves metadata)
  - `version_get_registry(cmd)` - Get latest registry version
  - `version_compare(installed, registry)` - Compare versions
  - `version_calculate_checksum(file_path)` - Calculate 8-char SHA256
  - `version_verify_checksum(cmd)` - Verify installed command

**Dependencies:** metadata.sh, registry.sh (`get_script_info()`), ms.sh globals (colors)

**Namespace:** `version_*`

### pack.sh (1,715 lines)
**Developer and Publishing Tools**
- All `ms pub pack` commands (lazy loaded)
- Functions: `pack_init()`, `pack_release()`, `pack_checksum()`, `pack_verify()`, `pack_version_add()`, `pack_version_update()`, `pack_reg_add()`, `pack_reg_remove()`
- Handlers: `handle_pub()`, `handle_pub_pack()`, `handle_pub_reg()`

**Dependencies:** registry.sh (`download_file()`), ms.sh (colors, `ms_error()`, `get_config_value()`, `calculate_file_checksum()`)

**Loading:** Lazy (loaded only when `ms pub` is invoked via `load_pack_tools()`)

**Namespace:** `pack_*`, `pub_*`

## Loading Order

Core modules are loaded in this order by ms.sh:

```sh
for lib in config.sh registry.sh metadata.sh version.sh; do
    # Load from MAGIC_SCRIPT_DIR/core/ or SCRIPT_DIR/../core/
    . "$lib"
done
```

**Why this order:**
1. `config.sh` - No dependencies, provides configuration access
2. `registry.sh` - No dependencies, provides download/registry functions
3. `metadata.sh` - Depends on ms.sh error handling
4. `version.sh` - Depends on metadata.sh and registry.sh
5. `pack.sh` - Lazy loaded, depends on all of the above

## Namespace Conventions

### Public API (External Use)
Functions that can be called from user scripts:
```sh
get_config_value()      # config.sh
get_script_info()       # registry.sh
```

### Module Public (Internal Use)
Functions with namespace prefixes for internal ms use:
```sh
metadata_get()          # metadata.sh
version_get_installed() # version.sh
pack_init()             # pack.sh
```

### Module Private (Internal Only)
Functions prefixed with `ms_internal_*`:
```sh
ms_internal_get_script_info()        # registry.sh
ms_internal_list_config_values()     # config.sh
```

### Backward Compatibility Wrappers
Old function names are preserved in ms.sh:
```sh
# In ms.sh
get_installation_metadata() { metadata_get "$@"; }
get_installed_version() { version_get_installed "$@"; }
calculate_file_checksum() { version_calculate_checksum "$@"; }
```

## Adding New Core Modules

To add a new core module:

1. **Create the module file:** `ms/core/newmodule.sh`
   ```sh
   #!/bin/sh
   # Magic Scripts - New Module
   #
   # Description of what this module does
   #
   # Dependencies:
   #   - List dependencies here
   #
   # Functions:
   #   - module_function_name() Description

   # Your functions here with module_* namespace
   ```

2. **Add to loading sequence in ms.sh:**
   ```sh
   for lib in config.sh registry.sh metadata.sh version.sh newmodule.sh; do
       # ... loading code
   done
   ```

3. **Document dependencies:** Clearly list what the module depends on

4. **Use namespace conventions:** Prefix functions with module name

5. **Add backward compatibility wrappers if needed**

## Error Handling

All core modules follow these patterns:

**Explicit error checks (no `set -e`):**
```sh
if ! download_file "$url" "$dest"; then
    ms_error "Download failed: $url"
    return 1
fi
```

**Standard return codes:**
- `0` - Success
- `1` - General error
- `2` - Special case (e.g., already installed/skip)

**Cleanup with traps:**
```sh
local temp_file=$(mktemp) || return 1
trap 'rm -f "$temp_file"' EXIT INT TERM
```

## Development Mode

Core modules support development mode via `MAGIC_SCRIPT_DIR`:

```sh
export MAGIC_SCRIPT_DIR="$(pwd)/ms"
./ms/scripts/ms.sh <command>
```

This allows testing changes without installing.

## Performance Considerations

- **Eager loading:** config, registry, metadata, version (fast, ~50ms total)
- **Lazy loading:** pack.sh (only when needed, saves ~15ms on startup)
- Total startup overhead: ~50-65ms (acceptable)

## Testing

Test core modules individually:

```sh
# Source the module
export MAGIC_SCRIPT_DIR="$(pwd)/ms"
. ms/core/metadata.sh

# Test functions
metadata_set "testcmd" "1.0.0" "default" "http://..." "abc123" "/path/to/script"
metadata_get "testcmd" "version"  # Should return 1.0.0
```

## Module Interdependencies

```
config.sh  (no deps)
    ↓
registry.sh  (no deps)
    ↓
metadata.sh  (ms.sh: ms_error)
    ↓
version.sh  (metadata.sh, registry.sh, ms.sh: colors)
    ↓
pack.sh  (all above + lazy loaded)
```
