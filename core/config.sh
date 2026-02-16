#!/bin/sh

# Magic Scripts Configuration System
# Generic key-value configuration storage

# Configuration file paths - simplified to single config location
CONFIG_FILE="$HOME/.local/share/magicscripts/config"
REG_DIR="$HOME/.local/share/magicscripts/reg"
REGLIST_FILE="${REG_DIR}/reglist"

# Internal function to ensure directories exist
ms_internal_ensure_config_dirs() {
    mkdir -p "$(dirname "$CONFIG_FILE")" 2>/dev/null
    mkdir -p "$REG_DIR" 2>/dev/null
}

# Get configuration registry files (merged from all registries)
ms_internal_get_config_registry_file() {
    local merged_file=$(mktemp) || { echo "Error: Cannot create temp file" >&2; return 1; }
    
    # Config info is in .mspack files pointed by .msreg files
    if [ -f "$REGLIST_FILE" ]; then
        while IFS=':' read -r name url; do
            [ -z "$name" ] && continue
            [ -z "$url" ] && continue
            [ "${name#\#}" != "$name" ] && continue  # Skip comments
            
            local reg_file="${REG_DIR}/${name}.msreg"
            
            if [ -f "$reg_file" ]; then
                # Get all commands from .msreg and fetch their .msver files for config info
                grep -v "^#" "$reg_file" 2>/dev/null | grep -v "^$" | while IFS='|' read -r cmd msver_url desc category; do
                    [ -z "$cmd" ] || [ -z "$msver_url" ] && continue
                    
                    # Download and parse .msver file for config entries
                    if command -v download_and_parse_msver >/dev/null 2>&1; then
                        download_and_parse_msver "$msver_url" "$cmd" 2>/dev/null | grep "^config|" | sed 's/^config|//' | sed 's/|/:/g' >> "$merged_file"
                    else
                        # Fallback: try to source registry.sh if not available
                        if [ -f "${MAGIC_SCRIPT_DIR:-$HOME/.local/share/magicscripts}/registry.sh" ]; then
                            . "${MAGIC_SCRIPT_DIR:-$HOME/.local/share/magicscripts}/registry.sh"
                            if command -v download_and_parse_msver >/dev/null 2>&1; then
                                download_and_parse_msver "$msver_url" "$cmd" 2>/dev/null | grep "^config|" | sed 's/^config|//' | sed 's/|/:/g' >> "$merged_file"
                            fi
                        fi
                    fi
                done
            fi
        done < "$REGLIST_FILE"
    fi
    
    # Fallback to development registry
    if [ ! -s "$merged_file" ] && [ -f "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/registry/ms.msreg" ]; then
        grep -v "^#" "${MAGIC_SCRIPT_DIR:-$(dirname "$0")}/registry/ms.msreg" 2>/dev/null | grep -v "^$" | while IFS='|' read -r cmd msver_url desc category; do
            [ -z "$cmd" ] || [ -z "$msver_url" ] && continue
            
            if command -v download_and_parse_msver >/dev/null 2>&1; then
                download_and_parse_msver "$msver_url" "$cmd" 2>/dev/null | grep "^config|" | sed 's/^config|//' | sed 's/|/:/g' >> "$merged_file"
            else
                # Fallback: try to source registry.sh if not available
                if [ -f "${MAGIC_SCRIPT_DIR:-$HOME/.local/share/magicscripts}/core/registry.sh" ]; then
                    . "${MAGIC_SCRIPT_DIR:-$HOME/.local/share/magicscripts}/core/registry.sh"
                    if command -v download_and_parse_msver >/dev/null 2>&1; then
                        download_and_parse_msver "$msver_url" "$cmd" 2>/dev/null | grep "^config|" | sed 's/^config|//' | sed 's/|/:/g' >> "$merged_file"
                    fi
                fi
            fi
        done
    fi
    
    echo "$merged_file"
}

