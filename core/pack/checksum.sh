#!/bin/sh
# Magic Scripts - Pack Checksum Module
# Checksum calculation and verification functions

#
# Calculate and display file checksum
#
# Usage: pack_checksum <file_path>
#
pack_checksum() {
    local file_path="$1"

    if [ -z "$file_path" ]; then
        ms_error "No file specified" "ms pub pack checksum <file>"
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

#
# Verify file checksum
#
# Usage: pack_verify_checksum <file_path> <expected_checksum>
#
pack_verify_checksum() {
    local file_path="$1"
    local expected="$2"

    if [ ! -f "$file_path" ]; then
        return 1
    fi

    local actual
    actual=$(calculate_file_checksum "$file_path")

    [ "$actual" = "$expected" ]
}

#
# Update checksum in .msver file
#
# Usage: pack_update_checksum_in_msver <msver_file> <version> <new_checksum>
#
pack_update_checksum_in_msver() {
    local msver_file="$1"
    local version="$2"
    local new_checksum="$3"

    if [ ! -f "$msver_file" ]; then
        return 1
    fi

    # Create temporary file
    local temp_file=$(mktemp) || return 1

    # Update checksum for specified version
    while IFS='|' read -r line_type ver url old_checksum rest; do
        if [ "$line_type" = "version" ] && [ "$ver" = "$version" ]; then
            echo "version|$ver|$url|$new_checksum|$rest"
        else
            echo "$line_type|$ver|$url|$old_checksum|$rest"
        fi
    done < "$msver_file" > "$temp_file"

    mv "$temp_file" "$msver_file"
}
