#!/bin/sh
# Magic Scripts - Metadata Management Module
#
# This module manages installation metadata for Magic Scripts commands.
# Metadata is stored in .msmeta files under $HOME/.local/share/magicscripts/installed/
#
# Dependencies:
#   - ms.sh: ms_error() function
#   - POSIX shell utilities: grep, cut, cat, mkdir, mv, rm, date
#
# Functions:
#   - metadata_get()          Get metadata for an installed command
#   - metadata_set()          Set metadata for an installed command
#   - metadata_update_key()   Update a single key in metadata
#   - metadata_remove()       Remove metadata for an installed command

# Get installation metadata
# Args: cmd [key]
# Returns: metadata value(s) or "unknown"
metadata_get() {
    local cmd="$1"
    local key="$2"  # Optional: specific key to get
    local meta_file="$HOME/.local/share/magicscripts/installed/$cmd.msmeta"

    if [ ! -f "$meta_file" ]; then
        [ -n "$key" ] && echo "unknown" || return 1
        return 1
    fi

    if [ -n "$key" ]; then
        grep "^$key=" "$meta_file" 2>/dev/null | cut -d'=' -f2- || echo "unknown"
    else
        cat "$meta_file"
    fi
}

# Set installation metadata
# Args: cmd version registry_name registry_url checksum script_path [install_script] [uninstall_script] [update_script] [install_script_checksum] [uninstall_script_checksum] [update_script_checksum]
metadata_set() {
    local cmd="$1"
    local version="$2"
    local registry_name="$3"
    local registry_url="$4"
    local checksum="$5"
    local script_path="$6"
    local install_script="$7"           # Optional: install script URL
    local uninstall_script="$8"         # Optional: uninstall script URL
    local update_script="$9"            # Optional: update script URL
    local install_script_checksum="${10}"       # Optional: install script checksum
    local uninstall_script_checksum="${11}"     # Optional: uninstall script checksum
    local update_script_checksum="${12}"        # Optional: update script checksum

    local installed_dir="$HOME/.local/share/magicscripts/installed"
    local meta_file="$installed_dir/$cmd.msmeta"

    mkdir -p "$installed_dir"

    # Create metadata file
    cat > "$meta_file" << EOF
command=$cmd
version=$version
registry_name=${registry_name:-unknown}
registry_url=${registry_url:-unknown}
checksum=${checksum:-unknown}
installed_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u)
script_path=${script_path:-unknown}
install_script=${install_script:-}
uninstall_script=${uninstall_script:-}
update_script=${update_script:-}
install_script_checksum=${install_script_checksum:-}
uninstall_script_checksum=${uninstall_script_checksum:-}
update_script_checksum=${update_script_checksum:-}
EOF
}

# Update a single key in installation metadata
# Args: cmd key value
metadata_update_key() {
    local cmd="$1"
    local key="$2"
    local value="$3"
    local meta_file="$HOME/.local/share/magicscripts/installed/$cmd.msmeta"

    if [ ! -f "$meta_file" ]; then
        ms_error "No metadata for '$cmd'" "Is it installed?"
        return 1
    fi

    if grep -q "^${key}=" "$meta_file"; then
        local tmp_file="${meta_file}.tmp"
        grep -v "^${key}=" "$meta_file" > "$tmp_file"
        echo "${key}=${value}" >> "$tmp_file"
        mv "$tmp_file" "$meta_file"
    else
        echo "${key}=${value}" >> "$meta_file"
    fi
}

# Remove installation metadata
# Args: cmd
metadata_remove() {
    local cmd="$1"
    local meta_file="$HOME/.local/share/magicscripts/installed/$cmd.msmeta"
    [ -f "$meta_file" ] && rm "$meta_file"
}
