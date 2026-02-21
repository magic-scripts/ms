#!/bin/sh

# Magic Scripts Registry System
# URL-based registry management with multi-source support

VERSION="dev"

# Source core utilities
UTILS_PATH="$(dirname "$0")/utils.sh"
if [ -f "$UTILS_PATH" ]; then
    . "$UTILS_PATH" || {
        echo "Error: Cannot load core utilities" >&2
        exit 1
    }
fi

# Registry directories and files
REG_DIR="$HOME/.local/share/magicscripts/reg"
REGLIST_FILE="$REG_DIR/reglist"

# Default registry configuration
DEFAULT_REGISTRY_NAME="default"

# Construct DEFAULT_REGISTRY_URL dynamically like setup.sh
get_default_registry_url() {
    local raw_url="https://raw.githubusercontent.com/magic-scripts/ms/main"
    echo "$raw_url/registry/ms.msreg"
}

# Initialize registry directories and default reglist
init_registry_dirs() {
    mkdir -p "$REG_DIR" 2>/dev/null || true
    mkdir -p "$REG_DIR/packages" 2>/dev/null || true

    # Create default reglist if it doesn't exist
    if [ ! -f "$REGLIST_FILE" ]; then
        echo "# Magic Scripts Registry List" > "$REGLIST_FILE"
        echo "# Format: name:url" >> "$REGLIST_FILE"
        echo "$DEFAULT_REGISTRY_NAME:$(get_default_registry_url)" >> "$REGLIST_FILE"
    else
        # Migrate from old 'ms' registry name to 'default'
        if grep -q "^ms:" "$REGLIST_FILE" && ! grep -q "^default:" "$REGLIST_FILE"; then
            sed 's/^ms:/default:/' "$REGLIST_FILE" > "${REGLIST_FILE}.tmp" && mv "${REGLIST_FILE}.tmp" "$REGLIST_FILE"
            # Also rename the cached registry file
            if [ -f "$REG_DIR/ms.msreg" ] && [ ! -f "$REG_DIR/default.msreg" ]; then
                mv "$REG_DIR/ms.msreg" "$REG_DIR/default.msreg" 2>/dev/null || true
            fi
        fi
    fi
}

# Get registry names only (helper function for programmatic use)
get_registry_names() {
    init_registry_dirs
    
    if [ -f "$REGLIST_FILE" ]; then
        while IFS=':' read -r name url; do
            [ -z "$name" ] && continue
            [ -z "$url" ] && continue
            [ "${name#\#}" != "$name" ] && continue  # Skip comments
            echo "$name"
        done < "$REGLIST_FILE"
    fi
}

# List all registries
list_registries() {
    init_registry_dirs
    
    echo "Registry sources:"
    echo ""
    
    if [ -f "$REGLIST_FILE" ]; then
        while IFS=':' read -r name url; do
            [ -z "$name" ] && continue
            [ -z "$url" ] && continue
            [ "${name#\#}" != "$name" ] && continue  # Skip comments
            
            printf "  %-10s %s\n" "$name" "$url"
            
            # Check if registry file exists locally
            local reg_file="$REG_DIR/${name}.msreg"
            if [ -f "$reg_file" ]; then
                local count=$(grep -v "^#" "$reg_file" | grep -v "^$" | wc -l | tr -d ' ')
                printf "  %-10s ↳ %d entries (cached)\n" "" "$count"
            else
                printf "  %-10s ↳ not downloaded\n" ""
            fi
            echo ""
        done < "$REGLIST_FILE"
    else
        echo "No registry sources configured."
        echo "Use 'ms reg add <name> <url>' to add a registry source."
    fi
}

