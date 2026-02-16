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
for lib in config.sh registry.sh metadata.sh version.sh; do
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

# Standardized error output helper
# Usage: ms_error "message" ["hint"]
ms_error() {
    local message="$1"
    local suggestion="$2"
    echo "${RED}Error: $message${NC}" >&2
    [ -n "$suggestion" ] && echo "  ${CYAN}Hint: $suggestion${NC}" >&2
}

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
    echo "  ${GREEN}search [query]${NC}          Search for available commands"
    echo "  ${GREEN}upgrade${NC}                 Update all registries to latest version"
    echo ""
    echo "${YELLOW}Configuration:${NC}"
    echo "  ${GREEN}config list${NC}             List all configuration values"
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
    echo "  ${GREEN}update${NC}                  Update all installed commands and Magic Scripts"
    echo "  ${GREEN}update <command>${NC}        Update specific command to latest version"
    echo "  ${GREEN}uninstall <commands...>${NC} Uninstall specific commands"
    echo "  ${GREEN}outdated${NC}                Show commands with available updates"
    echo "  ${GREEN}which <command>${NC}         Show command file paths"
    echo "  ${GREEN}pin <command>${NC}           Pin command to current version"
    echo "  ${GREEN}unpin <command>${NC}         Unpin command"
    echo "  ${GREEN}clean${NC}                   Clean cache and orphaned files"
    echo "  ${GREEN}run <command> [args]${NC}    One-shot execution without installing"
    echo ""
    echo "${YELLOW}Data:${NC}"
    echo "  ${GREEN}export [--full]${NC}         Export installed commands list"
    echo "  ${GREEN}import <file>${NC}           Install commands from export file"
    echo ""
    echo "${YELLOW}Publisher Tools:${NC}"
    echo "  ${GREEN}pub pack [cmd]${NC}          Package development and publishing"
    echo "  ${GREEN}pub reg [cmd]${NC}           Registry file management"
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

# Wrapper for backward compatibility - converts 3-tier registry format to old format
get_script_info() {
    local cmd="$1"
    local version="$2"  # Optional
    
    # Get command info using 3-tier registry system
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

# Download and execute a remote hook script
# Usage: execute_hook <hook_url> <arg1> <arg2> ...
# Returns: 0 on success, 1 on failure
execute_hook() {
    local hook_url="$1"
    shift

    if [ -z "$hook_url" ] || [ "$hook_url" = "" ]; then
        return 0
    fi

    local temp_hook=$(mktemp) || { echo "Error: Cannot create temp file" >&2; return 1; }
    local hook_success=false

    if command -v download_file >/dev/null 2>&1; then
        if download_file "$hook_url" "$temp_hook"; then
            if sh "$temp_hook" "$@" < /dev/tty; then
                hook_success=true
            fi
        fi
    elif command -v curl >/dev/null 2>&1; then
        if curl -fsSL "$hook_url" -o "$temp_hook"; then
            if sh "$temp_hook" "$@" < /dev/tty; then
                hook_success=true
            fi
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -q "$hook_url" -O "$temp_hook"; then
            if sh "$temp_hook" "$@" < /dev/tty; then
                hook_success=true
            fi
        fi
    else
        echo "${RED}Error: curl or wget required for hook script${NC}" >&2
    fi

    rm -f "$temp_hook"

    if [ "$hook_success" = true ]; then
        return 0
    else
        return 1
    fi
}

suggest_similar_command() {
    local input="$1"

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
        show)
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
        pack)
            echo "pub"
            ;;
        publish|publisher)
            echo "pub"
            ;;
        outdated|stale|old)
            echo "outdated"
            ;;
        where|path|location)
            echo "which"
            ;;
        lock|freeze)
            echo "pin"
            ;;
        unlock|unfreeze)
            echo "unpin"
            ;;
        sweep|purge|prune)
            echo "clean"
            ;;
        scaffold|create|new|template)
            echo "pub"
            ;;
        dump|backup)
            echo "export"
            ;;
        restore|load)
            echo "import"
            ;;
        exec|execute|try)
            echo "run"
            ;;
        ver|--version|-v)
            echo "version"
            ;;
        h|--help|-h)
            echo "help"
            ;;
        *)
            for cmd in help version status doctor upgrade search install uninstall update versions reinstall info config reg pub outdated which pin unpin clean export import run; do
                case "$cmd" in
                    *"$input"*|"$input"*)
                        echo "$cmd"
                        return
                        ;;
                esac

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
        ms_error "Registry '$registry_name' not found or empty" "Run 'ms reg list' to see available registries"
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
        
        # Use get_command_info to get proper script URL from registry system
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
    local installed_count=0
    local failed_count=0

    for cmd in "$@"; do
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

        # Find command in registries using registry system
        # Use newline-separated strings instead of bash arrays
        local found_registries=""
        local registry_info=""

        if command -v get_registry_names >/dev/null 2>&1; then
            local registries_list=$(get_registry_names)

            for registry_name in $registries_list; do
                if command -v get_registry_commands >/dev/null 2>&1; then
                    local registry_commands=$(get_registry_commands "$registry_name" 2>/dev/null)

                    # In registry system, just check if command exists by name in .msreg
                    local cmd_info=$(echo "$registry_commands" | grep "^$base_cmd|" | head -1)

                    if [ -n "$cmd_info" ]; then
                        # Now check if requested version is available in .msver
                        local full_cmd_info=$(get_command_info "$base_cmd" "$requested_version" 2>/dev/null)
                        local version_info=""

                        if [ -n "$requested_version" ]; then
                            version_info=$(echo "$full_cmd_info" | grep "^version|$requested_version|")
                        else
                            version_info=$(echo "$full_cmd_info" | grep "^version|" | grep -v "^version|dev|" | head -1)
                            if [ -z "$version_info" ]; then
                                version_info=$(echo "$full_cmd_info" | grep "^version|dev|" | head -1)
                            fi
                        fi

                        if [ -n "$version_info" ]; then
                            if [ -n "$found_registries" ]; then
                                found_registries="$found_registries
$registry_name"
                            else
                                found_registries="$registry_name"
                            fi
                            local name=$(echo "$cmd_info" | cut -d'|' -f1)
                            local msver_url=$(echo "$cmd_info" | cut -d'|' -f2)
                            local desc=$(echo "$cmd_info" | cut -d'|' -f3)
                            local category=$(echo "$cmd_info" | cut -d'|' -f4)
                            local version=$(echo "$version_info" | cut -d'|' -f2)
                            local info_line="command|$name|$msver_url|$desc|$category|$version"
                            if [ -n "$registry_info" ]; then
                                registry_info="$registry_info
