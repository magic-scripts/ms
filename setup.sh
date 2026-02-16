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
TEMP_DIR="$HOME/.cache/magicscripts-$$"

# Configurable branch/URL for development testing
# Usage: MS_INSTALL_BRANCH=develop sh setup.sh
BRANCH="${MS_INSTALL_BRANCH:-main}"
RAW_URL="https://raw.githubusercontent.com/magic-scripts/ms/${BRANCH}"

# URLs
REPO_URL="https://github.com/magic-scripts/ms"
REGISTRY_URL="$RAW_URL/registry/ms.msreg"

# Version parameters
REQUESTED_VERSION=""

check_command() {
    command -v "$1" >/dev/null 2>&1
}

cleanup() {
    rm -rf "$TEMP_DIR" 2>/dev/null || true
}

trap cleanup EXIT INT TERM

verify_url() {
    local url="$1"
    
    if check_command curl; then
        curl -fsSI "$url" > /dev/null 2>/dev/null
    elif check_command wget; then
        wget -q --spider "$url" 2>/dev/null
    else
        return 1
    fi
}

download_file() {
    local url="$1"
    local output="$2"
    
    # URL security validation
    case "$url" in
        https://*) ;; # HTTPS OK
        *) echo "${RED}Error: Only HTTPS URLs are allowed${NC}"; return 1 ;;
    esac
    local domain=$(echo "$url" | sed 's|https://||' | cut -d'/' -f1 | cut -d':' -f1)
    case "$domain" in
        localhost|127.0.0.1|0.0.0.0|::1) echo "${RED}Error: Internal URLs are not allowed${NC}"; return 1 ;;
    esac
    case "$domain" in
        10.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*|192.168.*) echo "${RED}Error: Private network URLs are not allowed${NC}"; return 1 ;;
    esac

    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$output")"
    
    if check_command curl; then
        # Use output redirection to avoid curl write issues
        curl -fsSL "$url" > "$output"
    elif check_command wget; then
        wget -q "$url" -O "$output"
    else
        echo "${RED}Error: curl or wget is required${NC}"
        exit 1
    fi
}

# Semantic version comparison (returns 0 if v1 > v2, 1 if v1 < v2, 2 if v1 == v2)
compare_versions() {
    local v1="$1"
    local v2="$2"
    
    # Handle dev versions
    if [ "$v1" = "dev" ] && [ "$v2" != "dev" ]; then
        return 1  # dev is lower than release versions
    elif [ "$v1" != "dev" ] && [ "$v2" = "dev" ]; then
        return 0  # release is higher than dev
    elif [ "$v1" = "dev" ] && [ "$v2" = "dev" ]; then
        return 2  # equal
    fi
    
    # Parse semantic versions
    local v1_major=$(echo "$v1" | cut -d'.' -f1)
    local v1_minor=$(echo "$v1" | cut -d'.' -f2)
    local v1_patch=$(echo "$v1" | cut -d'.' -f3)
    
    local v2_major=$(echo "$v2" | cut -d'.' -f1)
    local v2_minor=$(echo "$v2" | cut -d'.' -f2)
    local v2_patch=$(echo "$v2" | cut -d'.' -f3)
    
    # Compare major
    if [ "$v1_major" -gt "$v2_major" ]; then return 0; fi
    if [ "$v1_major" -lt "$v2_major" ]; then return 1; fi
    
    # Compare minor
    if [ "$v1_minor" -gt "$v2_minor" ]; then return 0; fi
    if [ "$v1_minor" -lt "$v2_minor" ]; then return 1; fi
    
    # Compare patch
    if [ "$v1_patch" -gt "$v2_patch" ]; then return 0; fi
    if [ "$v1_patch" -lt "$v2_patch" ]; then return 1; fi
    
    return 2  # equal
}

