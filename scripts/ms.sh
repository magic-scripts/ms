#!/bin/sh

# Set script identity for full config system access
export MS_SCRIPT_ID="ms"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MAGIC_SCRIPT_DIR="${MAGIC_SCRIPT_DIR:-$HOME/.local/share/magicscripts}"

# Cleanup function for safe exit
cleanup_ms() {
    # Clear reinstall mode flag if set
    if [ -n "${MS_REINSTALL_MODE:-}" ]; then
        unset MS_REINSTALL_MODE 2>/dev/null || true
    fi
    
    # Clean up any temp files created during execution
    # Add temp file cleanup here if needed in future
}

# Set trap for cleanup on exit/interrupt
trap cleanup_ms EXIT INT TERM

# Try to load libraries
for lib in config.sh registry.sh; do
    if [ -f "$MAGIC_SCRIPT_DIR/core/$lib" ]; then
        . "$MAGIC_SCRIPT_DIR/core/$lib"
    elif [ -f "$SCRIPT_DIR/../core/$lib" ]; then
        . "$SCRIPT_DIR/../core/$lib"
    elif [ -f "$SCRIPT_DIR/../$lib" ]; then
        . "$SCRIPT_DIR/../$lib"
    fi
done

# Version
VERSION="dev"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Format version for display
format_version() {
    local version="$1"
    if [ "$version" = "dev" ]; then
        echo "$version"
    else
        echo "v$version"
    fi
}

show_banner() {
    echo "${MAGENTA}╔═══════════════════════════════════════╗${NC}"
    echo "${MAGENTA}║             ${CYAN}Magic Scripts${MAGENTA}             ║${NC}"
    echo "${MAGENTA}║      ${YELLOW}Developer Automation Tools${MAGENTA}       ║${NC}"
    echo "${MAGENTA}╚═══════════════════════════════════════╝${NC}"
    echo "${BLUE}Version: $(format_version "$VERSION")${NC}"
    echo ""
}

show_help() {
    show_banner
    echo "${YELLOW}Usage:${NC}"
    echo "  ${CYAN}ms${NC} <command> [options]"
    echo ""
    echo "${YELLOW}Commands:${NC}"
    echo "  ${GREEN}help${NC}                    Show this help message"
    echo "  ${GREEN}version${NC}                 Show version information"
    echo "  ${GREEN}status${NC}                  Show installation status"
    echo "  ${GREEN}doctor${NC}                  Diagnose and repair system issues"
    echo "  ${GREEN}search [query]${NC}          Search for available commands"
    echo "  ${GREEN}upgrade${NC}                 Update all registries to latest version"
    echo ""
    echo "${YELLOW}Configuration:${NC}"
    echo "  ${GREEN}config list${NC}             List all configuration values"
    echo "  ${GREEN}config list -r [registry]${NC} Show available config keys (optionally filtered)"
    echo "  ${GREEN}config list -c <command>${NC}  Show config keys for specific command"
    echo "  ${GREEN}config set <key> <value>${NC} Set a configuration value"
    echo "  ${GREEN}config get <key>${NC}        Get a configuration value"
    echo "  ${GREEN}config remove <key>${NC}     Remove a configuration value"
    echo ""
    echo "${YELLOW}Registry Management:${NC}"
    echo "  ${GREEN}reg list${NC}                List all registries"
    echo "  ${GREEN}reg add <name> <url>${NC}    Add a new registry"
    echo "  ${GREEN}reg remove <name>${NC}       Remove a registry"
    echo ""
    echo "${YELLOW}Package Management:${NC}"
    echo "  ${GREEN}install <commands...>${NC}   Install specific commands (use cmd:version for versions)"
    echo "  ${GREEN}install -r <registry>${NC}   Install all commands from a registry"
    echo "  ${GREEN}reinstall <commands...>${NC} Completely reinstall commands (remove + install)"
    echo "  ${GREEN}update${NC}                  Update all installed commands and Magic Scripts"
    echo "  ${GREEN}update <command>${NC}        Update specific command to latest version"
    echo "  ${GREEN}update self${NC}             Update Magic Scripts itself only"
    echo "  ${GREEN}uninstall <commands...>${NC} Uninstall specific commands"
    echo "  ${GREEN}versions <command>${NC}      Show available versions for a command"
    echo ""
    
    # Show installed commands only
    INSTALL_DIR="$HOME/.local/bin/ms"
    echo "${YELLOW}Installed Magic Scripts:${NC}"
    local installed_count=0
    local installed_list=""
    
    if command -v get_all_commands >/dev/null 2>&1; then
        installed_list=$(get_all_commands | while IFS= read -r cmd; do
            if [ -f "$INSTALL_DIR/$cmd" ]; then
                if command -v get_script_description >/dev/null 2>&1; then
                    desc=$(get_script_description "$cmd" 2>/dev/null || echo "Magic Scripts command")
                else
                    desc="Magic Scripts command"
                fi
                printf "  ${GREEN}%-12s${NC} %s\n" "$cmd" "$desc"
                echo "INSTALLED" >&2
            fi
        done 2>&1)
    fi
    
    if echo "$installed_list" | grep -q "INSTALLED"; then
        echo "$installed_list" | grep -v "INSTALLED"
        installed_count=$(echo "$installed_list" | grep -c "INSTALLED")
    else
        echo "  ${YELLOW}No commands installed${NC}"
        echo "  Use ${CYAN}ms search${NC} to browse available commands"
        echo "  Use ${CYAN}ms install <registry>${NC} to install from a registry"
    fi
    
    echo ""
    echo "${YELLOW}Examples:${NC}"
    echo "  ${CYAN}ms config set AUTHOR_NAME 'Your Name'${NC}  # Set author name"
    echo "  ${CYAN}ms reg add custom <url>${NC}                # Add custom registry"
    echo "  ${CYAN}ms search docker${NC}                       # Search for docker commands"
    echo "  ${CYAN}ms install ms${NC}                          # Install all from ms registry"
    echo "  ${CYAN}ms install gigen licgen${NC}                # Install specific commands"
    echo "  ${CYAN}ms upgrade${NC}                             # Update all registries"
    echo "  ${CYAN}ms status${NC}                              # Check installation"
}

# Wrapper for backward compatibility - converts new 2-tier format to old format
get_script_info() {
    local cmd="$1"
    local version="$2"  # Optional
    
    # Get command info using new 2-tier system
    local cmd_info
    if command -v get_command_info >/dev/null 2>&1; then
        cmd_info=$(get_command_info "$cmd" "$version")
        
        if [ -n "$cmd_info" ]; then
            # Extract command metadata: command_meta|name|description|category|msver_url|msver_checksum
            local cmd_meta=$(echo "$cmd_info" | grep "^command_meta|" | head -1)
            
            if [ -n "$cmd_meta" ]; then
                local name=$(echo "$cmd_meta" | cut -d'|' -f2)
                local description=$(echo "$cmd_meta" | cut -d'|' -f3)
                local category=$(echo "$cmd_meta" | cut -d'|' -f4)
                local msver_url=$(echo "$cmd_meta" | cut -d'|' -f5)
                
                # Get version info - use specified version or first available version
                local version_info
                if [ -n "$version" ]; then
                    version_info=$(echo "$cmd_info" | grep "^version|$version|" | head -1)
                else
                    version_info=$(echo "$cmd_info" | grep "^version|" | head -1)
                fi
                
                if [ -n "$version_info" ]; then
                    local ver=$(echo "$version_info" | cut -d'|' -f2)
                    local url=$(echo "$version_info" | cut -d'|' -f3)  
                    local checksum=$(echo "$version_info" | cut -d'|' -f4)
                    local install_script=$(echo "$version_info" | cut -d'|' -f5)
                    local uninstall_script=$(echo "$version_info" | cut -d'|' -f6)
                    
                    # Return in extended format: command|name|script_uri|description|category|version|checksum|install_script|uninstall_script
                    echo "command|$name|$url|$description|$category|$ver|$checksum|$install_script|$uninstall_script"
                    return 0
                fi
            fi
        fi
    fi
    
    return 1
}

# Helper for install functions - finds best version for a command
find_best_version() {
    local cmd="$1"
    local requested_version="$2"  # Optional: specific version requested
    local allow_dev="$3"          # Optional: allow dev versions
    
    if command -v get_command_versions >/dev/null 2>&1; then
        local versions=$(get_command_versions "$cmd")
        
        if [ -z "$versions" ]; then
            return 1
        fi
        
        local best_version=""
        local best_url=""
        local best_checksum=""
        local dev_version=""
        local dev_url=""
        local dev_checksum=""
        
        # Parse all available versions
        echo "$versions" | while IFS='|' read -r prefix version url checksum; do
            [ "$prefix" != "version" ] && continue
            
            # If specific version requested, match exactly
            if [ -n "$requested_version" ]; then
                if [ "$version" = "$requested_version" ]; then
                    echo "$version|$url|$checksum"
                    return 0
                fi
                continue
            fi
            
            # Store dev version separately
            if [ "$version" = "dev" ]; then
                dev_version="$version"
                dev_url="$url"
                dev_checksum="$checksum"
                if [ "$allow_dev" = "true" ]; then
                    echo "$version|$url|$checksum"
                    return 0
                fi
                continue
            fi
            
            # Find highest semantic version (simplified - just use first non-dev for now)
            if [ -z "$best_version" ]; then
                best_version="$version"
                best_url="$url"
                best_checksum="$checksum"
            fi
        done
        
        # If we get here and no specific version was found, return best or dev fallback
        if [ -n "$best_version" ]; then
            echo "$best_version|$best_url|$best_checksum"
            return 0
        elif [ -n "$dev_version" ]; then
            echo "$dev_version|$dev_url|$dev_checksum"
            return 0
        fi
    fi
    
    return 1
}