# Validate if a config key is registered and accessible
ms_internal_validate_config_key() {
    local key="$1"
    local calling_script="$2"  # optional: name of script requesting the key
    
    local config_registry_file=$(ms_internal_get_config_registry_file)
    if [ ! -f "$config_registry_file" ] || [ ! -s "$config_registry_file" ]; then
        rm -f "$config_registry_file" 2>/dev/null
        return 1  # No registry file, deny access
    fi
    
    # Check if key is registered in the config registry
    local key_entry=$(grep "^$key:" "$config_registry_file")
    if [ -z "$key_entry" ]; then
        rm -f "$config_registry_file" 2>/dev/null
        return 1  # Key not registered, deny access
    fi
    
    # If calling script is provided, check if it has access to this key
    if [ -n "$calling_script" ]; then
        local allowed_scripts=$(echo "$key_entry" | cut -d':' -f5)
        if [ "$allowed_scripts" != "all" ] && [ "$allowed_scripts" != "$calling_script" ]; then
            # Check if script is in comma-separated list
            local script_found=0
            local old_ifs="$IFS"
            IFS=","
            for script in $allowed_scripts; do
                if [ "$script" = "$calling_script" ]; then
                    script_found=1
                    break
                fi
            done
            IFS="$old_ifs"
            
            if [ $script_found -eq 0 ]; then
                rm -f "$config_registry_file" 2>/dev/null
                return 1  # Script doesn't have access to this key
            fi
        fi
    fi
    
    rm -f "$config_registry_file" 2>/dev/null
    return 0  # Key is valid and accessible
}

