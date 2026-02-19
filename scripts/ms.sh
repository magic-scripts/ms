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

# Try to load core libraries
for lib in config.sh registry.sh metadata.sh version.sh; do
    if [ -f "$MAGIC_SCRIPT_DIR/core/$lib" ]; then
        . "$MAGIC_SCRIPT_DIR/core/$lib"
    elif [ -f "$SCRIPT_DIR/../core/$lib" ]; then
        . "$SCRIPT_DIR/../core/$lib"
    elif [ -f "$SCRIPT_DIR/../$lib" ]; then
        . "$SCRIPT_DIR/../$lib"
    fi
done

# Try to load command handler libraries
for lib in install.sh uninstall.sh update.sh query.sh maintenance.sh; do
    if [ -f "$MAGIC_SCRIPT_DIR/lib/$lib" ]; then
        . "$MAGIC_SCRIPT_DIR/lib/$lib"
    elif [ -f "$SCRIPT_DIR/../lib/$lib" ]; then
        . "$SCRIPT_DIR/../lib/$lib"
    fi
done

# Version
VERSION="dev"
# Auto-detect installed version from msmeta if not injected by wrapper
if [ -z "${MS_INSTALLED_VERSION}" ]; then
    _ms_meta_ver=$(grep '^version=' "$HOME/.local/share/magicscripts/installed/ms.msmeta" 2>/dev/null | cut -d'=' -f2)
    if [ -n "$_ms_meta_ver" ] && [ "$_ms_meta_ver" != "dev" ]; then
        MS_INSTALLED_VERSION="$_ms_meta_ver"
    fi
    unset _ms_meta_ver
fi

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
    echo "${BLUE}Version: $(format_version "${MS_INSTALLED_VERSION:-$VERSION}")${NC}"
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
    echo "  ${GREEN}list${NC}                    List installed commands with version info"
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
            echo "list"
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
            for cmd in help version status doctor upgrade search list install uninstall update versions reinstall info config reg pub outdated which pin unpin clean export import run; do
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
            echo "${RED}Error: Cannot reinstall 'ms' — the tool cannot reinstall itself while running.${NC}"
            echo "To update Magic Scripts, use: ${CYAN}ms update ms${NC}"
            exit 1
        else
            for _reinstall_cmd in "$@"; do
                if [ "$_reinstall_cmd" = "ms" ]; then
                    echo "${YELLOW}Skipping ms — use '${CYAN}ms update ms${YELLOW}' instead${NC}"
                    continue
                fi
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
                # Run uninstall hook from existing metadata before reinstalling
                _ri_existing_uninstall=$(metadata_get "$_reinstall_cmd" "uninstall_script" 2>/dev/null)
                if [ -n "$_ri_existing_uninstall" ] && [ "$_ri_existing_uninstall" != "unknown" ] && [ "$_ri_existing_uninstall" != "" ]; then
                    echo "  ${CYAN}Running uninstall hook for $_reinstall_cmd...${NC}"
                    execute_hook "$_ri_existing_uninstall" "$_reinstall_cmd"
                fi
                # Get registry_name from existing .msmeta file
                _ri_registry_name=""
                _ri_meta_file="$MAGIC_SCRIPT_DIR/installed/${_reinstall_cmd}.msmeta"
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
    list|ls)
        shift
        handle_list "$@"
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
        ms_error "'ms init' has been moved" "Use 'ms pub pack init <name>' instead"
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
