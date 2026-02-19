#!/bin/sh
# Magic Scripts - Pack Tools Module
#
# Developer/publisher tools for creating and releasing Magic Scripts commands.
# This module is lazy-loaded only when "ms pub" commands are used.
#
# Functions exported:
#   - pack_init()             - Scaffold new command project
#   - pack_checksum()         - Calculate SHA256 checksum
#   - pack_verify()           - Validate registry files
#   - pack_version_add()      - Add version entry
#   - pack_version_update()   - Update version checksum
#   - pack_release()          - Full release workflow
#   - pack_reg_add()          - Add registry entry
#   - pack_reg_remove()       - Remove registry entry
#   - pub_reg_init()          - Initialize .msreg file
#   - pub_reg_add()           - Add entry with auto-detection
#   - pub_reg_remove()        - Remove entry with auto-detection
#   - handle_pub()            - Main pub command router
#   - handle_pub_pack()       - Pack command router
#   - handle_pub_reg()        - Reg command router
#   - handle_pub_pack_version() - Version command router
#
# Dependencies:
#   - registry.sh: download_file()
#   - ms.sh globals: colors (RED, GREEN, YELLOW, CYAN, NC)
#   - ms.sh functions: ms_error(), get_config_value(), calculate_file_checksum()
#

# Check git global identity (warn only, non-fatal)
_pack_check_git_config() {
    local git_name git_email
    git_name=$(git config --global user.name 2>/dev/null)
    git_email=$(git config --global user.email 2>/dev/null)
    if [ -z "$git_name" ] || [ -z "$git_email" ]; then
        echo ""
        echo "${YELLOW}Warning: git identity not fully configured.${NC}"
        [ -z "$git_name" ] && echo "  Run: git config --global user.name \"Your Name\""
        [ -z "$git_email" ] && echo "  Run: git config --global user.email \"you@example.com\""
    fi
}

# Test SSH connectivity to the remote host (warn only, non-fatal)
_pack_check_ssh_remote() {
    local url="$1"
    case "$url" in
        git@*)
            local host
            host=$(printf '%s' "$url" | sed 's/git@\([^:]*\):.*/\1/')
            printf "  Checking SSH access to %s... " "$host"
            local ssh_out
            ssh_out=$(ssh -T "git@$host" \
                -o ConnectTimeout=5 \
                -o StrictHostKeyChecking=accept-new \
                -o BatchMode=yes 2>&1)
            if printf '%s' "$ssh_out" | grep -qi "successfully authenticated\|hi "; then
                echo "${GREEN}OK${NC}"
            else
                echo "${YELLOW}warning${NC}"
                if printf '%s' "$ssh_out" | grep -qi "permission denied\|publickey"; then
                    echo "  SSH key not authorized. Run: ssh -T git@$host"
                elif printf '%s' "$ssh_out" | grep -qi "could not resolve\|connection refused\|timed out"; then
                    echo "  Cannot reach $host. Check your network connection."
                else
                    echo "  SSH test inconclusive. Proceeding with push attempt."
                fi
            fi
            ;;
    esac
}

# Push a branch to origin with error diagnosis ($1=branch $2=project_dir)
_pack_push_branch() {
    local branch="$1"
    local proj="$2"
    printf "  Pushing %b%s%b... " "${CYAN}" "$branch" "${NC}"
    local push_out push_exit
    push_out=$(git push -u origin "$branch" 2>&1); push_exit=$?
    if [ "$push_exit" -eq 0 ]; then
        echo "${GREEN}OK${NC}"
        return 0
    fi
    echo "${RED}failed${NC}"
    if printf '%s' "$push_out" | grep -qi "permission denied\|publickey"; then
        echo "    SSH key not authorized. Run: ssh -T git@github.com"
    elif printf '%s' "$push_out" | grep -qi "repository not found\|does not exist\|not found"; then
        echo "    Repository not found on remote. Create it first, then:"
        echo "    cd $proj && git push -u origin $branch"
    elif printf '%s' "$push_out" | grep -qi "could not resolve\|unable to connect\|timed out"; then
        echo "    Network error. Check your internet connection."
    else
        printf "    %s\n" "$push_out"
    fi
    return 1
}

pack_init() {
    # Check for help flag first
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "help" ]; then
        show_pub_pack_init_help
        return 0
    fi

    local name=""
    local author=""
    local email=""
    local license=""
    local description=""
    local category=""
    local remote_url=""
    local skip_interactive=false

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --author)
                author="$2"
                shift 2
                ;;
            --email)
                email="$2"
                shift 2
                ;;
            --license)
                license="$2"
                shift 2
                ;;
            --description)
                description="$2"
                shift 2
                ;;
            --category)
                category="$2"
                shift 2
                ;;
            --remote)
                remote_url="$2"
                shift 2
                ;;
            -y|--yes)
                skip_interactive=true
                shift
                ;;
            -*)
                ms_error "Unknown option: $1" "ms pack init <name> [options]"
                return 1
                ;;
            *)
                if [ -z "$name" ]; then
                    name="$1"
                else
                    ms_error "Unexpected argument: $1" "ms pack init <name> [options]"
                    return 1
                fi
                shift
                ;;
        esac
    done

    if [ -z "$name" ]; then
        ms_error "No project name specified" "ms pack init <name> [options]"
        return 1
    fi

    # Validate name
    case "$name" in
        *[!a-zA-Z0-9_-]*)
            ms_error "Invalid name '$name': use only letters, numbers, dashes, underscores"
            return 1
            ;;
    esac

    if [ -d "$name" ]; then
        ms_error "Directory '$name' already exists"
        return 1
    fi

    # Get defaults from config
    local default_author=$(get_config_value "MS_AUTHOR_NAME" "Your Name")
    local default_email=$(get_config_value "MS_AUTHOR_EMAIL" "your@email.com")

    # Interactive prompts for missing values (unless -y is set)
    if [ "$skip_interactive" = false ]; then
        if [ -z "$author" ]; then
            printf "Author name [${CYAN}%s${NC}]: " "$default_author"
            read -r author < /dev/tty
            [ -z "$author" ] && author="$default_author"
        fi

        if [ -z "$email" ]; then
            printf "Author email [${CYAN}%s${NC}]: " "$default_email"
            read -r email < /dev/tty
            [ -z "$email" ] && email="$default_email"
        fi

        if [ -z "$license" ]; then
            printf "License [${CYAN}MIT${NC}]: "
            read -r license < /dev/tty
            [ -z "$license" ] && license="MIT"
        fi

        if [ -z "$description" ]; then
            printf "Description [${CYAN}$name${NC}]: "
            read -r description < /dev/tty
            [ -z "$description" ] && description="$name"
        fi

        if [ -z "$category" ]; then
            printf "Category [${CYAN}utility${NC}]: "
            read -r category < /dev/tty
            [ -z "$category" ] && category="utility"
        fi

        if [ -z "$remote_url" ]; then
            printf "GitHub SSH URL [${CYAN}e.g. git@github.com:org/%s.git${NC}] (optional): " "$name"
            read -r remote_url < /dev/tty
        fi
    else
        # Use defaults for -y mode
        [ -z "$author" ] && author="$default_author"
        [ -z "$email" ] && email="$default_email"
        [ -z "$license" ] && license="MIT"
        [ -z "$description" ] && description="$name"
        [ -z "$category" ] && category="utility"
    fi

    local upper_name=$(echo "$name" | tr 'a-z' 'A-Z' | tr '-' '_')
    local raw_base="https://raw.githubusercontent.com/magic-scripts/$name/develop"
    local main_base="https://raw.githubusercontent.com/magic-scripts/$name/main"

    echo ""
    echo "${YELLOW}Creating project '$name'...${NC}"

    mkdir -p "$name/scripts" "$name/registry" "$name/installer" "$name/man"

    # scripts/<name>.sh
    cat > "$name/scripts/${name}.sh" << SCRIPT_EOF