# Internal function to get raw config value (used by public functions)
ms_internal_get_config_value() {
    local key="$1"
    local default_value="$2"
    
    local value=""
    
    # Get value from config file
    if [ -f "$CONFIG_FILE" ]; then
        value=$(grep "^${key}=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2- | head -1)
    fi
    
    # Return value if found
    if [ -n "$value" ]; then
        echo "$value"
        return 0
    fi
    
    # Use default if provided
    if [ -n "$default_value" ]; then
        echo "Using default value for $key: $default_value" >&2
        echo "$default_value"
        return 0
    fi
    
    # Config required but not found
    echo "Configuration required: $key" >&2
    echo "Set with: ms config set $key <value>" >&2
    return 1
}

# Public API: Get configuration value with validation
# Usage: get_config_value KEY [DEFAULT] [-g for global only]
get_config_value() {
    local key="$1"
    local default_value="$2"
    
    if [ -z "$key" ]; then
        echo "Error: Configuration key is required" >&2
        return 1
    fi
    
    # Validate key is registered
    local config_registry_file=$(ms_internal_get_config_registry_file)
    if [ -f "$config_registry_file" ] && [ -s "$config_registry_file" ]; then
        # Use MS_SCRIPT_ID for script-specific validation
        local calling_script="${MS_SCRIPT_ID:-}"
        
        # If MS_SCRIPT_ID is empty or unset, deny access
        if [ -z "$calling_script" ] || [ "$calling_script" = "" ]; then
            rm -f "$config_registry_file" 2>/dev/null
            echo "Error: Configuration access denied - script identity required" >&2
            echo "This is an internal system function. Use 'ms config' commands instead." >&2
            return 1
        fi
        
        # Allow ms.sh full access to all registered keys
        if [ "$calling_script" != "ms" ]; then
            # First check if key is registered at all
            if ! grep -q "^$key:" "$config_registry_file" 2>/dev/null; then
                rm -f "$config_registry_file" 2>/dev/null
                echo "Error: Configuration key '$key' is not registered" >&2
                echo "Use 'ms config list -r' to see available configuration keys" >&2
                return 1
            fi
            
            # Then check if script has access
            if ! ms_internal_validate_config_key "$key" "$calling_script"; then
                echo "Error: Script '$calling_script' does not have access to configuration key '$key'" >&2
                echo "Use 'ms config list -r' to see available configuration keys" >&2
                return 1
            fi
        else
            # Even ms needs the key to be registered
            if ! grep -q "^$key:" "$config_registry_file" 2>/dev/null; then
                rm -f "$config_registry_file" 2>/dev/null
                echo "Error: Configuration key '$key' is not registered" >&2
                echo "Use 'ms config list -r' to see available configuration keys" >&2
                return 1
            fi
        fi
    fi
    
    rm -f "$config_registry_file" 2>/dev/null
    
    # Call internal function with validated key
    ms_internal_get_config_value "$@"
}

# Internal function to set configuration value
ms_internal_set_config_value() {
    local key="$1"
    local value="$2"
    
    if [ -z "$key" ] || [ -z "$value" ]; then
        echo "Error: Both key and value are required" >&2
        return 1
    fi
    
    ms_internal_ensure_config_dirs
    
    # Create config file if it doesn't exist
    touch "$CONFIG_FILE" 2>/dev/null || {
        echo "Error: Cannot create config file: $CONFIG_FILE" >&2
        return 1
    }
    
    # Remove existing key
    grep -v "^${key}=" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" 2>/dev/null || true
    
    # Add new key=value
    echo "${key}=${value}" >> "${CONFIG_FILE}.tmp"
    
    # Replace original file
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    
    echo "Set config: $key = $value"
}

# Public API: Set configuration value with validation
# Usage: set_config_value KEY VALUE [-g for global]
set_config_value() {
    local key="$1"
    local value="$2"
    
    if [ -z "$key" ] || [ -z "$value" ]; then
        echo "Error: Both key and value are required" >&2
        return 1
    fi
    
    # Validate key is registered
    local config_registry_file=$(ms_internal_get_config_registry_file)
    if [ -f "$config_registry_file" ] && [ -s "$config_registry_file" ]; then
        # Use MS_SCRIPT_ID for script-specific validation
        local calling_script="${MS_SCRIPT_ID:-}"
        
        # If MS_SCRIPT_ID is empty or unset, deny access
        if [ -z "$calling_script" ] || [ "$calling_script" = "" ]; then
            rm -f "$config_registry_file" 2>/dev/null
            echo "Error: Configuration access denied - script identity required" >&2
            echo "This is an internal system function. Use 'ms config' commands instead." >&2
            return 1
        fi
        
        # Allow ms.sh full access to all registered keys
        if [ "$calling_script" != "ms" ]; then
            # First check if key is registered at all
            if ! grep -q "^$key:" "$config_registry_file" 2>/dev/null; then
                rm -f "$config_registry_file" 2>/dev/null
                echo "Error: Configuration key '$key' is not registered" >&2
                echo "Use 'ms config list -r' to see available configuration keys" >&2
                return 1
            fi
            
            # Then check if script has access
            if ! ms_internal_validate_config_key "$key" "$calling_script"; then
                echo "Error: Script '$calling_script' does not have access to configuration key '$key'" >&2
                echo "Use 'ms config list -r' to see available configuration keys" >&2
                return 1
            fi
        else
            # Even ms needs the key to be registered
            if ! grep -q "^$key:" "$config_registry_file" 2>/dev/null; then
                rm -f "$config_registry_file" 2>/dev/null
                echo "Error: Configuration key '$key' is not registered" >&2
                echo "Use 'ms config list -r' to see available configuration keys" >&2
                return 1
            fi
        fi
    fi
    
    rm -f "$config_registry_file" 2>/dev/null
    
    # Call internal function with validated key
    ms_internal_set_config_value "$@"
}

# Internal function to remove configuration value
ms_internal_remove_config_value() {
    local key="$1"
    
    if [ -z "$key" ]; then
        echo "Error: Key is required" >&2
        return 1
    fi
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Config file not found: $CONFIG_FILE" >&2
        return 1
    fi
    
    # Remove the key
    grep -v "^${key}=" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" 2>/dev/null || true
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    
    echo "Removed config: $key"
}

# Public API: Remove configuration value with validation
remove_config_value() {
    local key="$1"
    
    if [ -z "$key" ]; then
        echo "Error: Key is required" >&2
        return 1
    fi
    
    # Validate key is registered
    local config_registry_file=$(ms_internal_get_config_registry_file)
    if [ -f "$config_registry_file" ] && [ -s "$config_registry_file" ]; then
        if ! ms_internal_validate_config_key "$key"; then
            rm -f "$config_registry_file" 2>/dev/null
            echo "Error: Configuration key '$key' is not registered or accessible" >&2
            echo "Use 'ms config list -r' to see available configuration keys" >&2
            return 1
        fi
    fi
    
    rm -f "$config_registry_file" 2>/dev/null
    
    # Call internal function with validated key
    ms_internal_remove_config_value "$@"
}

# Internal function to get config key info from registry
ms_internal_get_config_key_info() {
    local key="$1"
    local config_registry_file=$(ms_internal_get_config_registry_file)
    
    if [ -f "$config_registry_file" ]; then
        local result=$(grep "^$key:" "$config_registry_file" | head -1)
        rm -f "$config_registry_file" 2>/dev/null
        echo "$result"
    else
        rm -f "$config_registry_file" 2>/dev/null
    fi
}

# Internal function to get all config keys for a command/script
ms_internal_get_command_config_keys() {
    local command="$1"
    local config_registry_file=$(ms_internal_get_config_registry_file)
    
    if [ -f "$config_registry_file" ]; then
        while IFS=':' read -r key default desc category script; do
            # Check if script matches exactly, or is in comma-separated list, or is "all"
            if [ "$script" = "$command" ] || [ "$script" = "all" ] || echo ",$script," | grep -q ",$command,"; then
                echo "$key:$default:$desc:$category:$script"
            fi
        done < "$config_registry_file"
        rm -f "$config_registry_file" 2>/dev/null
    else
        rm -f "$config_registry_file" 2>/dev/null
    fi
}

# Internal function to get all registered config keys by category
ms_internal_get_config_keys_by_category() {
    local target_category="$1"
    local config_registry_file=$(ms_internal_get_config_registry_file)
    
    if [ -f "$config_registry_file" ]; then
        while IFS=':' read -r key default desc category script; do
            if [ -z "$target_category" ] || [ "$category" = "$target_category" ]; then
                echo "$key:$default:$desc:$category:$script"
            fi
        done < "$config_registry_file"
        rm -f "$config_registry_file" 2>/dev/null
    else
        rm -f "$config_registry_file" 2>/dev/null
    fi
}

# Internal function for interactive config setup
ms_internal_interactive_config_setup() {
    local target="$1"  # command name or config key
    
    if [ -z "$target" ]; then
        # Show all categories and let user choose
        echo "=== Configuration Setup ==="
        echo ""
        echo "Choose configuration category:"
        echo "  1) all       - All configuration keys"
        echo "  2) global    - Global settings (author, email)"
        echo "  3) database  - Database connection settings"
        echo "  4) docker    - Docker and compose settings"
        echo "  5) project   - Project initialization defaults"
        echo "  6) development - Development tools settings"
        echo ""
        printf "Enter category (1-6) or command name: "
        if [ -t 0 ]; then
            read -r choice < /dev/tty
        else
            exec < /dev/tty
            read -r choice
        fi
        
        case "$choice" in
            1) ms_internal_interactive_setup_category "" ;;
            2) ms_internal_interactive_setup_category "global" ;;
            3) ms_internal_interactive_setup_category "database" ;;
            4) ms_internal_interactive_setup_category "docker" ;;
            5) ms_internal_interactive_setup_category "project" ;;
            6) ms_internal_interactive_setup_category "development" ;;
            *) ms_internal_interactive_setup_command "$choice" ;;
        esac
        return
    fi
    
    # Check if target is a registered config key
    local key_info=$(ms_internal_get_config_key_info "$target")
    if [ -n "$key_info" ]; then
        ms_internal_interactive_setup_key "$target"
        return
    fi
    
    # Check if target is a command
    ms_internal_interactive_setup_command "$target"
}

