#!/bin/sh

# Magic Scripts Registry System
# URL-based registry management with multi-source support

VERSION="0.0.1"

# Registry directories and files
REG_DIR="$HOME/.local/share/magicscripts/reg"
REGLIST_FILE="$REG_DIR/reglist"

# Default registry URL
DEFAULT_REGISTRY_NAME="ms"
DEFAULT_REGISTRY_URL="https://raw.githubusercontent.com/magic-scripts/ms/main/core/ms.msreg"

# Initialize registry directories and default reglist
init_registry_dirs() {
    mkdir -p "$REG_DIR" 2>/dev/null || true
    
    # Create default reglist if it doesn't exist
    if [ ! -f "$REGLIST_FILE" ]; then
        echo "# Magic Scripts Registry List" > "$REGLIST_FILE"
        echo "# Format: name:url" >> "$REGLIST_FILE"
        echo "$DEFAULT_REGISTRY_NAME:$DEFAULT_REGISTRY_URL" >> "$REGLIST_FILE"
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
        echo "Error: Invalid URL format for download: $url" >&2
        return 1
    fi
    
    # Security check: prevent access to localhost/internal IPs
    if echo "$url" | grep -q -E "(localhost|127\.0\.0\.1|0\.0\.0\.0|::1|192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)" ; then
        echo "Error: Downloads from local/internal addresses are not allowed for security" >&2
        return 1
    fi
    
    if check_command curl; then
        curl -fsSL "$url" -o "$output" 2>/dev/null
    elif check_command wget; then
        wget -q "$url" -O "$output" 2>/dev/null
    else
        echo "Error: curl or wget is required for downloading" >&2
        return 1
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
        echo "Error: Both registry name and URL are required" >&2
        return 1
    fi
    
    # Validate name (alphanumeric + underscore/hyphen only)
    if ! echo "$name" | grep -q "^[a-zA-Z0-9_-]*$"; then
        echo "Error: Registry name can only contain letters, numbers, underscore, and hyphen" >&2
        return 1
    fi
    
    # Validate URL format and security
    if ! echo "$url" | grep -q "^https\?://[a-zA-Z0-9.-]\+\.[a-zA-Z]\{2,\}"; then
        echo "Error: Invalid URL format. Must be a valid HTTP/HTTPS URL" >&2
        return 1
    fi
    
    # Security check: ensure URL points to a reasonable domain
    if echo "$url" | grep -q -E "(localhost|127\.0\.0\.1|0\.0\.0\.0|::1)"; then
        echo "Error: URLs pointing to localhost are not allowed for security reasons" >&2
        return 1
    fi
    
    # Validate registry name
    if ! echo "$name" | grep -q "^[a-zA-Z0-9_-]\+$"; then
        echo "Error: Registry name can only contain letters, numbers, underscores, and dashes" >&2
        return 1
    fi
    
    init_registry_dirs
    
    # Check if registry already exists
    if [ -f "$REGLIST_FILE" ] && grep -q "^$name:" "$REGLIST_FILE"; then
        echo "Error: Registry '$name' already exists" >&2
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
        echo "Error: Registry name is required" >&2
        return 1
    fi
    
    # Warn about removing default registry but allow it
    if [ "$name" = "$DEFAULT_REGISTRY_NAME" ]; then
        echo "Warning: Removing the default registry '$DEFAULT_REGISTRY_NAME'" >&2
        echo "You can restore it later with:" >&2
        echo "  ms reg add $DEFAULT_REGISTRY_NAME $DEFAULT_REGISTRY_URL" >&2
        echo "" >&2
    fi
    
    if [ ! -f "$REGLIST_FILE" ]; then
        echo "Error: No registry list found" >&2
        return 1
    fi
    
    # Check if registry exists
    if ! grep -q "^$name:" "$REGLIST_FILE"; then
        echo "Error: Registry '$name' not found" >&2
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
        echo "Error: No registry list found" >&2
        return 1
    fi
    
    # Get URL for registry
    url=$(grep "^$name:" "$REGLIST_FILE" | cut -d':' -f2-)
    if [ -z "$url" ]; then
        echo "Error: Registry '$name' not found in reglist" >&2
        return 1
    fi
    
    local reg_file="$REG_DIR/${name}.msreg"
    local temp_file="${reg_file}.tmp"
    
    printf "Updating %s... " "$name"
    if download_file "$url" "$temp_file"; then
        # Validate downloaded file (basic format check)
        if grep -q ":" "$temp_file" 2>/dev/null; then
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
    local temp_commands=$(mktemp) || { echo "Error: Cannot create temp file" >&2; return 1; }
    trap "rm -f '$temp_commands'" EXIT
    
    # Check development registry first (for version support)
    if [ -f "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/core/ms.msreg" ]; then
        grep -v "^#" "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/core/ms.msreg" | grep -v "^config:" | grep -v "^$" | while IFS=':' read -r cmd script desc category version checksum; do
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
                grep "^command|" "$reg_file" | while IFS='|' read -r prefix cmd script desc category version checksum; do
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
    if [ -f "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/core/ms.msreg" ]; then
        local result=$(grep "^command|$cmd|" "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/core/ms.msreg" | head -1)
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
                local result=$(grep "^command|$cmd|" "$reg_file" | head -1)
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
        echo "$info" | cut -d':' -f3
    else
        echo "Magic Scripts command"
    fi
}

