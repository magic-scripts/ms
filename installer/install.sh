#!/bin/sh

# Magic Scripts Component Installer
# This script is used by other Magic Scripts commands to install themselves
# NOT for initial ms setup (use setup.sh instead)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Environment variables that should be set by the calling ms command:
# - INSTALL_DIR: Where to install command wrappers
# - MAGIC_DIR: Magic Scripts data directory  
# - COMMAND_NAME: Name of the command being installed
# - COMMAND_VERSION: Version to install
# - COMMAND_URL: Download URL for the script
# - COMMAND_CHECKSUM: Expected checksum
# - COMMAND_DESCRIPTION: Command description
# - TEMP_DIR: Temporary directory for downloads

check_command() {
    command -v "$1" >/dev/null 2>&1
}

download_file() {
    local url="$1"
    local output="$2"

    # Basic URL validation for security
    if ! echo "$url" | grep -q "^https\?://[a-zA-Z0-9.-]\+\.[a-zA-Z]\{2,\}"; then
        echo "Error: Invalid URL format for download: $url" >&2
        return 1
    fi

    # Security check: prevent access to localhost/internal IPs
    if echo "$url" | grep -q -E "(localhost|127\.0\.0\.1|0\.0\.0\.0|::1|192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)" ; then
        echo "Error: Downloads from local/internal addresses are not allowed for security" >&2
        return 1
    fi

    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$output")"

    if check_command curl; then
        curl -fsSL "$url" > "$output"
    elif check_command wget; then
        wget -q "$url" -O "$output"
    else
        echo "${RED}Error: curl or wget is required${NC}"
        return 1
    fi
}

# Validate required environment variables
if [ -z "$INSTALL_DIR" ] || [ -z "$MAGIC_DIR" ] || [ -z "$COMMAND_NAME" ] || [ -z "$COMMAND_URL" ]; then
    echo "${RED}Error: Required environment variables not set${NC}"
    echo "This script should be called by Magic Scripts commands, not directly."
    exit 1
fi

echo "Installing $COMMAND_NAME..."

# Create directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$MAGIC_DIR/scripts" 
mkdir -p "$MAGIC_DIR/installed"

# Download the script
script_path="$MAGIC_DIR/scripts/$COMMAND_NAME.sh"
printf "  Downloading $COMMAND_NAME.sh... "
if download_file "$COMMAND_URL" "$script_path"; then
    chmod 755 "$script_path"
    printf "${GREEN}done${NC}\n"
    
    # Verify checksum if provided
    if [ -n "$COMMAND_CHECKSUM" ] && [ "$COMMAND_CHECKSUM" != "dev" ]; then
        echo "    Verifying checksum..."
        actual_checksum=$(shasum -a 256 "$script_path" 2>/dev/null | cut -d' ' -f1 | cut -c1-8 || echo "unknown")
        if [ "$actual_checksum" != "$COMMAND_CHECKSUM" ]; then
            echo "${YELLOW}    Warning: Checksum mismatch (expected: $COMMAND_CHECKSUM, got: $actual_checksum)${NC}"
        else
            echo "${GREEN}    ✓ Checksum verified${NC}"
        fi
    fi
else
    printf "${RED}failed${NC}\n"
    echo "${RED}Error: Failed to download $COMMAND_NAME from $COMMAND_URL${NC}"
    exit 1
fi

# Create wrapper script
wrapper_path="$INSTALL_DIR/$COMMAND_NAME"
printf "  Creating wrapper script... "
cat > "$wrapper_path" << EOF
#!/bin/sh
MAGIC_SCRIPT_DIR="$MAGIC_DIR"
exec "\$MAGIC_SCRIPT_DIR/scripts/$COMMAND_NAME.sh" "\$@"
EOF
chmod 755 "$wrapper_path"
printf "${GREEN}done${NC}\n"

# Create metadata file
metadata_path="$MAGIC_DIR/installed/$COMMAND_NAME.msmeta"
printf "  Creating metadata... "
cat > "$metadata_path" << EOF
command=$COMMAND_NAME
version=${COMMAND_VERSION:-unknown}
registry_name=${COMMAND_REGISTRY:-unknown}
registry_url=${COMMAND_REGISTRY_URL:-unknown}
checksum=${COMMAND_CHECKSUM:-unknown}
installed_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
script_path=$script_path
description=${COMMAND_DESCRIPTION:-Magic Scripts command}
EOF
printf "${GREEN}done${NC}\n"

echo "${GREEN}✓ $COMMAND_NAME installed successfully${NC}"