# Internal function for interactive setup by category
ms_internal_interactive_setup_category() {
    local category="$1"
    local keys=""
    
    if [ -z "$category" ]; then
        echo "=== All Configuration Keys ==="
        keys=$(ms_internal_get_config_keys_by_category "")
    else
        echo "=== ${category} Configuration ==="
        keys=$(ms_internal_get_config_keys_by_category "$category")
    fi
    
    if [ -z "$keys" ]; then
        echo "No configuration keys found for category: $category"
        return 1
    fi
    
    echo ""
    
    # Use a temporary file to avoid subshell issues with read
    local temp_file=$(mktemp) || { echo "Error: Cannot create temp file" >&2; return 1; }
    echo "$keys" > "$temp_file"
    
    # Use file descriptor 3 for the temp file to avoid conflict with stdin
    exec 3< "$temp_file"
    while IFS=':' read -r key default desc category script <&3; do
        [ -z "$key" ] && continue
        current_value=$(get_config_value "$key" "$default" 2>/dev/null)
        printf "%-20s: %s\n" "$key" "$desc"
        printf "%-20s  Current: %s\n" "" "${current_value:-<not set>}"
        printf "%-20s  Default: %s\n" "" "${default:-<none>}"
        printf "Enter new value (or press Enter to keep current): "
        if [ -t 0 ]; then
            read -r new_value < /dev/tty
        else
            exec < /dev/tty
            read -r new_value
        fi
        
        if [ -n "$new_value" ]; then
            set_config_value "$key" "$new_value"
        fi
        echo ""
    done
    exec 3<&-  # Close file descriptor 3
    
    rm -f "$temp_file"
}