# Get commands from specific registry
get_registry_commands() {
    local registry_name="$1"
    local reg_file="$REG_DIR/${registry_name}.msreg"
    
    if [ -f "$reg_file" ]; then
        grep "^command|" "$reg_file"
    else
        return 1
    fi
}

# Get config keys from all registries
get_all_config_keys() {
    local temp_configs=$(mktemp) || { echo "Error: Cannot create temp file" >&2; return 1; }
    trap "rm -f '$temp_configs'" EXIT
    
    # Check development registry first
    if [ -f "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/core/ms.msreg" ]; then
        grep "^config|" "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/core/ms.msreg" >> "$temp_configs"
    fi
    
    # Add configs from cached registries if not already found
    if [ -f "$REGLIST_FILE" ]; then
        while IFS=':' read -r name url; do
            [ -z "$name" ] && continue
            [ -z "$url" ] && continue
            [ "${name#\\#}" != "$name" ] && continue  # Skip comments
            
            local reg_file="$REG_DIR/${name}.msreg"
            if [ -f "$reg_file" ]; then
                grep "^config|" "$reg_file" | while IFS='|' read -r prefix key default desc category scripts; do
                    if [ -n "$key" ] && ! grep -q "^config|$key|" "$temp_configs" 2>/dev/null; then
                        echo "config|$key|$default|$desc|$category|$scripts" >> "$temp_configs"
                    fi
                done
            fi
        done < "$REGLIST_FILE"
    fi
    
    if [ -f "$temp_configs" ]; then
        cat "$temp_configs"
        rm -f "$temp_configs"
    fi
}

# Search commands by query
search_commands() {
    local query="$1"
    local temp_results=$(mktemp) || { echo "Error: Cannot create temp file" >&2; return 1; }
    
    echo "=== Search Results${query:+ for '$query'} ==="
    echo ""
    
    > "$temp_results"  # Clear temp file
    
    # Check development registry first (for version support)
    if [ -f "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/core/ms.msreg" ]; then
        grep "^command|" "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/core/ms.msreg" | while IFS='|' read -r prefix cmd script desc category version checksum; do
            [ -z "$cmd" ] && continue
            
            if [ -z "$query" ] || echo "$cmd $desc $category" | grep -qi "$query"; then
                # Show version if available (6-field format), otherwise show old format
                if [ -n "$version" ] && [ "$version" != "" ]; then
                    printf "  %-12s %s [%s] (v%s)\n" "$cmd" "$desc" "$category" "$version" >> "$temp_results"
                else
                    printf "  %-12s %s [%s]\n" "$cmd" "$desc" "$category" >> "$temp_results"
                fi
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
                grep "^command|" "$reg_file" | while IFS='|' read -r prefix cmd script desc category version checksum; do
                    [ -z "$cmd" ] && continue
                    
                    if [ -z "$query" ] || echo "$cmd $desc $category" | grep -qi "$query"; then
                        # Show version if available (6-field format), otherwise show old format
                        if [ -n "$version" ] && [ "$version" != "" ]; then
                            printf "  %-12s %s [%s] (v%s)\n" "$cmd" "$desc" "$category" "$version" >> "$temp_results"
                        else
                            printf "  %-12s %s [%s]\n" "$cmd" "$desc" "$category" >> "$temp_results"
                        fi
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
download_and_parse_msver() {
    local msver_url="$1"
    local target_cmd="$2"      # Optional: filter by command
    local target_version="$3"  # Optional: filter by version
    
    local temp_msver=$(mktemp) || { echo "Error: Cannot create temp file" >&2; return 1; }
    trap "rm -f '$temp_msver'" EXIT
    
    if ! download_file "$msver_url" "$temp_msver"; then
        echo "Error: Cannot download .msver file from $msver_url" >&2
        return 1
    fi
    
    # Parse .msver file
    while IFS='|' read -r entry_type key value desc_or_checksum extra1 extra2 extra3; do
        [ "${entry_type#\#}" != "$entry_type" ] && continue  # Skip comments
        [ -z "$entry_type" ] && continue
        
        case "$entry_type" in
            version)
                local version="$key"
                local url="$value" 
                local checksum="$desc_or_checksum"
                
                # Filter by version if specified
                if [ -n "$target_version" ] && [ "$version" != "$target_version" ]; then
                    continue
                fi
                
                echo "version|$version|$url|$checksum"
                ;;
            config)
                local config_key="$key"
                local default_value="$value"
                local description="$desc_or_checksum"
                local category="$extra1"
                local scripts="$extra2"
                
                # Filter by command if specified (check if command is in scripts list)
                if [ -n "$target_cmd" ]; then
                    case ",$scripts," in
                        *,"$target_cmd",*) ;; # Command found in scripts list
                        *) continue ;;        # Command not found, skip
                    esac
                fi
                
                echo "config|$config_key|$default_value|$description|$category|$scripts"
                ;;
        esac
    done < "$temp_msver"
    
    rm -f "$temp_msver"
}