# Add a registry
add_registry() {
    local name="$1"
    local url="$2"

    if [ -z "$name" ] || [ -z "$url" ]; then
        echo "${RED}Error: Both registry name and URL are required${NC}" >&2
        return 1
    fi
    
    # Validate URL format and security
    if ! echo "$url" | grep -q "^https\?://[a-zA-Z0-9.-]\+\.[a-zA-Z]\{2,\}"; then
        echo "${RED}Error: Invalid URL format. Must be a valid HTTP/HTTPS URL${NC}" >&2
        return 1
    fi
    
    # Security check: ensure URL points to a reasonable domain
    if echo "$url" | grep -q -E "(localhost|127\.0\.0\.1|0\.0\.0\.0|::1|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)"; then
        echo "${RED}Error: URLs pointing to localhost or private networks are not allowed for security reasons${NC}" >&2
        return 1
    fi
    
    # Validate registry name
    if ! echo "$name" | grep -q "^[a-zA-Z0-9_-]\+$"; then
        echo "${RED}Error: Registry name can only contain letters, numbers, underscores, and dashes${NC}" >&2
        return 1
    fi
    
    init_registry_dirs
    
    # Check if registry already exists
    if [ -f "$REGLIST_FILE" ] && grep -qF "$name:" "$REGLIST_FILE"; then
        echo "${RED}Error: Registry '$name' already exists${NC}" >&2
        return 1
    fi
    
    # Add registry to reglist
    echo "$name:$url" >> "$REGLIST_FILE"
    echo "Added registry: $name -> $url"
    
    # Try to download immediately
    echo "Downloading registry..."
    if update_registry "$name"; then
        echo "Registry '$name' added and downloaded successfully"
    else
        echo "Warning: Registry added but failed to download. Check URL and try 'ms upgrade'"
    fi
}

# Remove a registry
remove_registry() {
    local name="$1"

    if [ -z "$name" ]; then
        echo "${RED}Error: Registry name is required${NC}" >&2
        return 1
    fi
    
    # Warn about removing default registry but allow it
    if [ "$name" = "$DEFAULT_REGISTRY_NAME" ]; then
        echo "Warning: Removing the default registry '$DEFAULT_REGISTRY_NAME'" >&2
        echo "You can restore it later with:" >&2
        echo "  ms reg add $DEFAULT_REGISTRY_NAME $(get_default_registry_url)" >&2
        echo "" >&2
    fi
    
    if [ ! -f "$REGLIST_FILE" ]; then
        echo "${RED}Error: No registry list found${NC}" >&2
        return 1
    fi

    # Check if registry exists
    if ! grep -qF "$name:" "$REGLIST_FILE"; then
        echo "${RED}Error: Registry '$name' not found${NC}" >&2
        return 1
    fi
    
    # Remove from reglist
    grep -vF "$name:" "$REGLIST_FILE" > "${REGLIST_FILE}.tmp"
    mv "${REGLIST_FILE}.tmp" "$REGLIST_FILE"
    
    # Remove registry file if exists
    local reg_file="$REG_DIR/${name}.msreg"
    if [ -f "$reg_file" ]; then
        rm "$reg_file"
    fi
    
    echo "Removed registry: $name"
}

# Update a specific registry
update_registry() {
    local name="$1"
    local url=""

    if [ ! -f "$REGLIST_FILE" ]; then
        echo "${RED}Error: No registry list found${NC}" >&2
        return 1
    fi

    # Get URL for registry
    url=$(grep -F "$name:" "$REGLIST_FILE" | cut -d':' -f2-)
    if [ -z "$url" ]; then
        echo "${RED}Error: Registry '$name' not found in reglist${NC}" >&2
        return 1
    fi
    
    local reg_file="$REG_DIR/${name}.msreg"
    local temp_file="${reg_file}.tmp"
    
    printf "Updating %s... " "$name"
    if download_file "$url" "$temp_file"; then
        # Validate downloaded file (basic format check)
        if grep -q "|" "$temp_file" 2>/dev/null; then
            mv "$temp_file" "$reg_file"
            echo "done"
            return 0
        else
            rm -f "$temp_file"
            echo "failed (invalid format)"
            return 1
        fi
    else
        rm -f "$temp_file"
        echo "failed (download error)"
        return 1
    fi
}

# Update all registries
update_registries() {
    init_registry_dirs
    
    if [ ! -f "$REGLIST_FILE" ]; then
        echo "No registry list found. Creating default..."
        init_registry_dirs
    fi
    
    echo "Updating all registries..."
    echo ""
    
    local success_count=0
    local total_count=0
    
    while IFS=':' read -r name url; do
        [ -z "$name" ] || [ -z "$url" ] && continue
        [ "${name#\#}" != "$name" ] && continue  # Skip comments
        
        total_count=$((total_count + 1))
        if update_registry "$name"; then
            success_count=$((success_count + 1))
        fi
    done < "$REGLIST_FILE"
    
    echo ""
    echo "Updated $success_count/$total_count registries successfully"

    if [ $success_count -lt $total_count ]; then
        echo "Some registries failed to update. Check network connection and URLs."
        return 1
    fi

    # Migrate registry formats from 4-field to 2-field
    echo ""
    echo "Migrating registry formats..."
    while IFS=':' read -r name url; do
        [ -z "$name" ] || [ -z "$url" ] && continue
        [ "${name#\#}" != "$name" ] && continue

        local reg_file="$REG_DIR/${name}.msreg"
        if [ -f "$reg_file" ]; then
            migrate_msreg_format "$reg_file"
        fi
    done < "$REGLIST_FILE"

    # Refresh package caches after migration
    refresh_package_caches

    return 0
}

