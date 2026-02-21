#!/bin/sh
# Magic Scripts - Maintenance Operations Module
#
# This module handles maintenance and utility operations including:
# - Version pinning/unpinning
# - System diagnostics (doctor)
# - Cache cleanup
# - Export/import of installed commands
#
# Dependencies:
#   - metadata.sh: metadata_get(), metadata_update_key()
#   - version.sh: version_get_installed(), version_verify_checksum()
#   - registry.sh: get_all_commands()
#   - ms.sh globals: colors, MAGIC_SCRIPT_DIR
#   - ms.sh functions: ms_error(), format_version()
#
# Functions:
#   - handle_pin()      Pin command to current version
#   - handle_doctor()   Run system diagnostics
#   - handle_clean()    Clean caches and temporary files
#   - handle_export()   Export installed commands list
#   - handle_import()   Import and install from export file

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
        local current_ver=$(get_installed_version "$cmd")
        echo "${YELLOW}'$cmd' is not pinned${NC} (current: $(format_version "$current_ver"))"
        return 0
    fi

    # Remove pinned key by writing empty value
    local tmp_file="${meta_file}.tmp"
    grep -v "^pinned=" "$meta_file" > "$tmp_file"
    mv "$tmp_file" "$meta_file"

    local unpinned_ver=$(get_installed_version "$cmd")
    echo "${GREEN}Unpinned '$cmd'${NC} (current: $(format_version "$unpinned_ver"))"
    echo "  ${CYAN}Hint:${NC} This command will now be updated with 'ms update'"
}


handle_doctor() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "help" ]; then
        echo "${YELLOW}Diagnose Magic Scripts installation and fix common issues${NC}"
        echo ""
        echo "Usage: ms doctor [--fix]"
        echo ""
        echo "Options:"
        echo "  ${GREEN}-f, --fix${NC}     Attempt to fix issues automatically"
        echo ""
        echo "Examples:"
        echo "  ms doctor              # Run diagnostic checks"
        echo "  ms doctor --fix        # Run checks and fix issues"
        exit 0
    fi

    local fix_mode=false

    # Parse options
    if [ "$1" = "-f" ] || [ "$1" = "--fix" ]; then
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
                                        echo "    ❌ $cmd ${BLUE}[$(format_version "$installed_version")]${NC}: Reinstallation failed"
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
            local line_num=0

            while IFS= read -r line; do
                line_num=$((line_num + 1))

                case "$line" in
                    ""|\#*) continue ;;
                esac

                local field_count=$(echo "$line" | awk -F'|' '{print NF}')

                # Accept both 2-field (new format) and 4-field (legacy format)
                if [ "$field_count" -ne 2 ] && [ "$field_count" -ne 4 ]; then
                    if [ "$bad_lines" -eq 0 ]; then
                        echo "  ❌ $reg_name.msreg: Found malformed entries:"
                    fi
                    bad_lines=$((bad_lines + 1))
                    echo "    ${YELLOW}Line $line_num: Expected 2 or 4 fields, got $field_count${NC}"
                fi
            done < "$reg_file"

            if [ "$bad_lines" -gt 0 ]; then
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
        echo "  ${CYAN}ms clean${NC} [options]"
        echo ""
        echo "${YELLOW}Options:${NC}"
        echo "  ${GREEN}-d, --dry-run${NC} Show what would be cleaned without deleting"
        echo "  ${GREEN}-y, --yes${NC}     Skip confirmation prompt"
        echo ""
        echo "${YELLOW}Cleans:${NC}"
        echo "  Registry cache files, orphaned metadata, temp files"
        return 0
    fi

    local dry_run=false
    local auto_confirm=false

    while [ $# -gt 0 ]; do
        case "$1" in
            -d|--dry-run)
                dry_run=true
                ;;
            -y|--yes)
                auto_confirm=true
                ;;
            *)
                echo "${RED}Unknown option: $1${NC}"
                echo "Run ${CYAN}ms clean --help${NC} for usage"
                return 1
                ;;
        esac
        shift
    done

    # Count files before confirmation (unless dry-run or auto-confirm)
    if [ "$dry_run" = false ] && [ "$auto_confirm" = false ]; then
        local reg_dir="$HOME/.local/share/magicscripts/reg"
        local meta_dir="$HOME/.local/share/magicscripts/installed"
        local preview_reg=0
        local preview_meta=0
        local preview_tmp=0

        # Count registry cache files
        if [ -d "$reg_dir" ]; then
            for cache_file in "$reg_dir"/*.msreg; do
                [ -f "$cache_file" ] && preview_reg=$((preview_reg + 1))
            done
        fi

        # Count orphaned metadata
        if [ -d "$meta_dir" ]; then
            for meta_file in "$meta_dir"/*.msmeta; do
                [ -f "$meta_file" ] || continue
                local cmd_name=$(basename "$meta_file" .msmeta)
                [ ! -f "$HOME/.local/bin/ms/$cmd_name" ] && preview_meta=$((preview_meta + 1))
            done
        fi

        # Count temp files
        for tmp_file in /tmp/ms_*; do
            [ -f "$tmp_file" ] && preview_tmp=$((preview_tmp + 1))
        done

        local preview_total=$((preview_reg + preview_meta + preview_tmp))

        if [ "$preview_total" -eq 0 ]; then
            echo "${GREEN}Nothing to clean.${NC}"
            return 0
        fi

        echo "${YELLOW}The following will be removed:${NC}"
        echo "  Registry cache files:  ${CYAN}$preview_reg${NC}"
        echo "  Orphaned metadata:     ${CYAN}$preview_meta${NC}"
        echo "  Temp files:            ${CYAN}$preview_tmp${NC}"
        echo "  ${YELLOW}Total: $preview_total file(s)${NC}"
        echo ""
        printf "Proceed with cleaning? [y/N] "
        read -r confirm
        case "$confirm" in
            y|Y)
                echo ""
                ;;
            *)
                echo "${YELLOW}Cleaning cancelled.${NC}"
                return 0
                ;;
        esac
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

    # 4. Package cache (.mspack and .msver files)
    local pkg_dir="$HOME/.local/share/magicscripts/reg/packages"
    local pkg_count=0
    if [ -d "$pkg_dir" ]; then
        # POSIX-compliant file counting
        for f in "$pkg_dir"/*; do
            [ -f "$f" ] && pkg_count=$((pkg_count + 1))
        done
        if [ "$dry_run" = true ]; then
            echo "  ${CYAN}Would remove:${NC} $pkg_dir/* (package cache)"
        else
            rm -rf "$pkg_dir"
            mkdir -p "$pkg_dir"
        fi
    fi
    echo "  Package cache: ${GREEN}$pkg_count${NC} file(s)"
    total_cleaned=$((total_cleaned + pkg_count))

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
            echo "${RED}failed${NC} (attempted: $(format_version "$cmd_version"))"
            failed_count=$((failed_count + 1))
        fi
    done < "$import_file"

    echo ""
    echo "Import complete!"
    echo "  Installed: ${GREEN}$installed_count${NC}"
    [ $skipped_count -gt 0 ] && echo "  Skipped: ${GREEN}$skipped_count${NC}"
    [ $failed_count -gt 0 ] && echo "  Failed: ${RED}$failed_count${NC}"
}