# Internal function for interactive setup by command
ms_internal_interactive_setup_command() {
    local command="$1"
    local keys=$(ms_internal_get_command_config_keys "$command")
    
    if [ -z "$keys" ]; then
        echo "No configuration keys found for command: $command"
        echo ""
        echo "Available commands with configuration:"
        local config_registry_file=$(ms_internal_get_config_registry_file)
        if [ -f "$config_registry_file" ]; then
            cut -d':' -f5 "$config_registry_file" | sort -u | grep -v "^$" | while read -r cmd; do
                echo "  - $cmd"
            done
            rm -f "$config_registry_file" 2>/dev/null
        else
            rm -f "$config_registry_file" 2>/dev/null
        fi
        return 1
    fi
    
    echo "=== Configuration for $command ==="
    echo ""
    
    # Use a temporary file to avoid subshell issues with read
    local temp_file=$(mktemp) || { echo "Error: Cannot create temp file" >&2; return 1; }
    echo "$keys" > "$temp_file"
    
    # Use file descriptor 3 for the temp file to avoid conflict with stdin
    exec 3< "$temp_file"
    while IFS=':' read -r key default desc category script <&3; do
        [ -z "$key" ] && continue
        current_value=$(get_config_value "$key" "$default" 2>/dev/null)
        printf "%-20s: %s\n" "$key" "$desc"
        printf "%-20s  Current: %s\n" "" "${current_value:-<not set>}"
        printf "%-20s  Default: %s\n" "" "${default:-<none>}"
        printf "Enter new value (or press Enter to keep current): "
        if [ -t 0 ]; then
            read -r new_value < /dev/tty
        else
            exec < /dev/tty
            read -r new_value
        fi
        
        if [ -n "$new_value" ]; then
            set_config_value "$key" "$new_value"
        fi
        echo ""
    done
    exec 3<&-  # Close file descriptor 3
    
    rm -f "$temp_file"
}

# Internal function for interactive setup by key
ms_internal_interactive_setup_key() {
    local key="$1"
    local key_info=$(ms_internal_get_config_key_info "$key")
    
    if [ -z "$key_info" ]; then
        echo "Configuration key '$key' not found in registry"
        return 1
    fi
    
    local default desc category script
    IFS=':' read -r _ default desc category script <<EOF
$key_info
EOF
    
    local current_value=$(get_config_value "$key" "$default" 2>/dev/null)
    
    echo "=== Configure $key ==="
    echo ""
    echo "Description: $desc"
    echo "Category: $category"
    echo "Used by: $script"
    echo "Current value: ${current_value:-<not set>}"
    echo "Default value: ${default:-<none>}"
    echo ""
    printf "Enter new value (or press Enter to keep current): "
    if [ -t 0 ]; then
        read -r new_value < /dev/tty
    else
        exec < /dev/tty
        read -r new_value
    fi
    
    if [ -n "$new_value" ]; then
        set_config_value "$key" "$new_value"
        echo ""
        echo "✓ Updated $key = $new_value"
    else
        echo ""
        echo "No changes made to $key"
    fi
}