# Get all commands from all registries
get_all_commands() {
    local temp_commands=$(create_temp_file "commands") || return 1

    # Check development registry first (for version support)
    if [ -f "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/registry/ms.msreg" ]; then
        local temp_entries=$(create_temp_file "entries") || return 1
        grep -v "^#" "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/registry/ms.msreg" | grep -v "^$" > "$temp_entries"

        while IFS='|' read -r cmd script desc category rest; do
            [ -n "$cmd" ] && echo "$cmd" >> "$temp_commands"
        done < "$temp_entries"

        cleanup_temp_file "$temp_entries"
    fi

    # Add commands from cached registries if not already in development registry
    if [ -f "$REGLIST_FILE" ]; then
        while IFS=':' read -r name url; do
            [ -z "$name" ] && continue
            [ -z "$url" ] && continue
            [ "${name#\#}" != "$name" ] && continue  # Skip comments

            local reg_file="$REG_DIR/${name}.msreg"
            if [ -f "$reg_file" ]; then
                local temp_entries=$(create_temp_file "entries") || continue
                grep -v "^#" "$reg_file" | grep -v "^$" > "$temp_entries"

                while IFS='|' read -r cmd script desc category rest; do
                    if [ -n "$cmd" ] && ! grep -qFx "$cmd" "$temp_commands" 2>/dev/null; then
                        echo "$cmd" >> "$temp_commands"
                    fi
                done < "$temp_entries"

                cleanup_temp_file "$temp_entries"
            fi
        done < "$REGLIST_FILE"
    fi

    if [ -f "$temp_commands" ]; then
        sort -u "$temp_commands"
    fi

    cleanup_temp_file "$temp_commands"
}

# Get script information by command name
get_script_info() {
    local cmd="$1"
    local reg_file
    local result=""

    # Check development registry first (for version support)
    if [ -f "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/registry/ms.msreg" ]; then
        result=$(grep -F "$cmd|" "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/registry/ms.msreg" | head -1)
        if [ -n "$result" ]; then
            # Normalize and return
            _normalize_registry_entry "$result"
            return 0
        fi
    fi

    # Fallback to cached registries
    if [ -f "$REGLIST_FILE" ]; then
        while IFS=':' read -r name url; do
            [ -z "$name" ] && continue
            [ -z "$url" ] && continue
            [ "${name#\#}" != "$name" ] && continue  # Skip comments

            reg_file="$REG_DIR/${name}.msreg"
            if [ -f "$reg_file" ]; then
                result=$(grep -F "$cmd|" "$reg_file" | head -1)
                if [ -n "$result" ]; then
                    # Normalize and return
                    _normalize_registry_entry "$result"
                    return 0
                fi
            fi
        done < "$REGLIST_FILE"
    fi

    return 1
}

# Normalize registry entry to 4-field format
# Converts 2-field (cmd|mspack_url) to 4-field (cmd|mspack_url|desc|category)
_normalize_registry_entry() {
    local entry="$1"
    local field_count=$(echo "$entry" | awk -F'|' '{print NF}')

    if [ "$field_count" -eq 2 ]; then
        # Extract fields from 2-field format
        local cmd_name=$(echo "$entry" | cut -d'|' -f1)
        local mspack_url=$(echo "$entry" | cut -d'|' -f2)

        # Get description/category from cached .mspack
        if ! is_mspack_cached "$cmd_name"; then
            cache_mspack "$mspack_url" "$cmd_name" >/dev/null 2>&1 || {
                # Cache failed - return with unknown values
                echo "$cmd_name|$mspack_url|Unknown|utility"
                return 0
            }
        fi

        local mspack_cache=$(get_mspack_cache_path "$cmd_name")
        local desc=$(grep "^description|" "$mspack_cache" 2>/dev/null | cut -d'|' -f2)
        local category=$(grep "^category|" "$mspack_cache" 2>/dev/null | cut -d'|' -f2)

        # Return normalized 4-field format
        echo "$cmd_name|$mspack_url|${desc:-Unknown}|${category:-utility}"
    else
        # Already 4-field format or other - return as-is
        echo "$entry"
    fi

    return 0
}