$info_line"
                            else
                                registry_info="$info_line"
                            fi
                        fi
                    fi
                fi
            done
        fi

        # Count found registries
        local reg_count=0
        if [ -n "$found_registries" ]; then
            reg_count=$(echo "$found_registries" | wc -l | tr -d ' ')
        fi

        # Handle installation based on what we found
        if [ "$reg_count" -eq 0 ]; then
            printf "  Installing ${CYAN}%s${NC}... " "$base_cmd"
            if [ -n "$requested_version" ]; then
                echo "${RED}version $requested_version not found in any registry${NC}"
            else
                echo "${RED}not found in any registry${NC}"
            fi
            failed_count=$((failed_count + 1))
            continue
        elif [ "$reg_count" -eq 1 ]; then
            local target_registry="$found_registries"
            local target_info="$registry_info"
            local found_version=$(echo "$target_info" | cut -d'|' -f6)

            printf "  Installing ${CYAN}%s${NC}" "$base_cmd"
            if [ -n "$requested_version" ] && [ "$requested_version" != "latest" ]; then
                printf ":${CYAN}%s${NC}" "$requested_version"
            elif [ -n "$found_version" ]; then
                printf ":${CYAN}%s${NC}" "$found_version"
            fi
            printf " from ${YELLOW}%s${NC}... " "$target_registry"

            if [ "$found_version" = "dev" ] && [ -z "$requested_version" ]; then
                echo ""
                echo "    ${YELLOW}⚠️  Installing development version (no stable release available)${NC}"
                printf "    "
            fi

            local full_cmd_info=$(get_command_info "$base_cmd" "$found_version" 2>/dev/null)
            local version_info=$(echo "$full_cmd_info" | grep "^version|$found_version|" | head -1)

            if [ -z "$version_info" ]; then
                version_info=$(echo "$full_cmd_info" | grep "^version|" | head -1)
            fi

            local install_result
            if [ -n "$version_info" ]; then
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
            local menu_idx=1
            while read -r _reg_name; do
                echo "  $menu_idx) $_reg_name"
                menu_idx=$((menu_idx + 1))
            done <<EOF
$found_registries
EOF
            echo ""
            printf "Choose registry (1-$reg_count): "
            read choice < /dev/tty

            if [ -n "$choice" ] && [ "$choice" -ge 1 ] 2>/dev/null && [ "$choice" -le "$reg_count" ] 2>/dev/null; then
                local target_registry=$(echo "$found_registries" | sed -n "${choice}p")
                local target_info=$(echo "$registry_info" | sed -n "${choice}p")
                local found_version=$(echo "$target_info" | cut -d'|' -f6)

                printf "  Installing ${CYAN}%s${NC}" "$base_cmd"
                if [ -n "$requested_version" ] && [ "$requested_version" != "latest" ]; then
                    printf ":${CYAN}%s${NC}" "$requested_version"
                elif [ -n "$found_version" ]; then
                    printf ":${CYAN}%s${NC}" "$found_version"
                fi
                printf " from ${YELLOW}%s${NC}... " "$target_registry"

                if [ "$found_version" = "dev" ] && [ -z "$requested_version" ]; then
                    echo ""
                    echo "    ${YELLOW}⚠️  Installing development version (no stable release available)${NC}"
                    printf "    "
                fi

                local full_cmd_info=$(get_command_info "$base_cmd" "$found_version" 2>/dev/null)
                local version_info=$(echo "$full_cmd_info" | grep "^version|$found_version|" | head -1)

                if [ -z "$version_info" ]; then
                    version_info=$(echo "$full_cmd_info" | grep "^version|" | head -1)
                fi

                local install_result
                if [ -n "$version_info" ]; then
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

    # Parse options - collect commands as newline-separated string
    local specific_registry=""
    local commands=""

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
                if [ -n "$commands" ]; then
                    commands="$commands
$1"
                else
                    commands="$1"
                fi
                shift
                ;;
        esac
    done

    # Count commands
    local cmd_count=0
    if [ -n "$commands" ]; then
        cmd_count=$(echo "$commands" | wc -l | tr -d ' ')
    fi

    # Create directories if needed
    [ ! -d "$INSTALL_DIR" ] && mkdir -p "$INSTALL_DIR"
    [ ! -d "$MAGIC_SCRIPT_DIR" ] && mkdir -p "$MAGIC_SCRIPT_DIR"

    # Handle registry-only installation (no commands specified)
    if [ -n "$specific_registry" ] && [ "$cmd_count" -eq 0 ]; then
        install_registry_all "$specific_registry"
        return $?
    fi

    # Handle specific registry with commands
    if [ -n "$specific_registry" ] && [ "$cmd_count" -gt 0 ]; then
        echo "Installing specified commands from '$specific_registry' registry..."
        echo ""

        local installed_count=0
        local failed_count=0

        while read -r cmd; do
            if [ "$cmd" = "ms" ]; then
                printf "  Installing ${CYAN}%s${NC}... " "$cmd"
                echo "${YELLOW}already installed${NC}"
                echo "  Use ${CYAN}ms reinstall ms${NC} to reinstall"
                continue
            fi

            # Get command from specific registry using registry system
            if command -v get_command_info >/dev/null 2>&1; then
                # Use get_command_info to properly handle registry system
                local full_cmd_info=$(get_command_info "$cmd" 2>/dev/null)

                if [ -n "$full_cmd_info" ]; then
                    # Parse command metadata and version info from get_command_info output
                    local cmd_meta=$(echo "$full_cmd_info" | grep "^command_meta|")
                    local version_info=$(echo "$full_cmd_info" | grep "^version|" | head -1)

                    if [ -n "$version_info" ]; then
                        printf "  Installing ${CYAN}%s${NC} from ${YELLOW}%s${NC}... " "$cmd" "$specific_registry"

                        # Extract script URL from version info: version|version_name|script_url|checksum|install_script|uninstall_script|update_script|man_url
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
        done <<EOF
$commands
EOF
        
        echo ""
        echo "Installation complete!"
        echo "Installed: ${GREEN}$installed_count${NC} commands"
        [ $failed_count -gt 0 ] && echo "Failed: ${RED}$failed_count${NC} commands"
        return
    fi
    
    # Handle commands without specific registry (search all registries)
    if [ "$cmd_count" -gt 0 ]; then
        # Pass each command as a separate argument
        local _old_ifs="$IFS"
        IFS='
