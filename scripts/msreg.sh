#!/bin/sh

# Magic Scripts Registry Manager
# Manages .msreg files with checksum calculation

VERSION="0.0.1"
SCRIPT_NAME="msreg"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

show_help() {
    echo "${CYAN}$SCRIPT_NAME v$VERSION${NC}"
    echo "Magic Scripts Registry Manager"
    echo ""
    echo "Usage:"
    echo "  ${CYAN}$SCRIPT_NAME -f <registry_file> add <command>:<version> <uri>${NC}"
    echo "  ${CYAN}$SCRIPT_NAME -f <registry_file> remove <command>:<version>${NC}"
    echo "  ${CYAN}$SCRIPT_NAME -f <registry_file> config add <key> <default> <desc> <category> <scripts>${NC}"
    echo "  ${CYAN}$SCRIPT_NAME -f <registry_file> config remove <key> [command]${NC}"
    echo "  ${CYAN}$SCRIPT_NAME -f <registry_file> config list${NC}"
    echo "  ${CYAN}$SCRIPT_NAME checksum <file_path>${NC}"
    echo "  ${CYAN}$SCRIPT_NAME --version, -v${NC}"
    echo "  ${CYAN}$SCRIPT_NAME --help, -h${NC}"
    echo ""
    echo "Examples:"
    echo "  ${CYAN}$SCRIPT_NAME -f core/ms.msreg add gigen:2.1.0 https://example.com/gigen.sh${NC}"
    echo "  ${CYAN}$SCRIPT_NAME -f core/ms.msreg remove gigen:2.1.0${NC}"
    echo "  ${CYAN}$SCRIPT_NAME -f core/ms.msreg config add AUTHOR_NAME \"\" \"Your name\" global \"gigen,licgen\"${NC}"
    echo "  ${CYAN}$SCRIPT_NAME checksum ./scripts/gigen.sh${NC}"
    echo ""
    echo "Registry format:"
    echo "  command:script_path:description:category:version:checksum"
    echo "  config:key:default_value:description:category:scripts"
}

show_version() {
    echo "$SCRIPT_NAME v$VERSION"
}

# Calculate SHA256 checksum of a file
calculate_checksum() {
    local file_path="$1"
    
    if [ ! -f "$file_path" ]; then
        echo "${RED}Error: File '$file_path' not found${NC}" >&2
        return 1
    fi
    
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file_path" | cut -d' ' -f1 | cut -c1-8
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file_path" | cut -d' ' -f1 | cut -c1-8
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$file_path" | cut -d' ' -f2 | cut -c1-8
    else
        echo "${RED}Error: No checksum utility found (sha256sum, shasum, or openssl required)${NC}" >&2
        return 1
    fi
}

# Validate registry file
validate_registry_file() {
    local reg_file="$1"
    
    if [ -z "$reg_file" ]; then
        echo "${RED}Error: Registry file path is required${NC}" >&2
        echo "Use: $SCRIPT_NAME -f <registry_file> <command>" >&2
        return 1
    fi
    
    if [ ! -f "$reg_file" ]; then
        echo "${RED}Error: Registry file '$reg_file' not found${NC}" >&2
        return 1
    fi
    
    # Basic format validation
    if ! head -1 "$reg_file" | grep -q "Magic Scripts.*Registry" 2>/dev/null; then
        echo "${RED}Error: '$reg_file' does not appear to be a valid .msreg file${NC}" >&2
        return 1
    fi
    
    return 0
}

