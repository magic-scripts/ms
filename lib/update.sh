#!/bin/sh
# Magic Scripts - Update Operations Module
#
# This module handles command updates including:
# - Single command updates
# - Bulk updates (all installed commands)
# - Magic Scripts core updates
# - Version checking and comparison
#
# Dependencies:
#   - install.sh: install_script()
#   - metadata.sh: metadata_get(), metadata_set()
#   - version.sh: version_get_installed(), version_get_registry(), version_compare()
#   - registry.sh: download_file(), ms_internal_get_script_info(), get_script_info()
#   - ms.sh globals: colors, MAGIC_SCRIPT_DIR
#   - ms.sh functions: ms_error(), format_version()
#
# Functions:
#   - handle_update()    Main update command handler

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
        # Refresh registry cache before updating
        if command -v update_registries >/dev/null 2>&1; then
            printf "  Refreshing registry cache... "
            if update_registries >/dev/null 2>&1; then
                printf "${GREEN}done${NC}\n"
            else
                printf "${YELLOW}skipped${NC}\n"
            fi
            echo ""
        fi

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

            # dev version: always update to latest dev; stable: check registry version
            local update_target_version
            if [ "$installed_version" = "dev" ]; then
                update_target_version="dev"
            else
                local registry_version=$(get_registry_version "$cmd")
                local comparison=$(compare_versions "$installed_version" "$registry_version")
                if [ "$comparison" = "same" ] && [ "$installed_version" != "unknown" ]; then
                    echo "${GREEN}already latest${NC} ($(format_version "$installed_version"))"
                    skipped_count=$((skipped_count + 1))
                    continue
                fi
                update_target_version="$registry_version"
            fi

            if command -v get_command_info >/dev/null 2>&1; then
                local full_cmd_info=$(get_command_info "$cmd" "$update_target_version" 2>/dev/null)
                local version_info
                if [ "$update_target_version" = "dev" ]; then
                    version_info=$(printf '%s\n' "$full_cmd_info" | grep "^version|dev|" | head -1)
                else
                    version_info=$(version_select_latest_stable "$full_cmd_info")
                fi
                if [ -n "$version_info" ]; then
                    local script_url=$(printf '%s\n' "$version_info" | cut -d'|' -f3)
                    local new_version=$(printf '%s\n' "$version_info" | cut -d'|' -f2)
                    local install_hook=$(printf '%s\n' "$version_info" | cut -d'|' -f5)
                    local uninstall_hook=$(printf '%s\n' "$version_info" | cut -d'|' -f6)
                    local update_hook=$(printf '%s\n' "$version_info" | cut -d'|' -f7)
                    local man_url=$(printf '%s\n' "$version_info" | cut -d'|' -f8)
                    if install_script "$cmd" "$script_url" "default" "$new_version" "$install_hook" "$uninstall_hook" "$update_hook" "$man_url" "" >/dev/null 2>&1; then
                        echo "${GREEN}done${NC} ($(format_version "$installed_version") → $(format_version "$new_version"))"
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
    
    local script_url install_script_url uninstall_script_url update_script_url man_url version_name expected_checksum
    script_url=$(echo "$ms_info" | cut -d'|' -f3)
    expected_checksum=$(echo "$ms_info" | cut -d'|' -f4)
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
    
    if [ $install_result -eq 0 ]; then
        # Verify ms.sh checksum using msver field 4
        if [ -n "$expected_checksum" ] && [ "$expected_checksum" != "dev" ]; then
            local ms_script="$HOME/.local/share/magicscripts/scripts/ms.sh"
            local actual_checksum
            actual_checksum=$(version_calculate_checksum "$ms_script")
            if [ "$actual_checksum" = "$expected_checksum" ]; then
                echo "${GREEN}✓ ms.sh checksum verified${NC}"
            else
                echo "${RED}✗ ms.sh checksum mismatch (expected: $expected_checksum, got: $actual_checksum)${NC}"
                install_result=1
            fi
        else
            echo "${BLUE}ℹ ms.sh checksum verification skipped (dev version)${NC}"
        fi
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