'
        # shellcheck disable=SC2086
        install_commands_with_detection $commands
        local _ret=$?
        IFS="$_old_ifs"
        return $_ret
    fi
    
    # No commands specified - show help
    ms_error "No commands specified" "ms install <command1> [command2...]"
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
        case "$script_uri" in
            http://*|https://*)
                # Remote URI - download with security validation
                if command -v download_file >/dev/null 2>&1; then
                    if ! download_file "$script_uri" "$target_script"; then
                        echo "Error: Failed to download script from $script_uri" >&2
                        return 1
                    fi
                elif command -v curl >/dev/null 2>&1; then
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
                ;;
            *)
                # Local path - copy it
                if [ -f "$script_uri" ]; then
                    cp "$script_uri" "$target_script"
                    chmod 755 "$target_script"
                else
                    echo "Error: Local script not found: $script_uri" >&2
                    return 1
                fi
                ;;
        esac
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
        case "$man_url" in
            http://*|https://*)
                # Remote URL - download with security validation
                if command -v download_file >/dev/null 2>&1; then
                    if download_file "$man_url" "$man_file"; then
                        man_download_success=true
                    fi
                elif command -v curl >/dev/null 2>&1; then
                    if curl -fsSL "$man_url" -o "$man_file" 2>/dev/null; then
                        man_download_success=true
                    fi
                elif command -v wget >/dev/null 2>&1; then
                    if wget -q "$man_url" -O "$man_file" 2>/dev/null; then
                        man_download_success=true
                    fi
                fi
                ;;
            *)
                # Local file - copy it
                if [ -f "$man_url" ]; then
                    if cp "$man_url" "$man_file" 2>/dev/null; then
                        man_download_success=true
                    fi
                fi
                ;;
        esac
        
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
        if execute_hook "$install_hook_script" "$cmd" "$version" "$target_script" "$INSTALL_DIR/$cmd" "$registry_name"; then
            echo "  ${GREEN}Install script completed successfully${NC}"
        else
            echo "${YELLOW}Warning: Install script failed for $cmd, proceeding with installation${NC}" >&2
        fi
        echo "  ${YELLOW}═══════════════════════════════════════${NC}"
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
        if execute_hook "$update_hook_script" "$cmd" "$old_version" "$target_version" "$target_script" "$INSTALL_DIR/$cmd" "$registry_name"; then
            echo "  ${GREEN}Update script completed successfully${NC}"
        else
            echo "${YELLOW}Warning: Update script failed for $cmd${NC}" >&2
            echo "  ${YELLOW}Installation completed but update tasks may not have been performed${NC}" >&2
        fi
        echo "  ${YELLOW}═══════════════════════════════════════${NC}"
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
                local version=$(get_installation_metadata "$cmd" "version")
                local script_path=$(get_installation_metadata "$cmd" "script_path")
                local registry_name=$(get_installation_metadata "$cmd" "registry_name")

                echo "  ${CYAN}Running uninstall script for $cmd...${NC}"
                echo "  ${YELLOW}═══════════════════════════════════════${NC}"
                if execute_hook "$uninstall_script_url" "$cmd" "$version" "$script_path" "$INSTALL_DIR/$cmd" "$registry_name"; then
                    echo "  ${GREEN}Uninstall script completed successfully${NC}"
                    if [ "$cmd" = "ms" ] && [ "${MS_REINSTALL_MODE:-}" != "true" ]; then
                        echo "  ${GREEN}Magic Scripts has been completely removed.${NC}"
                        exit 0
                    fi
                else
                    echo "${YELLOW}Warning: Uninstall script failed for $cmd, proceeding with removal${NC}" >&2
                    if [ "$cmd" = "ms" ]; then
                        echo "  ${YELLOW}Attempting direct removal as fallback...${NC}"
                        if [ -f "$INSTALL_DIR/ms" ]; then
                            rm -f "$INSTALL_DIR/ms"
                            echo "  ${GREEN}Removed${NC}: ms command"
                        fi
                        if [ -d "$HOME/.local/share/magicscripts" ]; then
                            rm -rf "$HOME/.local/share/magicscripts"
                            echo "  ${GREEN}Removed${NC}: Magic Scripts data directory"
                        fi
                        echo "  ${GREEN}Magic Scripts has been removed via fallback method.${NC}"
                        exit 0
                    fi
                fi
                echo "  ${YELLOW}═══════════════════════════════════════${NC}"
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

# Version management utilities
# Get installation metadata
# ============================================================================
# Backward Compatibility Wrappers
# These functions maintain the old API while delegating to the new modules
# ============================================================================

# Metadata wrappers (delegate to metadata.sh)
get_installation_metadata() { metadata_get "$@"; }
set_installation_metadata() { metadata_set "$@"; }
update_installation_metadata_key() { metadata_update_key "$@"; }
remove_installation_metadata() { metadata_remove "$@"; }

# Version wrappers (delegate to version.sh)
get_installed_version() { version_get_installed "$@"; }
set_installed_version() { version_set_installed "$@"; }
get_registry_version() { version_get_registry "$@"; }
compare_versions() { version_compare "$@"; }
calculate_file_checksum() { version_calculate_checksum "$@"; }
verify_command_checksum() { version_verify_checksum "$@"; }