# Get script description
get_script_description() {
    local cmd="$1"
    local info=$(get_script_info "$cmd")

    if [ -n "$info" ]; then
        echo "$info" | cut -d'|' -f3
    else
        echo "Magic Scripts command"
    fi
}

# Get commands from specific registry
get_registry_commands() {
    local registry_name="$1"
    local reg_file="$REG_DIR/${registry_name}.msreg"
    
    if [ -f "$reg_file" ]; then
        grep -v "^#" "$reg_file" | grep -v "^$"
    else
        return 1
    fi
}

# Search commands by query
search_commands() {
    local query="$1"
    local temp_results=$(create_temp_file "results") || { echo "${RED}Error: Cannot create temp file${NC}" >&2; return 1; }
    
    echo "=== Search Results${query:+ for '$query'} ==="
    echo ""
    
    > "$temp_results"  # Clear temp file
    
    # Check development registry first (for version support)
    if [ -f "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/registry/ms.msreg" ]; then
        local temp_entries=$(create_temp_file "entries") || { cleanup_temp_file "$temp_results"; return 1; }
        grep -v "^#" "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/registry/ms.msreg" | grep -v "^$" > "$temp_entries"

        while IFS='|' read -r cmd mspack_url extra1 extra2; do
            [ -z "$cmd" ] && continue

            # Detect format by field count
            local desc category
            if [ -n "$extra2" ]; then
                # Old 4-field format: cmd|mspack_url|desc|category
                desc="$extra1"
                category="$extra2"
            else
                # New 2-field format: cmd|mspack_url
                # Get description and category from cached mspack
                if ! is_mspack_cached "$cmd"; then
                    cache_mspack "$mspack_url" "$cmd" >/dev/null 2>&1 || continue
                fi

                local mspack_cache=$(get_mspack_cache_path "$cmd")
                desc=$(grep "^description|" "$mspack_cache" 2>/dev/null | cut -d'|' -f2)
                category=$(grep "^category|" "$mspack_cache" 2>/dev/null | cut -d'|' -f2)

                # Fallback if not found
                [ -z "$desc" ] && desc="No description available"
                [ -z "$category" ] && category="utility"
            fi

            if [ -z "$query" ] || echo "$cmd $desc $category" | grep -qi "$query"; then
                printf "  %-12s %s [%s]\n" "$cmd" "$desc" "$category" >> "$temp_results"
            fi
        done < "$temp_entries"

        cleanup_temp_file "$temp_entries"
    fi
    
    # Fallback to cached registries if no results from development registry
    if [ ! -s "$temp_results" ] && [ -f "$REGLIST_FILE" ]; then
        while IFS=':' read -r name url; do
            [ -z "$name" ] && continue
            [ -z "$url" ] && continue
            [ "${name#\#}" != "$name" ] && continue  # Skip comments

            local reg_file="$REG_DIR/${name}.msreg"
            if [ -f "$reg_file" ]; then
                local temp_entries=$(create_temp_file "entries") || continue
                grep -v "^#" "$reg_file" | grep -v "^$" > "$temp_entries"

                while IFS='|' read -r cmd mspack_url extra1 extra2; do
                    [ -z "$cmd" ] && continue

                    # Detect format by field count
                    local desc category
                    if [ -n "$extra2" ]; then
                        # Old 4-field format
                        desc="$extra1"
                        category="$extra2"
                    else
                        # New 2-field format - get from cached mspack
                        if ! is_mspack_cached "$cmd"; then
                            cache_mspack "$mspack_url" "$cmd" >/dev/null 2>&1 || continue
                        fi

                        local mspack_cache=$(get_mspack_cache_path "$cmd")
                        desc=$(grep "^description|" "$mspack_cache" 2>/dev/null | cut -d'|' -f2)
                        category=$(grep "^category|" "$mspack_cache" 2>/dev/null | cut -d'|' -f2)

                        [ -z "$desc" ] && desc="No description available"
                        [ -z "$category" ] && category="utility"
                    fi

                    if [ -z "$query" ] || echo "$cmd $desc $category" | grep -qi "$query"; then
                        printf "  %-12s %s [%s]\n" "$cmd" "$desc" "$category" >> "$temp_results"
                    fi
                done < "$temp_entries"

                cleanup_temp_file "$temp_entries"
            fi
        done < "$REGLIST_FILE"
    fi
    
    if [ -s "$temp_results" ]; then
        cat "$temp_results"
    else
        if [ -n "$query" ]; then
            echo "  No commands found matching '$query'"
        else
            echo "  No commands available"
        fi
        echo ""
        echo "Try 'ms upgrade' to update registries."
    fi

    cleanup_temp_file "$temp_results"
}