#!/bin/sh

# $name - Magic Scripts command

VERSION="0.1.0"
SCRIPT_NAME="$name"

show_help() {
    echo "\$SCRIPT_NAME v\$VERSION"
    echo "$description"
    echo ""
    echo "Usage:"
    echo "  \$SCRIPT_NAME              Run the command"
    echo "  \$SCRIPT_NAME --help       Show this help message"
    echo "  \$SCRIPT_NAME --version    Show version information"
}

show_version() {
    echo "\$SCRIPT_NAME v\$VERSION"
}

case "\$1" in
    -h|--help|help)
        show_help
        exit 0
        ;;
    -v|--version|version)
        show_version
        exit 0
        ;;
esac

echo "Hello from $name!"
SCRIPT_EOF
    chmod +x "$name/scripts/${name}.sh"

    # registry/<name>.mspack
    cat > "$name/registry/${name}.mspack" << MSPACK_EOF
# ${name}.mspack - Package Manifest
# Format: type|field1|field2|...

# Package metadata
name|$name
description|$description
author|$author <$email>
license|$license
license_url|https://github.com/magic-scripts/$name/blob/main/LICENSE
repo_url|https://github.com/magic-scripts/$name
issues_url|https://github.com/magic-scripts/$name/issues
category|$category
stability|beta
min_ms_version|0.0.1

# Version file link
msver_url|$main_base/registry/${name}.msver

# Configuration keys
config|${upper_name}_OPTION|default|Default option value|settings|$name
MSPACK_EOF

    # registry/<name>.msver
    cat > "$name/registry/${name}.msver" << MSVER_EOF
# $name Version Tree
# Format: version|version_name|download_url|checksum|install_script|uninstall_script|update_script|man_url
version|dev|$raw_base/scripts/${name}.sh|dev|$raw_base/installer/install.sh|$raw_base/installer/uninstall.sh||$raw_base/man/${name}.1
MSVER_EOF

    # installer/install.sh
    cat > "$name/installer/install.sh" << INSTALL_EOF
#!/bin/sh

# $name Install Script
echo "$name install script completed successfully"
INSTALL_EOF
    chmod +x "$name/installer/install.sh"

    # installer/uninstall.sh
    cat > "$name/installer/uninstall.sh" << UNINSTALL_EOF
#!/bin/sh

# $name Uninstall Script
echo "$name uninstall script completed successfully"
UNINSTALL_EOF
    chmod +x "$name/installer/uninstall.sh"

    # .gitignore
    cat > "$name/.gitignore" << GITIGNORE_EOF
.ms-cache/
*.tmp
.DS_Store
GITIGNORE_EOF

    echo ""
    echo "${GREEN}Created project '$name':${NC}"
    echo "  $name/"
    echo "  ├── scripts/${name}.sh"
    echo "  ├── registry/${name}.mspack"
    echo "  ├── registry/${name}.msver"
    echo "  ├── installer/install.sh"
    echo "  ├── installer/uninstall.sh"
    echo "  ├── man/"
    echo "  └── .gitignore"

    # Git setup
    if command -v git >/dev/null 2>&1; then
        _pack_check_git_config

        local orig_dir="$(pwd)"
        cd "$name"
        git init -q
        git add .
        git commit -q -m "init: scaffold $name project"
        git checkout -q -b develop

        echo ""
        echo "${GREEN}Git initialized with branches:${NC}"
        echo "  ${CYAN}main${NC}     <- initial commit"
        echo "  ${CYAN}develop${NC}  <- current branch (active development)"

        # Remote setup and push
        if [ -n "$remote_url" ]; then
            echo ""
            _pack_check_ssh_remote "$remote_url"

            if git remote | grep -q "^origin$"; then
                echo "  ${YELLOW}Note: remote 'origin' already exists, updating URL${NC}"
                git remote set-url origin "$remote_url"
            else
                git remote add origin "$remote_url"
            fi
            echo "  ${CYAN}origin${NC}   <- $remote_url"

            echo ""
            echo "${YELLOW}Pushing to remote...${NC}"
            local push_failed=false
            _pack_push_branch main "$name"    || push_failed=true
            _pack_push_branch develop "$name" || push_failed=true

            if [ "$push_failed" = false ]; then
                echo "${GREEN}All branches pushed successfully.${NC}"

                # Set GitHub repo description via gh CLI if available
                if command -v gh >/dev/null 2>&1 && [ -n "$description" ]; then
                    local gh_repo
                    gh_repo=$(printf '%s' "$remote_url" | sed 's/git@[^:]*:\(.*\)\.git$/\1/')
                    if [ -n "$gh_repo" ]; then
                        printf "  Setting GitHub repo description... "
                        if gh repo edit "$gh_repo" --description "$description" 2>/dev/null; then
                            echo "${GREEN}OK${NC}"
                        else
                            echo "${YELLOW}skipped (gh not authenticated or insufficient permissions)${NC}"
                        fi
                    fi
                fi
            else
                echo "${YELLOW}Some pushes failed. Fix the issues above and push manually.${NC}"
            fi
        fi

        cd "$orig_dir"
    else
        echo ""
        echo "${YELLOW}Note: git not found. Initialize git manually when ready.${NC}"
    fi

    echo ""
    echo "Next steps:"
    echo "  1. ${CYAN}cd $name${NC}"
    echo "  2. Edit ${CYAN}scripts/${name}.sh${NC} with your command logic"
    echo "  3. ${CYAN}ms pub pack verify registry/${NC}"
    echo "  4. ${CYAN}ms pub pack release registry/ 0.1.0${NC}"
}
# ============================================================================
# Pack Tools (ms pack)
# ============================================================================

ensure_trailing_newline() {
    local file="$1"
    if [ -s "$file" ] && [ -n "$(tail -c 1 "$file")" ]; then
        echo "" >> "$file"
    fi
}

show_pub_pack_release_help() {
    echo "${YELLOW}Automate version release workflow${NC}"
    echo ""
    echo "${YELLOW}Usage:${NC}"
    echo "  ${CYAN}ms pack release <registry_dir> <version>${NC} [options]"
    echo ""
    echo "${YELLOW}Options:${NC}"
    echo "  ${GREEN}--checksum-from <file>${NC}  Script file path (auto-detects if not specified)"
    echo "  ${GREEN}--no-push${NC}               Skip pushing branches to origin (push is on by default)"
    echo "  ${GREEN}--no-git${NC}                Skip git operations (only update .msver)"
    echo ""
    echo "${YELLOW}Examples:${NC}"
    echo "  ${CYAN}ms pack release registry/ 1.0.0${NC}"
    echo "  ${CYAN}ms pack release registry/ 1.0.0 --no-push${NC}"
    echo "  ${CYAN}ms pack release registry/ 1.0.0 --no-git${NC}"
    echo "  ${CYAN}ms pack release registry/ 1.0.0 --checksum-from scripts/foo.sh${NC}"
    echo ""
    echo "${YELLOW}Git Workflow (default):${NC}"
    echo "  Requires: on ${CYAN}develop${NC} branch"
    echo "  1. Verify registry files"
    echo "  2. Calculate checksum"
    echo "  3. Rewrite URLs: /develop/ or /main/ -> /release/v<version>/"
    echo "  4. Register version in .msver"
    echo "  5. Create ${CYAN}release/v<version>${NC} branch + commit"
    echo "  6. Merge to ${CYAN}main${NC}"
    echo "  7. Return to ${CYAN}develop${NC} and sync from main"
    echo "  8. Push release, main, develop to origin [skip with --no-push]"
}