handle_info() {
    local cmd="$1"

    if [ -z "$cmd" ]; then
        ms_error "No command specified" "ms info <command>"
        return 1
    fi

    if ! command -v get_command_info >/dev/null 2>&1; then
        ms_error "Registry system not available" "Run 'ms upgrade' to update registries"
        return 1
    fi

    local full_info
    full_info=$(get_command_info "$cmd" 2>/dev/null)

    if [ -z "$full_info" ]; then
        echo "${RED}Command '$cmd' not found in any registry${NC}"
        return 1
    fi

    local cmd_meta
    cmd_meta=$(echo "$full_info" | grep "^command_meta|" | head -1)
    local reg_description
    reg_description=$(echo "$cmd_meta" | cut -d'|' -f3)
    local reg_category
    reg_category=$(echo "$cmd_meta" | cut -d'|' -f4)

    echo ""
    echo "${BLUE}═══════════════════════════════════════════${NC}"
    echo "${BLUE}  $cmd${NC}"
    echo "${BLUE}═══════════════════════════════════════════${NC}"
    echo ""

    echo "  ${CYAN}Description:${NC}  $reg_description"
    echo "  ${CYAN}Category:${NC}     $reg_category"

    # Show metadata from mspack if available
    local metadata
    metadata=$(echo "$full_info" | grep "^meta|")
    if [ -n "$metadata" ]; then
        local author license stab repo_url issues min_ms
        author=$(echo "$metadata" | grep "^meta|author|" | head -1 | cut -d'|' -f3)
        license=$(echo "$metadata" | grep "^meta|license|" | head -1 | cut -d'|' -f3)
        stab=$(echo "$metadata" | grep "^meta|stability|" | head -1 | cut -d'|' -f3)
        repo_url=$(echo "$metadata" | grep "^meta|repo_url|" | head -1 | cut -d'|' -f3)
        issues=$(echo "$metadata" | grep "^meta|issues_url|" | head -1 | cut -d'|' -f3)
        min_ms=$(echo "$metadata" | grep "^meta|min_ms_version|" | head -1 | cut -d'|' -f3)

        [ -n "$author" ] && echo "  ${CYAN}Author:${NC}       $author"
        [ -n "$license" ] && echo "  ${CYAN}License:${NC}      $license"
        [ -n "$stab" ] && echo "  ${CYAN}Stability:${NC}    $stab"
        [ -n "$repo_url" ] && echo "  ${CYAN}Repository:${NC}  $repo_url"
        [ -n "$issues" ] && echo "  ${CYAN}Issues:${NC}       $issues"
        [ -n "$min_ms" ] && echo "  ${CYAN}Min ms ver:${NC}  $min_ms"
    fi

    # Show versions
    local versions
    versions=$(echo "$full_info" | grep "^version|")
    if [ -n "$versions" ]; then
        local installed_version
        installed_version=$(get_installed_version "$cmd" 2>/dev/null)
        echo ""
        echo "  ${CYAN}Versions:${NC}"
        echo "$versions" | while IFS='|' read -r _prefix ver _url _checksum _rest; do
            if [ "$ver" = "$installed_version" ]; then
                echo "    ${GREEN}$ver (installed)${NC}"
            else
                echo "    $ver"
            fi
        done
    fi

    # Show config keys
    local configs
    configs=$(echo "$full_info" | grep "^config|")
    if [ -n "$configs" ]; then
        echo ""
        echo "  ${CYAN}Configuration keys:${NC}"
        echo "$configs" | while IFS='|' read -r _prefix cfg_key cfg_default cfg_desc _rest; do
            printf "    %-25s %s" "$cfg_key" "$cfg_desc"
            [ -n "$cfg_default" ] && printf " (default: %s)" "$cfg_default"
            echo ""
        done
    fi

    echo ""
}

handle_which() {
    local cmd="$1"

    if [ "$cmd" = "-h" ] || [ "$cmd" = "--help" ] || [ "$cmd" = "help" ]; then
        echo "${YELLOW}Show file paths for an installed command${NC}"
        echo ""
        echo "${YELLOW}Usage:${NC}"
        echo "  ${CYAN}ms which <command>${NC}"
        echo ""
        echo "${YELLOW}Shows:${NC}"
        echo "  Wrapper script, main script, metadata, and man page paths"
        return 0
    fi

    if [ -z "$cmd" ]; then
        ms_error "No command specified" "ms which <command>"
        return 1
    fi

    local wrapper="$HOME/.local/bin/ms/$cmd"
    local script="$HOME/.local/share/magicscripts/scripts/${cmd}.sh"
    local meta="$HOME/.local/share/magicscripts/installed/${cmd}.msmeta"
    local man_file="$HOME/.local/share/magicscripts/man/${cmd}.1"

    if [ ! -f "$wrapper" ] && [ ! -f "$meta" ]; then
        ms_error "'$cmd' is not installed" "Run 'ms install $cmd' to install it"
        return 1
    fi

    echo ""
    echo "${CYAN}$cmd${NC}"
    echo ""

    if [ -f "$wrapper" ]; then
        echo "  ${GREEN}Wrapper:${NC}   $wrapper"
    else
        echo "  ${YELLOW}Wrapper:${NC}   (not found)"
    fi

    if [ -f "$script" ]; then
        echo "  ${GREEN}Script:${NC}    $script"
    else
        echo "  ${YELLOW}Script:${NC}    (not found)"
    fi

    if [ -f "$meta" ]; then
        echo "  ${GREEN}Metadata:${NC}  $meta"
        local ver=$(get_installation_metadata "$cmd" "version")
        local pinned=$(get_installation_metadata "$cmd" "pinned")
        [ -n "$ver" ] && [ "$ver" != "unknown" ] && echo "  ${GREEN}Version:${NC}   $(format_version "$ver")"
        [ "$pinned" = "true" ] && echo "  ${YELLOW}Pinned:${NC}    yes"
    else
        echo "  ${YELLOW}Metadata:${NC}  (not found)"
    fi

    if [ -f "$man_file" ]; then
        echo "  ${GREEN}Man page:${NC}  $man_file"
    fi

    echo ""
}

