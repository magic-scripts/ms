#!/bin/sh
# Magic Scripts - Pack Main Handlers
# Main command routing and handling functions

#
# Main pub command router
#
# Usage: handle_pub [pack|reg] [subcommand] [args...]
#
handle_pub() {
    local subcommand="$1"
    shift

    case "$subcommand" in
        pack)
            handle_pub_pack "$@"
            ;;
        reg)
            handle_pub_reg "$@"
            ;;
        -h|--help|help|"")
            cat <<EOF
${YELLOW}Magic Scripts Publisher Tools${NC}

${YELLOW}Usage:${NC}
  ${CYAN}ms pub pack${NC} <command>  - Package management commands
  ${CYAN}ms pub reg${NC}  <command>  - Registry management commands

${YELLOW}Pack Commands:${NC}
  ${CYAN}init${NC}      - Initialize new command project
  ${CYAN}checksum${NC}  - Calculate file checksum
  ${CYAN}version${NC}   - Manage version entries
  ${CYAN}release${NC}   - Create release
  ${CYAN}verify${NC}    - Verify registry files

${YELLOW}Registry Commands:${NC}
  ${CYAN}init${NC}      - Initialize new .msreg file
  ${CYAN}add${NC}       - Add entry to registry
  ${CYAN}remove${NC}    - Remove entry from registry

${YELLOW}Examples:${NC}
  ms pub pack init mycmd
  ms pub pack checksum scripts/mycmd.sh
  ms pub pack version add 1.0.0
  ms pub reg add mycmd

For detailed help on a specific command:
  ms pub pack <command> --help
  ms pub reg <command> --help
EOF
            ;;
        *)
            ms_error "Unknown pub command: $subcommand" "Run 'ms pub --help' for usage"
            return 1
            ;;
    esac
}

#
# Pack command router
#
# Usage: handle_pub_pack <subcommand> [args...]
#
handle_pub_pack() {
    local subcommand="$1"
    shift

    case "$subcommand" in
        init)
            pack_init "$@"
            ;;
        checksum)
            pack_checksum "$@"
            ;;
        version)
            handle_pub_pack_version "$@"
            ;;
        release)
            pack_release "$@"
            ;;
        verify)
            pack_verify "$@"
            ;;
        -h|--help|help|"")
            cat <<EOF
${YELLOW}Pack Command Usage${NC}

${CYAN}ms pub pack init${NC} <name> [options]
  Initialize new command project with git repository

${CYAN}ms pub pack checksum${NC} <file>
  Calculate SHA256 checksum (8-char format)

${CYAN}ms pub pack version${NC} <add|update|list>
  Manage version entries in .msver file

${CYAN}ms pub pack release${NC} <version>
  Full release workflow (verify → checksum → git)

${CYAN}ms pub pack verify${NC} [directory]
  Validate registry file formats
EOF
            ;;
        *)
            ms_error "Unknown pack command: $subcommand" "Run 'ms pub pack --help' for usage"
            return 1
            ;;
    esac
}

#
# Reg command router
#
# Usage: handle_pub_reg <subcommand> [args...]
#
handle_pub_reg() {
    local subcommand="$1"
    shift

    case "$subcommand" in
        init)
            pub_reg_init "$@"
            ;;
        add)
            pub_reg_add "$@"
            ;;
        remove)
            pub_reg_remove "$@"
            ;;
        -h|--help|help|"")
            cat <<EOF
${YELLOW}Registry Command Usage${NC}

${CYAN}ms pub reg init${NC} <name>
  Create new .msreg file with template

${CYAN}ms pub reg add${NC} <name>
  Add entry to .msreg file (auto-detects file)

${CYAN}ms pub reg remove${NC} <name>
  Remove entry from .msreg file
EOF
            ;;
        *)
            ms_error "Unknown reg command: $subcommand" "Run 'ms pub reg --help' for usage"
            return 1
            ;;
    esac
}

#
# Version subcommand router
#
# Usage: handle_pub_pack_version <add|update|list> [args...]
#
handle_pub_pack_version() {
    local action="$1"
    shift

    case "$action" in
        add)
            pack_version_add "$@"
            ;;
        update)
            pack_version_update "$@"
            ;;
        list)
            # List versions from .msver file
            if [ -f ".msver" ]; then
                grep "^version|" .msver | cut -d'|' -f2-
            else
                ms_error "No .msver file found in current directory"
                return 1
            fi
            ;;
        -h|--help|help|"")
            cat <<EOF
${YELLOW}Version Command Usage${NC}

${CYAN}ms pub pack version add${NC} <version> [options]
  Add new version entry to .msver file

${CYAN}ms pub pack version update${NC} <version>
  Update checksum for existing version

${CYAN}ms pub pack version list${NC}
  List all versions in .msver file
EOF
            ;;
        *)
            ms_error "Unknown version action: $action" "Run 'ms pub pack version --help' for usage"
            return 1
            ;;
    esac
}
