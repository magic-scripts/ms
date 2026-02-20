#!/bin/sh
# Magic Scripts - Version Management Module
#
# This module provides version comparison, checksum calculation, and verification utilities.
#
# Dependencies:
#   - metadata.sh: metadata_get(), metadata_set()
#   - registry.sh: get_script_info()
#   - POSIX shell utilities: sha256sum/shasum/openssl, cut
#   - ms.sh globals: color variables (BLUE, NC)
#
# Functions:
#   - version_get_installed()      Get installed version of a command
#   - version_set_installed()      Set installed version (preserves metadata)
#   - version_get_registry()       Get latest version from registry
#   - version_compare()            Compare two versions
#   - version_calculate_checksum() Calculate SHA256 checksum (8-char)
#   - version_verify_checksum()    Verify installed command checksum

# Get installed version (wrapper for metadata_get)
# Args: cmd
# Returns: version string or "unknown"
version_get_installed() {
    local cmd="$1"
    metadata_get "$cmd" "version"
}

# Set installed version (preserves existing metadata)
# Args: cmd version
version_set_installed() {
    local cmd="$1"
    local version="$2"

    # Try to preserve existing metadata if available
    local meta_file="$HOME/.local/share/magicscripts/installed/$cmd.msmeta"
    if [ -f "$meta_file" ]; then
        local registry_name=$(metadata_get "$cmd" "registry_name")
        local registry_url=$(metadata_get "$cmd" "registry_url")
        local checksum=$(metadata_get "$cmd" "checksum")
        local script_path=$(metadata_get "$cmd" "script_path")
        metadata_set "$cmd" "$version" "$registry_name" "$registry_url" "$checksum" "$script_path"
    else
        metadata_set "$cmd" "$version" "unknown" "unknown" "unknown" "unknown"
    fi
}

# Get registry version for a command
# Args: cmd
# Returns: version string or "unknown"
version_get_registry() {
    local cmd="$1"
    if command -v get_command_info >/dev/null 2>&1; then
        local cmd_info
        cmd_info=$(get_command_info "$cmd" 2>/dev/null)
        if [ -n "$cmd_info" ]; then
            local latest_line
            latest_line=$(version_select_latest_stable "$cmd_info")
            if [ -n "$latest_line" ]; then
                echo "$latest_line" | cut -d'|' -f2
                return 0
            fi
        fi
    fi
    echo "unknown"
}

# Select latest stable version line from msver content (excludes dev)
# Args: versions_text (multiline containing "version|x.y.z|..." lines)
# Returns: full version line of latest stable, empty string if none exists
version_select_latest_stable() {
    local versions_text="$1"
    local non_dev
    non_dev=$(printf '%s\n' "$versions_text" | grep "^version|" | grep -v "^version|dev|")
    [ -z "$non_dev" ] && return 1
    local latest_name
    latest_name=$(printf '%s\n' "$non_dev" | \
        sed 's/^version|\([^|]*\)|.*/\1/' | \
        sort -t. -k1,1n -k2,2n -k3,3n | \
        tail -1)
    printf '%s\n' "$non_dev" | grep "^version|${latest_name}|" | head -1
}

# Compare two versions
# Args: installed_version registry_version
# Returns: "same" or "update_needed"
version_compare() {
    local installed="$1"
    local registry="$2"

    # If both versions are unknown, cannot compare
    if [ "$installed" = "unknown" ] && [ "$registry" = "unknown" ]; then
        echo "unknown"
        return
    fi

    # If either version is unknown, consider update needed
    if [ "$installed" = "unknown" ] || [ "$registry" = "unknown" ]; then
        echo "update_needed"
        return
    fi

    # Simple version comparison (assumes semantic versioning)
    if [ "$installed" = "$registry" ]; then
        echo "same"
    else
        echo "update_needed"
    fi
}

# Calculate file checksum (8-character SHA256)
# Args: file_path
# Returns: 8-character checksum or "unknown"
version_calculate_checksum() {
    local file_path="$1"

    if [ ! -f "$file_path" ]; then
        echo "unknown"
        return 1
    fi

    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file_path" | cut -d' ' -f1 | cut -c1-8
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file_path" | cut -d' ' -f1 | cut -c1-8
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$file_path" | cut -d' ' -f2 | cut -c1-8
    else
        echo "unknown"
        return 1
    fi
}

# Verify installed command checksum
# Args: cmd
# Returns:
#   0 - Checksum matches
#   1 - Checksum mismatch
#   2 - Cannot verify (no metadata)
#   3 - Script file not found
#   4 - Cannot calculate checksum
#   5 - Dev version (no verification needed)
version_verify_checksum() {
    local cmd="$1"
    local expected_checksum=$(metadata_get "$cmd" "checksum")
    local script_path=$(metadata_get "$cmd" "script_path")

    if [ "$expected_checksum" = "unknown" ] || [ -z "$expected_checksum" ] || [ "$script_path" = "unknown" ]; then
        return 2  # Cannot verify - no metadata
    fi

    # Skip checksum verification for dev versions
    if [ "$expected_checksum" = "dev" ]; then
        echo "${BLUE}ℹ Checksum verification skipped (development resource)${NC}" >&2
        return 5  # Dev version - no verification needed
    fi

    if [ ! -f "$script_path" ]; then
        return 3  # Script file not found
    fi

    local actual_checksum=$(version_calculate_checksum "$script_path")
    if [ "$actual_checksum" = "unknown" ]; then
        return 4  # Cannot calculate checksum
    fi

    if [ "$expected_checksum" = "$actual_checksum" ]; then
        return 0  # Match
    else
        return 1  # Mismatch
    fi
}