# Find best version from registry
find_best_ms_version() {
    local temp_registry="$TEMP_DIR/ms.msreg"
    local best_version=""
    local best_url=""
    local best_checksum=""
    local best_install_script=""
    local best_uninstall_script=""
    local dev_version=""
    local dev_url=""
    local dev_checksum=""
    local dev_install_script=""
    local dev_uninstall_script=""
    
    # Download registry
    if ! download_file "$REGISTRY_URL" "$temp_registry"; then
        echo "${RED}Error: Cannot download registry from $REGISTRY_URL${NC}"
        exit 1
    fi
    
    # Parse registry for ms command - 3-tier system (msreg -> mspack -> msver)
    # Format: name|mspack_url|description|category
    while IFS='|' read -r name package_url desc category; do
        [ "$name" = "ms" ] || continue

        # Download package file (could be .mspack or legacy .msver)
        local temp_package="$TEMP_DIR/ms_package_$$.txt"
        if ! download_file "$package_url" "$temp_package"; then
            echo "${RED}Error: Cannot download package file from $package_url${NC}"
            exit 1
        fi

        # Detect 3-tier: check for msver_url| line in downloaded file
        local actual_msver_url=""
        actual_msver_url=$(grep "^msver_url|" "$temp_package" 2>/dev/null | head -1 | cut -d'|' -f2)

        local temp_msver="$TEMP_DIR/ms_msver_$$.txt"
        if [ -n "$actual_msver_url" ]; then
            # 3-tier: download actual .msver from mspack's msver_url pointer
            if ! download_file "$actual_msver_url" "$temp_msver"; then
                echo "${RED}Error: Cannot download ms.msver from $actual_msver_url${NC}"
                exit 1
            fi
        else
            # Legacy 2-tier: package_url pointed directly to .msver
            cp "$temp_package" "$temp_msver"
        fi
        rm -f "$temp_package"
        
        # Parse version information from .msver file
        while IFS='|' read -r entry_type version url checksum install_script uninstall_script _update_script _man_url; do
            [ "$entry_type" = "version" ] || continue
            
            # If specific version requested, match exactly
            if [ -n "$REQUESTED_VERSION" ]; then
                if [ "$version" = "$REQUESTED_VERSION" ]; then
                    echo "$version|$url|$checksum|$install_script|$uninstall_script"
                    rm -f "$temp_msver"
                    return 0
                fi
                continue
            fi
            
            # Store dev version separately
            if [ "$version" = "dev" ]; then
                dev_version="$version"
                dev_url="$url"
                dev_checksum="$checksum"
                dev_install_script="$install_script"
                dev_uninstall_script="$uninstall_script"
                # Skip dev versions unless explicitly allowed
            fi
            
            # Find highest version (skip dev in version comparison)
            if [ "$version" != "dev" ]; then
                if [ -z "$best_version" ]; then
                    best_version="$version"
                    best_url="$url" 
                    best_checksum="$checksum"
                    best_install_script="$install_script"
                    best_uninstall_script="$uninstall_script"
                else
                    if compare_versions "$version" "$best_version"; then
                        best_version="$version"
                        best_url="$url"
                        best_checksum="$checksum"
                        best_install_script="$install_script"
                        best_uninstall_script="$uninstall_script"
                    fi
                fi
            else
                # Dev version - can be used if requested or as fallback
                if [ -z "$best_version" ]; then
                    best_version="$version"
                    best_url="$url" 
                    best_checksum="$checksum"
                    best_install_script="$install_script"
                    best_uninstall_script="$uninstall_script"
                fi
            fi
        done < "$temp_msver"
        
        rm -f "$temp_msver"
        break  # We found ms command, no need to continue
    done < "$temp_registry"
    
    # If no suitable version found but dev version exists, use dev
    if [ -z "$best_version" ] && [ -n "$dev_version" ]; then
        echo "$dev_version|$dev_url|$dev_checksum|$dev_install_script|$dev_uninstall_script"
        return 0
    fi
    
    if [ -z "$best_version" ]; then
        if [ -n "$REQUESTED_VERSION" ]; then
            echo "${RED}Error: Version $REQUESTED_VERSION not found${NC}"
        else
            echo "${RED}Error: No suitable version found${NC}"
        fi
        exit 1
    fi
    
    echo "$best_version|$best_url|$best_checksum|$best_install_script|$best_uninstall_script"
}

update_shell_config() {
    local shell_config="$1"
    local path_line='export PATH="$HOME/.local/bin/ms:$PATH"'
    local manpath_line='export MANPATH="$HOME/.local/share/man:$MANPATH"'
    
    # Check if already exists with proper installer comment
    if grep -q "# Magic Scripts - added by installer" "$shell_config" 2>/dev/null && \
       grep -q "export PATH.*\.local/bin/ms" "$shell_config" 2>/dev/null; then
        echo "${GREEN}PATH configuration already exists in $shell_config${NC}"
        
        # Check if MANPATH needs to be added
        if ! grep -q "export MANPATH.*\.local/share/man" "$shell_config" 2>/dev/null; then
            echo "$manpath_line" >> "$shell_config"
            echo "${GREEN}Added MANPATH configuration to $shell_config${NC}"
            return 0
        fi
        return 1
    fi
    
    # If PATH exists but without proper installer comment, remove it first
    if grep -q "export PATH.*\.local/bin/ms" "$shell_config" 2>/dev/null; then
        echo "${YELLOW}Found existing PATH configuration without installer comment, updating...${NC}"
        # Remove existing line
        grep -v "export PATH.*\.local/bin/ms" "$shell_config" > "$shell_config.tmp"
        mv "$shell_config.tmp" "$shell_config"
    fi
    
    # Add configuration
    echo "" >> "$shell_config"
    echo "# Magic Scripts - added by installer" >> "$shell_config"
    echo "$path_line" >> "$shell_config"
    echo "$manpath_line" >> "$shell_config"
    echo "${GREEN}Added PATH and MANPATH configuration to $shell_config${NC}"
    return 0
}