# Download and parse .msver file
# Parse a version-only .msver file
# Outputs: version|... lines
_parse_msver_file() {
    local msver_file="$1"
    local target_version="$2"

    while IFS='|' read -r entry_type key value desc_or_checksum extra1 extra2 extra3 extra4 extra5 extra6; do
        [ "${entry_type#\#}" != "$entry_type" ] && continue
        [ -z "$entry_type" ] && continue

        case "$entry_type" in
            version)
                if [ -n "$target_version" ] && [ "$key" != "$target_version" ]; then
                    continue
                fi
                echo "version|$key|$value|$desc_or_checksum|$extra1|$extra2|$extra3|$extra4|$extra5|$extra6"
                ;;
        esac
    done < "$msver_file"
}

# Download and parse a package file (.mspack or legacy .msver)
# Handles both 3-tier (mspack -> msver) and legacy 2-tier (msver with config) formats
# Outputs: meta|, config|, and version| lines
download_and_parse_msver() {
    local package_url="$1"
    local target_cmd="$2"
    local target_version="$3"
    local force_refresh="${4:-false}"  # NEW: optional force refresh flag

    local temp_file=$(create_temp_file "mspack") || { echo "${RED}Error: Cannot create temp file${NC}" >&2; return 1; }

    # NEW: Try to use cached mspack if available (unless force refresh)
    local mspack_cache=""
    if [ "$force_refresh" != "true" ] && [ -n "$target_cmd" ]; then
        mspack_cache=$(get_mspack_cache_path "$target_cmd")
        if [ -f "$mspack_cache" ] && [ -s "$mspack_cache" ]; then
            # Use cached file
            cat "$mspack_cache" > "$temp_file"
        else
            # Download and cache
            if ! download_file "$package_url" "$temp_file"; then
                echo "${RED}Error: Cannot download package file from $package_url${NC}" >&2
                cleanup_temp_file "$temp_file"
                return 1
            fi
            # Cache the downloaded mspack (ensure directory exists)
            mkdir -p "$(dirname "$mspack_cache")" 2>/dev/null || return 1
            if ! cp "$temp_file" "$mspack_cache"; then
                cleanup_temp_file "$temp_file"
                return 1
            fi
        fi
    else
        # No caching (legacy path or force refresh)
        if ! download_file "$package_url" "$temp_file"; then
            echo "${RED}Error: Cannot download package file from $package_url${NC}" >&2
            cleanup_temp_file "$temp_file"
            return 1
        fi
    fi

    echo "" >> "$temp_file"

    # Detect if this is a 3-tier mspack (has msver_url| line) or legacy 2-tier msver
    local msver_url=""

    # Parse the file
    while IFS='|' read -r entry_type key value desc_or_checksum extra1 extra2 extra3 extra4 extra5 extra6; do
        [ "${entry_type#\#}" != "$entry_type" ] && continue
        [ -z "$entry_type" ] && continue

        case "$entry_type" in
            version)
                # Legacy .msver or inline version lines
                if [ -n "$target_version" ] && [ "$key" != "$target_version" ]; then
                    continue
                fi
                echo "version|$key|$value|$desc_or_checksum|$extra1|$extra2|$extra3|$extra4|$extra5|$extra6"
                ;;
            config)
                if [ -n "$target_cmd" ]; then
                    case ",$extra2," in
                        *,"$target_cmd",*) ;;
                        *) continue ;;
                    esac
                fi
                echo "config|$key|$value|$desc_or_checksum|$extra1|$extra2"
                ;;
            msver_url)
                # 3-tier: this file is an mspack, store URL for later download
                msver_url="$key"
                ;;
            name|description|author|license|license_url|repo_url|issues_url|homepage_url|docs_url|stability|min_ms_version|category)
                # Package metadata: key|value (NEW: added category)
                echo "meta|$entry_type|$key"
                ;;
        esac
    done < "$temp_file"

    # NEW: If msver_url was found, download and cache the msver file
    if [ -n "$msver_url" ]; then
        local temp_msver=$(create_temp_file "msver") || { cleanup_temp_file "$temp_file"; return 1; }

        # Try to use cached msver
        local msver_cache=""
        if [ "$force_refresh" != "true" ] && [ -n "$target_cmd" ]; then
            msver_cache=$(get_msver_cache_path "$target_cmd")
            if [ -f "$msver_cache" ] && [ -s "$msver_cache" ]; then
                # Use cached msver
                cat "$msver_cache" > "$temp_msver"
            else
                # Download and cache msver
                if ! download_file "$msver_url" "$temp_msver"; then
                    echo "${RED}Error: Cannot download .msver file from $msver_url${NC}" >&2
                    cleanup_temp_file "$temp_msver"
                    cleanup_temp_file "$temp_file"
                    return 1
                fi
                # Cache the downloaded msver (ensure directory exists)
                mkdir -p "$(dirname "$msver_cache")" 2>/dev/null || {
                    cleanup_temp_file "$temp_msver"
                    cleanup_temp_file "$temp_file"
                    return 1
                }
                if ! cp "$temp_msver" "$msver_cache"; then
                    cleanup_temp_file "$temp_msver"
                    cleanup_temp_file "$temp_file"
                    return 1
                fi
            fi
        else
            # No caching (legacy path or force refresh)
            if ! download_file "$msver_url" "$temp_msver"; then
                echo "${RED}Error: Cannot download .msver file from $msver_url${NC}" >&2
                cleanup_temp_file "$temp_msver"
                cleanup_temp_file "$temp_file"
                return 1
            fi
        fi

        echo "" >> "$temp_msver"
        _parse_msver_file "$temp_msver" "$target_version"
        cleanup_temp_file "$temp_msver"
    fi

    cleanup_temp_file "$temp_file"
}

