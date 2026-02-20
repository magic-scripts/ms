#!/bin/sh

# Magic Scripts Registry System
# URL-based registry management with multi-source support

VERSION="dev"

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

# Check if command exists
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# Download file with curl or wget
download_file() {
    local url="$1"
    local output="$2"
    
    # Basic URL validation for security
    if ! echo "$url" | grep -q "^https\?://[a-zA-Z0-9.-]\+\.[a-zA-Z]\{2,\}"; then
        echo "${RED}Error: Invalid URL format for download: $url${NC}" >&2
        return 1
    fi
    
    # Security check: prevent access to localhost/internal IPs
    if echo "$url" | grep -q -E "(localhost|127\.0\.0\.1|0\.0\.0\.0|::1|192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)" ; then
        echo "${RED}Error: Downloads from local/internal addresses are not allowed for security${NC}" >&2
        return 1
    fi
    
    if check_command curl; then
        curl -fsSL "$url" -o "$output" 2>/dev/null
    elif check_command wget; then
        wget -q "$url" -O "$output" 2>/dev/null
    else
        echo "${RED}Error: curl or wget is required for downloading${NC}" >&2
        return 1
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
    if [ -f "$REGLIST_FILE" ] && grep -q "^$name:" "$REGLIST_FILE"; then
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
    if ! grep -q "^$name:" "$REGLIST_FILE"; then
        echo "${RED}Error: Registry '$name' not found${NC}" >&2
        return 1
    fi
    
    # Remove from reglist
    grep -v "^$name:" "$REGLIST_FILE" > "${REGLIST_FILE}.tmp"
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
    url=$(grep "^$name:" "$REGLIST_FILE" | cut -d':' -f2-)
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
    
    return 0
}

# Get all commands from all registries
get_all_commands() {
    local temp_commands=$(mktemp) || { echo "${RED}Error: Cannot create temp file${NC}" >&2; return 1; }
    
    # Check development registry first (for version support)
    if [ -f "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/registry/ms.msreg" ]; then
        grep -v "^#" "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/registry/ms.msreg" | grep -v "^$" | while IFS='|' read -r cmd script desc category; do
            [ -n "$cmd" ] && echo "$cmd" >> "$temp_commands"
        done
    fi
    
    # Add commands from cached registries if not already in development registry
    if [ -f "$REGLIST_FILE" ]; then
        while IFS=':' read -r name url; do
            [ -z "$name" ] && continue
            [ -z "$url" ] && continue
            [ "${name#\#}" != "$name" ] && continue  # Skip comments
            
            local reg_file="$REG_DIR/${name}.msreg"
            if [ -f "$reg_file" ]; then
                grep -v "^#" "$reg_file" | grep -v "^$" | while IFS='|' read -r cmd script desc category; do
                    if [ -n "$cmd" ] && ! grep -q "^$cmd$" "$temp_commands" 2>/dev/null; then
                        echo "$cmd" >> "$temp_commands"
                    fi
                done
            fi
        done < "$REGLIST_FILE"
    fi
    
    if [ -f "$temp_commands" ]; then
        sort -u "$temp_commands"
        rm -f "$temp_commands"
    fi
}

# Get script information by command name
get_script_info() {
    local cmd="$1"
    local reg_file
    
    # Check development registry first (for version support)
    if [ -f "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/registry/ms.msreg" ]; then
        local result=$(grep "^$cmd|" "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/registry/ms.msreg" | head -1)
        if [ -n "$result" ]; then
            echo "$result"
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
                local result=$(grep "^$cmd|" "$reg_file" | head -1)
                if [ -n "$result" ]; then
                    echo "$result"
                    return 0
                fi
            fi
        done < "$REGLIST_FILE"
    fi
    
    return 1
}