show_help() {
    echo "Magic Scripts Installer"
    echo ""
    echo "Usage:"
    echo "  install.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -v, --version VERSION    Install specific version (e.g., 0.0.1, 0.0.2, dev)"
 
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  install.sh                     # Install latest stable version"
    echo "  install.sh -v 0.0.1           # Install specific version"
    echo "  install.sh -v dev             # Install dev version"
    echo ""
}

# Parse command line arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -v|--version)
            if [ -z "$2" ]; then
                echo "${RED}Error: -v requires a version argument${NC}"
                echo "Usage: setup.sh -v <version>"
                exit 1
            fi
            REQUESTED_VERSION="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

echo "========================================="
echo "        Magic Scripts Setup v0.0.1      "
echo "       Developer Automation Tools       "
echo "========================================="
echo ""

# Verify registry is accessible
echo "Verifying registry access..."
if ! verify_url "$REGISTRY_URL"; then
    echo "${RED}Error: Cannot access Magic Scripts registry${NC}"
    echo ""
    echo "Please check:"
    echo "  1. Repository exists at: $REPO_URL"
    echo "  2. Registry file is available at: $REGISTRY_URL"
    echo "  3. Repository is public or you have access"
    echo ""
    exit 1
fi
echo "${GREEN}✓ Registry accessible${NC}"

# Find best version to install
echo ""
echo "Determining version to install..."
if [ -n "$REQUESTED_VERSION" ]; then
    echo "Requested version: $REQUESTED_VERSION"
else
    echo "Finding latest stable version..."
fi

version_info=$(find_best_ms_version)
MS_VERSION=$(echo "$version_info" | cut -d'|' -f1)
MS_URL=$(echo "$version_info" | cut -d'|' -f2)
MS_CHECKSUM=$(echo "$version_info" | cut -d'|' -f3)
MS_INSTALL_SCRIPT=$(echo "$version_info" | cut -d'|' -f4)
MS_UNINSTALL_SCRIPT=$(echo "$version_info" | cut -d'|' -f5)

echo "${GREEN}Selected version: $MS_VERSION${NC}"
echo ""

# Check for existing installation
if [ -f "$HOME/.local/bin/ms/ms" ]; then
    echo "${YELLOW}Existing Magic Scripts installation detected.${NC}"
    echo "This will update the existing installation."
    echo ""
fi

echo "Creating installation directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$MAGIC_DIR"
mkdir -p "$TEMP_DIR"

# Direct installation for ms bootstrap (setup script)
echo "Installing Magic Scripts core system..."
    mkdir -p "$MAGIC_DIR/core"
    mkdir -p "$MAGIC_DIR/scripts"
    
    # Download core files (version-independent)
    printf "  Downloading config.sh... "
    if download_file "$RAW_URL/core/config.sh" "$MAGIC_DIR/core/config.sh"; then
        printf "${GREEN}done${NC}\n"
    else
        printf "${RED}failed${NC}\n"
        echo ""
        echo "${RED}Error: Failed to download core configuration file${NC}"
        exit 1
    fi
    
    printf "  Downloading registry.sh... "
    if download_file "$RAW_URL/core/registry.sh" "$MAGIC_DIR/core/registry.sh"; then
        printf "${GREEN}done${NC}\n"
    else
        printf "${RED}failed${NC}\n"
        exit 1
    fi
    
    # Registry system will be initialized automatically by ms.sh
    # No need to download registry files during installation
    
    if [ "$MS_VERSION" = "dev" ]; then
        printf "  Downloading ms.sh ($MS_VERSION)... "
    else
        printf "  Downloading ms.sh (v$MS_VERSION)... "
    fi
    if download_file "$MS_URL" "$MAGIC_DIR/scripts/ms.sh"; then
        chmod 755 "$MAGIC_DIR/scripts/ms.sh"
        printf "${GREEN}done${NC}\n"
        
        # Verify checksum if not dev version
        if [ "$MS_VERSION" != "dev" ] && [ "$MS_CHECKSUM" != "dev" ]; then
            echo "    Verifying checksum..."
            actual_checksum=$(shasum -a 256 "$MAGIC_DIR/scripts/ms.sh" 2>/dev/null | cut -d' ' -f1 | cut -c1-8 || echo "unknown")
            if [ "$actual_checksum" != "$MS_CHECKSUM" ]; then
                echo "${RED}    Error: Checksum mismatch (expected: $MS_CHECKSUM, got: $actual_checksum)${NC}"
                echo "${RED}    Installation aborted. The downloaded file may be corrupted or tampered.${NC}"
                rm -f "$MAGIC_DIR/scripts/ms.sh"
                exit 1
            else
                echo "${GREEN}    ✓ Checksum verified${NC}"
            fi
        fi
    else
        printf "${RED}failed${NC}\n"
        echo ""
        echo "${RED}Error: Failed to download ms.sh from $MS_URL${NC}"
        exit 1
    fi