# Get command info from registry system (supports both 2-tier and 3-tier)
# Returns: command_meta|, meta|, config|, and version| lines
get_command_info() {
    local cmd="$1"
    local version="$2"  # Optional: specific version

    # First get command metadata from .msreg files
    local cmd_meta=""

    # Check development registry first (if in development environment)
    local script_dir="$(cd "$(dirname "$0")" && pwd)"
    if [ -f "$script_dir/registry/ms.msreg" ]; then
        cmd_meta=$(grep -F "$cmd|" "$script_dir/registry/ms.msreg" | head -1)
    elif [ -n "${MAGIC_SCRIPT_DIR:-}" ] && [ -f "${MAGIC_SCRIPT_DIR}/registry/ms.msreg" ]; then
        cmd_meta=$(grep -F "$cmd|" "${MAGIC_SCRIPT_DIR}/registry/ms.msreg" | head -1)
    fi

    # Fallback to cached registries
    if [ -z "$cmd_meta" ] && [ -f "$REGLIST_FILE" ]; then
        while IFS=':' read -r name url; do
            [ -z "$name" ] && continue
            [ -z "$url" ] && continue
            [ "${name#\#}" != "$name" ] && continue

            local reg_file="$REG_DIR/${name}.msreg"
            if [ -f "$reg_file" ]; then
                cmd_meta=$(grep -F "$cmd|" "$reg_file" | head -1)
                [ -n "$cmd_meta" ] && break
            fi
        done < "$REGLIST_FILE"
    fi

    if [ -z "$cmd_meta" ]; then
        return 1
    fi

    # Parse command metadata: name|package_url|description|category
    # package_url can be .mspack (3-tier) or .msver (legacy 2-tier)
    local name=$(echo "$cmd_meta" | cut -d'|' -f1)
    local package_url=$(echo "$cmd_meta" | cut -d'|' -f2)
    local description=$(echo "$cmd_meta" | cut -d'|' -f3)
    local category=$(echo "$cmd_meta" | cut -d'|' -f4)

    # Download and parse the package/version file
    local package_info=""
    if [ -n "$package_url" ]; then
        package_info=$(download_and_parse_msver "$package_url" "$cmd" "$version")
    fi

    # Return combined info (command_meta + all meta/dep/config/version lines)
    echo "command_meta|$name|$description|$category|$package_url"
    if [ -n "$package_info" ]; then
        echo "$package_info"
    fi
}

# Get all versions for a command
get_command_versions() {
    local cmd="$1"
    local cmd_info=$(get_command_info "$cmd")

    if [ -z "$cmd_info" ]; then
        return 1
    fi

    echo "$cmd_info" | grep "^version|"
}

# Get config keys for a specific command
get_command_config_keys() {
    local cmd="$1"
    local cmd_info=$(get_command_info "$cmd")

    if [ -z "$cmd_info" ]; then
        return 1
    fi

    echo "$cmd_info" | grep "^config|"
}

