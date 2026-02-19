#!/bin/sh
# Magic Scripts - Install Operations Module
#
# This module handles all installation-related operations including:
# - Script installation and updates
# - Registry-wide installations
# - Command detection and resolution
# - Hook script execution
#
# Dependencies:
#   - registry.sh: get_command_info(), get_registry_commands(), download_file()
#   - metadata.sh: metadata_set(), metadata_remove()
#   - version.sh: version_get_installed(), version_get_registry(), version_calculate_checksum(), version_verify_checksum()
#   - ms.sh globals: colors (RED, GREEN, YELLOW, BLUE, CYAN, NC), MAGIC_SCRIPT_DIR
#   - ms.sh functions: ms_error(), format_version()
#
# Functions:
#   - execute_hook()                      Execute install/uninstall/update hooks
#   - install_script()                    Core installation logic
#   - install_registry_all()              Install all commands from a registry
#   - install_commands_with_detection()   Install commands with multi-registry detection
#   - handle_install()                    Main install command handler

# Execute a hook script (install/uninstall/update)
# Args: hook_url [additional args passed to hook]
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


# Core installation logic
# Args: cmd script_uri registry_name version [force_flag] [install_hook_script] [uninstall_hook_script] [update_hook_script] [man_url]
# Returns: 0=success, 1=error, 2=already installed (skip)
install_script() {
    local cmd="$1"
    local script_uri="$2"  # Full URI instead of relative path
    local registry_name="$3"
    local version="$4"
    local force_flag="$5"
    local install_hook_script="$6"
    local uninstall_hook_script="$7"
    local update_hook_script="$8"
    local man_url="$9"
    
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
    local registry_version="$version"
    if [ -z "$registry_version" ]; then
        registry_version=$(version_get_registry "$cmd")
    fi
    local installed_version=$(version_get_installed "$cmd")
    
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
        metadata_remove "$cmd"
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
_ms_ver=\$(grep '^version=' "$MAGIC_DATA_DIR/installed/$cmd.msmeta" 2>/dev/null | cut -d'=' -f2)
MS_INSTALLED_VERSION=\${_ms_ver:-dev}
export MS_INSTALLED_VERSION
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
    metadata_set "$cmd" "$target_version" "$final_registry_name" "$registry_url" "$registry_checksum" "$target_script" "$install_hook_script" "$uninstall_hook_script"
    
    # Verify installation integrity
    version_verify_checksum "$cmd"
    local verify_result=$?
    case $verify_result in
        0)
            # Checksum verified successfully
            ;;
        1)
            echo "${RED}Warning: Checksum mismatch detected for $cmd${NC}" >&2
            local expected=$(metadata_get "$cmd" "checksum")
            local actual=$(version_calculate_checksum "$target_script")
            echo "  Expected: $expected, Got: $actual" >&2
            echo "  The installation may be corrupted." >&2
            return 1
            ;;
        5)
            # Dev version - already printed message in version_verify_checksum
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
        local version_info=$(version_select_latest_stable "$full_cmd_info")
        
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
        local has_dev_only=""
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

        # Block if already installed
        if [ -f "$HOME/.local/bin/ms/$base_cmd" ]; then
            printf "  ${CYAN}%-20s${NC}  already installed\n" "$base_cmd"
            printf "    Use '${CYAN}ms update %s${NC}' to upgrade, or '${CYAN}ms reinstall %s${NC}' to reinstall\n" \
                "$base_cmd" "$base_cmd"
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
                            version_info=$(version_select_latest_stable "$full_cmd_info")
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
                        elif [ -z "$requested_version" ]; then
                            # Package found in registry but has no stable version
                            has_dev_only="$registry_name"
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
            elif [ -n "$has_dev_only" ]; then
                echo "${YELLOW}skipped${NC}"
                echo "    No stable release available. Use ${CYAN}ms install ${base_cmd}:dev${NC} to install the dev version."
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
                echo "${YELLOW}skipped${NC}"
                echo "    No stable release available. Use ${CYAN}ms install ${base_cmd}:dev${NC} to install the dev version."
                failed_count=$((failed_count + 1))
                continue
            fi

            local full_cmd_info=$(get_command_info "$base_cmd" "$found_version" 2>/dev/null)
            local version_info=$(echo "$full_cmd_info" | grep "^version|$found_version|" | head -1)

            if [ -z "$version_info" ]; then
                version_info=$(version_select_latest_stable "$full_cmd_info")
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
                    echo "${YELLOW}skipped${NC}"
                    echo "    No stable release available. Use ${CYAN}ms install ${base_cmd}:dev${NC} to install the dev version."
                    failed_count=$((failed_count + 1))
                    continue
                fi

                local full_cmd_info=$(get_command_info "$base_cmd" "$found_version" 2>/dev/null)
                local version_info=$(echo "$full_cmd_info" | grep "^version|$found_version|" | head -1)

                if [ -z "$version_info" ]; then
                    version_info=$(version_select_latest_stable "$full_cmd_info")
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

            # Block if already installed
            if [ -f "$HOME/.local/bin/ms/$cmd" ]; then
                printf "  ${CYAN}%-20s${NC}  already installed\n" "$cmd"
                printf "    Use '${CYAN}ms update %s${NC}' to upgrade, or '${CYAN}ms reinstall %s${NC}' to reinstall\n" \
                    "$cmd" "$cmd"
                continue
            fi

            # Get command from specific registry using registry system
            if command -v get_command_info >/dev/null 2>&1; then
                # Use get_command_info to properly handle registry system
                local full_cmd_info=$(get_command_info "$cmd" 2>/dev/null)

                if [ -n "$full_cmd_info" ]; then
                    # Parse command metadata and version info from get_command_info output
                    local cmd_meta=$(echo "$full_cmd_info" | grep "^command_meta|")
                    local version_info=$(version_select_latest_stable "$full_cmd_info")

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