# Validate registry format and check for duplicates
validate_registry_format() {
    local reg_file="$1"
    local line_num=0
    local errors=0
    local seen_commands=""
    
    while IFS= read -r line || [ -n "$line" ]; do
        line_num=$((line_num + 1))
        
        # Skip empty lines and comments
        [ -z "$line" ] && continue
        [ "${line#\#}" != "$line" ] && continue
        
        # Check config lines
        if echo "$line" | grep -q "^config:"; then
            local field_count=$(echo "$line" | tr ':' '\n' | wc -l)
            if [ $field_count -ne 6 ]; then
                echo "${RED}Error: Invalid config format at line $line_num${NC}" >&2
                echo "  Expected: config:key:default:description:category:scripts" >&2
                echo "  Got: $line" >&2
                errors=$((errors + 1))
            fi
            continue
        fi
        
        # Check command lines
        local field_count=$(echo "$line" | tr ':' -f | wc -l)
        if [ $field_count -ne 6 ]; then
            echo "${RED}Error: Invalid command format at line $line_num${NC}" >&2
            echo "  Expected: command:path:description:category:version:checksum" >&2
            echo "  Got: $line" >&2
            errors=$((errors + 1))
            continue
        fi
        
        # Check for duplicates
        local cmd=$(echo "$line" | cut -d':' -f1)
        local version=$(echo "$line" | cut -d':' -f5)
        local cmd_version="${cmd}:${version}"
        
        if echo "$seen_commands" | grep -q "$cmd_version"; then
            echo "${RED}Error: Duplicate entry at line $line_num: $cmd_version${NC}" >&2
            errors=$((errors + 1))
        else
            seen_commands="$seen_commands $cmd_version"
        fi
        
    done < "$reg_file"
    
    return $errors
}

# Add command to registry
add_command() {
    local reg_file="$1"
    local cmd_version="$2"
    local uri="$3"
    
    if [ -z "$cmd_version" ] || [ -z "$uri" ]; then
        echo "${RED}Error: Both command:version and URI are required${NC}" >&2
        echo "Usage: $SCRIPT_NAME -f <file> add <command>:<version> <uri>" >&2
        return 1
    fi
    
    # Parse command and version
    local command=$(echo "$cmd_version" | cut -d':' -f1)
    local version=$(echo "$cmd_version" | cut -d':' -f2)
    
    if [ -z "$command" ] || [ -z "$version" ] || [ "$command" = "$version" ]; then
        echo "${RED}Error: Invalid format. Use command:version (e.g., gigen:2.1.0)${NC}" >&2
        return 1
    fi
    
    validate_registry_file "$reg_file" || return 1
    
    # Check if command:version already exists
    if grep -q "^$command|.*|.*|.*|$version|" "$reg_file" 2>/dev/null; then
        echo "${RED}Error: Command '$command' version '$version' already exists in registry${NC}" >&2
        echo "Use 'remove' first if you want to update it" >&2
        return 1
    fi
    
    # Download and calculate checksum
    local temp_file="/tmp/msreg_download_$$"
    echo "Downloading $uri..."
    
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$uri" -o "$temp_file" 2>/dev/null
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$uri" -O "$temp_file" 2>/dev/null
    else
        echo "${RED}Error: curl or wget required for downloading${NC}" >&2
        return 1
    fi
    
    if [ ! -f "$temp_file" ] || [ ! -s "$temp_file" ]; then
        echo "${RED}Error: Failed to download file from $uri${NC}" >&2
        rm -f "$temp_file"
        return 1
    fi
    
    local checksum=$(calculate_checksum "$temp_file")
    if [ $? -ne 0 ]; then
        rm -f "$temp_file"
        return 1
    fi
    
    rm -f "$temp_file"
    
    # Prompt for missing information
    printf "Description: "
    read description < /dev/tty
    
    printf "Category: "
    read category < /dev/tty
    
    printf "Script path (relative to MAGIC_SCRIPT_DIR): "
    read script_path < /dev/tty
    
    if [ -z "$description" ] || [ -z "$category" ] || [ -z "$script_path" ]; then
        echo "${RED}Error: All fields are required${NC}" >&2
        return 1
    fi
    
    # Add to registry
    local entry="$command|$script_path|$description|$category|$version|$checksum"
    
    # Find insertion point (after last command entry, before config entries)
    local temp_reg="/tmp/msreg_temp_$$"
    local inserted=0
    
    while IFS= read -r line; do
        if [ $inserted -eq 0 ] && (echo "$line" | grep -q "^config:" || echo "$line" | grep -q "^$"); then
            echo "$entry" >> "$temp_reg"
            inserted=1
        fi
        echo "$line" >> "$temp_reg"
    done < "$reg_file"
    
    # If no config section found, append at end
    if [ $inserted -eq 0 ]; then
        echo "$entry" >> "$temp_reg"
    fi
    
    mv "$temp_reg" "$reg_file"
    
    echo "${GREEN}✓ Added $command:$version to registry${NC}"
    echo "  Checksum: $checksum"
    echo "  Entry: $entry"
}

