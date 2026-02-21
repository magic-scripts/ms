#!/bin/sh
# Magic Scripts - Uninstall Operations Module
#
# This module handles command uninstallation including:
# - Individual command removal
# - Uninstall hook execution
# - Metadata cleanup
# - Man page removal
#
# Dependencies:
#   - install.sh: execute_hook()
#   - metadata.sh: metadata_get(), metadata_remove()
#   - registry.sh: get_all_commands(), ms_internal_get_script_info()
#   - ms.sh globals: colors, MAGIC_SCRIPT_DIR
#   - ms.sh functions: ms_error()
#
# Functions:
#   - handle_uninstall()    Main uninstall command handler

handle_uninstall() {
    echo "${YELLOW}Magic Scripts Uninstaller${NC}"
    echo "======================="
    echo ""
    
    INSTALL_DIR="$HOME/.local/bin/ms"
    local remove_all=false

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

                        # Remove core libraries (ms-specific)
                        if [ -d "$HOME/.local/share/magicscripts/core" ]; then
                            rm -rf "$HOME/.local/share/magicscripts/core"
                            echo "  ${GREEN}Removed${NC}: core libraries"
                        fi

                        # Remove lib modules (ms-specific)
                        if [ -d "$HOME/.local/share/magicscripts/lib" ]; then
                            rm -rf "$HOME/.local/share/magicscripts/lib"
                            echo "  ${GREEN}Removed${NC}: lib modules"
                        fi

                        # Remove registry cache
                        if [ -d "$HOME/.local/share/magicscripts/reg" ]; then
                            rm -rf "$HOME/.local/share/magicscripts/reg"
                            echo "  ${GREEN}Removed${NC}: registry cache"
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
                local should_clean_path=false
                if [ "$remove_all" = true ]; then
                    # Remove all PATH entries when removing all commands
                    should_clean_path=true
                elif [ ! -d "$INSTALL_DIR" ] || [ -z "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]; then
                    # Remove PATH if no commands remain
                    should_clean_path=true
                fi

                if [ "$should_clean_path" = true ]; then
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
            local uninstall_script_checksum=$(get_installation_metadata "$cmd" "uninstall_script_checksum")
            if [ -n "$uninstall_script_url" ] && [ "$uninstall_script_url" != "" ]; then
                local version=$(get_installation_metadata "$cmd" "version")
                local script_path=$(get_installation_metadata "$cmd" "script_path")
                local registry_name=$(get_installation_metadata "$cmd" "registry_name")

                echo "  ${CYAN}Running uninstall script for $cmd...${NC}"
                echo "  ${YELLOW}═══════════════════════════════════════${NC}"
                if execute_hook "$uninstall_script_url" "$uninstall_script_checksum" "$cmd" "$version" "$script_path" "$INSTALL_DIR/$cmd" "$registry_name"; then
                    echo "  ${GREEN}Uninstall script completed successfully${NC}"
                else
                    echo "${YELLOW}Warning: Uninstall script failed for $cmd $(format_version "$version"), proceeding with removal${NC}" >&2
                    if [ "$cmd" = "ms" ]; then
                        echo "  ${YELLOW}Attempting direct removal as fallback...${NC}"
                        if [ -f "$INSTALL_DIR/ms" ]; then
                            rm -f "$INSTALL_DIR/ms"
                            echo "  ${GREEN}Removed${NC}: ms command"
                        fi

                        # Respect user's choice in fallback
                        if [ "$remove_all" = true ]; then
                            # Remove everything
                            if [ -d "$HOME/.local/share/magicscripts" ]; then
                                rm -rf "$HOME/.local/share/magicscripts"
                                echo "  ${GREEN}Removed${NC}: Magic Scripts data directory"
                            fi
                        else
                            # Remove only ms-specific files
                            if [ -d "$HOME/.local/share/magicscripts" ]; then
                                rm -f "$HOME/.local/share/magicscripts/installed/ms.msmeta" 2>/dev/null
                                rm -f "$HOME/.local/share/magicscripts/scripts/ms.sh" 2>/dev/null
                                rm -rf "$HOME/.local/share/magicscripts/core" 2>/dev/null
                                rm -rf "$HOME/.local/share/magicscripts/lib" 2>/dev/null
                                rm -rf "$HOME/.local/share/magicscripts/reg" 2>/dev/null
                                echo "  ${GREEN}Removed${NC}: ms-specific files"
                            fi
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