# Get command info from 2-tier registry system
get_command_info() {
    local cmd="$1"
    local version="$2"  # Optional: specific version
    
    # First get command metadata from .msreg files
    local cmd_meta=""
    
    # Check development registry first
    if [ -f "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/core/ms.msreg" ]; then
        cmd_meta=$(grep "^command|$cmd|" "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/core/ms.msreg" | head -1)
    fi
    
    # Fallback to cached registries
    if [ -z "$cmd_meta" ] && [ -f "$REGLIST_FILE" ]; then
        while IFS=':' read -r name url; do
            [ -z "$name" ] && continue
            [ -z "$url" ] && continue
            [ "${name#\#}" != "$name" ] && continue  # Skip comments
            
            local reg_file="$REG_DIR/${name}.msreg"
            if [ -f "$reg_file" ]; then
                cmd_meta=$(grep "^command|$cmd|" "$reg_file" | head -1)
                [ -n "$cmd_meta" ] && break
            fi
        done < "$REGLIST_FILE"
    fi
    
    if [ -z "$cmd_meta" ]; then
        return 1
    fi
    
    # Parse command metadata: command|name|msver_url|description|category|msver_checksum
    local prefix=$(echo "$cmd_meta" | cut -d'|' -f1)
    local name=$(echo "$cmd_meta" | cut -d'|' -f2)
    local msver_url=$(echo "$cmd_meta" | cut -d'|' -f3)
    local description=$(echo "$cmd_meta" | cut -d'|' -f4)
    local category=$(echo "$cmd_meta" | cut -d'|' -f5)
    local msver_checksum=$(echo "$cmd_meta" | cut -d'|' -f6)
    
    # Now get version info from .msver file
    local version_info=""
    if [ -n "$msver_url" ]; then
        version_info=$(download_and_parse_msver "$msver_url" "$cmd" "$version")
    fi
    
    # Return combined info
    echo "command_meta|$name|$description|$category|$msver_url|$msver_checksum"
    echo "$version_info"
}

# Get all versions for a command
get_command_versions() {
    local cmd="$1"
    
    # Get command metadata first
    local cmd_info=$(get_command_info "$cmd")
    
    if [ -z "$cmd_info" ]; then
        return 1
    fi
    
    # Extract .msver URL from command metadata  
    local msver_url=$(echo "$cmd_info" | grep "^command_meta|" | cut -d'|' -f5)
    
    if [ -n "$msver_url" ]; then
        download_and_parse_msver "$msver_url" "$cmd" | grep "^version|"
    fi
}

# Get config keys for a specific command
get_command_config_keys() {
    local cmd="$1"
    
    # Get command metadata first
    local cmd_info=$(get_command_info "$cmd")
    
    if [ -z "$cmd_info" ]; then
        return 1
    fi
    
    # Extract .msver URL from command metadata
    local msver_url=$(echo "$cmd_info" | grep "^command_meta|" | cut -d'|' -f5)
    
    if [ -n "$msver_url" ]; then
        download_and_parse_msver "$msver_url" "$cmd" | grep "^config|"
    fi
}

# Get version
get_version() {
    echo "$VERSION"
}

# Initialize on load
init_registry_dirs