# Get metadata for a command (author, license, etc.)
get_command_metadata() {
    local cmd="$1"
    local cmd_info=$(get_command_info "$cmd")

    if [ -z "$cmd_info" ]; then
        return 1
    fi

    echo "$cmd_info" | grep "^meta|"
}

# Get registry URL by name
get_registry_url() {
    local registry_name="$1"
    
    if [ -f "$REGLIST_FILE" ]; then
        grep -F "$registry_name:" "$REGLIST_FILE" 2>/dev/null | cut -d':' -f2-
    fi
}

# Get version
get_version() {
    echo "$VERSION"
}

# ============================================================================
# Package Cache Management Functions
# ============================================================================

# Get cache file path for a command's mspack
# Args: command_name
# Returns: path to cache file
get_mspack_cache_path() {
    local cmd="$1"
    echo "$REG_DIR/packages/${cmd}.mspack"
}

# Get cache file path for a command's msver
# Args: command_name
# Returns: path to cache file
get_msver_cache_path() {
    local cmd="$1"
    echo "$REG_DIR/packages/${cmd}.msver"
}

# Check if mspack cache exists and is valid
# Args: command_name
# Returns: 0 if valid cache exists, 1 otherwise
is_mspack_cached() {
    local cmd="$1"
    local cache_file=$(get_mspack_cache_path "$cmd")
    [ -f "$cache_file" ] && [ -s "$cache_file" ]
}

# Check if msver cache exists and is valid
# Args: command_name
# Returns: 0 if valid cache exists, 1 otherwise
is_msver_cached() {
    local cmd="$1"
    local cache_file=$(get_msver_cache_path "$cmd")
    [ -f "$cache_file" ] && [ -s "$cache_file" ]
}

# Download and cache mspack file
# Args: mspack_url command_name
# Returns: 0 on success, 1 on failure
cache_mspack() {
    local mspack_url="$1"
    local cmd="$2"
    local cache_file=$(get_mspack_cache_path "$cmd")
    local temp_file="${cache_file}.tmp"

    if ! download_file "$mspack_url" "$temp_file"; then
        rm -f "$temp_file"
        return 1
    fi

    # Validate format (basic check for mspack structure)
    if ! grep -q "^name|" "$temp_file" 2>/dev/null; then
        rm -f "$temp_file"
        return 1
    fi

    # Atomic move with error checking
    if ! mv "$temp_file" "$cache_file"; then
        rm -f "$temp_file"
        return 1
    fi

    return 0
}

# Download and cache msver file
# Args: msver_url command_name
# Returns: 0 on success, 1 on failure
cache_msver() {
    local msver_url="$1"
    local cmd="$2"
    local cache_file=$(get_msver_cache_path "$cmd")
    local temp_file="${cache_file}.tmp"

    if ! download_file "$msver_url" "$temp_file"; then
        rm -f "$temp_file"
        return 1
    fi

    # Validate format (basic check for version entries)
    if ! grep -q "^version|" "$temp_file" 2>/dev/null; then
        rm -f "$temp_file"
        return 1
    fi

    # Atomic move with error checking
    if ! mv "$temp_file" "$cache_file"; then
        rm -f "$temp_file"
        return 1
    fi

    return 0
}

# Invalidate cache for a specific command
# Args: command_name
invalidate_package_cache() {
    local cmd="$1"
    rm -f "$(get_mspack_cache_path "$cmd")"
    rm -f "$(get_msver_cache_path "$cmd")"
}

# Invalidate all package caches
invalidate_all_package_caches() {
    rm -rf "$REG_DIR/packages"
    mkdir -p "$REG_DIR/packages" 2>/dev/null || true
}

# ============================================================================
# Registry Format Migration
# ============================================================================