handle_outdated() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "help" ]; then
        echo "${YELLOW}Check for outdated installed commands${NC}"
        echo ""
        echo "${YELLOW}Usage:${NC}"
        echo "  ${CYAN}ms outdated${NC}"
        echo ""
        echo "${YELLOW}Shows:${NC}"
        echo "  Installed commands with newer versions available in registries"
        echo "  Pinned commands are marked but skipped during updates"
        return 0
    fi

    if ! command -v get_all_commands >/dev/null 2>&1; then
        ms_error "Registry system not available" "Run 'ms upgrade' to update registries"
        return 1
    fi

    local ms_install_dir="$HOME/.local/bin/ms"
    local installed_commands=""

    if [ -d "$ms_install_dir" ]; then
        for cmd_file in "$ms_install_dir"/*; do
            if [ -f "$cmd_file" ] && [ -x "$cmd_file" ]; then
                local cmd_name=$(basename "$cmd_file")
                if [ "$cmd_name" != "ms" ]; then
                    installed_commands="$installed_commands $cmd_name"
                fi
            fi
        done
    fi

    if [ -z "$installed_commands" ]; then
        echo "${YELLOW}No Magic Scripts commands installed.${NC}"
        return 0
    fi

    echo "${YELLOW}Checking for updates...${NC}"
    echo ""

    local outdated_count=0
    local pinned_count=0
    local up_to_date_count=0

    for cmd in $installed_commands; do
        local installed_version=$(get_installed_version "$cmd")
        local registry_version=$(get_registry_version "$cmd")

        if [ "$registry_version" = "unknown" ]; then
            continue
        fi

        local comparison=$(compare_versions "$installed_version" "$registry_version")
        local is_pinned=$(get_installation_metadata "$cmd" "pinned")

        if [ "$comparison" = "update_needed" ]; then
            if [ "$is_pinned" = "true" ]; then
                printf "  ${CYAN}%-20s${NC} ${YELLOW}%-10s → %-10s${NC} ${YELLOW}(pinned)${NC}\n" "$cmd" "$(format_version "$installed_version")" "$(format_version "$registry_version")"
                pinned_count=$((pinned_count + 1))
            else
                printf "  ${CYAN}%-20s${NC} ${RED}%-10s${NC} → ${GREEN}%-10s${NC}\n" "$cmd" "$(format_version "$installed_version")" "$(format_version "$registry_version")"
            fi
            outdated_count=$((outdated_count + 1))
        else
            up_to_date_count=$((up_to_date_count + 1))
        fi
    done

    echo ""
    if [ $outdated_count -eq 0 ]; then
        echo "${GREEN}All commands are up to date.${NC}"
    else
        echo "$outdated_count command(s) can be updated."
        [ $pinned_count -gt 0 ] && echo "$pinned_count command(s) are pinned (use 'ms unpin <cmd>' to allow updates)."
        echo "Run '${CYAN}ms update${NC}' to update all."
    fi
}

handle_pin() {
    local cmd="$1"

    if [ "$cmd" = "-h" ] || [ "$cmd" = "--help" ] || [ "$cmd" = "help" ]; then
        echo "${YELLOW}Pin a command to its current version${NC}"
        echo ""
        echo "${YELLOW}Usage:${NC}"
        echo "  ${CYAN}ms pin <command>${NC}"
        echo ""
        echo "Pinned commands are skipped during ${CYAN}ms update${NC}."
        echo "Use ${CYAN}ms unpin <command>${NC} to remove the pin."
        return 0
    fi

    if [ -z "$cmd" ]; then
        ms_error "No command specified" "ms pin <command>"
        return 1
    fi

    local wrapper="$HOME/.local/bin/ms/$cmd"
    local meta_file="$HOME/.local/share/magicscripts/installed/$cmd.msmeta"

    if [ ! -f "$wrapper" ] && [ ! -f "$meta_file" ]; then
        ms_error "'$cmd' is not installed" "Run 'ms install $cmd' first"
        return 1
    fi

    local already_pinned=$(get_installation_metadata "$cmd" "pinned")
    if [ "$already_pinned" = "true" ]; then
        local ver=$(get_installed_version "$cmd")
        echo "${YELLOW}'$cmd' is already pinned at $(format_version "$ver")${NC}"
        return 0
    fi

    update_installation_metadata_key "$cmd" "pinned" "true" || return 1

    local ver=$(get_installed_version "$cmd")
    echo "${GREEN}Pinned '$cmd' at $(format_version "$ver")${NC}"
    echo "  ${CYAN}Hint:${NC} This command will be skipped during 'ms update'"
}

handle_unpin() {
    local cmd="$1"

    if [ "$cmd" = "-h" ] || [ "$cmd" = "--help" ] || [ "$cmd" = "help" ]; then
        echo "${YELLOW}Unpin a command to allow updates${NC}"
        echo ""
        echo "${YELLOW}Usage:${NC}"
        echo "  ${CYAN}ms unpin <command>${NC}"
        echo ""
        echo "Removes the version pin so the command can be updated again."
        return 0
    fi

    if [ -z "$cmd" ]; then
        ms_error "No command specified" "ms unpin <command>"
        return 1
    fi

    local meta_file="$HOME/.local/share/magicscripts/installed/$cmd.msmeta"

    if [ ! -f "$meta_file" ]; then
        ms_error "'$cmd' is not installed" "Run 'ms install $cmd' first"
        return 1
    fi

    local is_pinned=$(get_installation_metadata "$cmd" "pinned")
    if [ "$is_pinned" != "true" ]; then
        echo "${YELLOW}'$cmd' is not pinned${NC}"
        return 0
    fi

    # Remove pinned key by writing empty value
    local tmp_file="${meta_file}.tmp"
    grep -v "^pinned=" "$meta_file" > "$tmp_file"
    mv "$tmp_file" "$meta_file"

    echo "${GREEN}Unpinned '$cmd'${NC}"
    echo "  ${CYAN}Hint:${NC} This command will now be updated with 'ms update'"
}

handle_versions() {
    if [ $# -eq 0 ]; then
        ms_error "No command specified" "ms versions <command>"
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
                echo "$registry_commands" | while IFS='|' read -r cmd msver_url desc category; do
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
    
    # Show all available versions from registry system
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
        if command -v download_file >/dev/null 2>&1; then
            if download_file "$update_script_url" "$temp_update"; then
                printf "${GREEN}done${NC}\n"
            else
                printf "${RED}failed${NC}\n"
                rm -f "$temp_update"
                return 1
            fi
        elif command -v curl >/dev/null 2>&1; then
            if curl -fsSL "$update_script_url" -o "$temp_update"; then
                printf "${GREEN}done${NC}\n"
            else
                printf "${RED}failed${NC}\n"
                rm -f "$temp_update"
                return 1
            fi
        elif command -v wget >/dev/null 2>&1; then
            if wget -q "$update_script_url" -O "$temp_update"; then
                printf "${GREEN}done${NC}\n"
            else
                printf "${RED}failed${NC}\n"
                rm -f "$temp_update"
                return 1
            fi
        else
            echo "${RED}Error: curl or wget required${NC}"
            rm -f "$temp_update"
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

            # Check if pinned
            local is_pinned=$(get_installation_metadata "$cmd" "pinned")
            if [ "$is_pinned" = "true" ]; then
                local pinned_ver=$(get_installed_version "$cmd")
                echo "${YELLOW}pinned${NC} ($(format_version "$pinned_ver"))"
                skipped_count=$((skipped_count + 1))
                continue
            fi

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
            
            # Download upgrade script with security validation
            local temp_upgrade=$(mktemp) || { echo "Error: Cannot create temp file" >&2; return 1; }
            if command -v download_file >/dev/null 2>&1; then
                if download_file "$update_script_url" "$temp_upgrade"; then
                    upgrade_script="$temp_upgrade"
                else
                    echo "${RED}Error: Failed to download upgrade script${NC}"
                    rm -f "$temp_upgrade"
                    exit 1
                fi
            elif command -v curl >/dev/null 2>&1; then
                if curl -fsSL "$update_script_url" -o "$temp_upgrade"; then
                    upgrade_script="$temp_upgrade"
                else
                    echo "${RED}Error: Failed to download upgrade script${NC}"
                    rm -f "$temp_upgrade"
                    exit 1
                fi
            elif command -v wget >/dev/null 2>&1; then
                if wget -q "$update_script_url" -O "$temp_upgrade"; then
                    upgrade_script="$temp_upgrade"
                else
                    echo "${RED}Error: Failed to download upgrade script${NC}"
                    rm -f "$temp_upgrade"
                    exit 1
                fi
            else
                echo "${RED}Error: curl or wget required for self-update${NC}"
                rm -f "$temp_upgrade"
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
            ms_error "Command '$cmd' not found in registry" "Run 'ms upgrade' to update registries"
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
            
            # Check if command exists in correct location (registry system)
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
                            # Use registry system for reinstall
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
    for dir in \
        "$HOME/.local/bin" \
        "$HOME/.local/share/magicscripts" \
        "$HOME/.local/share/magicscripts/scripts" \
        "$HOME/.local/share/magicscripts/core" \
        "$HOME/.local/share/magicscripts/installed" \
        "$HOME/.local/share/magicscripts/reg"
    do
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

    # 5. Orphan Detection
    echo "${YELLOW}Orphan Detection${NC}"
    local orphan_found=false

    # Orphan metadata: .msmeta without corresponding wrapper
    if [ -d "$installed_dir" ]; then
        for meta_file in "$installed_dir"/*.msmeta; do
            [ ! -f "$meta_file" ] && continue
            local cmd=$(basename "$meta_file" .msmeta)
            local install_dir="$HOME/.local/bin/ms"
            if [ ! -f "$install_dir/$cmd" ]; then
                echo "  ❌ Orphan metadata: $cmd (no wrapper in $install_dir)"
                total_issues=$((total_issues + 1))
                orphan_found=true
                if [ "$fix_mode" = true ]; then
                    rm -f "$meta_file"
                    echo "    ✅ Removed orphan metadata: $cmd"
                    fixed_issues=$((fixed_issues + 1))
                fi
            fi
        done
    fi

    # Orphan scripts: .sh without corresponding metadata
    local scripts_dir="$HOME/.local/share/magicscripts/scripts"
    if [ -d "$scripts_dir" ]; then
        for script_file in "$scripts_dir"/*.sh; do
            [ ! -f "$script_file" ] && continue
            local cmd=$(basename "$script_file" .sh)
            if [ ! -f "$installed_dir/$cmd.msmeta" ]; then
                echo "  ❌ Orphan script: $cmd (no metadata in $installed_dir)"
                total_issues=$((total_issues + 1))
                orphan_found=true
                if [ "$fix_mode" = true ]; then
                    rm -f "$script_file"
                    echo "    ✅ Removed orphan script: $cmd"
                    fixed_issues=$((fixed_issues + 1))
                fi
            fi
        done
    fi

    if [ "$orphan_found" = false ]; then
        echo "  ✅ No orphans detected"
    fi
    echo ""

    # 6. Registry Format Validation
    echo "${YELLOW}Registry Format${NC}"
    local reg_dir="$HOME/.local/share/magicscripts/reg"
    local reg_format_ok=true
    if [ -d "$reg_dir" ]; then
        for reg_file in "$reg_dir"/*.msreg; do
            [ ! -f "$reg_file" ] && continue
            local reg_name=$(basename "$reg_file" .msreg)
            local bad_lines=0
            while IFS= read -r line; do
                case "$line" in
                    ""|\#*) continue ;;
                esac
                local field_count=$(echo "$line" | tr '|' '\n' | wc -l | tr -d ' ')
                if [ "$field_count" -ne 4 ]; then
                    bad_lines=$((bad_lines + 1))
                fi
            done < "$reg_file"
            if [ "$bad_lines" -gt 0 ]; then
                echo "  ❌ $reg_name.msreg: $bad_lines malformed entries (expected 4 fields)"
                total_issues=$((total_issues + 1))
                reg_format_ok=false
            else
                local entry_count=$(grep -v "^#" "$reg_file" | grep -v "^$" | wc -l | tr -d ' ')
                echo "  ✅ $reg_name.msreg: $entry_count entries, format OK"
            fi
        done
    fi
    if [ "$reg_format_ok" = true ] && [ ! -d "$reg_dir" ]; then
        echo "  ⚠️  No cached registries found"
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

# ============================================================================
# Utility Commands
# ============================================================================

handle_clean() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "help" ]; then
        echo "${YELLOW}Clean up cache files and orphaned data${NC}"
        echo ""
        echo "${YELLOW}Usage:${NC}"
        echo "  ${CYAN}ms clean${NC} [--dry-run]"
        echo ""
        echo "${YELLOW}Options:${NC}"
        echo "  ${GREEN}--dry-run${NC}    Show what would be cleaned without deleting"
        echo ""
        echo "${YELLOW}Cleans:${NC}"
        echo "  Registry cache files, orphaned metadata, temp files"
        return 0
    fi

    local dry_run=false
    if [ "$1" = "--dry-run" ]; then
        dry_run=true
    fi

    echo "${YELLOW}Cleaning Magic Scripts cache...${NC}"
    echo ""

    local total_cleaned=0

    # 1. Registry cache files
    local reg_dir="$HOME/.local/share/magicscripts/reg"
    local reg_count=0
    if [ -d "$reg_dir" ]; then
        for cache_file in "$reg_dir"/*.msreg; do
            [ -f "$cache_file" ] || continue
            reg_count=$((reg_count + 1))
            if [ "$dry_run" = true ]; then
                echo "  ${CYAN}Would remove:${NC} $cache_file"
            else
                rm -f "$cache_file"
            fi
        done
    fi
    echo "  Registry cache: ${GREEN}$reg_count${NC} file(s)"
    total_cleaned=$((total_cleaned + reg_count))

    # 2. Orphaned metadata (no wrapper script)
    local meta_dir="$HOME/.local/share/magicscripts/installed"
    local orphan_meta_count=0
    if [ -d "$meta_dir" ]; then
        for meta_file in "$meta_dir"/*.msmeta; do
            [ -f "$meta_file" ] || continue
            local cmd_name=$(basename "$meta_file" .msmeta)
            if [ ! -f "$HOME/.local/bin/ms/$cmd_name" ]; then
                orphan_meta_count=$((orphan_meta_count + 1))
                if [ "$dry_run" = true ]; then
                    echo "  ${CYAN}Would remove:${NC} $meta_file (orphaned)"
                else
                    rm -f "$meta_file"
                fi
            fi
        done
    fi
    echo "  Orphaned metadata: ${GREEN}$orphan_meta_count${NC} file(s)"
    total_cleaned=$((total_cleaned + orphan_meta_count))

    # 3. Temp files
    local tmp_count=0
    for tmp_file in /tmp/ms_*; do
        [ -f "$tmp_file" ] || continue
        tmp_count=$((tmp_count + 1))
        if [ "$dry_run" = true ]; then
            echo "  ${CYAN}Would remove:${NC} $tmp_file"
        else
            rm -f "$tmp_file"
        fi
    done
    echo "  Temp files: ${GREEN}$tmp_count${NC} file(s)"
    total_cleaned=$((total_cleaned + tmp_count))

    echo ""
    if [ "$dry_run" = true ]; then
        echo "Dry run: ${YELLOW}$total_cleaned${NC} file(s) would be cleaned."
    else
        echo "Cleaned ${GREEN}$total_cleaned${NC} file(s)."
    fi
}

handle_export() {
    local full_mode=false

    case "$1" in
        --full) full_mode=true ;;
        -h|--help|help)
            echo "${YELLOW}Export installed commands list${NC}"
            echo ""
            echo "${YELLOW}Usage:${NC}"
            echo "  ${CYAN}ms export${NC}           Export simple list (name:version)"
            echo "  ${CYAN}ms export --full${NC}    Include registry info (name:version@registry)"
            echo ""
            echo "Output goes to stdout. Redirect to a file:"
            echo "  ${CYAN}ms export > backup.txt${NC}"
            return 0
            ;;
    esac

    local ms_install_dir="$HOME/.local/bin/ms"

    if [ "$full_mode" = true ]; then
        echo "# Magic Scripts export (full)"
    else
        echo "# Magic Scripts export"
    fi
    echo "# Date: $(date -u +"%Y-%m-%d" 2>/dev/null || date -u)"

    if [ -d "$ms_install_dir" ]; then
        for cmd_file in "$ms_install_dir"/*; do
            [ -f "$cmd_file" ] && [ -x "$cmd_file" ] || continue
            local cmd_name=$(basename "$cmd_file")
            [ "$cmd_name" = "ms" ] && continue

            local ver=$(get_installed_version "$cmd_name")
            [ "$ver" = "unknown" ] && ver="latest"

            if [ "$full_mode" = true ]; then
                local reg=$(get_installation_metadata "$cmd_name" "registry_name")
                [ "$reg" = "unknown" ] && reg="default"
                echo "${cmd_name}:${ver}@${reg}"
            else
                echo "${cmd_name}:${ver}"
            fi
        done
    fi
}

handle_import() {
    local import_file=""

    case "$1" in
        -h|--help|help)
            echo "${YELLOW}Import and install commands from export file${NC}"
            echo ""
            echo "${YELLOW}Usage:${NC}"
            echo "  ${CYAN}ms import <file>${NC}          Install from export file"
            echo "  ${CYAN}ms import --file <file>${NC}   Same as above"
            echo ""
            echo "File format (one per line):"
            echo "  command:version"
            echo "  command:version@registry"
            return 0
            ;;
        --file)
            import_file="$2"
            ;;
        *)
            import_file="$1"
            ;;
    esac

    if [ -z "$import_file" ]; then
        ms_error "No import file specified" "ms import <file>"
        return 1
    fi

    if [ ! -f "$import_file" ]; then
        ms_error "File not found: '$import_file'"
        return 1
    fi

    echo "${YELLOW}Importing commands from $import_file...${NC}"
    echo ""

    local installed_count=0
    local skipped_count=0
    local failed_count=0

    while IFS= read -r line; do
        # Skip comments and empty lines
        case "$line" in
            "#"*|"") continue ;;
        esac

        # Parse name:version[@registry]
        local cmd_name=""
        local cmd_version=""
        local cmd_registry=""

        # Strip @registry if present
        case "$line" in
            *@*)
                cmd_registry=$(echo "$line" | sed 's/.*@//')
                line=$(echo "$line" | sed 's/@.*//')
                ;;
        esac

        cmd_name=$(echo "$line" | cut -d':' -f1)
        cmd_version=$(echo "$line" | cut -d':' -f2)

        [ -z "$cmd_name" ] && continue

        # Check if already installed at same version
        local current_ver=$(get_installed_version "$cmd_name" 2>/dev/null)
        if [ "$current_ver" = "$cmd_version" ] && [ "$current_ver" != "unknown" ]; then
            echo "  ${CYAN}$cmd_name${NC}: ${GREEN}already installed${NC} ($(format_version "$current_ver"))"
            skipped_count=$((skipped_count + 1))
            continue
        fi

        printf "  Installing ${CYAN}%s${NC}:%s... " "$cmd_name" "$cmd_version"

        # Use handle_install with version
        if [ "$cmd_version" != "latest" ] && [ -n "$cmd_version" ]; then
            handle_install "${cmd_name}:${cmd_version}" >/dev/null 2>&1
        else
            handle_install "$cmd_name" >/dev/null 2>&1
        fi

        if [ $? -eq 0 ]; then
            echo "${GREEN}done${NC}"
            installed_count=$((installed_count + 1))
        else
            echo "${RED}failed${NC}"
            failed_count=$((failed_count + 1))
        fi
    done < "$import_file"

    echo ""
    echo "Import complete!"
    echo "  Installed: ${GREEN}$installed_count${NC}"
    [ $skipped_count -gt 0 ] && echo "  Skipped: ${GREEN}$skipped_count${NC}"
    [ $failed_count -gt 0 ] && echo "  Failed: ${RED}$failed_count${NC}"
}