suggest_similar_command() {
    local input="$1"
    
    # Common typos and patterns
    case "$input" in
        add|Add)
            echo "install"
            ;;
        remove|Remove|rm|delete)
            echo "uninstall"
            ;;
        list|ls)
            echo "search"
            ;;
        find)
            echo "search"
            ;;
        info|show)
            echo "status"
            ;;
        fix|repair)
            echo "doctor"
            ;;
        get)
            echo "install"
            ;;
        put)
            echo "install"
            ;;
        conf|configure)
            echo "config"
            ;;
        registry|repo)
            echo "reg"
            ;;
        ver|--version|-v)
            echo "version"
            ;;
        h|--help|-h)
            echo "help"
            ;;
        *)
            # Check for single character typos or similar patterns
            for cmd in help version status doctor upgrade search install uninstall update versions reinstall config reg; do
                # Check if input is a substring or close match
                case "$cmd" in
                    *"$input"*|"$input"*)
                        echo "$cmd"
                        return
                        ;;
                esac
                
                # Check if they start with the same letter and are similar length
                input_first=$(echo "$input" | cut -c1)
                cmd_first=$(echo "$cmd" | cut -c1)
                input_len=${#input}
                cmd_len=${#cmd}
                len_diff=$((input_len - cmd_len))
                if [ $len_diff -lt 0 ]; then
                    len_diff=$((-len_diff))
                fi
                
                if [ "$input_first" = "$cmd_first" ] && [ $len_diff -le 2 ]; then
                    echo "$cmd"
                    return
                fi
            done
            ;;
    esac
}

show_status() {
    echo "${YELLOW}Magic Scripts Installation Status${NC}"
    echo "================================"
    echo ""
    
    INSTALL_DIR="$HOME/.local/bin/ms"
    
    # Get installed commands by scanning install directory
    if command -v get_all_commands >/dev/null 2>&1; then
        all_commands=$(get_all_commands | tr '\n' ' ')
    else
        # Fallback: scan installation directory directly
        all_commands=""
        if [ -d "$INSTALL_DIR" ]; then
            for cmd_file in "$INSTALL_DIR"/*; do
                [ -e "$cmd_file" ] || continue
                if [ -x "$cmd_file" ]; then
                    local cmd=$(basename "$cmd_file")
                    all_commands="$all_commands $cmd"
                fi
            done
        fi
    fi
    
    echo "${CYAN}Installed Commands:${NC}"
    local installed_count=0
    for cmd in $all_commands; do
        if [ -f "$INSTALL_DIR/$cmd" ]; then
            # Get version and description
            local version=$(get_installed_version "$cmd")
            if [ "$version" = "unknown" ] || [ -z "$version" ]; then
                version="?"
            fi
            
            if command -v get_script_description >/dev/null 2>&1; then
                desc=$(get_script_description "$cmd" 2>/dev/null || echo "Magic Scripts command")
            else
                desc="Magic Scripts command"
            fi
            
            printf "  ${GREEN}✓ %-12s${NC} ${BLUE}[%s]${NC} %s\n" "$cmd" "$version" "$desc"
            installed_count=$((installed_count + 1))
        fi
    done
    
    if [ $installed_count -eq 0 ]; then
        echo "  ${YELLOW}No commands installed${NC}"
        echo "  Use ${CYAN}ms install${NC} to install commands"
    fi
    
    echo ""
    echo "${CYAN}Directories:${NC}"
    if [ -d "$MAGIC_SCRIPT_DIR" ]; then
        echo "  ${GREEN}✓${NC} Magic Scripts directory: $MAGIC_SCRIPT_DIR"
    else
        echo "  ${RED}✗${NC} Magic Scripts directory: $MAGIC_SCRIPT_DIR"
    fi
    
    if [ -d "$HOME/.local/share/magicscripts" ]; then
        echo "  ${GREEN}✓${NC} Magic Scripts data directory: $HOME/.local/share/magicscripts"
    else
        echo "  ${RED}✗${NC} Magic Scripts data directory: $HOME/.local/share/magicscripts"
    fi
    
    echo ""
    echo "${CYAN}Configuration:${NC}"
    if [ -f "$HOME/.local/share/magicscripts/config" ]; then
        echo "  ${GREEN}✓${NC} Config file: $HOME/.local/share/magicscripts/config"
    else
        echo "  ${YELLOW}!${NC} Config file: Not found (will use defaults)"
    fi
    
    echo ""
    echo "${CYAN}PATH:${NC}"
    if echo "$PATH" | grep -q "$INSTALL_DIR"; then
        echo "  ${GREEN}✓${NC} $INSTALL_DIR is in PATH"
    else
        echo "  ${RED}✗${NC} $INSTALL_DIR is NOT in PATH"
        echo "  Add to your shell config: ${CYAN}export PATH=\"$INSTALL_DIR:\$PATH\"${NC}"
    fi
    
    echo ""
    echo "Total installed: ${GREEN}$installed_count${NC} commands"
}

handle_config() {
    case "$1" in
        list)
            shift
            if command -v ms_internal_list_config_values >/dev/null 2>&1; then
                ms_internal_list_config_values "$@"
            else
                echo "${RED}Config system not available${NC}"
                exit 1
            fi
            ;;
        set)
            shift
            
            # Handle interactive setup: ms config set <command_or_key> or ms config set
            if [ $# -eq 1 ] || [ $# -eq 0 ]; then
                if command -v ms_internal_interactive_config_setup >/dev/null 2>&1; then
                    ms_internal_interactive_config_setup "$1"  # $1 will be empty for ms config set
                else
                    echo "${RED}Interactive config system not available${NC}"
                    exit 1
                fi
                return
            fi
            
            # Handle direct key-value setting: ms config set <key> <value>
            if [ -z "$1" ] || [ -z "$2" ]; then
                echo "${RED}Error: Usage: ms config set <key> <value>${NC}"
                echo "${RED}   or: ms config set <command_or_key>        # Interactive setup${NC}"
                exit 1
            fi
            
            if command -v set_config_value >/dev/null 2>&1; then
                set_config_value "$1" "$2"
            else
                echo "${RED}Config system not available${NC}"
                exit 1
            fi
            ;;
        get)
            if [ -z "$2" ]; then
                echo "${RED}Error: Usage: ms config get <key>${NC}"
                exit 1
            fi
            
            if command -v get_config_value >/dev/null 2>&1; then
                value=$(get_config_value "$2")
                if [ $? -eq 0 ]; then
                    echo "${CYAN}$2${NC} = ${YELLOW}$value${NC}"
                else
                    echo "${RED}Key not found: $2${NC}"
                    exit 1
                fi
            else
                echo "${RED}Config system not available${NC}"
                exit 1
            fi
            ;;
        remove)
            shift
            
            if [ -z "$1" ]; then
                echo "${RED}Error: Usage: ms config remove <key>${NC}"
                exit 1
            fi
            
            if command -v remove_config_value >/dev/null 2>&1; then
                remove_config_value "$1"
            else
                echo "${RED}Config system not available${NC}"
                exit 1
            fi
            ;;
        *)
            echo "${RED}Error: Unknown config command: $1${NC}"
            echo "Available: list, set, get, remove"
            echo ""
            echo "${YELLOW}Usage:${NC}"
            echo "  ${CYAN}ms config list${NC}                      # List current config values"
            echo "  ${CYAN}ms config list -r${NC}                   # Show all available config keys"
            echo "  ${CYAN}ms config list -r template${NC}          # Show config keys from template registry"
            echo "  ${CYAN}ms config list -c msworld${NC}           # Show config keys for msworld command"
            echo "  ${CYAN}ms config set AUTHOR_NAME 'Your Name'${NC} # Set specific config"
            echo "  ${CYAN}ms config set DB_HOST localhost${NC}     # Set config value"
            echo "  ${CYAN}ms config set gigen${NC}                 # Interactive setup for gigen"
            echo "  ${CYAN}ms config set AUTHOR_NAME${NC}           # Interactive setup for single key"
            echo "  ${CYAN}ms config set${NC}                       # Interactive setup menu"
            echo "  ${CYAN}ms config get AUTHOR_NAME${NC}            # Get config value"
            exit 1
            ;;
    esac
}

handle_reg() {
    case "$1" in
        list)
            if command -v list_registries >/dev/null 2>&1; then
                list_registries
            else
                echo "${RED}Registry system not available${NC}"
                exit 1
            fi
            ;;
        add)
            if [ -z "$2" ] || [ -z "$3" ]; then
                echo "${RED}Error: Usage: ms reg add <name> <url>${NC}"
                exit 1
            fi
            
            if command -v add_registry >/dev/null 2>&1; then
                add_registry "$2" "$3"
            else
                echo "${RED}Registry system not available${NC}"
                exit 1
            fi
            ;;
        remove)
            if [ -z "$2" ]; then
                echo "${RED}Error: Usage: ms reg remove <name>${NC}"
                exit 1
            fi
            
            if command -v remove_registry >/dev/null 2>&1; then
                remove_registry "$2"
            else
                echo "${RED}Registry system not available${NC}"
                exit 1
            fi
            ;;
        *)
            echo "${RED}Error: Unknown registry command: $1${NC}"
            echo "Available: list, add, remove"
            echo ""
            echo "${YELLOW}Examples:${NC}"
            echo "  ${CYAN}ms reg list${NC}                    # List all registries"
            echo "  ${CYAN}ms reg add custom <url>${NC}       # Add a new registry"
            echo "  ${CYAN}ms reg remove custom${NC}          # Remove a registry"
            echo ""
            echo "Use ${CYAN}ms upgrade${NC} to update all registries."
            exit 1
            ;;
    esac
}

handle_search() {
    local query="$1"
    
    if command -v search_commands >/dev/null 2>&1; then
        search_commands "$query"
    else
        echo "${RED}Search system not available${NC}"
        exit 1
    fi
}

# Install all commands from a specific registry
install_registry_all() {
    local registry_name="$1"
    
    if ! command -v get_registry_commands >/dev/null 2>&1; then
        echo "${RED}Error: Registry system not available${NC}"
        return 1
    fi
    
    local registry_commands=""
    registry_commands=$(get_registry_commands "$registry_name" 2>/dev/null)
    
    if [ -z "$registry_commands" ]; then
        echo "${RED}Error: Registry '$registry_name' not found or empty${NC}"
        return 1
    fi
    
    echo "Installing all commands from '$registry_name' registry..."
    echo ""
    
    local installed_count=0
    local failed_count=0
    
    # Use temporary file to avoid subshell variable issues
    local temp_file=$(mktemp) || { echo "${RED}Error: Cannot create temp file${NC}"; return 1; }
    echo "$registry_commands" > "$temp_file"
    
    while IFS='|' read -r cmd msver_url desc category; do
        [ -z "$cmd" ] && continue
        [ "$cmd" = "ms" ] && continue  # Skip ms core command
        
        printf "  Installing ${CYAN}%s${NC}... " "$cmd"
        
        # Use get_command_info to get proper script URL from 2-tier system
        local full_cmd_info=$(get_command_info "$cmd" 2>/dev/null)
        local version_info=$(echo "$full_cmd_info" | grep "^version|" | head -1)
        
        local install_result
        if [ -n "$version_info" ]; then
            # Extract script URL from version info: version|version_name|script_url|checksum|install_script|uninstall_script|update_script|man_url
            local script_url=$(echo "$version_info" | cut -d'|' -f3)
            local version_name=$(echo "$version_info" | cut -d'|' -f2)
            local install_script_url=$(echo "$version_info" | cut -d'|' -f5)
            local uninstall_script_url=$(echo "$version_info" | cut -d'|' -f6)
            local update_script_url=$(echo "$version_info" | cut -d'|' -f7)
            local man_url=$(echo "$version_info" | cut -d'|' -f8)
            
            install_script "$cmd" "$script_url" "$registry_name" "$version_name" "" "$install_script_url" "$uninstall_script_url" "$update_script_url" "$man_url"
            install_result=$?
        else
            echo "${RED}no version available${NC}"
            install_result=1
            continue
        fi
        
        case $install_result in
            0)
                echo "${GREEN}done${NC}"
                installed_count=$((installed_count + 1))
                ;;
            2)
                echo "${YELLOW}already installed${NC}"
                ;;
            *)
                echo "${RED}failed${NC}"
                failed_count=$((failed_count + 1))
                ;;
        esac
    done < "$temp_file"
    
    rm -f "$temp_file"
    
    echo ""
    echo "Registry installation complete!"
    echo "Installed: ${GREEN}$installed_count${NC} commands"
    [ $failed_count -gt 0 ] && echo "Failed: ${RED}$failed_count${NC} commands"
}

# Install specific commands with duplicate detection
install_commands_with_detection() {
    local commands=("$@")
    local installed_count=0
    local failed_count=0
    
    for cmd in "${commands[@]}"; do
        # Parse command:version format
        local base_cmd="$cmd"
        local requested_version=""
        if echo "$cmd" | grep -q ':'; then
            base_cmd=$(echo "$cmd" | cut -d':' -f1)
            requested_version=$(echo "$cmd" | cut -d':' -f2)
            # Convert 'latest' to empty (means get highest version)
            if [ "$requested_version" = "latest" ]; then
                requested_version=""
            fi
        fi
        
        if [ "$base_cmd" = "ms" ]; then
            printf "  Installing ${CYAN}%s${NC}... " "$cmd"
            echo "${YELLOW}already installed${NC}"
            echo "  Use ${CYAN}ms reinstall ms${NC} to reinstall"
            continue
        fi
        
        # Find command in registries using 2-tier system
        local found_registries=()
        local registry_info=()
        
        if command -v get_registry_names >/dev/null 2>&1; then
            local registries_list=$(get_registry_names)
            
            for registry_name in $registries_list; do
                if command -v get_registry_commands >/dev/null 2>&1; then
                    local registry_commands=$(get_registry_commands "$registry_name" 2>/dev/null)
                    
                    # In 2-tier system, just check if command exists by name in .msreg
                    local cmd_info=$(echo "$registry_commands" | grep "^$base_cmd|" | head -1)
                    
                    if [ -n "$cmd_info" ]; then
                        # Now check if requested version is available in .msver
                        local full_cmd_info=$(get_command_info "$base_cmd" "$requested_version" 2>/dev/null)
                        local version_info=""
                        
                        if [ -n "$requested_version" ]; then
                            # Look for specific version
                            version_info=$(echo "$full_cmd_info" | grep "^version|$requested_version|")
                        else
                            # Look for best available version (non-dev first, then dev)
                            version_info=$(echo "$full_cmd_info" | grep "^version|" | grep -v "^version|dev|" | head -1)
                            if [ -z "$version_info" ]; then
                                version_info=$(echo "$full_cmd_info" | grep "^version|dev|" | head -1)
                            fi
                        fi
                        
                        # Only add to found registries if version is available
                        if [ -n "$version_info" ]; then
                            found_registries+=("$registry_name")
                            # Create registry info with version information: command|name|msver_url|desc|category|version
                            local name=$(echo "$cmd_info" | cut -d'|' -f1)
                            local msver_url=$(echo "$cmd_info" | cut -d'|' -f2)
                            local desc=$(echo "$cmd_info" | cut -d'|' -f3)
                            local category=$(echo "$cmd_info" | cut -d'|' -f4)
                            local version=$(echo "$version_info" | cut -d'|' -f2)
                            
                            registry_info+=("command|$name|$msver_url|$desc|$category|$version")
                        fi
                    fi
                fi
            done
        fi
        
        # Handle installation based on what we found
        if [ ${#found_registries[@]} -eq 0 ]; then
            printf "  Installing ${CYAN}%s${NC}... " "$base_cmd"
            if [ -n "$requested_version" ]; then
                echo "${RED}version $requested_version not found in any registry${NC}"
            else
                echo "${RED}not found in any registry${NC}"
            fi
            failed_count=$((failed_count + 1))
            continue
        elif [ ${#found_registries[@]} -eq 1 ]; then
            # Single registry found
            local target_registry="${found_registries[0]}"
            local target_info="${registry_info[0]}"
            local found_version=$(echo "$target_info" | cut -d'|' -f6)
            
            printf "  Installing ${CYAN}%s${NC}" "$base_cmd"
            if [ -n "$requested_version" ] && [ "$requested_version" != "latest" ]; then
                printf ":${CYAN}%s${NC}" "$requested_version"
            elif [ "$found_version" != "" ]; then
                printf ":${CYAN}%s${NC}" "$found_version"
            fi
            printf " from ${YELLOW}%s${NC}... " "$target_registry"
            
            # Show warning if installing dev version without explicit request
            if [ "$found_version" = "dev" ] && [ -z "$requested_version" ]; then
                echo ""
                echo "    ${YELLOW}⚠️  Installing development version (no stable release available)${NC}"
                printf "    "
            fi
            
            # Use get_command_info to get proper script URL from 2-tier system
            local full_cmd_info=$(get_command_info "$base_cmd" "$found_version" 2>/dev/null)
            local version_info=$(echo "$full_cmd_info" | grep "^version|$found_version|" | head -1)
            
            # If specific version not found, try any available version
            if [ -z "$version_info" ]; then
                version_info=$(echo "$full_cmd_info" | grep "^version|" | head -1)
            fi
            
            local install_result
            if [ -n "$version_info" ]; then
                # Extract script URL from version info: version|version_name|script_url|checksum|install_script|uninstall_script|update_script|man_url|man_url
                local script_url=$(echo "$version_info" | cut -d'|' -f3)
                local install_hook_script=$(echo "$version_info" | cut -d'|' -f5)
                local uninstall_hook_script=$(echo "$version_info" | cut -d'|' -f6)
                local update_hook_script=$(echo "$version_info" | cut -d'|' -f7)
                local man_url=$(echo "$version_info" | cut -d'|' -f8)
                
                install_script "$base_cmd" "$script_url" "$target_registry" "$found_version" "" "$install_hook_script" "$uninstall_hook_script" "$update_hook_script" "$man_url"
                install_result=$?
            else
                echo "${RED}no version available${NC}"
                install_result=1
            fi
            
            case $install_result in
                0)
                    echo "${GREEN}done${NC}"
                    installed_count=$((installed_count + 1))
                    ;;
                2)
                    echo "${YELLOW}already installed${NC}"
                    ;;
                *)
                    echo "${RED}failed${NC}"
                    failed_count=$((failed_count + 1))
                    ;;
            esac
        else
            # Multiple registries found - show selection menu
            echo ""
            echo "${YELLOW}Command '$cmd' found in multiple registries:${NC}"
            for i in $(seq 0 $((${#found_registries[@]} - 1))); do
                echo "  $((i + 1))) ${found_registries[$i]}"
            done
            echo ""
            printf "Choose registry (1-${#found_registries[@]}): "
            read choice < /dev/tty
            
            if [ "$choice" -ge 1 ] && [ "$choice" -le ${#found_registries[@]} ]; then
                local selected_index=$((choice - 1))
                local target_registry="${found_registries[$selected_index]}"
                local target_info="${registry_info[$selected_index]}"
                local found_version=$(echo "$target_info" | cut -d'|' -f6)
                
                printf "  Installing ${CYAN}%s${NC}" "$base_cmd"
                if [ -n "$requested_version" ] && [ "$requested_version" != "latest" ]; then
                    printf ":${CYAN}%s${NC}" "$requested_version"
                elif [ "$found_version" != "" ]; then
                    printf ":${CYAN}%s${NC}" "$found_version"
                fi
                printf " from ${YELLOW}%s${NC}... " "$target_registry"
                
                # Show warning if installing dev version without explicit request
                if [ "$found_version" = "dev" ] && [ -z "$requested_version" ]; then
                    echo ""
                    echo "    ${YELLOW}⚠️  Installing development version (no stable release available)${NC}"
                    printf "    "
                fi
                
                # Use get_command_info to get proper script URL from 2-tier system
                local full_cmd_info=$(get_command_info "$base_cmd" "$found_version" 2>/dev/null)
                local version_info=$(echo "$full_cmd_info" | grep "^version|$found_version|" | head -1)
                
                # If specific version not found, try any available version
                if [ -z "$version_info" ]; then
                    version_info=$(echo "$full_cmd_info" | grep "^version|" | head -1)
                fi
                
                local install_result
                if [ -n "$version_info" ]; then
                    # Extract script URL from version info: version|version_name|script_url|checksum|install_script|uninstall_script|update_script|man_url|man_url|man_url
                    local script_url=$(echo "$version_info" | cut -d'|' -f3)
                    local install_script_url=$(echo "$version_info" | cut -d'|' -f5)
                    local uninstall_script_url=$(echo "$version_info" | cut -d'|' -f6)
                    local update_script_url=$(echo "$version_info" | cut -d'|' -f7)
                    local man_url=$(echo "$version_info" | cut -d'|' -f8)
                    
                    install_script "$base_cmd" "$script_url" "$target_registry" "$found_version" "" "$install_script_url" "$uninstall_script_url" "$update_script_url" "$man_url"
                    install_result=$?
                else
                    echo "${RED}no version available${NC}"
                    install_result=1
                fi
                
                case $install_result in
                    0)
                        echo "${GREEN}done${NC}"
                        installed_count=$((installed_count + 1))
                        ;;
                    2)
                        echo "${YELLOW}already installed${NC}"
                        ;;
                    *)
                        echo "${RED}failed${NC}"
                        failed_count=$((failed_count + 1))
                        ;;
                esac
            else
                echo "  ${RED}Invalid selection. Skipping $cmd${NC}"
                failed_count=$((failed_count + 1))
            fi
        fi
    done
    
    echo ""
    echo "Installation complete!"
    echo "Installed: ${GREEN}$installed_count${NC} commands"
    [ $failed_count -gt 0 ] && echo "Failed: ${RED}$failed_count${NC} commands"
}

handle_install() {
    echo "${YELLOW}Magic Scripts Installer${NC}"
    echo "===================="
    echo ""
    
    INSTALL_DIR="$HOME/.local/bin/ms"
    
    # Parse options
    local specific_registry=""
    local commands=()
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -r|--registry)
                specific_registry="$2"
                shift 2
                ;;
            -h|--help)
                echo "Usage:"
                echo "  ${CYAN}ms install <command1> [command2...]${NC}        # Install specific commands"
                echo "  ${CYAN}ms install -r <registry>${NC}                   # Install entire registry"
                echo "  ${CYAN}ms install -r <registry> <command>${NC}         # Install from specific registry"
                echo ""
                echo "Options:"
                echo "  -r, --registry <name>    Use specific registry"
                echo ""
                echo "Examples:"
                echo "  ${CYAN}ms install gigen licgen${NC}           # Install from any available registry"
                echo "  ${CYAN}ms install -r ms${NC}                  # Install all commands from ms registry"
                echo "  ${CYAN}ms install -r template gigen${NC}      # Install from specific registry"
                echo ""
                echo "Available registries:"
                if command -v list_registries >/dev/null 2>&1; then
                    list_registries | grep -E '^ ' | head -5
                fi
                return 0
                ;;
            *)
                commands+=("$1")
                shift
                ;;
        esac
    done
    
    # Create directories if needed
    [ ! -d "$INSTALL_DIR" ] && mkdir -p "$INSTALL_DIR"
    [ ! -d "$MAGIC_SCRIPT_DIR" ] && mkdir -p "$MAGIC_SCRIPT_DIR"
    
    # Handle registry-only installation (no commands specified)
    if [ -n "$specific_registry" ] && [ ${#commands[@]} -eq 0 ]; then
        install_registry_all "$specific_registry"
        return $?
    fi
    
    # Handle specific registry with commands
    if [ -n "$specific_registry" ] && [ ${#commands[@]} -gt 0 ]; then
        echo "Installing specified commands from '$specific_registry' registry..."
        echo ""
        
        local installed_count=0
        local failed_count=0
        
        for cmd in "${commands[@]}"; do
            if [ "$cmd" = "ms" ]; then
                printf "  Installing ${CYAN}%s${NC}... " "$cmd"
                echo "${YELLOW}already installed${NC}"
                echo "  Use ${CYAN}ms reinstall ms${NC} to reinstall"
                continue
            fi
            
            # Get command from specific registry using 2-tier system
            if command -v get_command_info >/dev/null 2>&1; then
                # Use get_command_info to properly handle 2-tier system
                local full_cmd_info=$(get_command_info "$cmd" 2>/dev/null)
                
                if [ -n "$full_cmd_info" ]; then
                    # Parse command metadata and version info from get_command_info output
                    local cmd_meta=$(echo "$full_cmd_info" | grep "^command_meta|")
                    local version_info=$(echo "$full_cmd_info" | grep "^version|" | head -1)
                    
                    if [ -n "$version_info" ]; then
                        printf "  Installing ${CYAN}%s${NC} from ${YELLOW}%s${NC}... " "$cmd" "$specific_registry"
                        
                        # Extract script URL from version info: version|version_name|script_url|checksum|install_script|uninstall_script|update_script|man_url|man_url|man_url
                        local script_url=$(echo "$version_info" | cut -d'|' -f3)
                        local version_name=$(echo "$version_info" | cut -d'|' -f2)
                        local install_script_url=$(echo "$version_info" | cut -d'|' -f5)
                        local uninstall_script_url=$(echo "$version_info" | cut -d'|' -f6)
                        local update_script_url=$(echo "$version_info" | cut -d'|' -f7)
                        local man_url=$(echo "$version_info" | cut -d'|' -f8)
                        
                        local install_result
                        install_script "$cmd" "$script_url" "$specific_registry" "$version_name" "" "$install_script_url" "$uninstall_script_url" "$update_script_url" "$man_url"
                        install_result=$?
                    else
                        printf "  Installing ${CYAN}%s${NC}... " "$cmd"
                        echo "${RED}no version available${NC}"
                        install_result=1
                    fi
                    
                    case $install_result in
                        0)
                            echo "${GREEN}done${NC}"
                            installed_count=$((installed_count + 1))
                            ;;
                        2)
                            echo "${YELLOW}already installed${NC}"
                            ;;
                        *)
                            echo "${RED}failed${NC}"
                            failed_count=$((failed_count + 1))
                            ;;
                    esac
                else
                    printf "  Installing ${CYAN}%s${NC}... " "$cmd"
                    echo "${RED}not found in registry '$specific_registry'${NC}"
                    failed_count=$((failed_count + 1))
                fi
            else
                echo "${RED}Error: Registry system not available${NC}"
                return 1
            fi
        done
        
        echo ""
        echo "Installation complete!"
        echo "Installed: ${GREEN}$installed_count${NC} commands"
        [ $failed_count -gt 0 ] && echo "Failed: ${RED}$failed_count${NC} commands"
        return
    fi
    
    # Handle commands without specific registry (search all registries)
    if [ ${#commands[@]} -gt 0 ]; then
        install_commands_with_detection "${commands[@]}"
        return $?
    fi
    
    # No commands specified - show help
    echo "${RED}Error: No commands specified${NC}"
    echo "Usage: ${CYAN}ms install <command1> [command2...]${NC}"
    echo "   or: ${CYAN}ms install -r <registry>${NC}"
    echo ""
    echo "Examples:"
    echo "  ${CYAN}ms install gigen${NC}        # Install gigen from any registry"
    echo "  ${CYAN}ms install -r ms${NC}        # Install all commands from ms registry"
    exit 1
}

install_script() {
    local cmd="$1"
    local script_uri="$2"  # Now expects full URI instead of relative path
    local registry_name="$3"  # Registry name that provided the command
    local version="$4"        # Version being installed
    local force_flag="$5"     # Optional: "force" to force reinstall
    local install_hook_script="$6"  # Optional: install script URL
    local uninstall_hook_script="$7"  # Optional: uninstall script URL
    local update_hook_script="$8"  # Optional: update script URL
    local man_url="$9"        # Optional: man page URL
    
    # Handle legacy calls without version parameter
    if [ "$4" = "force" ]; then
        version=""
        force_flag="force"
    fi
    
    # Install directly to ~/.local/bin for PATH compatibility
    local INSTALL_DIR="$HOME/.local/bin/ms"
    # Data directory for scripts
    local MAGIC_DATA_DIR="$HOME/.local/share/magicscripts"
    
    # Extract filename from URI and determine target path
    local script_filename=$(basename "$script_uri")
    local target_script="$MAGIC_DATA_DIR/scripts/$script_filename"
    
    # Get version information
    local registry_version="$version"  # Use the passed version
    if [ -z "$registry_version" ]; then
        registry_version=$(get_registry_version "$cmd")
    fi
    local installed_version=$(get_installed_version "$cmd")
    
    # Detect if this is an update scenario  
    local is_update=false
    local old_version=""
    if [ "$force_flag" != "force" ] && [ -f "$INSTALL_DIR/$cmd" ] && [ "$installed_version" != "unknown" ]; then
        # If same version, skip
        if [ "$installed_version" = "$registry_version" ]; then
            return 2  # Already installed with correct version (skip code)
        fi
        # If different version, this is an update
        is_update=true
        old_version="$installed_version"
        
        # Remove old version files
        rm -f "$INSTALL_DIR/$cmd"
        remove_installation_metadata "$cmd"
        # Remove old script file if exists (exact match only)
        local old_script_file="$MAGIC_DATA_DIR/scripts/$cmd.sh"
        if [ -f "$old_script_file" ]; then
            rm -f "$old_script_file"
        fi
    fi
    
    # Use registry version as target version
    local target_version="$registry_version"
    
    # Create directories if they don't exist
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$(dirname "$target_script")"
    
    # Check if we need to download/update the script
    local need_download=false
    
    if [ ! -f "$target_script" ]; then
        need_download=true
    elif [ "$force_flag" = "force" ] || [ "$installed_version" != "$target_version" ]; then
        need_download=true
    fi
    
    # Download script if needed
    if [ "$need_download" = true ]; then
        # Ensure directory exists
        mkdir -p "$(dirname "$target_script")"
        
        # Check if URI is remote or local
        if [[ "$script_uri" =~ ^https?:// ]]; then
            # Remote URI - download it
            if command -v curl >/dev/null 2>&1; then
                if ! curl -fsSL "$script_uri" -o "$target_script" 2>/dev/null; then
                    echo "Error: Failed to download script from $script_uri" >&2
                    return 1
                fi
            elif command -v wget >/dev/null 2>&1; then
                if ! wget -q "$script_uri" -O "$target_script" 2>/dev/null; then
                    echo "Error: Failed to download script from $script_uri" >&2
                    return 1
                fi
            else
                echo "Error: curl or wget required for downloading" >&2
                return 1
            fi
            chmod 755 "$target_script"
        else
            # Local path - copy it
            if [ -f "$script_uri" ]; then
                cp "$script_uri" "$target_script"
                chmod 755 "$target_script"
            else
                echo "Error: Local script not found: $script_uri" >&2
                return 1
            fi
        fi
    fi
    
    # Verify script exists
    if [ ! -f "$target_script" ]; then
        echo "Error: Script installation failed" >&2
        return 1
    fi
    
    # Create or update wrapper in install directory
    cat > "$INSTALL_DIR/$cmd" << EOF
#!/bin/sh
MAGIC_SCRIPT_DIR="$MAGIC_DATA_DIR"
exec "$target_script" "\$@"
EOF
    chmod 755 "$INSTALL_DIR/$cmd"
    
    # Download and install man page if provided
    if [ -n "$man_url" ] && [ "$man_url" != "" ]; then
        local man_dir="$HOME/.local/share/man/man1"
        local man_file="$man_dir/$cmd.1"
        
        # Create man directory if it doesn't exist
        mkdir -p "$man_dir"
        
        # Download man page
        local man_download_success=false
        if [[ "$man_url" =~ ^https?:// ]]; then
            # Remote URL - download it
            if command -v curl >/dev/null 2>&1; then
                if curl -fsSL "$man_url" -o "$man_file" 2>/dev/null; then
                    man_download_success=true
                fi
            elif command -v wget >/dev/null 2>&1; then
                if wget -q "$man_url" -O "$man_file" 2>/dev/null; then
                    man_download_success=true
                fi
            fi
        elif [ -f "$man_url" ]; then
            # Local file - copy it
            if cp "$man_url" "$man_file" 2>/dev/null; then
                man_download_success=true
            fi
        fi
        
        if [ "$man_download_success" = true ]; then
            echo "  ${GREEN}Installed${NC}: $cmd man page"
        else
            echo "  ${YELLOW}Warning: Could not download man page from $man_url${NC}"
        fi
    fi
    
    # Get registry information for metadata
    local final_registry_name="${registry_name:-default}"
    local registry_url="unknown"  
    local registry_checksum="unknown"
    
    if command -v get_script_info >/dev/null 2>&1; then
        local script_info=$(get_script_info "$cmd" 2>/dev/null)
        if [ -n "$script_info" ]; then
            registry_checksum=$(echo "$script_info" | cut -d'|' -f7)
        fi
    fi
    
    # Get registry URL from reglist if available
    local reglist_file="$HOME/.local/share/magicscripts/reg/reglist"
    if [ -f "$reglist_file" ] && [ -n "$final_registry_name" ]; then
        registry_url=$(grep "^$final_registry_name:" "$reglist_file" | cut -d':' -f2-)
    fi
    
    # Fallback - try to get from existing ms metadata
    if [ "$registry_url" = "unknown" ] || [ -z "$registry_url" ]; then
        local ms_meta="$HOME/.local/share/magicscripts/installed/ms.msmeta"
        if [ -f "$ms_meta" ]; then
            registry_url=$(grep "^registry_url=" "$ms_meta" | cut -d'=' -f2-)
        fi
    fi
    
    # Last fallback to default URL
    if [ "$registry_url" = "unknown" ] || [ -z "$registry_url" ]; then
        if command -v get_registry_url >/dev/null 2>&1; then
            registry_url=$(get_registry_url "default" 2>/dev/null)
        fi
        if [ -z "$registry_url" ] || [ "$registry_url" = "unknown" ]; then
            # Construct default registry URL dynamically like setup.sh
            local raw_url="https://raw.githubusercontent.com/magic-scripts/ms/main"
            registry_url="$raw_url/registry/ms.msreg"
        fi
    fi
    
    # Execute install script if provided
    if [ -n "$install_hook_script" ] && [ "$install_hook_script" != "" ]; then
        echo "  ${CYAN}Running install script for $cmd...${NC}"
        echo "  ${YELLOW}═══════════════════════════════════════${NC}"
        
        # Download install script to temp file and execute with proper stdin
        local temp_install_script=$(mktemp) || { echo "Error: Cannot create temp file" >&2; return 1; }
        local install_success=false
        
        # Download the install script
        if command -v curl >/dev/null 2>&1; then
            if curl -fsSL "$install_hook_script" -o "$temp_install_script"; then
                if sh "$temp_install_script" "$cmd" "$version" "$target_script" "$INSTALL_DIR/$cmd" "$registry_name" < /dev/tty; then
                    install_success=true
                fi
            fi
        elif command -v wget >/dev/null 2>&1; then
            if wget -q "$install_hook_script" -O "$temp_install_script"; then
                if sh "$temp_install_script" "$cmd" "$version" "$target_script" "$INSTALL_DIR/$cmd" "$registry_name" < /dev/tty; then
                    install_success=true
                fi
            fi
        else
            echo "${RED}Error: curl or wget required for install script${NC}" >&2
        fi
        
        # Clean up temp file
        rm -f "$temp_install_script"
        
        echo "  ${YELLOW}═══════════════════════════════════════${NC}"
        if [ "$install_success" = true ]; then
            echo "  ${GREEN}Install script completed successfully${NC}"
        else
            echo "${YELLOW}Warning: Install script failed for $cmd, proceeding with installation${NC}" >&2
        fi
    fi
    
    # Record comprehensive installation metadata
    set_installation_metadata "$cmd" "$target_version" "$final_registry_name" "$registry_url" "$registry_checksum" "$target_script" "$install_hook_script" "$uninstall_hook_script"
    
    # Verify installation integrity
    verify_command_checksum "$cmd"
    local verify_result=$?
    case $verify_result in
        0)
            # Checksum verified successfully
            ;;
        1)
            echo "${RED}Warning: Checksum mismatch detected for $cmd${NC}" >&2
            local expected=$(get_installation_metadata "$cmd" "checksum")
            local actual=$(calculate_file_checksum "$target_script")
            echo "  Expected: $expected, Got: $actual" >&2
            echo "  The installation may be corrupted." >&2
            return 1
            ;;
        5)
            # Dev version - already printed message in verify_command_checksum
            ;;
        2|3|4)
            echo "${YELLOW}Warning: Could not verify checksum for $cmd${NC}" >&2
            ;;
    esac
    
    # Execute update script if this was an update (version change) and update_script is provided
    if [ "$is_update" = true ] && [ -n "$update_hook_script" ] && [ "$update_hook_script" != "" ]; then
        echo "  ${CYAN}Running update script for $cmd ($(format_version "$old_version") → $(format_version "$target_version"))...${NC}"
        echo "  ${YELLOW}═══════════════════════════════════════${NC}"
        
        # Download update script to temp file and execute
        local temp_update_script=$(mktemp) || { echo "Error: Cannot create temp file" >&2; return 1; }
        local update_success=false
        
        # Download the update script
        if command -v curl >/dev/null 2>&1; then
            if curl -fsSL "$update_hook_script" -o "$temp_update_script"; then
                if sh "$temp_update_script" "$cmd" "$old_version" "$target_version" "$target_script" "$INSTALL_DIR/$cmd" "$registry_name" < /dev/tty; then
                    update_success=true
                fi
            fi
        elif command -v wget >/dev/null 2>&1; then
            if wget -q "$update_hook_script" -O "$temp_update_script"; then
                if sh "$temp_update_script" "$cmd" "$old_version" "$target_version" "$target_script" "$INSTALL_DIR/$cmd" "$registry_name" < /dev/tty; then
                    update_success=true
                fi
            fi
        else
            echo "${RED}Error: curl or wget required for update script${NC}" >&2
        fi
        
        # Clean up temp file
        rm -f "$temp_update_script"
        
        echo "  ${YELLOW}═══════════════════════════════════════${NC}"
        if [ "$update_success" = true ]; then
            echo "  ${GREEN}Update script completed successfully${NC}"
        else
            echo "${YELLOW}Warning: Update script failed for $cmd${NC}" >&2
            echo "  ${YELLOW}Installation completed but update tasks may not have been performed${NC}" >&2
        fi
    fi
    
    return 0
}

handle_uninstall() {
    echo "${YELLOW}Magic Scripts Uninstaller${NC}"
    echo "======================="
    echo ""
    
    INSTALL_DIR="$HOME/.local/bin/ms"
    
    if [ $# -eq 0 ]; then
        echo "Usage: ${CYAN}ms uninstall <command1> [command2...]${NC}"
        echo ""
        echo "Installed commands:"
        if command -v get_all_commands >/dev/null 2>&1; then
            get_all_commands | while IFS= read -r cmd; do
                if [ -f "$INSTALL_DIR/$cmd" ]; then
                    local source_registry="unknown"
                    # Try to get registry name from installation metadata
                    if command -v get_installation_metadata >/dev/null 2>&1; then
                        local registry_name=$(get_installation_metadata "$cmd" "registry_name" 2>/dev/null)
                        if [ -n "$registry_name" ] && [ "$registry_name" != "unknown" ]; then
                            source_registry="(from $registry_name)"
                        fi
                    fi
                    echo "  $cmd $source_registry"
                fi
            done
        fi
        return 1
    fi
    
    local removed_count=0
    for cmd in "$@"; do
        
        if [ "$cmd" = "--all" ]; then
            echo "  ${YELLOW}Removing entire Magic Scripts installation...${NC}"
            if [ -d "$HOME/.local/bin/ms" ]; then
                rm -rf "$HOME/.local/bin/ms"
                echo "  ${GREEN}Removed${NC}: Installation directory"
                removed_count=$((removed_count + 1))
            fi
            if [ -d "$MAGIC_SCRIPT_DIR" ]; then
                rm -rf "$MAGIC_SCRIPT_DIR"
                echo "  ${GREEN}Removed${NC}: Magic Scripts data directory"
                removed_count=$((removed_count + 1))
            fi
            echo "  ${YELLOW}Note:${NC} Configuration files in Magic Scripts data directory were removed"
            echo "  ${YELLOW}Note:${NC} You may need to remove ~/.local/bin/ms from your PATH"
            break
        fi
        
        if [ -f "$INSTALL_DIR/$cmd" ]; then
            # Special confirmation for ms core uninstallation
            if [ "$cmd" = "ms" ]; then
                echo "  ${YELLOW}Uninstalling Magic Scripts core...${NC}"
                echo "  ${RED}WARNING: This will completely remove Magic Scripts and all data!${NC}"
                echo "  ${YELLOW}This action cannot be undone.${NC}"
                echo ""
                printf "  Are you sure you want to continue? [y/N]: "
                if [ -t 0 ]; then
                    read -r confirmation < /dev/tty
                else
                    exec < /dev/tty
                    read -r confirmation
                fi
                case "$confirmation" in
                    [Yy]|[Yy][Ee][Ss]) ;;
                    *) 
                        echo "  ${CYAN}Uninstallation cancelled.${NC}"
                        return 1
                        ;;
                esac
                echo ""
                
                # Check if other Magic Scripts commands are installed
                local other_commands=""
                local remove_all=false
                if [ -d "$INSTALL_DIR" ]; then
                    for cmd_file in "$INSTALL_DIR"/*; do
                        [ -e "$cmd_file" ] || continue
                        if [ -x "$cmd_file" ]; then
                            local cmd=$(basename "$cmd_file")
                            if [ "$cmd" != "ms" ]; then
                                other_commands="$other_commands $cmd"
                            fi
                        fi
                    done
                fi
                
                # If other commands exist, ask what to do
                if [ -n "$other_commands" ]; then
                    echo "  ${YELLOW}Other Magic Scripts commands are installed:${NC}$other_commands"
                    echo ""
                    printf "  ${YELLOW}What would you like to do?${NC}\n"
                    printf "  ${CYAN}1)${NC} Remove only ms (keep other commands)\n"
                    printf "  ${CYAN}2)${NC} Remove all Magic Scripts commands\n"
                    printf "  ${CYAN}3)${NC} Cancel uninstallation\n"
                    echo ""
                    printf "  Choose [1-3]: "
                    if [ -t 0 ]; then
                        read -r choice < /dev/tty
                    else
                        exec < /dev/tty
                        read -r choice
                    fi
                    
                    case "$choice" in
                        2)
                            remove_all=true
                            echo "  ${YELLOW}Will remove all Magic Scripts commands${NC}"
                            ;;
                        3)
                            echo "  ${CYAN}Uninstallation cancelled.${NC}"
                            return 1
                            ;;
                        1|"")
                            echo "  ${YELLOW}Will keep other commands${NC}"
                            ;;
                        *)
                            echo "  ${YELLOW}Invalid choice, keeping other commands${NC}"
                            ;;
                    esac
                    echo ""
                fi
                
                # Direct removal for ms core - don't rely on external script
                echo "  ${CYAN}Removing Magic Scripts core...${NC}"
                
                if [ "$remove_all" = true ]; then
                    # Remove all commands and installation directory
                    if [ -d "$INSTALL_DIR" ]; then
                        rm -rf "$INSTALL_DIR"
                        echo "  ${GREEN}Removed${NC}: all Magic Scripts commands"
                    fi
                    
                    # Remove core data directory
                    if [ -d "$HOME/.local/share/magicscripts" ]; then
                        rm -rf "$HOME/.local/share/magicscripts"
                        echo "  ${GREEN}Removed${NC}: Magic Scripts data directory"
                    fi
                else
                    # Remove only ms command
                    if [ -f "$INSTALL_DIR/ms" ]; then
                        rm -f "$INSTALL_DIR/ms"
                        echo "  ${GREEN}Removed${NC}: ms command"
                    fi
                    
                    # Remove install directory if empty
                    if [ -d "$INSTALL_DIR" ]; then
                        if [ -z "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]; then
                            rmdir "$INSTALL_DIR"
                            echo "  ${GREEN}Removed${NC}: empty installation directory"
                        fi
                    fi
                    
                    # Remove only ms-specific data, keep other command data
                    if [ -d "$HOME/.local/share/magicscripts" ]; then
                        # Remove ms metadata
                        if [ -f "$HOME/.local/share/magicscripts/installed/ms.msmeta" ]; then
                            rm -f "$HOME/.local/share/magicscripts/installed/ms.msmeta"
                            echo "  ${GREEN}Removed${NC}: ms metadata"
                        fi
                        
                        # Remove ms script
                        if [ -f "$HOME/.local/share/magicscripts/scripts/ms.sh" ]; then
                            rm -f "$HOME/.local/share/magicscripts/scripts/ms.sh"
                            echo "  ${GREEN}Removed${NC}: ms script"
                        fi
                        
                        # Only remove data directory if empty
                        if [ -z "$(ls -A "$HOME/.local/share/magicscripts" 2>/dev/null)" ]; then
                            rm -rf "$HOME/.local/share/magicscripts"
                            echo "  ${GREEN}Removed${NC}: empty data directory"
                        else
                            echo "  ${YELLOW}Kept${NC}: data directory (other commands' data preserved)"
                        fi
                    fi
                fi
                
                # Remove man page
                if [ -f "$HOME/.local/share/man/man1/ms.1" ]; then
                    rm -f "$HOME/.local/share/man/man1/ms.1"
                    echo "  ${GREEN}Removed${NC}: ms man page"
                fi
                
                # Clean shell config based on remove_all choice
                if [ "$remove_all" = true ] || [ ! -d "$INSTALL_DIR" ] || [ -z "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]; then
                    # Remove PATH if removing all commands or no commands remain
                    for config_file in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
                        if [ -f "$config_file" ] && grep -q "\.local/bin/ms" "$config_file"; then
                            cp "$config_file" "${config_file}.magic-scripts-backup"
                            grep -v "# Magic Scripts" "$config_file" | \
                            grep -v "\.local/bin/ms" | \
                            grep -v "\.local/share/man" > "${config_file}.tmp"
                            mv "${config_file}.tmp" "$config_file"
                            echo "  ${GREEN}Cleaned${NC}: $(basename "$config_file")"
                        fi
                    done
                else
                    echo "  ${YELLOW}Kept${NC}: shell config (other Magic Scripts commands still installed)"
                fi
                
                echo "  ${GREEN}Magic Scripts has been completely removed.${NC}"
                exit 0
            fi
            
            # Check if this command came from registry
            local registry_info=""
            if command -v ms_internal_get_script_info >/dev/null 2>&1; then
                script_info=$(ms_internal_get_script_info "$cmd" 2>/dev/null)
                if [ -n "$script_info" ]; then
                    registry_info=" (from registry)"
                fi
            fi
            
            # Execute uninstall script if exists
            local uninstall_script_url=$(get_installation_metadata "$cmd" "uninstall_script")
            if [ -n "$uninstall_script_url" ] && [ "$uninstall_script_url" != "" ]; then
                echo "  ${CYAN}Running uninstall script for $cmd...${NC}"
                echo "  ${YELLOW}═══════════════════════════════════════${NC}"
                
                # Download uninstall script to temp file and execute with proper stdin
                local temp_uninstall_script=$(mktemp) || { echo "Error: Cannot create temp file" >&2; return 1; }
                local uninstall_success=false
                local version=$(get_installation_metadata "$cmd" "version")
                local script_path=$(get_installation_metadata "$cmd" "script_path")
                local registry_name=$(get_installation_metadata "$cmd" "registry_name")
                
                # Download the uninstall script
                if command -v curl >/dev/null 2>&1; then
                    if curl -fsSL "$uninstall_script_url" -o "$temp_uninstall_script"; then
                        if sh "$temp_uninstall_script" "$cmd" "$version" "$script_path" "$INSTALL_DIR/$cmd" "$registry_name" < /dev/tty; then
                            uninstall_success=true
                        fi
                    fi
                elif command -v wget >/dev/null 2>&1; then
                    if wget -q "$uninstall_script_url" -O "$temp_uninstall_script"; then
                        if sh "$temp_uninstall_script" "$cmd" "$version" "$script_path" "$INSTALL_DIR/$cmd" "$registry_name" < /dev/tty; then
                            uninstall_success=true
                        fi
                    fi
                else
                    echo "${RED}Error: curl or wget required for uninstall script${NC}" >&2
                fi
                
                # Clean up temp file
                rm -f "$temp_uninstall_script"
                
                echo "  ${YELLOW}═══════════════════════════════════════${NC}"
                if [ "$uninstall_success" = true ]; then
                    echo "  ${GREEN}Uninstall script completed successfully${NC}"
                    # If we successfully uninstalled ms core, exit completely (unless this is part of reinstall)
                    if [ "$cmd" = "ms" ] && [ "${MS_REINSTALL_MODE:-}" != "true" ]; then
                        echo "  ${GREEN}Magic Scripts has been completely removed.${NC}"
                        exit 0
                    fi
                else
                    echo "${YELLOW}Warning: Uninstall script failed for $cmd, proceeding with removal${NC}" >&2
                    # If ms uninstall script failed, try direct removal as fallback
                    if [ "$cmd" = "ms" ]; then
                        echo "  ${YELLOW}Attempting direct removal as fallback...${NC}"
                        # Direct removal of ms core files
                        if [ -f "$INSTALL_DIR/ms" ]; then
                            rm -f "$INSTALL_DIR/ms"
                            echo "  ${GREEN}Removed${NC}: ms command"
                        fi
                        # Remove core data
                        if [ -d "$HOME/.local/share/magicscripts" ]; then
                            rm -rf "$HOME/.local/share/magicscripts"
                            echo "  ${GREEN}Removed${NC}: Magic Scripts data directory"
                        fi
                        echo "  ${GREEN}Magic Scripts has been removed via fallback method.${NC}"
                        exit 0
                    fi
                fi
            fi
            
            # Handle non-ms commands cleanup
            if [ "$cmd" != "ms" ]; then
                # Remove individual file
                if [ -f "$INSTALL_DIR/$cmd" ]; then
                    rm "$INSTALL_DIR/$cmd"
                fi
                
                echo "  ${GREEN}Removed${NC}: $cmd$registry_info"
                
                # Remove man page if exists
                if [ -f "$HOME/.local/share/man/man1/$cmd.1" ]; then
                    rm -f "$HOME/.local/share/man/man1/$cmd.1"
                    echo "  ${GREEN}Removed${NC}: $cmd man page"
                fi
                
                # Remove metadata
                remove_installation_metadata "$cmd"
                
                # Also remove associated script files if they exist
                if [ -n "$script_info" ]; then
                    local file=$(echo "$script_info" | cut -d'|' -f3)
                    local script_path="$MAGIC_SCRIPT_DIR/$file"
                    if [ -f "$script_path" ]; then
                        rm "$script_path" 2>/dev/null || true
                    fi
                fi
            fi
            
            removed_count=$((removed_count + 1))
        else
            echo "  ${YELLOW}Not found${NC}: $cmd"
        fi
    done
    
    echo ""
    echo "Removed ${GREEN}$removed_count${NC} commands"
}

doctor_check() {
    echo "${YELLOW}Magic Scripts Doctor${NC}"
    echo "=================="
    echo ""
    echo "${BLUE}Running system diagnostics...${NC}"
    echo ""
    
    local issues_found=0
    
    # Check directories
    echo "${CYAN}Checking directories:${NC}"
    for dir in "$HOME/.local/bin/ms" "$MAGIC_SCRIPT_DIR"; do
        if [ -d "$dir" ]; then
            echo "  ${GREEN}✓${NC} $dir"
        else
            echo "  ${RED}✗${NC} $dir (creating...)"
            if mkdir -p "$dir" 2>/dev/null; then
                echo "    ${GREEN}✓${NC} Created successfully"
            else
                echo "    ${RED}✗${NC} Failed to create"
                issues_found=$((issues_found + 1))
            fi
        fi
    done
    
    echo ""
    echo "${CYAN}Checking dependencies:${NC}"
    for dep in curl wget git; do
        if command -v "$dep" >/dev/null 2>&1; then
            echo "  ${GREEN}✓${NC} $dep"
        else
            echo "  ${RED}✗${NC} $dep (recommended)"
        fi
    done
    
    echo ""
    echo "${CYAN}Checking PATH:${NC}"
    if echo "$PATH" | grep -q "$HOME/.local/bin/ms"; then
        echo "  ${GREEN}✓${NC} $HOME/.local/bin/ms is in PATH"
    else
        echo "  ${RED}✗${NC} $HOME/.local/bin/ms is NOT in PATH"
        echo "    Add this to your shell config:"
        echo "    ${CYAN}export PATH=\"$HOME/.local/bin/ms:\$PATH\"${NC}"
        issues_found=$((issues_found + 1))
    fi
    
    echo ""
    if [ $issues_found -eq 0 ]; then
        echo "${GREEN}✅ All systems operational!${NC}"
    else
        echo "${YELLOW}⚠️  Found $issues_found issue(s) that need attention${NC}"
    fi
}

# Version management utilities
# Get installation metadata
get_installation_metadata() {
    local cmd="$1"
    local key="$2"  # Optional: specific key to get
    local meta_file="$HOME/.local/share/magicscripts/installed/$cmd.msmeta"
    
    if [ ! -f "$meta_file" ]; then
        [ -n "$key" ] && echo "unknown" || return 1
        return 1
    fi
    
    if [ -n "$key" ]; then
        grep "^$key=" "$meta_file" 2>/dev/null | cut -d'=' -f2- || echo "unknown"
    else
        cat "$meta_file"
    fi
}

# Set installation metadata
set_installation_metadata() {
    local cmd="$1"
    local version="$2"
    local registry_name="$3"
    local registry_url="$4"  
    local checksum="$5"
    local script_path="$6"
    local install_script="$7"      # Optional: install script URL
    local uninstall_script="$8"    # Optional: uninstall script URL
    
    local installed_dir="$HOME/.local/share/magicscripts/installed"
    local meta_file="$installed_dir/$cmd.msmeta"
    
    mkdir -p "$installed_dir"
    
    # Create metadata file
    cat > "$meta_file" << EOF
command=$cmd
version=$version
registry_name=${registry_name:-unknown}
registry_url=${registry_url:-unknown}
checksum=${checksum:-unknown}
installed_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u)
script_path=${script_path:-unknown}
install_script=${install_script:-}
uninstall_script=${uninstall_script:-}
EOF
}

# Remove installation metadata
remove_installation_metadata() {
    local cmd="$1"
    local meta_file="$HOME/.local/share/magicscripts/installed/$cmd.msmeta"
    [ -f "$meta_file" ] && rm "$meta_file"
}

# Get installed version (wrapper for backward compatibility)
get_installed_version() {
    local cmd="$1"
    get_installation_metadata "$cmd" "version"
}

# Set installed version (wrapper for backward compatibility)  
set_installed_version() {
    local cmd="$1"
    local version="$2"
    
    # Try to preserve existing metadata if available
    local meta_file="$HOME/.local/share/magicscripts/installed/$cmd.msmeta"
    if [ -f "$meta_file" ]; then
        local registry_name=$(get_installation_metadata "$cmd" "registry_name")
        local registry_url=$(get_installation_metadata "$cmd" "registry_url")
        local checksum=$(get_installation_metadata "$cmd" "checksum")
        local script_path=$(get_installation_metadata "$cmd" "script_path")
        set_installation_metadata "$cmd" "$version" "$registry_name" "$registry_url" "$checksum" "$script_path"
    else
        set_installation_metadata "$cmd" "$version" "unknown" "unknown" "unknown" "unknown"
    fi
}

# Calculate file checksum (same as msreg)
calculate_file_checksum() {
    local file_path="$1"
    
    if [ ! -f "$file_path" ]; then
        echo "unknown"
        return 1
    fi
    
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file_path" | cut -d' ' -f1 | cut -c1-8
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file_path" | cut -d' ' -f1 | cut -c1-8
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$file_path" | cut -d' ' -f2 | cut -c1-8
    else
        echo "unknown"
        return 1
    fi
}

# Verify installed command checksum
verify_command_checksum() {
    local cmd="$1"
    local expected_checksum=$(get_installation_metadata "$cmd" "checksum")
    local script_path=$(get_installation_metadata "$cmd" "script_path")
    
    if [ "$expected_checksum" = "unknown" ] || [ "$script_path" = "unknown" ]; then
        return 2  # Cannot verify - no metadata
    fi
    
    # Skip checksum verification for dev versions
    if [ "$expected_checksum" = "dev" ]; then
        echo "${BLUE}ℹ Checksum verification skipped (development resource)${NC}" >&2
        return 5  # Dev version - no verification needed
    fi
    
    if [ ! -f "$script_path" ]; then
        return 3  # Script file not found
    fi
    
    local actual_checksum=$(calculate_file_checksum "$script_path")
    if [ "$actual_checksum" = "unknown" ]; then
        return 4  # Cannot calculate checksum
    fi
    
    if [ "$expected_checksum" = "$actual_checksum" ]; then
        return 0  # Match
    else
        return 1  # Mismatch
    fi
}

get_registry_version() {
    local cmd="$1"
    if command -v get_script_info >/dev/null 2>&1; then
        local script_info=$(get_script_info "$cmd" 2>/dev/null)
        if [ -n "$script_info" ]; then
            # Extract version from script_info (format: command|cmd|uri|desc|category|version|checksum)
            echo "$script_info" | cut -d'|' -f6
        else
            echo "unknown"
        fi
    else
        echo "unknown"
    fi
}

compare_versions() {
    local installed="$1"
    local registry="$2"
    
    # If either version is unknown, consider update needed
    if [ "$installed" = "unknown" ] || [ "$registry" = "unknown" ]; then
        echo "update_needed"
        return
    fi
    
    # Simple version comparison (assumes semantic versioning)
    if [ "$installed" = "$registry" ]; then
        echo "same"
    else
        echo "update_needed"
    fi
}

handle_versions() {
    if [ $# -eq 0 ]; then
        echo "${RED}Error: No command specified${NC}"
        echo "Usage: ms versions <command>"
        echo "       ms versions --all         # Show versions for all commands"
        echo "       ms versions -r <registry> # Show versions for all commands in registry"
        echo ""
        echo "Examples:"
        echo "  ms versions gigen            # Show available versions for gigen"
        echo "  ms versions --all            # Show versions for all commands"
        echo "  ms versions -r template      # Show versions for all commands in template registry"
        exit 1
    fi
    
    # Handle registry-specific versions
    if [ "$1" = "-r" ] && [ -n "$2" ]; then
        local registry_name="$2"
        echo "${YELLOW}Available versions for commands in '$registry_name' registry:${NC}"
        echo ""
        
        if command -v get_registry_commands >/dev/null 2>&1; then
            local registry_commands=$(get_registry_commands "$registry_name" 2>/dev/null)
            if [ -n "$registry_commands" ]; then
                echo "$registry_commands" | while IFS='|' read -r prefix cmd msver_url desc category; do
                    [ -z "$cmd" ] || [ -z "$msver_url" ] && continue
                    
                    echo "${CYAN}$cmd${NC} - $desc"
                    if command -v download_and_parse_msver >/dev/null 2>&1; then
                        local versions=$(download_and_parse_msver "$msver_url" "$cmd" 2>/dev/null | grep "^version|")
                        if [ -n "$versions" ]; then
                            echo "$versions" | while IFS='|' read -r version_prefix version_name url checksum; do
                                printf "  %-10s %s\n" "$version_name" "$url"
                            done
                        else
                            echo "  No versions found"
                        fi
                    fi
                    echo ""
                done
            else
                echo "No commands found in registry '$registry_name'"
            fi
        else
            echo "Registry system not available"
        fi
        return
    fi
    
    if [ "$1" = "--all" ]; then
        echo "${YELLOW}Installed command versions:${NC}"
        echo ""
        
        if command -v get_all_commands >/dev/null 2>&1; then
            local all_commands=$(get_all_commands | tr '\n' ' ')
        else
            # Fallback: scan installation directory directly
            local all_commands=""
            local install_dir="$HOME/.local/bin/ms"
            if [ -d "$install_dir" ]; then
                for cmd_file in "$install_dir"/*; do
                    [ -e "$cmd_file" ] || continue
                    if [ -x "$cmd_file" ]; then
                        local cmd=$(basename "$cmd_file")
                        all_commands="$all_commands $cmd"
                    fi
                done
            fi
        fi
        
        printf "%-12s %-12s %-12s\n" "Command" "Installed" "Registry"
        printf "%-12s %-12s %-12s\n" "-------" "---------" "--------"
        
        for cmd in $all_commands; do
            local installed_version=$(get_installed_version "$cmd")
            local registry_version=$(get_registry_version "$cmd")
            printf "%-12s %-12s %-12s\n" "$cmd" "$installed_version" "$registry_version"
        done
        return
    fi
    
    local cmd="$1"
    local installed_version=$(get_installed_version "$cmd")
    local registry_version=$(get_registry_version "$cmd")
    
    echo "${YELLOW}Version information for $cmd:${NC}"
    echo "  Installed: $installed_version"
    echo "  Latest:    $registry_version"
    echo ""
    
    # Show all available versions from 2-tier system
    if command -v get_command_versions >/dev/null 2>&1; then
        local all_versions=$(get_command_versions "$cmd" 2>/dev/null)
        if [ -n "$all_versions" ]; then
            echo "${CYAN}Available versions:${NC}"
            echo "$all_versions" | while IFS='|' read -r version_prefix version_name url checksum; do
                if [ "$version_name" = "$installed_version" ]; then
                    printf "  ${GREEN}%-10s${NC} %s ${GREEN}(installed)${NC}\n" "$version_name" "$url"
                else
                    printf "  %-10s %s\n" "$version_name" "$url"
                fi
            done
            echo ""
        fi
    fi
    
    local comparison=$(compare_versions "$installed_version" "$registry_version")
    if [ "$comparison" = "same" ]; then
        echo "${GREEN}✓ Up to date${NC}"
    else
        echo "${YELLOW}⚠ Update available${NC}"
        echo "  Run: ${CYAN}ms update $cmd${NC}"
    fi
}

handle_reinstall() {
    if [ $# -eq 0 ]; then
        echo "${RED}Error: No command specified${NC}"
        echo "Usage: ${CYAN}ms reinstall <command1> [command2...]${NC}"
        echo ""
        echo "Examples:"
        echo "  ${CYAN}ms reinstall gigen${NC}           # Reinstall gigen command"
        echo "  ${CYAN}ms reinstall ms${NC}              # Reinstall Magic Scripts itself" 
        echo "  ${CYAN}ms reinstall gigen pgadduser${NC}  # Reinstall multiple commands"
        exit 1
    fi
    
    echo "${YELLOW}Magic Scripts Reinstaller${NC}"
    echo "========================="
    echo ""
    
    local reinstall_count=0
    local failed_count=0
    
    for cmd in "$@"; do
        # Parse command:version format
        local base_cmd="$cmd"
        local requested_version=""
        if echo "$cmd" | grep -q ':'; then
            base_cmd=$(echo "$cmd" | cut -d':' -f1)
            requested_version=$(echo "$cmd" | cut -d':' -f2)
        fi
        
        # Special handling for ms itself
        if [ "$base_cmd" = "ms" ]; then
            # handle_ms_force_reinstall shows its own messages
            if handle_ms_force_reinstall; then
                reinstall_count=$((reinstall_count + 1))
            else
                failed_count=$((failed_count + 1))
            fi
            continue
        fi
        
        printf "  Reinstalling ${CYAN}%s${NC}... " "$cmd"
        
        # Set reinstall mode for ms to prevent early exit
        if [ "$base_cmd" = "ms" ]; then
            export MS_REINSTALL_MODE=true
        fi
        
        # First, execute uninstall script if exists (before removing files)
        local INSTALL_DIR="$HOME/.local/bin/ms"
        if [ -f "$INSTALL_DIR/$base_cmd" ]; then
            local uninstall_script_url=$(get_installation_metadata "$base_cmd" "uninstall_script")
            if [ -n "$uninstall_script_url" ] && [ "$uninstall_script_url" != "" ]; then
                echo ""
                echo "    ${CYAN}Running uninstall script for $base_cmd...${NC}"
                echo "    ${YELLOW}═══════════════════════════════════════${NC}"
                
                # Download uninstall script to temp file and execute with proper stdin
                local temp_uninstall_script=$(mktemp) || { echo "Error: Cannot create temp file" >&2; return 1; }
                local uninstall_success=false
                local old_version=$(get_installation_metadata "$base_cmd" "version")
                local script_path=$(get_installation_metadata "$base_cmd" "script_path")
                local registry_name=$(get_installation_metadata "$base_cmd" "registry_name")
                
                # Download the uninstall script
                if command -v curl >/dev/null 2>&1; then
                    if curl -fsSL "$uninstall_script_url" -o "$temp_uninstall_script"; then
                        if sh "$temp_uninstall_script" "$base_cmd" "$old_version" "$script_path" "$INSTALL_DIR/$base_cmd" "$registry_name" < /dev/tty; then
                            uninstall_success=true
                        fi
                    fi
                elif command -v wget >/dev/null 2>&1; then
                    if wget -q "$uninstall_script_url" -O "$temp_uninstall_script"; then
                        if sh "$temp_uninstall_script" "$base_cmd" "$old_version" "$script_path" "$INSTALL_DIR/$base_cmd" "$registry_name" < /dev/tty; then
                            uninstall_success=true
                        fi
                    fi
                else
                    echo "${RED}Error: curl or wget required for uninstall script${NC}" >&2
                fi
                
                # Clean up temp file
                rm -f "$temp_uninstall_script"
                
                echo "    ${YELLOW}═══════════════════════════════════════${NC}"
                if [ "$uninstall_success" = true ]; then
                    echo "    ${GREEN}Uninstall script completed successfully${NC}"
                else
                    echo "    ${YELLOW}Warning: Uninstall script failed, proceeding with reinstall${NC}" >&2
                fi
                printf "  Continuing reinstallation of ${CYAN}%s${NC}... " "$cmd"
            fi
            
            rm -f "$INSTALL_DIR/$base_cmd"
        fi
        
        # Remove metadata
        remove_installation_metadata "$base_cmd"
        
        # Remove script file if exists
        if command -v get_script_info >/dev/null 2>&1; then
            local script_info=$(get_script_info "$base_cmd" "$requested_version" 2>/dev/null)
            if [ -n "$script_info" ]; then
                local script_uri=$(echo "$script_info" | cut -d'|' -f3)
                local script_filename=$(basename "$script_uri")
                local script_path="$HOME/.local/share/magicscripts/scripts/$script_filename"
                if [ -f "$script_path" ]; then
                    rm -f "$script_path"
                fi
            fi
        fi
        
        # Now reinstall using the install logic
        if command -v get_command_info >/dev/null 2>&1; then
            # If no version specified, use currently installed version
            if [ -z "$requested_version" ]; then
                requested_version=$(get_installed_version "$base_cmd")
                if [ "$requested_version" = "unknown" ] || [ -z "$requested_version" ]; then
                    # If can't determine current version, use latest
                    requested_version=""
                fi
            fi
            
            # Use get_command_info for 2-tier system support
            local full_cmd_info=$(get_command_info "$base_cmd" "$requested_version" 2>/dev/null)
            
            if [ -n "$full_cmd_info" ]; then
                local version_info=""
                if [ -n "$requested_version" ]; then
                    # Look for specific version
                    version_info=$(echo "$full_cmd_info" | grep "^version|$requested_version|" | head -1)
                else
                    # Look for best available version (non-dev first, then dev)
                    version_info=$(echo "$full_cmd_info" | grep "^version|" | grep -v "^version|dev|" | head -1)
                    if [ -z "$version_info" ]; then
                        version_info=$(echo "$full_cmd_info" | grep "^version|dev|" | head -1)
                    fi
                fi
                
                if [ -n "$version_info" ]; then
                    local version_name=$(echo "$version_info" | cut -d'|' -f2)
                    local script_url=$(echo "$version_info" | cut -d'|' -f3)
                    local install_hook_script=$(echo "$version_info" | cut -d'|' -f5)
                    local uninstall_hook_script=$(echo "$version_info" | cut -d'|' -f6)
                    local update_hook_script=$(echo "$version_info" | cut -d'|' -f7)
                    local man_url=$(echo "$version_info" | cut -d'|' -f8)
                    
                    # Get the registry name from metadata or find which registry has this command
                    local registry_name=$(get_installation_metadata "$base_cmd" "registry_name")
                    if [ -z "$registry_name" ] || [ "$registry_name" = "unknown" ]; then
                        # Try to find which registry contains this command
                        registry_name="default"  # Default fallback
                        if command -v get_registry_names >/dev/null 2>&1; then
                            for reg in $(get_registry_names); do
                                if get_registry_commands "$reg" 2>/dev/null | grep -q "^$base_cmd|"; then
                                    registry_name="$reg"
                                    break
                                fi
                            done
                        fi
                    fi
                    
                    if install_script "$base_cmd" "$script_url" "$registry_name" "$version_name" "force" "$install_hook_script" "$uninstall_hook_script" "$update_hook_script" "$man_url"; then
                        echo "${GREEN}done${NC}"
                        reinstall_count=$((reinstall_count + 1))
                    else
                        echo "${RED}failed${NC}"
                        failed_count=$((failed_count + 1))
                    fi
                else
                    echo "${RED}version not found${NC}"
                    failed_count=$((failed_count + 1))
                fi
            else
                echo "${RED}not found in registry${NC}"
                failed_count=$((failed_count + 1))
            fi
        else
            echo "${RED}registry unavailable${NC}"
            failed_count=$((failed_count + 1))
        fi
    done
    
    echo ""
    echo "Reinstallation complete!"
    echo "Reinstalled: ${GREEN}$reinstall_count${NC} commands"
    [ $failed_count -gt 0 ] && echo "Failed: ${RED}$failed_count${NC} commands"
}

handle_ms_force_reinstall() {
    echo ""
    echo "${BLUE}═══════════════════════════════════════════${NC}"
    echo "${BLUE}    Magic Scripts Script Update${NC}"
    echo "${BLUE}═══════════════════════════════════════════${NC}"
    echo ""
    echo "${YELLOW}This will update the Magic Scripts core script.${NC}"
    echo ""
    
    # Get ms version info from registry
    local full_cmd_info
    if command -v get_command_info >/dev/null 2>&1; then
        full_cmd_info=$(get_command_info "ms" 2>/dev/null)
    fi
    
    if [ -z "$full_cmd_info" ]; then
        echo "${RED}✗ Cannot retrieve ms version information${NC}"
        return 1
    fi
    
    local ms_info=$(echo "$full_cmd_info" | grep "^version|" | head -1)
    if [ -z "$ms_info" ]; then
        echo "${RED}✗ No version information found for ms${NC}"
        return 1
    fi
    
    local script_url install_script_url uninstall_script_url update_script_url man_url version_name
    script_url=$(echo "$ms_info" | cut -d'|' -f3)
    version_name=$(echo "$ms_info" | cut -d'|' -f2)
    install_script_url=$(echo "$ms_info" | cut -d'|' -f5)
    uninstall_script_url=$(echo "$ms_info" | cut -d'|' -f6)
    update_script_url=$(echo "$ms_info" | cut -d'|' -f7)
    man_url=$(echo "$ms_info" | cut -d'|' -f8)
    
    if [ -z "$script_url" ]; then
        echo "${RED}✗ Invalid ms version information${NC}"
        return 1
    fi
    
    echo "${CYAN}Updating Magic Scripts core script...${NC}"
    echo "─────────────────────────────────────────"
    
    # Set reinstall mode to prevent early exit during uninstall
    export MS_REINSTALL_MODE=true
    
    # Use install_script function to reinstall ms with force flag
    local install_result
    if install_script "ms" "$script_url" "ms" "$version_name" "force" "$install_script_url" "$uninstall_script_url" "$update_script_url" "$man_url"; then
        install_result=0
    else
        install_result=1
    fi
    
    if [ $install_result -ne 0 ]; then
        echo ""
        echo "${RED}✗ Script update failed${NC}"
        return 1
    fi
    
    echo ""
    echo "${GREEN}═══════════════════════════════════════════${NC}"
    echo "${GREEN}✅ Magic Scripts core script updated!${NC}"
    echo "${GREEN}═══════════════════════════════════════════${NC}"
    echo ""
    echo "${YELLOW}Note: You may need to restart your terminal or run:${NC}"
    echo "  ${CYAN}exec \$SHELL${NC}"
    echo ""
    
    return 0
}

handle_update() {
    # Special case: ms update ms
    if [ "$1" = "ms" ]; then
        echo "${YELLOW}Updating Magic Scripts core...${NC}"
        
        # Get update script URL from ms.msreg -> ms.msver  
        local update_script_url
        if command -v ms_internal_get_script_info >/dev/null 2>&1; then
            local ms_info=$(ms_internal_get_script_info "ms" 2>/dev/null)
            if [ -n "$ms_info" ]; then
                # Get msver URL from ms_info (format: command|cmd|uri|desc|category|version|checksum)
                local msver_url=$(echo "$ms_info" | cut -d'|' -f3)
                # Download and parse msver to get update_script (field 7)
                if command -v download_and_parse_msver >/dev/null 2>&1; then
                    local version_info=$(download_and_parse_msver "$msver_url" "ms" 2>/dev/null | grep "^version|" | head -1)
                    if [ -n "$version_info" ]; then
                        update_script_url=$(echo "$version_info" | cut -d'|' -f7)
                    fi
                fi
            fi
        fi
        
        # Fallback to hardcoded URL if dynamic lookup fails
        if [ -z "$update_script_url" ]; then
            local raw_url="https://raw.githubusercontent.com/magic-scripts/ms/main"
            update_script_url="$raw_url/installer/update.sh"
        fi
        local temp_update=$(mktemp) || { echo "Error: Cannot create temp file" >&2; return 1; }
        
        printf "  Downloading update script... "
        if command -v curl >/dev/null 2>&1; then
            if curl -fsSL "$update_script_url" -o "$temp_update"; then
                printf "${GREEN}done${NC}\n"
            else
                printf "${RED}failed${NC}\n"
                return 1
            fi
        elif command -v wget >/dev/null 2>&1; then
            if wget -q "$update_script_url" -O "$temp_update"; then
                printf "${GREEN}done${NC}\n"
            else
                printf "${RED}failed${NC}\n"
                return 1
            fi
        else
            echo "${RED}Error: curl or wget required${NC}"
            return 1
        fi
        
        chmod +x "$temp_update"
        echo "  Running update..."
        exec sh "$temp_update"
        return
    fi
    
    if [ $# -eq 0 ]; then
        echo "${YELLOW}Updating all installed commands...${NC}"
        echo ""
        
        # Get list of installed commands
        local installed_commands=""
        local install_dir="$HOME/.local/bin"
        local ms_install_dir="$HOME/.local/bin/ms"
        
        # Check both installation directories
        if [ -d "$ms_install_dir" ]; then
            for cmd_file in "$ms_install_dir"/*; do
                if [ -f "$cmd_file" ] && [ -x "$cmd_file" ]; then
                    local cmd_name=$(basename "$cmd_file")
                    if [ "$cmd_name" != "ms" ]; then  # Skip ms core command
                        installed_commands="$installed_commands $cmd_name"
                    fi
                fi
            done
        fi
        
        if [ -d "$install_dir" ]; then
            for cmd_file in "$install_dir"/*; do
                if [ -f "$cmd_file" ] && [ -x "$cmd_file" ]; then
                    local cmd_name=$(basename "$cmd_file")
                    # Only include commands that are likely Magic Scripts commands
                    if command -v get_script_info >/dev/null 2>&1; then
                        if get_script_info "$cmd_name" >/dev/null 2>&1; then
                            # Avoid duplicates
                            case " $installed_commands " in
                                *" $cmd_name "*) ;;
                                *) installed_commands="$installed_commands $cmd_name" ;;
                            esac
                        fi
                    fi
                fi
            done
        fi
        
        if [ -z "$installed_commands" ]; then
            echo "${YELLOW}No Magic Scripts commands found to update.${NC}"
            echo ""
            echo "You can install commands with:"
            echo "  ${CYAN}ms install ms${NC}    # Install all commands from ms registry"
            return
        fi
        
        local updated_count=0
        local failed_count=0
        
        # Update each command with version checking
        local skipped_count=0
        for cmd in $installed_commands; do
            printf "  Updating ${CYAN}%s${NC}... " "$cmd"
            
            # Check version first
            local installed_version=$(get_installed_version "$cmd")
            local registry_version=$(get_registry_version "$cmd")
            local comparison=$(compare_versions "$installed_version" "$registry_version")
            
            if [ "$comparison" = "same" ] && [ "$installed_version" != "unknown" ]; then
                echo "${GREEN}already latest${NC} ($(format_version "$installed_version"))"
                skipped_count=$((skipped_count + 1))
                continue
            fi
            
            if command -v get_script_info >/dev/null 2>&1; then
                script_info=$(get_script_info "$cmd" 2>/dev/null)
                if [ -n "$script_info" ]; then
                    file=$(echo "$script_info" | cut -d'|' -f3)
                    # Force update by passing current registry version
                    if install_script "$cmd" "$file" "default" "$registry_version" "" "" "" "" "" >/dev/null 2>&1; then
                        echo "${GREEN}done${NC} ($(format_version "$installed_version") → $(format_version "$registry_version"))"
                        updated_count=$((updated_count + 1))
                    else
                        echo "${RED}failed${NC}"
                        failed_count=$((failed_count + 1))
                    fi
                else
                    echo "${YELLOW}not found in registry${NC}"
                    failed_count=$((failed_count + 1))
                fi
            else
                echo "${RED}registry unavailable${NC}"
                failed_count=$((failed_count + 1))
            fi
        done
        
        echo ""
        echo "Command updates complete!"
        echo "Updated: ${GREEN}$updated_count${NC} commands"
        [ $skipped_count -gt 0 ] && echo "Already latest: ${GREEN}$skipped_count${NC} commands"
        [ $failed_count -gt 0 ] && echo "Failed: ${RED}$failed_count${NC} commands"
        
        # Finally, update Magic Scripts itself
        echo ""
        echo "${YELLOW}Updating Magic Scripts core system...${NC}"
        handle_update self
        return
    fi
    
    if [ "$1" = "self" ]; then
        # Update Magic Scripts itself
        echo "${YELLOW}Updating Magic Scripts...${NC}"
        
        # Check if upgrade script exists
        local upgrade_script=""
        if [ -f "$SCRIPT_DIR/installer/update.sh" ]; then
            upgrade_script="$SCRIPT_DIR/installer/update.sh"
        elif [ -f "$MAGIC_SCRIPT_DIR/installer/update.sh" ]; then
            upgrade_script="$MAGIC_SCRIPT_DIR/installer/update.sh"
        else
            # Get update script URL dynamically (same logic as update command)
            local update_script_url
            if command -v ms_internal_get_script_info >/dev/null 2>&1; then
                local ms_info=$(ms_internal_get_script_info "ms" 2>/dev/null)
                if [ -n "$ms_info" ]; then
                    local msver_url=$(echo "$ms_info" | cut -d'|' -f3)
                    if command -v download_and_parse_msver >/dev/null 2>&1; then
                        local version_info=$(download_and_parse_msver "$msver_url" "ms" 2>/dev/null | grep "^version|" | head -1)
                        if [ -n "$version_info" ]; then
                            update_script_url=$(echo "$version_info" | cut -d'|' -f7)
                        fi
                    fi
                fi
            fi
            
            # Fallback if dynamic lookup fails
            if [ -z "$update_script_url" ]; then
                local raw_url="https://raw.githubusercontent.com/magic-scripts/ms/main"
                update_script_url="$raw_url/installer/update.sh"
            fi
            
            # Download upgrade script
            local temp_upgrade=$(mktemp) || { echo "Error: Cannot create temp file" >&2; return 1; }
            if command -v curl >/dev/null 2>&1; then
                if curl -fsSL "$update_script_url" -o "$temp_upgrade"; then
                    upgrade_script="$temp_upgrade"
                else
                    echo "${RED}Error: Failed to download upgrade script${NC}"
                    exit 1
                fi
            elif command -v wget >/dev/null 2>&1; then
                if wget -q "$update_script_url" -O "$temp_upgrade"; then
                    upgrade_script="$temp_upgrade"
                else
                    echo "${RED}Error: Failed to download upgrade script${NC}"
                    exit 1
                fi
            else
                echo "${RED}Error: curl or wget required for self-update${NC}"
                exit 1
            fi
        fi
        
        chmod +x "$upgrade_script"
        exec "$upgrade_script"
        return
    fi
    
    # Update specific command
    local cmd="$1"
    
    # Check if command is installed
    if [ ! -f "$HOME/.local/bin/ms/$cmd" ]; then
        echo "${RED}Error: Command '$cmd' is not installed${NC}"
        echo ""
        echo "Available options:"
        echo "  ${CYAN}ms install $cmd${NC}     # Install the command"
        echo "  ${CYAN}ms search $cmd${NC}      # Search for the command"
        exit 1
    fi
    
    # Check version first
    local installed_version=$(get_installed_version "$cmd")
    local registry_version=$(get_registry_version "$cmd")
    local comparison=$(compare_versions "$installed_version" "$registry_version")
    
    echo "${YELLOW}Checking $cmd version...${NC}"
    echo "  Installed: $installed_version"
    echo "  Registry:  $registry_version"
    
    if [ "$comparison" = "same" ] && [ "$installed_version" != "unknown" ]; then
        echo "${GREEN}✓ $cmd is already up to date ($(format_version "$installed_version"))${NC}"
        echo "Use ${CYAN}ms install $cmd --force${NC} to reinstall"
        return
    fi
    
    echo ""
    echo "${YELLOW}Updating $cmd...${NC}"
    
    # Get script info from registry
    if command -v get_script_info >/dev/null 2>&1; then
        script_info=$(get_script_info "$cmd" 2>/dev/null)
        if [ -n "$script_info" ]; then
            file=$(echo "$script_info" | cut -d'|' -f3)
            printf "  Updating ${CYAN}%s${NC}... " "$cmd"
            if install_script "$cmd" "$file" "default" "$registry_version" "" "" "" "" ""; then
                echo "${GREEN}done${NC}"
                echo "Successfully updated $cmd ($(format_version "$installed_version") → $(format_version "$registry_version"))"
            else
                echo "${RED}failed${NC}"
                echo "${RED}Error: Failed to update $cmd${NC}"
                exit 1
            fi
        else
            echo "${RED}Error: Command '$cmd' not found in registry${NC}"
            echo "Try running: ${CYAN}ms upgrade${NC} to update registries"
            exit 1
        fi
    else
        echo "${RED}Error: Registry system not available${NC}"
        exit 1
    fi
}

# Doctor: System diagnosis and repair
handle_doctor() {
    local fix_mode=false
    
    # Parse options
    if [ "$1" = "--fix" ]; then
        fix_mode=true
        shift
    fi
    
    echo "${CYAN}🔍 Magic Scripts System Diagnosis${NC}"
    echo "=================================="
    echo ""
    
    local total_issues=0
    local fixed_issues=0
    
    # 1. Registry Status Check
    echo "${YELLOW}Registry Status${NC}"
    if command -v update_registries >/dev/null 2>&1; then
        local registry_ok=true
        echo "  ✅ Registry system available"
        
        # Check each registry
        local reglist_file="$HOME/.local/share/magicscripts/reg/reglist"
        if [ -f "$reglist_file" ]; then
            while IFS=':' read -r name url; do
                [ -z "$name" ] || [ -z "$url" ] && continue
                [ "${name#\#}" != "$name" ] && continue
                
                local reg_file="$HOME/.local/share/magicscripts/reg/${name}.msreg"
                if [ -f "$reg_file" ]; then
                    local count=$(grep -v "^#" "$reg_file" | grep -v "^$" | wc -l | tr -d ' ')
                    echo "  ✅ $name: $count entries"
                else
                    echo "  ❌ $name: not downloaded"
                    registry_ok=false
                    total_issues=$((total_issues + 1))
                fi
            done < "$reglist_file"
        else
            echo "  ❌ Registry list not found"
            registry_ok=false
            total_issues=$((total_issues + 1))
        fi
    else
        echo "  ❌ Registry system not available"
        total_issues=$((total_issues + 1))
    fi
    echo ""
    
    # 2. Installed Commands Check  
    echo "${YELLOW}Installed Commands${NC}"
    local installed_dir="$HOME/.local/share/magicscripts/installed"
    local commands_checked=0
    local checksum_issues=0
    
    if [ -d "$installed_dir" ]; then
        for meta_file in "$installed_dir"/*.msmeta; do
            [ ! -f "$meta_file" ] && continue
            
            local cmd=$(basename "$meta_file" .msmeta)
            commands_checked=$((commands_checked + 1))
            
            # Get version information
            local installed_version=$(get_installed_version "$cmd")
            local registry_version=$(get_registry_version "$cmd")
            local version_display="$installed_version"
            if [ "$installed_version" = "unknown" ]; then
                version_display="?"
            fi
            
            # Check if command exists in correct location (2-tier system)
            local install_dir="$HOME/.local/bin/ms"
            if [ -f "$install_dir/$cmd" ]; then
                # Verify checksum
                verify_command_checksum "$cmd"
                local verify_result=$?
                
                # Check for updates
                local update_status=""
                if [ "$installed_version" != "unknown" ] && [ "$registry_version" != "unknown" ]; then
                    local comparison=$(compare_versions "$installed_version" "$registry_version")
                    if [ "$comparison" = "update_needed" ]; then
                        update_status=" ${YELLOW}(update available: $(format_version "$registry_version"))${NC}"
                    fi
                fi
                
                case $verify_result in
                    0)
                        echo "  ✅ $cmd ${BLUE}[$version_display]${NC}: OK$update_status"
                        ;;
                    1)
                        echo "  ❌ $cmd ${BLUE}[$version_display]${NC}: Checksum mismatch$update_status"
                        total_issues=$((total_issues + 1))
                        checksum_issues=$((checksum_issues + 1))
                        
                        if [ "$fix_mode" = true ]; then
                            echo "    🔧 Attempting to reinstall $cmd..."
                            # Use 2-tier system for reinstall
                            if command -v get_command_info >/dev/null 2>&1; then
                                local full_cmd_info=$(get_command_info "$cmd" "$installed_version" 2>/dev/null)
                                local version_info=$(echo "$full_cmd_info" | grep "^version|$installed_version|" | head -1)
                                if [ -n "$version_info" ]; then
                                    local script_url=$(echo "$version_info" | cut -d'|' -f3)
                                    local install_script_url=$(echo "$version_info" | cut -d'|' -f5)
                                    local uninstall_script_url=$(echo "$version_info" | cut -d'|' -f6)
                                    local update_script_url=$(echo "$version_info" | cut -d'|' -f7)
                                    local man_url=$(echo "$version_info" | cut -d'|' -f8)
                                    local registry_name=$(get_installation_metadata "$cmd" "registry_name")
                                    if [ -z "$registry_name" ] || [ "$registry_name" = "unknown" ]; then
                                        registry_name="default"
                                    fi
                                    if install_script "$cmd" "$script_url" "$registry_name" "$installed_version" "force" "$install_script_url" "$uninstall_script_url" "$update_script_url" "$man_url" >/dev/null 2>&1; then
                                        echo "    ✅ $cmd: Reinstalled successfully"
                                        fixed_issues=$((fixed_issues + 1))
                                    else
                                        echo "    ❌ $cmd: Reinstallation failed"
                                    fi
                                fi
                            fi
                        fi
                        ;;
                    2)
                        echo "  ⚠️  $cmd ${BLUE}[$version_display]${NC}: Cannot verify (no checksum data)$update_status"
                        ;;
                    3)
                        echo "  ❌ $cmd ${BLUE}[$version_display]${NC}: Script file missing$update_status"
                        total_issues=$((total_issues + 1))
                        ;;
                    4)
                        echo "  ⚠️  $cmd ${BLUE}[$version_display]${NC}: Cannot calculate checksum$update_status"
                        ;;
                    5)
                        echo "  ℹ️  $cmd ${BLUE}[$version_display]${NC}: Dev version (checksum not verified)$update_status"
                        ;;
                esac
            else
                echo "  ❌ $cmd ${BLUE}[$version_display]${NC}: Command not found in PATH$update_status"
                total_issues=$((total_issues + 1))
            fi
        done
    else
        echo "  ⚠️  No installation metadata found"
    fi
    
    if [ $commands_checked -eq 0 ]; then
        echo "  ℹ️  No installed commands found"
    fi
    echo ""
    
    # 3. System Structure Check
    echo "${YELLOW}System Structure${NC}"
    local required_dirs=(
        "$HOME/.local/bin"
        "$HOME/.local/share/magicscripts"
        "$HOME/.local/share/magicscripts/scripts"  
        "$HOME/.local/share/magicscripts/core"
        "$HOME/.local/share/magicscripts/installed"
        "$HOME/.local/share/magicscripts/reg"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo "  ✅ $dir: OK"
        else
            echo "  ❌ $dir: Missing"
            total_issues=$((total_issues + 1))
            
            if [ "$fix_mode" = true ]; then
                mkdir -p "$dir" 2>/dev/null && {
                    echo "    ✅ Created $dir"
                    fixed_issues=$((fixed_issues + 1))
                }
            fi
        fi
    done
    echo ""
    
    # 4. PATH Check
    echo "${YELLOW}PATH Configuration${NC}"
    if echo "$PATH" | grep -q "$HOME/.local/bin/ms"; then
        echo "  ✅ ~/.local/bin/ms is in PATH"
    else
        echo "  ⚠️  ~/.local/bin/ms not found in PATH"
        echo "    Add this to your shell profile:"
        echo "    export PATH=\"\$HOME/.local/bin/ms:\$PATH\""
    fi
    echo ""
    
    # Summary
    echo "${YELLOW}Summary${NC}"
    if [ $total_issues -eq 0 ]; then
        echo "  🎉 No issues found! System is healthy."
    else
        echo "  ⚠️  Issues found: $total_issues"
        if [ "$fix_mode" = true ]; then
            echo "  🔧 Fixed: $fixed_issues"
            local remaining=$((total_issues - fixed_issues))
            if [ $remaining -gt 0 ]; then
                echo "  ❌ Remaining: $remaining"
                echo ""
                echo "Some issues require manual intervention."
            else
                echo "  ✅ All issues have been resolved!"
            fi
        else
            echo ""
            echo "Run '${CYAN}ms doctor --fix${NC}' to attempt automatic repairs."
        fi
    fi
    
    return $total_issues
}

# Main command handling
case "$1" in
    ""|help|--help|-h)
        show_help
        ;;
    version|--version|-v)
        show_banner
        ;;
    status)
        show_status
        ;;
    config)
        shift
        handle_config "$@"
        ;;
    reg)
        shift
        handle_reg "$@"
        ;;
    search)
        shift
        handle_search "$@"
        ;;
    install)
        shift
        handle_install "$@"
        ;;
    uninstall)
        shift
        handle_uninstall "$@"
        ;;
    doctor)
        shift
        handle_doctor "$@"
        ;;
    upgrade)
        if command -v update_registries >/dev/null 2>&1; then
            update_registries
        else
            echo "${RED}Registry system not available${NC}"
            exit 1
        fi
        ;;
    update)
        shift
        handle_update "$@"
        ;;
    versions)
        shift
        handle_versions "$@"
        ;;
    reinstall)
        shift
        handle_reinstall "$@"
        ;;
    *)
        unknown_cmd="$1"
        suggestion=$(suggest_similar_command "$unknown_cmd")
        if [ -n "$suggestion" ]; then
            echo "${RED}Error: '$unknown_cmd' is not a command. Did you mean '$suggestion'?${NC}"
        else
            echo "${RED}Error: Unknown command: '$unknown_cmd'${NC}"
        fi
        echo "Run ${CYAN}ms help${NC} for available commands"
        exit 1
        ;;
esac