echo ""
echo "Installing Magic Scripts commands..."

printf "  Installing ms... "
cat > "$INSTALL_DIR/ms" << EOF
#!/bin/sh
MAGIC_SCRIPT_DIR="$MAGIC_DIR"
exec "\$MAGIC_SCRIPT_DIR/scripts/ms.sh" "\$@"
EOF
chmod 755 "$INSTALL_DIR/ms"

# Create metadata directory and file for ms command
mkdir -p "$MAGIC_DIR/installed"
cat > "$MAGIC_DIR/installed/ms.msmeta" << EOF
command=ms
version=$MS_VERSION
registry_name=ms
registry_url=$REGISTRY_URL
checksum=$MS_CHECKSUM
install_script=$MS_INSTALL_SCRIPT
uninstall_script=$MS_UNINSTALL_SCRIPT
installed_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
script_path=$MAGIC_DIR/scripts/ms.sh
EOF

printf "${GREEN}done${NC}\n"

echo ""
echo "Initializing registries..."
printf "  Updating ms registry... "
if "$INSTALL_DIR/ms" upgrade >/dev/null 2>&1; then
    printf "${GREEN}done${NC}\n"
else
    printf "${YELLOW}failed${NC}\n"
    echo "  ${YELLOW}Warning: Registry initialization failed. You can run 'ms upgrade' later.${NC}"
fi

echo ""

# Update shell configuration
PATH_UPDATED=false

if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
    echo "${YELLOW}Updating shell configuration...${NC}"
    
    # Try to detect and update shell configuration files
    for config_file in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
        if [ -f "$config_file" ] || [ "$config_file" = "$HOME/.profile" ]; then
            if update_shell_config "$config_file"; then
                PATH_UPDATED=true
                SHELL_CONFIG="$config_file"
                break
            fi
        fi
    done
    
    if [ "$PATH_UPDATED" = false ]; then
        # Create .profile if no config file was found
        if update_shell_config "$HOME/.profile"; then
            PATH_UPDATED=true
            SHELL_CONFIG="$HOME/.profile"
        fi
    fi
else
    echo "${GREEN}$INSTALL_DIR is already in PATH${NC}"
fi

echo ""
echo "========================================="
if [ "$MS_VERSION" = "dev" ]; then
    echo "${GREEN}✅ Magic Scripts $MS_VERSION installed!${NC}"
else
    echo "${GREEN}✅ Magic Scripts v$MS_VERSION installed!${NC}"
fi
echo "========================================="
echo ""
echo "Installed core command:"
echo "  ${BLUE}ms${NC}           Magic Scripts main interface"
echo ""
echo "${YELLOW}Next steps:${NC}"
echo "  ${CYAN}ms config list -r${NC}      # See available configuration keys"
echo "  ${CYAN}ms search${NC}              # Browse available commands"
echo "  ${CYAN}ms install -r ms${NC}       # Install all commands from ms registry"
echo "  ${CYAN}ms help${NC}                # Show detailed help"
echo ""

if [ "$PATH_UPDATED" = true ]; then
    echo "${YELLOW}IMPORTANT: To use commands immediately, run:${NC}"
    echo "  ${CYAN}source $SHELL_CONFIG${NC}"
    echo ""
    echo "Or restart your terminal."
else
    echo "${GREEN}All commands are ready to use!${NC}"
fi

echo ""
echo "Installation directory: ${CYAN}$INSTALL_DIR${NC}"
echo "Data directory: ${CYAN}$MAGIC_DIR${NC}"
echo "Repository: ${CYAN}$REPO_URL${NC}"