# Internal function to list all configuration values with descriptions
ms_internal_list_config_values() {
    local show_registry=false
    local registry_filter=""
    local command_filter=""
    
    # Parse flags
    while [ $# -gt 0 ]; do
        case "$1" in
            -r|--registry) 
                show_registry=true
                if [ -n "$2" ] && [ "${2#-}" = "$2" ]; then
                    registry_filter="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            -c|--command) 
                show_registry=true
                if [ -n "$2" ] && [ "${2#-}" = "$2" ]; then
                    command_filter="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            *) shift ;;
        esac
    done
    
    if [ "$show_registry" = true ]; then
        if [ -n "$registry_filter" ]; then
            echo "=== Configuration Keys for Registry '$registry_filter' ==="
        elif [ -n "$command_filter" ]; then
            echo "=== Configuration Keys for Command '$command_filter' ==="
        else
            echo "=== Available Configuration Keys ==="
        fi
        echo ""
        
        # Get config keys based on filter
        local config_found=false
        
        if [ -n "$registry_filter" ]; then
            # Get config keys from specific registry
            local reg_file="${REG_DIR}/${registry_filter}.msreg"
            if [ -f "$reg_file" ]; then
                grep -v "^#" "$reg_file" 2>/dev/null | grep -v "^$" | while IFS='|' read -r cmd msver_url desc category; do
                    [ -z "$cmd" ] || [ -z "$msver_url" ] && continue
                    
                    if command -v download_and_parse_msver >/dev/null 2>&1; then
                        download_and_parse_msver "$msver_url" "$cmd" 2>/dev/null | grep "^config|" | while IFS='|' read -r config_prefix key default desc cat scripts; do
                            printf "%-20s [%s]: %s\n" "$key" "${cat:-misc}" "$desc"
                            printf "%-20s Default: %s, Used by: %s\n" "" "${default:-<none>}" "$scripts"
                            echo ""
                            config_found=true
                        done
                    else
                        # Fallback: try to source registry.sh if not available
                        if [ -f "${MAGIC_SCRIPT_DIR:-$HOME/.local/share/magicscripts}/registry.sh" ]; then
                            . "${MAGIC_SCRIPT_DIR:-$HOME/.local/share/magicscripts}/registry.sh"
                            if command -v download_and_parse_msver >/dev/null 2>&1; then
                                download_and_parse_msver "$msver_url" "$cmd" 2>/dev/null | grep "^config|" | while IFS='|' read -r config_prefix key default desc cat scripts; do
                                    printf "%-20s [%s]: %s\n" "$key" "${cat:-misc}" "$desc"
                                    printf "%-20s Default: %s, Used by: %s\n" "" "${default:-<none>}" "$scripts"
                                    echo ""
                                    config_found=true
                                done
                            fi
                        fi
                    fi
                done
            else
                echo "Registry '$registry_filter' not found"
            fi
        elif [ -n "$command_filter" ]; then
            # Get config keys for specific command
            if command -v get_command_config_keys >/dev/null 2>&1; then
                get_command_config_keys "$command_filter" | while IFS='|' read -r config_prefix key default desc cat scripts; do
                    printf "%-20s [%s]: %s\n" "$key" "${cat:-misc}" "$desc"
                    printf "%-20s Default: %s, Used by: %s\n" "" "${default:-<none>}" "$scripts"
                    echo ""
                    config_found=true
                done
            fi
        else
            # Get all config keys
            local config_registry_file=$(ms_internal_get_config_registry_file)
            if [ -f "$config_registry_file" ]; then
                while IFS=':' read -r key default desc category script; do
                    [ -z "$key" ] && continue
                    printf "%-20s [%s]: %s\n" "$key" "$category" "$desc"
                    printf "%-20s Default: %s, Used by: %s\n" "" "${default:-<none>}" "$script"
                    echo ""
                    config_found=true
                done < "$config_registry_file"
                rm -f "$config_registry_file" 2>/dev/null
            else
                echo "Config registry not found"
                rm -f "$config_registry_file" 2>/dev/null
            fi
        fi
        
        if [ "$config_found" != true ]; then
            if [ -n "$registry_filter" ]; then
                echo "No configuration keys found for registry '$registry_filter'"
            elif [ -n "$command_filter" ]; then
                echo "No configuration keys found for command '$command_filter'"
            else
                echo "No configuration keys found"
            fi
        fi
        return
    fi
    
    echo "=== Configuration Values ==="
    echo ""
    
    if [ -f "$CONFIG_FILE" ]; then
        echo "Config file ($CONFIG_FILE):"
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                key=$(echo "$line" | cut -d'=' -f1)
                value=$(echo "$line" | cut -d'=' -f2-)
                key_info=$(ms_internal_get_config_key_info "$key")
                if [ -n "$key_info" ]; then
                    desc=$(echo "$key_info" | cut -d':' -f3)
                    printf "  %-20s = %-20s # %s\n" "$key" "$value" "$desc"
                else
                    printf "  %s\n" "$line"
                fi
            fi
        done < "$CONFIG_FILE"
        echo ""
    else
        echo "No configuration file found."
        echo "Use 'ms config set <key> <value>' to add configuration."
        echo "Use 'ms config set <command>' for interactive setup."
    fi
}