handle_run() {
    local cmd="$1"

    if [ "$cmd" = "-h" ] || [ "$cmd" = "--help" ] || [ "$cmd" = "help" ]; then
        echo "${YELLOW}Run a command without installing it${NC}"
        echo ""
        echo "${YELLOW}Usage:${NC}"
        echo "  ${CYAN}ms run <command>${NC} [args...]"
        echo ""
        echo "Downloads the latest version, verifies checksum, executes, and cleans up."
        echo "The command is not installed permanently."
        return 0
    fi

    if [ -z "$cmd" ]; then
        ms_error "No command specified" "ms run <command> [args...]"
        return 1
    fi

    shift  # Remove command name, rest are args

    if ! command -v get_script_info >/dev/null 2>&1; then
        ms_error "Registry system not available" "Run 'ms upgrade' to update registries"
        return 1
    fi

    local script_info=$(get_script_info "$cmd" 2>/dev/null)
    if [ -z "$script_info" ]; then
        ms_error "Command '$cmd' not found in any registry" "Run 'ms search' to see available commands"
        return 1
    fi

    local script_url=$(echo "$script_info" | cut -d'|' -f3)
    local expected_checksum=$(echo "$script_info" | cut -d'|' -f7)

    local tmp_script="/tmp/ms_run_${cmd}_$$"

    # Ensure cleanup on exit
    _ms_run_cleanup() {
        rm -f "$tmp_script"
    }
    trap '_ms_run_cleanup' EXIT INT TERM

    printf "Downloading ${CYAN}%s${NC}... " "$cmd"

    if command -v download_file >/dev/null 2>&1; then
        if ! download_file "$script_url" "$tmp_script" 2>/dev/null; then
            echo "${RED}failed${NC}"
            ms_error "Failed to download '$cmd'"
            trap - EXIT INT TERM
            rm -f "$tmp_script"
            return 1
        fi
    elif command -v curl >/dev/null 2>&1; then
        if ! curl -fsSL "$script_url" -o "$tmp_script" 2>/dev/null; then
            echo "${RED}failed${NC}"
            ms_error "Failed to download '$cmd'"
            trap - EXIT INT TERM
            rm -f "$tmp_script"
            return 1
        fi
    else
        echo "${RED}failed${NC}"
        ms_error "curl or wget required"
        trap - EXIT INT TERM
        return 1
    fi

    echo "${GREEN}done${NC}"

    # Verify checksum if not dev
    if [ -n "$expected_checksum" ] && [ "$expected_checksum" != "dev" ] && [ "$expected_checksum" != "unknown" ]; then
        local actual_checksum=$(calculate_file_checksum "$tmp_script")
        if [ "$actual_checksum" != "$expected_checksum" ]; then
            ms_error "Checksum mismatch for '$cmd'" "Expected: $expected_checksum, Got: $actual_checksum"
            trap - EXIT INT TERM
            rm -f "$tmp_script"
            return 1
        fi
    fi

    chmod +x "$tmp_script"

    echo ""
    # Run the script with remaining args
    sh "$tmp_script" "$@"
    local exit_code=$?

    # Cleanup
    trap - EXIT INT TERM
    rm -f "$tmp_script"

    return $exit_code
}


