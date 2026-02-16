#!/bin/sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="$HOME/.local/bin/ms"
MAGIC_DIR="$HOME/.local/share/magicscripts"

# URLs
RAW_URL="https://raw.githubusercontent.com/magic-scripts/ms/main"

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

    if check_command curl; then
        curl -fsSL "$url" -o "$output"
    elif check_command wget; then
        wget -q "$url" -O "$output"
    else
        echo "${RED}Error: curl or wget is required${NC}"
        exit 1
    fi
}

echo "========================================="
echo "      Magic Scripts Self-Updater       "
echo "========================================="
echo ""

# Check if Magic Scripts is installed
if [ ! -f "$INSTALL_DIR/ms" ] || [ ! -d "$MAGIC_DIR" ]; then
    echo "${RED}Error: Magic Scripts doesn't appear to be installed.${NC}"
    echo ""
    echo "Please run the setup script first:"
    echo "  ${CYAN}curl -fsSL https://raw.githubusercontent.com/magic-scripts/ms/main/setup.sh | sh${NC}"
    exit 1
fi

echo "${YELLOW}Updating Magic Scripts core system...${NC}"
echo ""

# Update core files
printf "  Downloading config.sh... "
if download_file "$RAW_URL/core/config.sh" "$MAGIC_DIR/core/config.sh"; then
    printf "${GREEN}done${NC}\n"
else
    printf "${RED}failed${NC}\n"
    exit 1
fi

printf "  Downloading registry.sh... "
if download_file "$RAW_URL/core/registry.sh" "$MAGIC_DIR/core/registry.sh"; then
    printf "${GREEN}done${NC}\n"
else
    printf "${RED}failed${NC}\n"
    exit 1
fi

printf "  Downloading ms.sh... "
if download_file "$RAW_URL/scripts/ms.sh" "$MAGIC_DIR/scripts/ms.sh"; then
    chmod +x "$MAGIC_DIR/scripts/ms.sh"
    printf "${GREEN}done${NC}\n"
else
    printf "${RED}failed${NC}\n"
    exit 1
fi

# Update registries
echo ""
echo "Updating registries..."
printf "  Updating ms registry... "
if "$INSTALL_DIR/ms" upgrade >/dev/null 2>&1; then
    printf "${GREEN}done${NC}\n"
else
    printf "${YELLOW}warning${NC}\n"
    echo "  ${YELLOW}Warning: Registry update failed, but core update succeeded${NC}"
fi

echo ""
echo "========================================="
echo "${GREEN}✅ Magic Scripts successfully updated!${NC}"
echo "========================================="
echo ""

echo "${CYAN}What was updated:${NC}"
echo "  - Core system files (config.sh, registry.sh, ms.sh)"
echo "  - Registry data"
echo ""

echo "${CYAN}Next steps:${NC}"
echo "  ${CYAN}ms status${NC}                    # Check system status"
echo "  ${CYAN}ms update <command>${NC}          # Update individual commands"
echo "  ${CYAN}ms search${NC}                    # Browse available commands"
echo ""

echo "Update completed successfully!"