pack_release() {
    local registry_dir=""
    local version=""
    local checksum_from=""
    local do_push=true
    local no_git=false

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help|help)
                show_pub_pack_release_help
                return 0
                ;;
            --checksum-from)
                shift
                checksum_from="$1"
                ;;
            --no-push)
                do_push=false
                ;;
            --no-git)
                no_git=true
                ;;
            *)
                if [ -z "$registry_dir" ]; then
                    registry_dir="$1"
                elif [ -z "$version" ]; then
                    version="$1"
                else
                    ms_error "Unexpected argument: '$1'"
                    return 1
                fi
                ;;
        esac
        shift
    done

    if [ -z "$registry_dir" ] || [ -z "$version" ]; then
        ms_error "Missing required arguments" "ms pack release <registry_dir> <version> [options]"
        return 1
    fi

    if [ ! -d "$registry_dir" ]; then
        ms_error "Directory not found: '$registry_dir'"
        return 1
    fi

    # Step 0: Branch check (unless --no-git)
    if [ "$no_git" = false ]; then
        if ! command -v git >/dev/null 2>&1; then
            ms_error "git is not installed" "Use --no-git to skip git operations"
            return 1
        fi
        local current_branch=$(git branch --show-current 2>/dev/null)
        if [ "$current_branch" != "develop" ]; then
            ms_error "Must be on develop branch (current: $current_branch)" "git checkout develop"
            return 1
        fi
    fi

    local total_steps=4
    if [ "$no_git" = false ]; then
        total_steps=7
    fi

    echo "${YELLOW}Starting release v${version}...${NC}"
    echo ""

    # Step 1: Verify registry files
    echo "${CYAN}[1/${total_steps}] Verifying registry files...${NC}"
    if ! pack_verify "$registry_dir"; then
        ms_error "Registry verification failed. Fix issues before releasing."
        return 1
    fi
    echo ""

    # Find msver file
    local msver_file=""
    for f in "$registry_dir"/*.msver; do
        [ -f "$f" ] || continue
        msver_file="$f"
        break
    done

    if [ -z "$msver_file" ]; then
        ms_error "No .msver file found in '$registry_dir'"
        return 1
    fi

    # Step 2: Calculate checksum
    echo "${CYAN}[2/${total_steps}] Calculating checksum...${NC}"

    # Auto-detect script file if not specified
    if [ -z "$checksum_from" ]; then
        local parent_dir=$(dirname "$registry_dir")
        for script_file in "$parent_dir/scripts"/*.sh; do
            [ -f "$script_file" ] || continue
            checksum_from="$script_file"
            break
        done
    fi

    if [ -z "$checksum_from" ]; then
        ms_error "No script file found. Use --checksum-from to specify."
        return 1
    fi

    if [ ! -f "$checksum_from" ]; then
        ms_error "Script file not found: '$checksum_from'"
        return 1
    fi

    local new_checksum=$(calculate_file_checksum "$checksum_from")
    if [ "$new_checksum" = "unknown" ]; then
        ms_error "Failed to calculate checksum for '$checksum_from'"
        return 1
    fi
    echo "  Checksum: ${GREEN}$new_checksum${NC} (from $checksum_from)"

    # Step 3: URL rewrite + version registration
    echo ""
    echo "${CYAN}[3/${total_steps}] Registering version...${NC}"

    local branch_name="release/v${version}"

    # Helper: rewrite branch in URL (/develop/ or /main/ -> /release/v<version>/)
    rewrite_url_branch() {
        local url="$1"
        echo "$url" | sed "s|/develop/|/${branch_name}/|g; s|/main/|/${branch_name}/|g"
    }

    if grep -q "^version|${version}|" "$msver_file"; then
        echo "  Updating existing version $version in $msver_file"
        pack_version_update "$msver_file" "$version" --checksum-from "$checksum_from"
    else
        echo "  Adding new version $version to $msver_file"
        # Get URLs from existing dev entry
        local dev_line=$(grep "^version|dev|" "$msver_file" | head -1)
        if [ -z "$dev_line" ]; then
            dev_line=$(grep "^version|" "$msver_file" | head -1)
        fi

        local script_url=$(echo "$dev_line" | cut -d'|' -f3)
        local install_hook=$(echo "$dev_line" | cut -d'|' -f5)
        local uninstall_hook=$(echo "$dev_line" | cut -d'|' -f6)
        local update_hook=$(echo "$dev_line" | cut -d'|' -f7)
        local man_url=$(echo "$dev_line" | cut -d'|' -f8)

        # Rewrite URLs to point to release branch (unless --no-git)
        if [ "$no_git" = false ]; then
            script_url=$(rewrite_url_branch "$script_url")
            [ -n "$install_hook" ] && install_hook=$(rewrite_url_branch "$install_hook")
            [ -n "$uninstall_hook" ] && uninstall_hook=$(rewrite_url_branch "$uninstall_hook")
            [ -n "$update_hook" ] && update_hook=$(rewrite_url_branch "$update_hook")
            [ -n "$man_url" ] && man_url=$(rewrite_url_branch "$man_url")
            echo "  URLs rewritten to branch: ${CYAN}$branch_name${NC}"
        fi

        pack_version_add "$msver_file" "$version" "$script_url" \
            --checksum-from "$checksum_from" \
            ${install_hook:+--install "$install_hook"} \
            ${uninstall_hook:+--uninstall "$uninstall_hook"} \
            ${update_hook:+--update "$update_hook"} \
            ${man_url:+--man "$man_url"}
    fi

    # Step 4-7: Git workflow (skip if --no-git)
    if [ "$no_git" = false ]; then
        # Step 4: Create release branch
        echo ""
        echo "${CYAN}[4/${total_steps}] Creating release branch...${NC}"
        if ! git checkout -b "$branch_name" 2>/dev/null; then
            ms_error "Failed to create branch '$branch_name'" "Branch may already exist"
            return 1
        fi
        git add -A 2>/dev/null
        if ! git commit -m "release: v${version}" 2>/dev/null; then
            echo "  ${YELLOW}No changes to commit${NC}"
        fi
        echo "  Created branch: ${GREEN}$branch_name${NC}"

        # Step 5: Merge to main
        echo ""
        echo "${CYAN}[5/${total_steps}] Merging to main...${NC}"
        if ! git checkout main 2>/dev/null; then
            ms_error "Failed to checkout main branch" "Does 'main' branch exist?"
            git checkout develop 2>/dev/null
            return 1
        fi
        if ! git merge "$branch_name" --no-edit 2>/dev/null; then
            ms_error "Failed to merge '$branch_name' into main" "Resolve conflicts manually"
            return 1
        fi
        echo "  ${GREEN}Merged $branch_name into main${NC}"

        # Step 6: Back to develop, sync from main
        echo ""
        echo "${CYAN}[6/${total_steps}] Syncing develop from main...${NC}"
        if ! git checkout develop 2>/dev/null; then
            ms_error "Failed to checkout develop branch"
            return 1
        fi
        if ! git merge main --no-edit 2>/dev/null; then
            ms_error "Failed to merge main into develop" "Resolve conflicts manually"
            return 1
        fi
        echo "  ${GREEN}Synced develop with main${NC}"

        # Step 7: Push if requested
        if [ "$do_push" = true ]; then
            echo ""
            echo "${CYAN}[7/${total_steps}] Pushing to origin...${NC}"
            local push_failed=false
            if ! git push -u origin "$branch_name" 2>/dev/null; then
                echo "  ${YELLOW}Warning: Failed to push $branch_name${NC}"
                push_failed=true
            fi
            if ! git push -u origin main 2>/dev/null; then
                echo "  ${YELLOW}Warning: Failed to push main${NC}"
                push_failed=true
            fi
            if ! git push -u origin develop 2>/dev/null; then
                echo "  ${YELLOW}Warning: Failed to push develop${NC}"
                push_failed=true
            fi
            if [ "$push_failed" = true ]; then
                echo "  ${YELLOW}Some pushes failed. You may need to push manually.${NC}"
            else
                echo "  ${GREEN}Pushed $branch_name, main, develop to origin${NC}"
            fi
        fi
    else
        echo ""
        echo "${CYAN}[4/${total_steps}] Skipping git operations (--no-git)${NC}"
    fi

    echo ""
    echo "${GREEN}Release v${version} complete!${NC}"
}

show_pub_help() {
    echo "${YELLOW}Magic Scripts Publisher Tools${NC}"
    echo ""
    echo "${YELLOW}Usage:${NC}"
    echo "  ${CYAN}ms pub${NC} <toolset> <command> [options]"
    echo ""
    echo "${YELLOW}Toolsets:${NC}"
    echo "  ${GREEN}pack${NC}    Package development tools"
    echo "  ${GREEN}reg${NC}     Registry file management tools"
    echo ""
    echo "${YELLOW}Examples:${NC}"
    echo "  ${CYAN}ms pub pack init mycommand${NC}"
    echo "  ${CYAN}ms pub pack release registry/ 1.0.0${NC}"
    echo "  ${CYAN}ms pub reg init custom${NC}"
    echo "  ${CYAN}ms pub reg add mycommand${NC}"
    echo ""
    echo "Run ${CYAN}ms pub pack help${NC} or ${CYAN}ms pub reg help${NC} for detailed usage."
}

show_pub_pack_help() {
    echo "${YELLOW}Magic Scripts Package Tools${NC}"
    echo ""
    echo "${YELLOW}Usage:${NC}"
    echo "  ${CYAN}ms pub pack${NC} <command> [options]"
    echo ""
    echo "${YELLOW}Commands:${NC}"
    echo "  ${GREEN}init <name> [opts]${NC}            Create new command project scaffold"
    echo "  ${GREEN}checksum <file>${NC}               Calculate 8-char SHA256 checksum"
    echo "  ${GREEN}version add${NC}                   Add a version entry to .msver file"
    echo "  ${GREEN}version update${NC}                Update checksum for existing version"
    echo "  ${GREEN}verify <directory>${NC}            Validate registry files in directory"
    echo "  ${GREEN}release <dir> <ver>${NC}           Automate version release workflow"
    echo ""
    echo "${YELLOW}Examples:${NC}"
    echo "  ${CYAN}ms pub pack init mycommand${NC}"
    echo "  ${CYAN}ms pub pack init mycommand --remote https://github.com/user/mycommand.git${NC}"
    echo "  ${CYAN}ms pub pack checksum scripts/my-script.sh${NC}"
    echo "  ${CYAN}ms pub pack version add registry/foo.msver 1.0.0 scripts/foo.sh${NC}"
    echo "  ${CYAN}ms pub pack version update registry/foo.msver 1.0.0 --checksum-from scripts/foo.sh${NC}"
    echo "  ${CYAN}ms pub pack verify registry/${NC}"
    echo "  ${CYAN}ms pub pack release registry/ 1.0.0${NC}"
    echo ""
    echo "Run ${CYAN}ms pub pack <command> --help${NC} for detailed usage of each command."
}

show_pub_pack_init_help() {
    echo "${YELLOW}Create new Magic Scripts command project${NC}"
    echo ""
    echo "${YELLOW}Usage:${NC}"
    echo "  ${CYAN}ms pack init <name>${NC} [options]"
    echo ""
    echo "${YELLOW}Options:${NC}"
    echo "  ${GREEN}--author <name>${NC}        Author name (default: config MS_AUTHOR_NAME)"
    echo "  ${GREEN}--email <email>${NC}        Author email (default: config MS_AUTHOR_EMAIL)"
    echo "  ${GREEN}--license <type>${NC}       License type (default: MIT)"
    echo "  ${GREEN}--description <text>${NC}   Project description (default: project name)"
    echo "  ${GREEN}--category <cat>${NC}       Category (default: utility)"
    echo "  ${GREEN}--remote <url>${NC}         Remote repository URL (optional)"
    echo "  ${GREEN}-y, --yes${NC}              Skip interactive prompts, use defaults"
    echo ""
    echo "${YELLOW}Behavior:${NC}"
    echo "  - Parameters provided via flags are used directly"
    echo "  - Missing values prompt interactively (unless -y is set)"
    echo "  - Creates project structure with git (main + develop branches)"
    echo "  - If --remote is provided, adds remote and pushes both branches"
    echo ""
    echo "${YELLOW}Examples:${NC}"
    echo "  ${CYAN}ms pack init mycommand${NC}"
    echo "    Interactive mode: prompts for author, email, license, etc."
    echo ""
    echo "  ${CYAN}ms pack init mycommand -y${NC}"
    echo "    Non-interactive: uses all defaults from config"
    echo ""
    echo "  ${CYAN}ms pack init mycommand --author \"John Doe\" --email \"john@example.com\"${NC}"
    echo "    Partial params: prompts for remaining values"
    echo ""
    echo "  ${CYAN}ms pack init mycommand --remote https://github.com/user/mycommand.git -y${NC}"
    echo "    Full automation: creates project, adds remote, pushes to GitHub"
}

show_pub_pack_version_help() {
    echo "${YELLOW}Manage version entries in .msver files${NC}"
    echo ""
    echo "${YELLOW}Usage:${NC}"
    echo "  ${CYAN}ms pack version add <msver_file> <version> <script_url>${NC} [options]"
    echo "  ${CYAN}ms pack version update <msver_file> <version> --checksum-from <file>${NC}"
    echo ""
    echo "${YELLOW}Add Options:${NC}"
    echo "  ${GREEN}--checksum-from <file>${NC}  Calculate checksum from local file"
    echo "  ${GREEN}--install <url>${NC}         Install hook script URL"
    echo "  ${GREEN}--uninstall <url>${NC}       Uninstall hook script URL"
    echo "  ${GREEN}--update <url>${NC}          Update hook script URL"
    echo "  ${GREEN}--man <url>${NC}             Man page URL"
    echo ""
    echo "${YELLOW}Notes:${NC}"
    echo "  If <script_url> is a local file, checksum is auto-calculated."
    echo "  For remote URLs, --checksum-from is required."
    echo ""
    echo "${YELLOW}Examples:${NC}"
    echo "  ${CYAN}ms pack version add registry/foo.msver 1.0.0 scripts/foo.sh${NC}"
    echo "  ${CYAN}ms pack version add registry/foo.msver 1.0.0 https://example.com/foo.sh --checksum-from scripts/foo.sh${NC}"
    echo "  ${CYAN}ms pack version update registry/foo.msver 1.0.0 --checksum-from scripts/foo.sh${NC}"
}

show_pub_reg_help() {
    echo "${YELLOW}Registry File Management Tools${NC}"
    echo ""
    echo "${YELLOW}Usage:${NC}"
    echo "  ${CYAN}ms pub reg${NC} <command> [options]"
    echo ""
    echo "${YELLOW}Commands:${NC}"
    echo "  ${GREEN}init <name>${NC}              Create new .msreg registry file"
    echo "  ${GREEN}add <name> [options]${NC}     Add entry to registry file (auto-detects file)"
    echo "  ${GREEN}remove <name> [options]${NC}  Remove entry from registry file"
    echo ""
    echo "${YELLOW}Examples:${NC}"
    echo "  ${CYAN}ms pub reg init custom${NC}"
    echo "  ${CYAN}ms pub reg add mycommand --url https://example.com/mycommand.mspack${NC}"
    echo "  ${CYAN}ms pub reg remove mycommand${NC}"
    echo ""
    echo "Run ${CYAN}ms pub reg <command> --help${NC} for detailed usage of each command."
}

show_pub_reg_init_help() {
    echo "${YELLOW}Create new .msreg registry file${NC}"
    echo ""
    echo "${YELLOW}Usage:${NC}"
    echo "  ${CYAN}ms pub reg init <name>${NC} [options]"
    echo ""
    echo "${YELLOW}Options:${NC}"
    echo "  ${GREEN}--description <text>${NC}  Registry description (default: \"<name> registry\")"
    echo "  ${GREEN}-y, --yes${NC}             Skip interactive prompts"
    echo ""
    echo "${YELLOW}Behavior:${NC}"
    echo "  - Creates file in registry/ if directory exists, otherwise in current directory"
    echo "  - Adds proper header comments and format documentation"
    echo "  - Interactive mode prompts for description"
    echo ""
    echo "${YELLOW}Examples:${NC}"
    echo "  ${CYAN}ms pub reg init custom${NC}"
    echo "  ${CYAN}ms pub reg init custom --description \"My custom registry\" -y${NC}"
}

show_pub_reg_add_help() {
    echo "${YELLOW}Add entry to .msreg registry file${NC}"
    echo ""
    echo "${YELLOW}Usage:${NC}"
    echo "  ${CYAN}ms pub reg add <name>${NC} [options]"
    echo ""
    echo "${YELLOW}Options:${NC}"
    echo "  ${GREEN}--file <path>${NC}         .msreg file (auto-detected if omitted)"
    echo "  ${GREEN}--url <mspack_url>${NC}    Package manifest URL (required)"
    echo "  ${GREEN}--description <text>${NC}  Command description (default: command name)"
    echo "  ${GREEN}--category <cat>${NC}      Category (default: utilities)"
    echo "  ${GREEN}-y, --yes${NC}             Skip interactive prompts"
    echo ""
    echo "${YELLOW}File Auto-Detection:${NC}"
    echo "  1. Searches registry/*.msreg"
    echo "  2. Falls back to ./*.msreg"
    echo "  3. If multiple found, prompts for selection"
    echo ""
    echo "${YELLOW}Examples:${NC}"
    echo "  ${CYAN}ms pub reg add mycommand${NC}"
    echo "  ${CYAN}ms pub reg add mycommand --url https://example.com/mycommand.mspack -y${NC}"
    echo "  ${CYAN}ms pub reg add mycommand --file registry/custom.msreg --url https://example.com/mycommand.mspack${NC}"
}

show_pub_reg_remove_help() {
    echo "${YELLOW}Remove entry from .msreg registry file${NC}"
    echo ""
    echo "${YELLOW}Usage:${NC}"
    echo "  ${CYAN}ms pub reg remove <name>${NC} [options]"
    echo ""
    echo "${YELLOW}Options:${NC}"
    echo "  ${GREEN}--file <path>${NC}  .msreg file (auto-detected if omitted)"
    echo ""
    echo "${YELLOW}Examples:${NC}"
    echo "  ${CYAN}ms pub reg remove mycommand${NC}"
    echo "  ${CYAN}ms pub reg remove mycommand --file registry/custom.msreg${NC}"
}

pack_checksum() {
    local file_path="$1"

    if [ -z "$file_path" ]; then
        ms_error "No file specified" "ms pack checksum <file>"
        return 1
    fi

    if [ ! -f "$file_path" ]; then
        ms_error "File not found: '$file_path'"
        return 1
    fi

    local checksum
    checksum=$(calculate_file_checksum "$file_path")

    if [ $? -ne 0 ] || [ "$checksum" = "unknown" ]; then
        ms_error "Failed to calculate checksum" "Ensure sha256sum, shasum, or openssl is installed"
        return 1
    fi

    echo "${CYAN}File:${NC}     $file_path"
    echo "${CYAN}Checksum:${NC} ${GREEN}$checksum${NC}"
}

pack_version_add() {
    local msver_file=""
    local version=""
    local script_url=""
    local checksum_from=""
    local install_url=""
    local uninstall_url=""
    local update_url=""
    local man_url=""

    local positional_count=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --checksum-from)
                [ -z "$2" ] && { ms_error "Missing value for --checksum-from"; return 1; }
                checksum_from="$2"
                shift 2
                ;;
            --install)
                [ -z "$2" ] && { ms_error "Missing value for --install"; return 1; }
                install_url="$2"
                shift 2
                ;;
            --uninstall)
                [ -z "$2" ] && { ms_error "Missing value for --uninstall"; return 1; }
                uninstall_url="$2"
                shift 2
                ;;
            --update)
                [ -z "$2" ] && { ms_error "Missing value for --update"; return 1; }
                update_url="$2"
                shift 2
                ;;
            --man)
                [ -z "$2" ] && { ms_error "Missing value for --man"; return 1; }
                man_url="$2"
                shift 2
                ;;
            -*)
                ms_error "Unknown option: '$1'" "ms pack version add --help"
                return 1
                ;;
            *)
                positional_count=$((positional_count + 1))
                case $positional_count in
                    1) msver_file="$1" ;;
                    2) version="$1" ;;
                    3) script_url="$1" ;;
                    *) ms_error "Too many arguments" "ms pack version add --help"; return 1 ;;
                esac
                shift
                ;;
        esac
    done

    if [ -z "$msver_file" ] || [ -z "$version" ] || [ -z "$script_url" ]; then
        ms_error "Missing required arguments" "ms pack version add <msver_file> <version> <script_url>"
        return 1
    fi

    # Validate no pipe in version name
    case "$version" in
        *\|*) ms_error "Version name cannot contain pipe '|' character"; return 1 ;;
    esac

    if [ ! -f "$msver_file" ]; then
        ms_error "File not found: '$msver_file'"
        return 1
    fi

    if [ ! -w "$msver_file" ]; then
        ms_error "File is not writable: '$msver_file'"
        return 1
    fi

    # Check for duplicate version
    if grep -q "^version|${version}|" "$msver_file"; then
        ms_error "Version '$version' already exists in $msver_file" "Use 'ms pack version update' to modify"
        return 1
    fi

    # Calculate checksum
    local checksum=""
    if [ -n "$checksum_from" ]; then
        if [ ! -f "$checksum_from" ]; then
            ms_error "Checksum source file not found: '$checksum_from'"
            return 1
        fi
        checksum=$(calculate_file_checksum "$checksum_from")
    elif [ -f "$script_url" ]; then
        checksum=$(calculate_file_checksum "$script_url")
        echo "${YELLOW}Auto-calculated checksum from local file: ${GREEN}$checksum${NC}"
    else
        ms_error "Cannot auto-calculate checksum for remote URL" "Use --checksum-from <local_file> to provide checksum"
        return 1
    fi

    if [ "$checksum" = "unknown" ] || [ -z "$checksum" ]; then
        ms_error "Failed to calculate checksum"
        return 1
    fi

    # Build version line
    local version_line="version|$version|$script_url|$checksum|$install_url|$uninstall_url|$update_url|$man_url"

    # Ensure file ends with newline before appending
    ensure_trailing_newline "$msver_file"

    echo "$version_line" >> "$msver_file"

    echo "${GREEN}Added version '$version' to $msver_file${NC}"
    echo "${CYAN}Line:${NC} $version_line"
}

pack_version_update() {
    local msver_file=""
    local version=""
    local checksum_from=""

    local positional_count=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --checksum-from)
                [ -z "$2" ] && { ms_error "Missing value for --checksum-from"; return 1; }
                checksum_from="$2"
                shift 2
                ;;
            -*)
                ms_error "Unknown option: '$1'" "ms pack version update --help"
                return 1
                ;;
            *)
                positional_count=$((positional_count + 1))
                case $positional_count in
                    1) msver_file="$1" ;;
                    2) version="$1" ;;
                    *) ms_error "Too many arguments"; return 1 ;;
                esac
                shift
                ;;
        esac
    done

    if [ -z "$msver_file" ] || [ -z "$version" ]; then
        ms_error "Missing required arguments" "ms pack version update <msver_file> <version> --checksum-from <file>"
        return 1
    fi

    if [ ! -f "$msver_file" ]; then
        ms_error "File not found: '$msver_file'"
        return 1
    fi

    if [ ! -w "$msver_file" ]; then
        ms_error "File is not writable: '$msver_file'"
        return 1
    fi

    local existing_line
    existing_line=$(grep "^version|${version}|" "$msver_file")
    if [ -z "$existing_line" ]; then
        ms_error "Version '$version' not found in $msver_file" "Use 'ms pack version add' to create it"
        return 1
    fi

    if [ -z "$checksum_from" ]; then
        ms_error "No --checksum-from specified" "ms pack version update <msver_file> <version> --checksum-from <file>"
        return 1
    fi

    if [ ! -f "$checksum_from" ]; then
        ms_error "Checksum source file not found: '$checksum_from'"
        return 1
    fi

    local new_checksum
    new_checksum=$(calculate_file_checksum "$checksum_from")
    if [ "$new_checksum" = "unknown" ] || [ -z "$new_checksum" ]; then
        ms_error "Failed to calculate checksum"
        return 1
    fi

    # Parse existing line and replace checksum (field 4)
    local old_checksum
    old_checksum=$(echo "$existing_line" | cut -d'|' -f4)

    local old_ver old_url old_install old_uninstall old_update old_man
    old_ver=$(echo "$existing_line" | cut -d'|' -f2)
    old_url=$(echo "$existing_line" | cut -d'|' -f3)
    old_install=$(echo "$existing_line" | cut -d'|' -f5)
    old_uninstall=$(echo "$existing_line" | cut -d'|' -f6)
    old_update=$(echo "$existing_line" | cut -d'|' -f7)
    old_man=$(echo "$existing_line" | cut -d'|' -f8)

    local new_line="version|$old_ver|$old_url|$new_checksum|$old_install|$old_uninstall|$old_update|$old_man"

    # Replace line using temp file pattern (portable)
    local temp_file="${msver_file}.tmp"
    while IFS= read -r line; do
        case "$line" in
            "version|${version}|"*)
                echo "$new_line"
                ;;
            *)
                echo "$line"
                ;;
        esac
    done < "$msver_file" > "$temp_file" && mv "$temp_file" "$msver_file"

    echo "${GREEN}Updated checksum for version '$version'${NC}"
    echo "${CYAN}Old:${NC} $old_checksum"
    echo "${CYAN}New:${NC} ${GREEN}$new_checksum${NC}"
}

pack_verify() {
    local dir="$1"

    if [ -z "$dir" ]; then
        ms_error "No directory specified" "ms pack verify <directory>"
        return 1
    fi

    if [ ! -d "$dir" ]; then
        ms_error "Directory not found: '$dir'"
        return 1
    fi

    echo "${YELLOW}Verifying registry files in: $dir${NC}"
    echo ""

    local total_issues=0
    local files_checked=0

    # Check .msreg files
    for reg_file in "$dir"/*.msreg; do
        [ ! -f "$reg_file" ] && continue
        files_checked=$((files_checked + 1))
        echo "${CYAN}Checking:${NC} $(basename "$reg_file") (registry)"

        local line_num=0
        while IFS= read -r line; do
            line_num=$((line_num + 1))
            case "$line" in
                \#*|"") continue ;;
            esac

            local field_count
            field_count=$(echo "$line" | awk -F'|' '{print NF}')
            if [ "$field_count" -lt 4 ]; then
                echo "  ${RED}Line $line_num: Expected 4+ pipe-separated fields, got $field_count${NC}"
                total_issues=$((total_issues + 1))
                continue
            fi

            local entry_url
            entry_url=$(echo "$line" | cut -d'|' -f2)
            case "$entry_url" in
                https://*) ;;
                http://*)
                    echo "  ${YELLOW}Line $line_num: Non-HTTPS URL${NC}"
                    ;;
                *)
                    echo "  ${RED}Line $line_num: Invalid URL: $entry_url${NC}"
                    total_issues=$((total_issues + 1))
                    ;;
            esac
        done < "$reg_file"
        echo "  ${GREEN}OK${NC}"
    done

    # Check .mspack files
    for pack_file in "$dir"/*.mspack; do
        [ ! -f "$pack_file" ] && continue
        files_checked=$((files_checked + 1))
        echo "${CYAN}Checking:${NC} $(basename "$pack_file") (package manifest)"

        local has_name=false
        local has_msver_url=false

        while IFS='|' read -r entry_type field1 field2 rest; do
            case "$entry_type" in
                \#*|"") continue ;;
                name) has_name=true ;;
                msver_url)
                    has_msver_url=true
                    case "$field1" in
                        https://*) ;;
                        *) echo "  ${RED}msver_url is not HTTPS: $field1${NC}"; total_issues=$((total_issues + 1)) ;;
                    esac
                    ;;
                config)
                    local cfg_fields
                    cfg_fields=$(echo "$entry_type|$field1|$field2|$rest" | awk -F'|' '{print NF}')
                    if [ "$cfg_fields" -lt 6 ]; then
                        echo "  ${YELLOW}Config line may have missing fields: $field1${NC}"
                    fi
                    ;;
            esac
        done < "$pack_file"

        if [ "$has_name" = false ]; then
            echo "  ${RED}Missing required 'name' field${NC}"
            total_issues=$((total_issues + 1))
        fi
        if [ "$has_msver_url" = false ]; then
            echo "  ${YELLOW}No msver_url field (2-tier mode)${NC}"
        fi
        echo "  ${GREEN}OK${NC}"
    done

    # Check .msver files
    for ver_file in "$dir"/*.msver; do
        [ ! -f "$ver_file" ] && continue
        files_checked=$((files_checked + 1))
        echo "${CYAN}Checking:${NC} $(basename "$ver_file") (version file)"

        local version_count=0
        while IFS='|' read -r entry_type ver_name dl_url checksum install_s uninstall_s update_s man_u; do
            case "$entry_type" in
                \#*|"") continue ;;
                version)
                    version_count=$((version_count + 1))

                    if [ -z "$ver_name" ]; then
                        echo "  ${RED}Empty version name${NC}"
                        total_issues=$((total_issues + 1))
                    fi

                    if [ -z "$dl_url" ]; then
                        echo "  ${RED}Missing download URL for version '$ver_name'${NC}"
                        total_issues=$((total_issues + 1))
                    fi

                    # Validate checksum format (8 hex chars or "dev")
                    if [ "$checksum" != "dev" ]; then
                        local checksum_len=${#checksum}
                        if [ "$checksum_len" -ne 8 ]; then
                            echo "  ${RED}Version '$ver_name': Checksum '$checksum' is not 8 characters (got $checksum_len)${NC}"
                            total_issues=$((total_issues + 1))
                        else
                            case "$checksum" in
                                *[!0-9a-fA-F]*)
                                    echo "  ${RED}Version '$ver_name': Checksum '$checksum' contains non-hex characters${NC}"
                                    total_issues=$((total_issues + 1))
                                    ;;
                            esac
                        fi
                    fi

                    # Try to find local script file and verify checksum
                    local script_basename
                    script_basename=$(basename "$dl_url")
                    local parent_dir
                    parent_dir=$(dirname "$dir")
                    local local_script="$parent_dir/scripts/$script_basename"
                    if [ -f "$local_script" ] && [ "$checksum" != "dev" ]; then
                        local actual_checksum
                        actual_checksum=$(calculate_file_checksum "$local_script")
                        if [ "$actual_checksum" != "$checksum" ]; then
                            echo "  ${RED}Version '$ver_name': Checksum mismatch!${NC}"
                            echo "    Expected: $checksum"
                            echo "    Actual:   $actual_checksum"
                            echo "    File:     $local_script"
                            total_issues=$((total_issues + 1))
                        else
                            echo "  ${GREEN}Version '$ver_name': Checksum verified ($checksum)${NC}"
                        fi
                    fi
                    ;;
                *)
                    echo "  ${YELLOW}Unknown entry type: '$entry_type'${NC}"
                    ;;
            esac
        done < "$ver_file"

        if [ "$version_count" -eq 0 ]; then
            echo "  ${YELLOW}No version entries found${NC}"
        else
            echo "  Found $version_count version(s)"
        fi
        echo "  ${GREEN}OK${NC}"
    done

    echo ""
    echo "Files checked: $files_checked"
    if [ "$total_issues" -gt 0 ]; then
        echo "${RED}Issues found: $total_issues${NC}"
        return 1
    else
        echo "${GREEN}All checks passed${NC}"
        return 0
    fi
}

pack_reg_add() {
    local msreg_file="$1"
    local name="$2"
    local mspack_url="$3"
    local description="$4"
    local category="$5"

    if [ -z "$msreg_file" ] || [ -z "$name" ] || [ -z "$mspack_url" ] || [ -z "$description" ] || [ -z "$category" ]; then
        ms_error "Missing required arguments" "ms pack reg add <msreg_file> <name> <mspack_url> <description> <category>"
        return 1
    fi

    if [ ! -f "$msreg_file" ]; then
        ms_error "File not found: '$msreg_file'"
        return 1
    fi

    if [ ! -w "$msreg_file" ]; then
        ms_error "File is not writable: '$msreg_file'"
        return 1
    fi

    # Validate name format
    case "$name" in
        *[!a-zA-Z0-9_-]*)
            ms_error "Invalid name '$name': use only letters, numbers, dashes, underscores"
            return 1
            ;;
    esac

    # Validate no pipe in fields
    case "$description$category" in
        *\|*)
            ms_error "Description and category cannot contain pipe '|' characters"
            return 1
            ;;
    esac

    # Check for duplicate
    if grep -q "^${name}|" "$msreg_file"; then
        ms_error "Entry '$name' already exists in $msreg_file"
        return 1
    fi

    # Validate URL
    case "$mspack_url" in
        https://*) ;;
        http://*)
            echo "${YELLOW}Warning: Non-HTTPS URL. HTTPS is recommended for security.${NC}"
            ;;
        *)
            ms_error "Invalid URL: '$mspack_url'" "URL must start with https://"
            return 1
            ;;
    esac

    local entry_line="$name|$mspack_url|$description|$category"

    ensure_trailing_newline "$msreg_file"
    echo "$entry_line" >> "$msreg_file"

    echo "${GREEN}Added '$name' to $msreg_file${NC}"
    echo "${CYAN}Line:${NC} $entry_line"
}

pack_reg_remove() {
    local msreg_file="$1"
    local name="$2"

    if [ -z "$msreg_file" ] || [ -z "$name" ]; then
        ms_error "Missing required arguments" "ms pack reg remove <msreg_file> <name>"
        return 1
    fi

    if [ ! -f "$msreg_file" ]; then
        ms_error "File not found: '$msreg_file'"
        return 1
    fi

    if [ ! -w "$msreg_file" ]; then
        ms_error "File is not writable: '$msreg_file'"
        return 1
    fi

    if ! grep -q "^${name}|" "$msreg_file"; then
        ms_error "Entry '$name' not found in $msreg_file"
        return 1
    fi

    grep -v "^${name}|" "$msreg_file" > "${msreg_file}.tmp" && mv "${msreg_file}.tmp" "$msreg_file"

    echo "${GREEN}Removed '$name' from $msreg_file${NC}"
}

pub_reg_init() {
    # Check for help flag
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "help" ]; then
        show_pub_reg_init_help
        return 0
    fi

    local name=""
    local description=""
    local skip_interactive=false

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --description)
                description="$2"
                shift 2
                ;;
            -y|--yes)
                skip_interactive=true
                shift
                ;;
            -*)
                ms_error "Unknown option: $1" "ms pub reg init <name> [options]"
                return 1
                ;;
            *)
                if [ -z "$name" ]; then
                    name="$1"
                else
                    ms_error "Unexpected argument: $1" "ms pub reg init <name> [options]"
                    return 1
                fi
                shift
                ;;
        esac
    done

    # Validate name
    if [ -z "$name" ]; then
        ms_error "No registry name specified" "ms pub reg init <name>"
        return 1
    fi

    # Validate name format
    case "$name" in
        *[!a-zA-Z0-9_-]*)
            ms_error "Invalid name '$name': use only letters, numbers, dashes, underscores"
            return 1
            ;;
    esac

    # Determine file path
    local file_path
    if [ -d "registry" ]; then
        file_path="registry/${name}.msreg"
    else
        file_path="${name}.msreg"
    fi

    if [ -f "$file_path" ]; then
        ms_error "File already exists: $file_path"
        return 1
    fi

    # Interactive prompt for description
    if [ "$skip_interactive" = false ] && [ -z "$description" ]; then
        printf "Registry description [${CYAN}$name registry${NC}]: "
        read -r description < /dev/tty
        [ -z "$description" ] && description="$name registry"
    fi
    [ -z "$description" ] && description="$name registry"

    # Create file with header
    cat > "$file_path" <<EOF
# $description
# Format: name|mspack_url|description|category
#
# Each command points to its own .mspack file containing:
# - Package metadata (author, license, dependencies, config keys)
# - Link to .msver file for version information

EOF

    echo "${GREEN}Created registry file: $file_path${NC}"
    echo "${CYAN}Description:${NC} $description"
    echo ""
    echo "Next steps:"
    echo "  ${CYAN}ms pub reg add <command>${NC}  # Add entries to this registry"
}

pub_reg_add() {
    # Check for help flag
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "help" ]; then
        show_pub_reg_add_help
        return 0
    fi

    local file_path=""
    local name=""
    local mspack_url=""
    local description=""
    local category=""
    local skip_interactive=false

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --file)
                file_path="$2"
                shift 2
                ;;
            --url)
                mspack_url="$2"
                shift 2
                ;;
            --description)
                description="$2"
                shift 2
                ;;
            --category)
                category="$2"
                shift 2
                ;;
            -y|--yes)
                skip_interactive=true
                shift
                ;;
            -*)
                ms_error "Unknown option: $1" "ms pub reg add <name> [options]"
                return 1
                ;;
            *)
                if [ -z "$name" ]; then
                    name="$1"
                else
                    ms_error "Unexpected argument: $1" "ms pub reg add <name> [options]"
                    return 1
                fi
                shift
                ;;
        esac
    done

    # Validate name
    if [ -z "$name" ]; then
        ms_error "No command name specified" "ms pub reg add <name> [options]"
        return 1
    fi

    # Auto-detect .msreg file
    if [ -z "$file_path" ]; then
        local found_files=""
        if [ -d "registry" ]; then
            found_files=$(find registry -maxdepth 1 -name "*.msreg" -type f 2>/dev/null)
        fi
        if [ -z "$found_files" ]; then
            found_files=$(find . -maxdepth 1 -name "*.msreg" -type f 2>/dev/null)
        fi

        local file_count=$(echo "$found_files" | grep -c '^' 2>/dev/null || echo "0")

        if [ "$file_count" -eq 0 ]; then
            ms_error "No .msreg files found" "Create one with 'ms pub reg init <name>'"
            return 1
        elif [ "$file_count" -eq 1 ]; then
            file_path="$found_files"
            echo "${CYAN}Using registry file:${NC} $file_path"
        else
            # Multiple files - interactive selection
            echo "${YELLOW}Multiple .msreg files found:${NC}"
            local i=1
            local file_array=""
            echo "$found_files" | while IFS= read -r f; do
                echo "  ${GREEN}$i${NC}) $f"
                i=$((i + 1))
            done
            printf "Select file [${CYAN}1-$file_count${NC}]: "
            read -r selection < /dev/tty
            file_path=$(echo "$found_files" | sed -n "${selection}p")

            if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
                ms_error "Invalid selection"
                return 1
            fi
            echo "${CYAN}Using registry file:${NC} $file_path"
        fi
    fi

    # Validate file exists
    if [ ! -f "$file_path" ]; then
        ms_error "File not found: '$file_path'"
        return 1
    fi

    # Interactive prompts for missing values
    if [ "$skip_interactive" = false ]; then
        if [ -z "$mspack_url" ]; then
            printf "Package URL (mspack): "
            read -r mspack_url < /dev/tty
        fi

        if [ -z "$description" ]; then
            printf "Description [${CYAN}$name${NC}]: "
            read -r description < /dev/tty
            [ -z "$description" ] && description="$name"
        fi

        if [ -z "$category" ]; then
            printf "Category [${CYAN}utilities${NC}]: "
            read -r category < /dev/tty
            [ -z "$category" ] && category="utilities"
        fi
    fi

    # Set defaults if still empty
    [ -z "$description" ] && description="$name"
    [ -z "$category" ] && category="utilities"

    # Validate required fields
    if [ -z "$mspack_url" ]; then
        ms_error "Package URL is required" "Use --url or interactive mode"
        return 1
    fi

    # Delegate to existing pack_reg_add for validation and insertion
    pack_reg_add "$file_path" "$name" "$mspack_url" "$description" "$category"
}

pub_reg_remove() {
    # Check for help flag
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ "$1" = "help" ]; then
        show_pub_reg_remove_help
        return 0
    fi

    local file_path=""
    local name=""

    # Parse arguments
    while [ $# -gt 0 ]; do
        case "$1" in
            --file)
                file_path="$2"
                shift 2
                ;;
            -*)
                ms_error "Unknown option: $1" "ms pub reg remove <name> [options]"
                return 1
                ;;
            *)
                if [ -z "$name" ]; then
                    name="$1"
                else
                    ms_error "Unexpected argument: $1" "ms pub reg remove <name> [options]"
                    return 1
                fi
                shift
                ;;
        esac
    done

    # Validate name
    if [ -z "$name" ]; then
        ms_error "No command name specified" "ms pub reg remove <name> [--file <path>]"
        return 1
    fi

    # Auto-detect .msreg file (same logic as pub_reg_add)
    if [ -z "$file_path" ]; then
        local found_files=""
        if [ -d "registry" ]; then
            found_files=$(find registry -maxdepth 1 -name "*.msreg" -type f 2>/dev/null)
        fi
        if [ -z "$found_files" ]; then
            found_files=$(find . -maxdepth 1 -name "*.msreg" -type f 2>/dev/null)
        fi

        local file_count=$(echo "$found_files" | grep -c '^' 2>/dev/null || echo "0")

        if [ "$file_count" -eq 0 ]; then
            ms_error "No .msreg files found"
            return 1
        elif [ "$file_count" -eq 1 ]; then
            file_path="$found_files"
            echo "${CYAN}Using registry file:${NC} $file_path"
        else
            # Multiple files - interactive selection
            echo "${YELLOW}Multiple .msreg files found:${NC}"
            local i=1
            echo "$found_files" | while IFS= read -r f; do
                echo "  ${GREEN}$i${NC}) $f"
                i=$((i + 1))
            done
            printf "Select file [${CYAN}1-$file_count${NC}]: "
            read -r selection < /dev/tty
            file_path=$(echo "$found_files" | sed -n "${selection}p")

            if [ -z "$file_path" ] || [ ! -f "$file_path" ]; then
                ms_error "Invalid selection"
                return 1
            fi
            echo "${CYAN}Using registry file:${NC} $file_path"
        fi
    fi

    # Delegate to existing pack_reg_remove
    pack_reg_remove "$file_path" "$name"
}

handle_pub_pack_version() {
    case "$1" in
        -h|--help|help|"")
            show_pub_pack_version_help
            return 0
            ;;
        add)
            shift
            pack_version_add "$@"
            ;;
        update)
            shift
            pack_version_update "$@"
            ;;
        *)
            ms_error "Unknown pack version command: '$1'" "Run 'ms pack version help' for usage"
            return 1
            ;;
    esac
}

handle_pub_reg() {
    case "$1" in
        -h|--help|help|"")
            show_pub_reg_help
            return 0
            ;;
        init)
            shift
            pub_reg_init "$@"
            ;;
        add)
            shift
            pub_reg_add "$@"
            ;;
        remove)
            shift
            pub_reg_remove "$@"
            ;;
        *)
            ms_error "Unknown pub reg command: '$1'" "Run 'ms pub reg help' for usage"
            return 1
            ;;
    esac
}

handle_pub() {
    case "$1" in
        -h|--help|help|"")
            show_pub_help
            return 0
            ;;
        pack)
            shift
            handle_pub_pack "$@"
            ;;
        reg)
            shift
            handle_pub_reg "$@"
            ;;
        *)
            ms_error "Unknown pub command: '$1'" "Run 'ms pub help' for available commands"
            return 1
            ;;
    esac
}

handle_pub_pack() {
    case "$1" in
        -h|--help|help|"")
            show_pub_pack_help
            return 0
            ;;
        init)
            shift
            pack_init "$@"
            ;;
        checksum)
            shift
            pack_checksum "$@"
            ;;
        version)
            shift
            handle_pub_pack_version "$@"
            ;;
        verify)
            shift
            pack_verify "$@"
            ;;
        reg)
            shift
            handle_pub_reg "$@"
            ;;
        release)
            shift
            pack_release "$@"
            ;;
        *)
            ms_error "Unknown pack command: '$1'" "Run 'ms pack help' for available commands"
            return 1
            ;;
    esac
}