# Load pack tools module (lazy loading)
load_pack_tools() {
    if [ -z "${PACK_TOOLS_LOADED:-}" ]; then
        for lib in "$MAGIC_SCRIPT_DIR/core/pack.sh" \
                   "$SCRIPT_DIR/../core/pack.sh" \
                   "$SCRIPT_DIR/../pack.sh"; do
            if [ -f "$lib" ]; then
                . "$lib"
                PACK_TOOLS_LOADED=1
                return 0
            fi
        done
        ms_error "Pack tools library not found"
        return 1
    fi
    return 0
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
    info)
        shift
        handle_info "$@"
        ;;
    reinstall)
        shift
        if [ $# -eq 0 ]; then
            ms_error "No command specified" "ms reinstall <command>"
            exit 1
        fi
        if [ "$1" = "ms" ]; then
            handle_ms_force_reinstall
        else
            for _reinstall_cmd in "$@"; do
                _ri_full_cmd_info=$(get_command_info "$_reinstall_cmd" 2>/dev/null)
                if [ -z "$_ri_full_cmd_info" ]; then
                    ms_error "Command '$_reinstall_cmd' not found in any registry" "ms upgrade"
                    continue
                fi
                _ri_version_info=$(echo "$_ri_full_cmd_info" | grep "^version|" | grep -v "^version|dev|" | head -1)
                if [ -z "$_ri_version_info" ]; then
                    _ri_version_info=$(echo "$_ri_full_cmd_info" | grep "^version|" | head -1)
                fi
                if [ -z "$_ri_version_info" ]; then
                    ms_error "No version available for '$_reinstall_cmd'"
                    continue
                fi
                # Get registry_name from existing .msmeta file
                _ri_registry_name=""
                _ri_meta_file="$MAGIC_DATA_DIR/installed/${_reinstall_cmd}.msmeta"
                if [ -f "$_ri_meta_file" ]; then
                    _ri_registry_name=$(grep "^registry_name=" "$_ri_meta_file" 2>/dev/null | cut -d'=' -f2-)
                fi
                [ -z "$_ri_registry_name" ] && _ri_registry_name="unknown"
                _ri_found_ver=$(echo "$_ri_version_info" | cut -d'|' -f2)
                _ri_script_url=$(echo "$_ri_version_info" | cut -d'|' -f3)
                _ri_install_hook=$(echo "$_ri_version_info" | cut -d'|' -f5)
                _ri_uninstall_hook=$(echo "$_ri_version_info" | cut -d'|' -f6)
                _ri_update_hook=$(echo "$_ri_version_info" | cut -d'|' -f7)
                _ri_man_url_val=$(echo "$_ri_version_info" | cut -d'|' -f8)
                printf "  Reinstalling ${CYAN}%s${NC}:${CYAN}%s${NC}... " "$_reinstall_cmd" "$_ri_found_ver"
                if install_script "$_reinstall_cmd" "$_ri_script_url" "$_ri_registry_name" "$_ri_found_ver" "force" "$_ri_install_hook" "$_ri_uninstall_hook" "$_ri_update_hook" "$_ri_man_url_val"; then
                    echo "${GREEN}done${NC}"
                else
                    echo "${RED}failed${NC}"
                fi
            done
        fi
        ;;
    outdated)
        shift
        handle_outdated "$@"
        ;;
    which)
        shift
        handle_which "$@"
        ;;
    pin)
        shift
        handle_pin "$@"
        ;;
    unpin)
        shift
        handle_unpin "$@"
        ;;
    clean)
        shift
        handle_clean "$@"
        ;;
    init)
        ms_error "'ms init' has been moved" "Use 'ms pack init <name>' instead"
        exit 1
        ;;
    export)
        shift
        handle_export "$@"
        ;;
    import)
        shift
        handle_import "$@"
        ;;
    run)
        shift
        handle_run "$@"
        ;;
    pub)
        shift
        load_pack_tools || exit 1
        handle_pub "$@"
        ;;
    *)
        unknown_cmd="$1"
        suggestion=$(suggest_similar_command "$unknown_cmd")
        if [ -n "$suggestion" ]; then
            ms_error "'$unknown_cmd' is not a command" "Did you mean '$suggestion'?"
        else
            ms_error "Unknown command: '$unknown_cmd'" "Run 'ms help' for available commands"
        fi
        exit 1
        ;;
esac