# Remove command from registry
remove_command() {
    local reg_file="$1"
    local cmd_version="$2"
    
    if [ -z "$cmd_version" ]; then
        echo "${RED}Error: command:version required${NC}" >&2
        echo "Usage: $SCRIPT_NAME -f <file> remove <command>:<version>" >&2
        return 1
    fi
    
    # Parse command and version
    local command=$(echo "$cmd_version" | cut -d':' -f1)
    local version=$(echo "$cmd_version" | cut -d':' -f2)
    
    if [ -z "$command" ] || [ -z "$version" ] || [ "$command" = "$version" ]; then
        echo "${RED}Error: Invalid format. Use command:version (e.g., gigen:2.1.0)${NC}" >&2
        return 1
    fi
    
    validate_registry_file "$reg_file" || return 1
    
    # Check if entry exists
    local existing_entry=$(grep "^$command|.*|.*|.*|$version|" "$reg_file" 2>/dev/null)
    if [ -z "$existing_entry" ]; then
        echo "${RED}Error: Command '$command' version '$version' not found in registry${NC}" >&2
        return 1
    fi
    
    # Remove the entry
    grep -v "^$command|.*|.*|.*|$version|" "$reg_file" > "${reg_file}.tmp"
    mv "${reg_file}.tmp" "$reg_file"
    
    echo "${GREEN}✓ Removed $command:$version from registry${NC}"
    echo "  Removed: $existing_entry"
}

# Add config entry to registry
add_config() {
    local reg_file="$1"
    local key="$2"
    local default_value="$3"
    local description="$4"
    local category="$5"
    local scripts="$6"
    
    if [ -z "$key" ] || [ -z "$description" ] || [ -z "$category" ] || [ -z "$scripts" ]; then
        echo "${RED}Error: All config parameters are required${NC}" >&2
        echo "Usage: $SCRIPT_NAME -f <file> config add <key> <default> <desc> <category> <scripts>" >&2
        return 1
    fi
    
    validate_registry_file "$reg_file" || return 1
    
    # Check if config key already exists
    if grep -q "^config:$key:" "$reg_file" 2>/dev/null; then
        echo "${RED}Error: Config key '$key' already exists in registry${NC}" >&2
        echo "Use 'config remove $key' first if you want to update it" >&2
        return 1
    fi
    
    # Create config entry
    local config_entry="config:$key:$default_value:$description:$category:$scripts"
    
    # Find insertion point (after commands, in config section)
    local temp_reg="/tmp/msreg_temp_$$"
    local in_config_section=0
    
    while IFS= read -r line; do
        # Insert after "# Configuration Keys" line or before first config entry
        if echo "$line" | grep -q "# Configuration Keys" || ([ $in_config_section -eq 0 ] && echo "$line" | grep -q "^config:"); then
            in_config_section=1
            echo "$line" >> "$temp_reg"
            if echo "$line" | grep -q "# Configuration Keys"; then
                echo "$config_entry" >> "$temp_reg"
            fi
        else
            echo "$line" >> "$temp_reg"
        fi
    done < "$reg_file"
    
    # If no config section found, append at end
    if [ $in_config_section -eq 0 ]; then
        echo "" >> "$temp_reg"
        echo "# Configuration Keys" >> "$temp_reg"
        echo "$config_entry" >> "$temp_reg"
    fi
    
    mv "$temp_reg" "$reg_file"
    
    echo "${GREEN}✓ Added config key '$key' to registry${NC}"
    echo "  Entry: $config_entry"
}

