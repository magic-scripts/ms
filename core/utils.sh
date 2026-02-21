#!/bin/sh
# Magic Scripts Core Utilities
# Centralized utility functions for all Magic Scripts components

# Color codes (if not already defined)
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[1;33m}"
CYAN="${CYAN:-\033[0;36m}"
BLUE="${BLUE:-\033[0;34m}"
NC="${NC:-\033[0m}"

#
# Display error message with optional hint
#
# Usage: utils_error <message> [hint] [exit_code]
# Returns: 1 if exit_code=0, otherwise exits
#
utils_error() {
    local message="$1"
    local suggestion="$2"
    local exit_code="${3:-1}"

    echo "${RED}Error: $message${NC}" >&2

    if [ -n "$suggestion" ]; then
        echo "  ${CYAN}Hint: $suggestion${NC}" >&2
    fi

    # exit_code=0이면 반환만, 아니면 exit
    if [ "$exit_code" -ne 0 ]; then
        exit "$exit_code"
    fi

    return 1
}

#
# Download file with security validation
#
# Usage: download_file <url> <output_path>
# Returns: 0 on success, 1 on failure
#
download_file() {
    local url="$1"
    local output="$2"

    # Basic URL validation for security
    if ! echo "$url" | grep -q "^https\?://[a-zA-Z0-9.-]\+\.[a-zA-Z]\{2,\}"; then
        echo "${RED}Error: Invalid URL format for download: $url${NC}" >&2
        return 1
    fi

    # Security check: prevent access to localhost/internal IPs
    if echo "$url" | grep -q -E "(localhost|127\.0\.0\.1|0\.0\.0\.0|::1|192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)" ; then
        echo "${RED}Error: Downloads from local/internal addresses are not allowed for security${NC}" >&2
        return 1
    fi

    # Try curl first, then wget
    if check_command curl; then
        if ! curl -fsSL "$url" -o "$output" 2>/dev/null; then
            return 1
        fi
    elif check_command wget; then
        if ! wget -q "$url" -O "$output" 2>/dev/null; then
            return 1
        fi
    else
        echo "${RED}Error: curl or wget is required for downloading${NC}" >&2
        return 1
    fi

    return 0
}

#
# Check if command exists
#
# Usage: check_command <command_name>
# Returns: 0 if exists, 1 otherwise
#
check_command() {
    command -v "$1" >/dev/null 2>&1
}

#
# Create temporary file safely
#
# Usage: create_temp_file [prefix]
# Output: temp file path
# Returns: 0 on success, 1 on failure
#
create_temp_file() {
    local prefix="${1:-ms}"
    local temp_file

    # Cross-platform compatibility: GNU mktemp (Linux) vs BSD mktemp (macOS, FreeBSD)
    if [ "$(uname)" = "Darwin" ] || [ "$(uname)" = "FreeBSD" ]; then
        # BSD mktemp: -t option auto-generates suffix
        temp_file=$(mktemp -t "${prefix}") || {
            echo "${RED}Error: Cannot create temporary file${NC}" >&2
            return 1
        }
    else
        # GNU mktemp: -t option requires full template
        temp_file=$(mktemp -t "${prefix}.XXXXXX") || {
            echo "${RED}Error: Cannot create temporary file${NC}" >&2
            return 1
        }
    fi

    echo "$temp_file"
    return 0
}

#
# Cleanup temporary file
#
# Usage: cleanup_temp_file <file_path>
#
cleanup_temp_file() {
    local temp_file="$1"
    [ -n "$temp_file" ] && rm -f "$temp_file"
}

#
# Safe directory creation
#
# Usage: safe_mkdir <dir_path>
# Returns: 0 on success, 1 on failure
#
safe_mkdir() {
    local dir_path="$1"

    if [ -z "$dir_path" ]; then
        echo "${RED}Error: Directory path is required${NC}" >&2
        return 1
    fi

    if ! mkdir -p "$dir_path" 2>/dev/null; then
        echo "${RED}Error: Cannot create directory: $dir_path${NC}" >&2
        return 1
    fi

    return 0
}

#
# Validate string is alphanumeric with limited special chars
#
# Usage: validate_name <string> [allowed_chars]
# Returns: 0 if valid, 1 otherwise
#
validate_name() {
    local name="$1"
    local allowed="${2:-a-zA-Z0-9_-}"

    if [ -z "$name" ]; then
        return 1
    fi

    if ! echo "$name" | grep -qE "^[$allowed]+$"; then
        return 1
    fi

    return 0
}
