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

# Define download_file function inline (update.sh runs as standalone script)
download_file() {
    local url="$1"
    local dest="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$dest" 2>/dev/null
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$dest" 2>/dev/null
    else
        return 1
    fi
}

# Determine target branch from environment variables
# MS_TARGET_VERSION: "dev", "1.0.0", etc. (preferred)
# MS_TARGET_BRANCH: explicit branch override
if [ -n "${MS_TARGET_BRANCH:-}" ]; then
    # Explicit branch specified
    BRANCH="$MS_TARGET_BRANCH"
elif [ -n "${MS_TARGET_VERSION:-}" ]; then
    # Version specified — determine branch
    case "$MS_TARGET_VERSION" in
        dev)
            BRANCH="develop"
            ;;
        *)
            # Semver version — use release branch
            BRANCH="release/v${MS_TARGET_VERSION}"
            ;;
    esac
else
    # Default: main branch (latest stable)
    BRANCH="main"
fi

# URLs
RAW_URL="https://raw.githubusercontent.com/magic-scripts/ms/${BRANCH}"

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
mkdir -p "$MAGIC_DIR/core"
for f in utils.sh config.sh registry.sh metadata.sh version.sh pack.sh; do
    printf "  Downloading $f... "
    if download_file "$RAW_URL/core/$f" "$MAGIC_DIR/core/$f"; then
        printf "${GREEN}done${NC}\n"
    else
        printf "${RED}failed${NC}\n"
        exit 1
    fi
done

# Update lib files
mkdir -p "$MAGIC_DIR/lib"
for f in install.sh uninstall.sh update.sh query.sh maintenance.sh; do
    printf "  Downloading $f... "
    if download_file "$RAW_URL/lib/$f" "$MAGIC_DIR/lib/$f"; then
        printf "${GREEN}done${NC}\n"
    else
        printf "${RED}failed${NC}\n"
        exit 1
    fi
done

# Update main script
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
echo "  - Core libraries: config.sh, registry.sh, metadata.sh, version.sh, pack.sh"
echo "  - Lib modules: install.sh, uninstall.sh, update.sh, query.sh, maintenance.sh"
echo "  - Main script: ms.sh"
echo "  - Registry data"
echo ""

echo "${CYAN}Next steps:${NC}"
echo "  ${CYAN}ms status${NC}                    # Check system status"
echo "  ${CYAN}ms update <command>${NC}          # Update individual commands"
echo "  ${CYAN}ms search${NC}                    # Browse available commands"
echo ""

echo "Update completed successfully!"