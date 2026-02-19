#!/bin/sh
# Magic Scripts - Query Operations Module
#
# This module handles command information and status queries including:
# - Command information display
# - Command location resolution
# - Outdated command detection
# - Version history listing
#
# Dependencies:
#   - metadata.sh: metadata_get()
#   - version.sh: version_get_installed(), version_get_registry(), version_compare()
#   - registry.sh: get_command_info(), get_all_commands()
#   - ms.sh globals: colors
#   - ms.sh functions: ms_error(), format_version()
#
# Functions:
#   - handle_info()      Show detailed command information
#   - handle_which()     Show command location
#   - handle_outdated()  List outdated commands
#   - handle_versions()  List available versions

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


handle_list() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "help" ]; then
        echo "${YELLOW}List installed commands with version info${NC}"
        echo ""
        echo "${YELLOW}Usage:${NC}"
        echo "  ${CYAN}ms list${NC}"
        echo ""
        echo "${YELLOW}Shows:${NC}"
        echo "  All installed commands, their installed version,"
        echo "  latest available version, and update status."
        echo "  Automatically updates registries before listing."
        return 0
    fi

    # Update registries first
    echo "${CYAN}Updating registries...${NC}"
    if command -v update_registries >/dev/null 2>&1; then
        update_registries >/dev/null 2>&1 || true
    fi
    echo ""

    local ms_install_dir="$HOME/.local/bin/ms"
    local count=0
    local update_count=0

    if [ ! -d "$ms_install_dir" ]; then
        echo "${YELLOW}No Magic Scripts commands installed.${NC}"
        return 0
    fi

    # Count installed commands
    for cmd_file in "$ms_install_dir"/*; do
        [ -f "$cmd_file" ] && [ -x "$cmd_file" ] && count=$((count + 1))
    done

    if [ "$count" -eq 0 ]; then
        echo "${YELLOW}No Magic Scripts commands installed.${NC}"
        return 0
    fi

    echo "${YELLOW}Installed Commands ($count)${NC}"

    for cmd_file in "$ms_install_dir"/*; do
        [ -f "$cmd_file" ] && [ -x "$cmd_file" ] || continue
        local cmd_name
        cmd_name=$(basename "$cmd_file")

        local installed
        installed=$(version_get_installed "$cmd_name")
        local latest
        latest=$(version_get_registry "$cmd_name")
        local is_pinned
        is_pinned=$(metadata_get "$cmd_name" "pinned")
        local comparison
        comparison=$(version_compare "$installed" "$latest")

        if [ "$latest" = "unknown" ]; then
            printf "  ${CYAN}%-20s${NC}  ${BLUE}%-10s${NC}   %-10s  ?\n" \
                "$cmd_name" "$(format_version "$installed")" "unknown"
        elif [ "$comparison" = "update_needed" ]; then
            if [ "$is_pinned" = "true" ]; then
                printf "  ${CYAN}%-20s${NC}  ${YELLOW}%-10s -> %-10s${NC}  (pinned)\n" \
                    "$cmd_name" "$(format_version "$installed")" "$(format_version "$latest")"
            else
                printf "  ${CYAN}%-20s${NC}  ${RED}%-10s${NC} -> ${GREEN}%-10s${NC}  update available\n" \
                    "$cmd_name" "$(format_version "$installed")" "$(format_version "$latest")"
            fi
            update_count=$((update_count + 1))
        else
            if [ "$is_pinned" = "true" ]; then
                printf "  ${CYAN}%-20s${NC}  ${GREEN}%-10s${NC}   ${GREEN}%-10s${NC}  ok (pinned)\n" \
                    "$cmd_name" "$(format_version "$installed")" "$(format_version "$latest")"
            else
                printf "  ${CYAN}%-20s${NC}  ${GREEN}%-10s${NC}   ${GREEN}%-10s${NC}  ok\n" \
                    "$cmd_name" "$(format_version "$installed")" "$(format_version "$latest")"
            fi
        fi
    done

    echo ""
    if [ "$update_count" -gt 0 ]; then
        echo "${YELLOW}$update_count update(s) available.${NC} Run '${CYAN}ms update${NC}' to update all."
    else
        echo "${GREEN}All commands are up to date.${NC}"
    fi
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