# Migrate .msreg from 4-field to 2-field format
# Args: msreg_file_path
# Returns: 0 on success or if already migrated, 1 on error
migrate_msreg_format() {
    local msreg_file="$1"

    [ ! -f "$msreg_file" ] && return 0

    # Check if already 2-field format
    local first_line=$(grep -v "^#" "$msreg_file" | grep -v "^$" | head -1)
    [ -z "$first_line" ] && return 0

    local field_count=$(echo "$first_line" | awk -F'|' '{print NF}')
    [ "$field_count" -eq 2 ] && return 0

    if [ "$field_count" -lt 4 ]; then
        echo "  ${YELLOW}Warning: ${msreg_file} has unexpected format (${field_count} fields)${NC}"
        return 1
    fi

    echo "  Migrating $(basename "$msreg_file") to 2-field format..."

    local temp_file=$(create_temp_file "migrate") || return 1
    local entries_file=$(create_temp_file "entries") || { cleanup_temp_file "$temp_file"; return 1; }

    # POSIX-compliant: extract entries to temp file
    grep -v "^#" "$msreg_file" | grep -v "^$" > "$entries_file"

    # Safety check: verify entries exist
    if [ ! -s "$entries_file" ]; then
        cleanup_temp_file "$temp_file"
        cleanup_temp_file "$entries_file"
        echo "  ${YELLOW}No entries to migrate${NC}"
        return 0
    fi

    # Preserve comments (exclude old format line)
    grep "^#" "$msreg_file" | grep -v "^# Format:" > "$temp_file" 2>/dev/null || true
    echo "# Format: name|mspack_url" >> "$temp_file"
    echo "#" >> "$temp_file"
    echo "# Migrated from 4-field to 2-field format" >> "$temp_file"
    echo "" >> "$temp_file"

    # Convert entries (read from temp file - POSIX compliant!)
    while IFS='|' read -r cmd mspack_url desc category rest; do
        [ -z "$cmd" ] || [ -z "$mspack_url" ] && continue
        echo "$cmd|$mspack_url" >> "$temp_file"
    done < "$entries_file"

    cleanup_temp_file "$entries_file"

    # Safety: verify result
    if [ ! -s "$temp_file" ]; then
        cleanup_temp_file "$temp_file"
        echo "  ${RED}Migration failed: no valid entries${NC}"
        return 1
    fi

    # Atomic replace with error handling
    if ! cp "$msreg_file" "${msreg_file}.backup"; then
        cleanup_temp_file "$temp_file"
        echo "  ${RED}Migration failed: could not create backup${NC}"
        return 1
    fi

    if ! mv "$temp_file" "$msreg_file"; then
        # Error-checked rollback
        if ! mv "${msreg_file}.backup" "$msreg_file"; then
            echo "  ${RED}CRITICAL: Migration and rollback both failed!${NC}"
            echo "  ${RED}Manual recovery required: ${msreg_file}.backup${NC}"
            return 2
        fi
        echo "  ${RED}Migration failed: restored from backup${NC}"
        return 1
    fi

    # Clean up backup on success
    rm -f "${msreg_file}.backup" 2>/dev/null || true
    echo "  ${GREEN}✓ Migration complete${NC}"
    return 0
}

# Refresh package caches for all commands in all registries
# Downloads and caches .mspack + .msver for each command
refresh_package_caches() {
    echo ""
    echo "Refreshing package caches..."

    local total=0
    local success=0
    local temp_entries=$(create_temp_file "refresh") || return 1

    if [ ! -f "$REGLIST_FILE" ]; then
        echo "No registries found"
        cleanup_temp_file "$temp_entries"
        return 0
    fi

    while IFS=':' read -r name url; do
        case "$name" in
            ""|\#*) continue ;;
        esac
        [ -z "$url" ] && continue

        local reg_file="$REG_DIR/${name}.msreg"
        [ ! -f "$reg_file" ] && continue

        # POSIX-compliant: use temp file instead of process substitution
        grep -v "^#" "$reg_file" | grep -v "^$" > "$temp_entries"

        while IFS='|' read -r cmd mspack_url rest; do
            case "$cmd" in
                ""|\#*) continue ;;
            esac
            [ -z "$mspack_url" ] && continue

            total=$((total + 1))
            printf "  Caching %s... " "$cmd"

            if cache_mspack "$mspack_url" "$cmd" 2>/dev/null; then
                # Also download and cache msver
                local mspack_cache=$(get_mspack_cache_path "$cmd")
                local msver_url=$(grep "^msver_url|" "$mspack_cache" 2>/dev/null | cut -d'|' -f2)

                if [ -n "$msver_url" ]; then
                    if cache_msver "$msver_url" "$cmd" 2>/dev/null; then
                        echo "done"
                        success=$((success + 1))
                    else
                        echo "failed (msver)"
                    fi
                else
                    echo "done"
                    success=$((success + 1))
                fi
            else
                echo "failed"
            fi
        done < "$temp_entries"

    done < "$REGLIST_FILE"

    cleanup_temp_file "$temp_entries"

    echo ""
    echo "Package cache refresh complete: $success/$total packages cached"
}

# Initialize on load
init_registry_dirs