# Remove config entry from registry
remove_config() {
    local reg_file="$1"
    local key="$2"
    local command="$3"  # Optional: remove from specific command only
    
    if [ -z "$key" ]; then
        echo "${RED}Error: Config key is required${NC}" >&2
        echo "Usage: $SCRIPT_NAME -f <file> config remove <key> [command]" >&2
        return 1
    fi
    
    validate_registry_file "$reg_file" || return 1
    
    # Check if config key exists
    local existing_entry=$(grep "^config:$key:" "$reg_file" 2>/dev/null)
    if [ -z "$existing_entry" ]; then
        echo "${RED}Error: Config key '$key' not found in registry${NC}" >&2
        return 1
    fi
    
    if [ -n "$command" ]; then
        # Remove command from scripts list
        local scripts=$(echo "$existing_entry" | cut -d':' -f6)
        local new_scripts=$(echo "$scripts" | sed "s/,$command//g" | sed "s/$command,//g" | sed "s/^$command$//g")
        
        if [ "$scripts" = "$new_scripts" ]; then
            echo "${YELLOW}Warning: Command '$command' not found in config '$key'${NC}" >&2
            return 1
        fi
        
        if [ -z "$new_scripts" ]; then
            # No scripts left, remove entire config entry
            grep -v "^config:$key:" "$reg_file" > "${reg_file}.tmp"
            mv "${reg_file}.tmp" "$reg_file"
            echo "${GREEN}✓ Removed config '$key' completely (no scripts remaining)${NC}"
        else
            # Update scripts list
            local new_entry=$(echo "$existing_entry" | cut -d':' -f1-5):$new_scripts
            sed "s|^config:$key:.*|$new_entry|" "$reg_file" > "${reg_file}.tmp"
            mv "${reg_file}.tmp" "$reg_file"
            echo "${GREEN}✓ Removed '$command' from config '$key'${NC}"
            echo "  Updated: $new_entry"
        fi
    else
        # Remove entire config entry
        grep -v "^config:$key:" "$reg_file" > "${reg_file}.tmp"
        mv "${reg_file}.tmp" "$reg_file"
        echo "${GREEN}✓ Removed config '$key' from registry${NC}"
        echo "  Removed: $existing_entry"
    fi
}

# List config entries
list_config() {
    local reg_file="$1"
    
    validate_registry_file "$reg_file" || return 1
    
    echo "${CYAN}Configuration Keys:${NC}"
    echo ""
    
    local found_configs=0
    while IFS='|' read -r prefix key default desc category scripts; do
        if [ "$prefix" = "config" ]; then
            found_configs=1
            printf "  %-20s %s\n" "$key" "$desc"
            printf "  %-20s Default: %s\n" "" "${default:-<empty>}"
            printf "  %-20s Category: %s, Scripts: %s\n" "" "$category" "$scripts"
            echo ""
        fi
    done < "$reg_file"
    
    if [ $found_configs -eq 0 ]; then
        echo "  No configuration keys found in registry"
    fi
}

# Handle checksum command
handle_checksum() {
    local file_path="$1"
    
    if [ -z "$file_path" ]; then
        echo "${RED}Error: file path required${NC}" >&2
        echo "Usage: $SCRIPT_NAME checksum <file_path>" >&2
        return 1
    fi
    
    local checksum=$(calculate_checksum "$file_path")
    if [ $? -eq 0 ]; then
        echo "File: $file_path"
        echo "SHA256 (first 8 chars): $checksum"
    fi
}

# Parse arguments
registry_file=""
command=""

# Parse options
while [ $# -gt 0 ]; do
    case "$1" in
        -f|--file)
            registry_file="$2"
            shift 2
            ;;
        -h|--help|help)
            show_help
            exit 0
            ;;
        -v|--version|version)
            show_version
            exit 0
            ;;
        checksum)
            # checksum doesn't need -f option
            shift
            handle_checksum "$1"
            exit $?
            ;;
        add|remove|config)
            command="$1"
            shift
            break
            ;;
        *)
            echo "${RED}Error: Unknown option: $1${NC}" >&2
            show_help
            exit 1
            ;;
    esac
done

# Handle commands that require registry file
case "$command" in
    add)
        add_command "$registry_file" "$@"
        ;;
    remove)
        remove_command "$registry_file" "$1"
        ;;
    config)
        case "$1" in
            add)
                shift
                add_config "$registry_file" "$@"
                ;;
            remove)
                shift
                remove_config "$registry_file" "$@"
                ;;
            list)
                list_config "$registry_file"
                ;;
            *)
                echo "${RED}Error: Unknown config command: $1${NC}" >&2
                echo "Available config commands: add, remove, list" >&2
                exit 1
                ;;
        esac
        ;;
    "")
        show_help
        exit 1
        ;;
    *)
        echo "${RED}Error: Unknown command: $command${NC}" >&2
        show_help
        exit 1
        ;;
esac