# Get script description
get_script_description() {
    local cmd="$1"
    local info=$(get_script_info "$cmd")
    
    if [ -n "$info" ]; then
        echo "$info" | cut -d'|' -f4
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
    local temp_results=$(mktemp) || { echo "${RED}Error: Cannot create temp file${NC}" >&2; return 1; }
    
    echo "=== Search Results${query:+ for '$query'} ==="
    echo ""
    
    > "$temp_results"  # Clear temp file
    
    # Check development registry first (for version support)
    if [ -f "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/registry/ms.msreg" ]; then
        grep -v "^#" "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/registry/ms.msreg" | grep -v "^$" | while IFS='|' read -r cmd script desc category; do
            [ -z "$cmd" ] && continue
            
            if [ -z "$query" ] || echo "$cmd $desc $category" | grep -qi "$query"; then
                # Version info is in .msver file pointed by $script
                # For now, just show basic info without version
                printf "  %-12s %s [%s]\n" "$cmd" "$desc" "$category" >> "$temp_results"
            fi
        done
    fi
    
    # Fallback to cached registries if no results from development registry
    if [ ! -s "$temp_results" ] && [ -f "$REGLIST_FILE" ]; then
        while IFS=':' read -r name url; do
            [ -z "$name" ] && continue
            [ -z "$url" ] && continue
            [ "${name#\#}" != "$name" ] && continue  # Skip comments
            
            local reg_file="$REG_DIR/${name}.msreg"
            if [ -f "$reg_file" ]; then
                grep -v "^#" "$reg_file" | grep -v "^$" | while IFS='|' read -r cmd script desc category; do
                    [ -z "$cmd" ] && continue
                    
                    if [ -z "$query" ] || echo "$cmd $desc $category" | grep -qi "$query"; then
                        # Show basic info without version
                        printf "  %-12s %s [%s]\n" "$cmd" "$desc" "$category" >> "$temp_results"
                    fi
                done
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
    
    rm -f "$temp_results"
}

# Download and parse .msver file
# Parse a version-only .msver file
# Outputs: version|... lines
_parse_msver_file() {
    local msver_file="$1"
    local target_version="$2"

    while IFS='|' read -r entry_type key value desc_or_checksum extra1 extra2 extra3; do
        [ "${entry_type#\#}" != "$entry_type" ] && continue
        [ -z "$entry_type" ] && continue

        case "$entry_type" in
            version)
                if [ -n "$target_version" ] && [ "$key" != "$target_version" ]; then
                    continue
                fi
                echo "version|$key|$value|$desc_or_checksum|$extra1|$extra2|$extra3"
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

    local temp_file=$(mktemp) || { echo "${RED}Error: Cannot create temp file${NC}" >&2; return 1; }

    if ! download_file "$package_url" "$temp_file"; then
        echo "${RED}Error: Cannot download package file from $package_url${NC}" >&2
        return 1
    fi

    echo "" >> "$temp_file"

    # Detect if this is a 3-tier mspack (has msver_url| line) or legacy 2-tier msver
    local msver_url=""

    # Parse the file
    while IFS='|' read -r entry_type key value desc_or_checksum extra1 extra2 extra3; do
        [ "${entry_type#\#}" != "$entry_type" ] && continue
        [ -z "$entry_type" ] && continue

        case "$entry_type" in
            version)
                # Legacy .msver or inline version lines
                if [ -n "$target_version" ] && [ "$key" != "$target_version" ]; then
                    continue
                fi
                echo "version|$key|$value|$desc_or_checksum|$extra1|$extra2|$extra3"
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
            name|description|author|license|license_url|repo_url|issues_url|homepage_url|docs_url|stability|min_ms_version)
                # Package metadata: key|value
                echo "meta|$entry_type|$key"
                ;;
        esac
    done < "$temp_file"

    # If msver_url was found, this is a 3-tier mspack — download and parse the msver too
    if [ -n "$msver_url" ]; then
        local temp_msver=$(mktemp) || { rm -f "$temp_file"; return 1; }
        if download_file "$msver_url" "$temp_msver"; then
            echo "" >> "$temp_msver"
            _parse_msver_file "$temp_msver" "$target_version"
        else
            echo "${RED}Error: Cannot download .msver file from $msver_url${NC}" >&2
            rm -f "$temp_msver"
            rm -f "$temp_file"
            return 1
        fi
        rm -f "$temp_msver"
    fi

    rm -f "$temp_file"
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
        cmd_meta=$(grep "^$cmd|" "$script_dir/registry/ms.msreg" | head -1)
    elif [ -n "${MAGIC_SCRIPT_DIR:-}" ] && [ -f "${MAGIC_SCRIPT_DIR}/registry/ms.msreg" ]; then
        cmd_meta=$(grep "^$cmd|" "${MAGIC_SCRIPT_DIR}/registry/ms.msreg" | head -1)
    fi

    # Fallback to cached registries
    if [ -z "$cmd_meta" ] && [ -f "$REGLIST_FILE" ]; then
        while IFS=':' read -r name url; do
            [ -z "$name" ] && continue
            [ -z "$url" ] && continue
            [ "${name#\#}" != "$name" ] && continue

            local reg_file="$REG_DIR/${name}.msreg"
            if [ -f "$reg_file" ]; then
                cmd_meta=$(grep "^$cmd|" "$reg_file" | head -1)
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
        grep "^$registry_name:" "$REGLIST_FILE" 2>/dev/null | cut -d':' -f2-
    fi
}

# Get version
get_version() {
    echo "$VERSION"
}

# Initialize on load
init_registry_dirs