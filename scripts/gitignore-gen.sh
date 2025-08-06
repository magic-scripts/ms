#!/bin/sh

# Set script identity for config system security
export MS_SCRIPT_ID="gigen"

VERSION="0.0.1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Try to load config system
if [ -f "$SCRIPT_DIR/../core/config.sh" ]; then
    . "$SCRIPT_DIR/../core/config.sh"
elif [ -f "$HOME/.local/share/magicscripts/core/config.sh" ]; then
    . "$HOME/.local/share/magicscripts/core/config.sh"
fi

# Get author information using config system or fallbacks
get_author_info() {
    local author_name=""
    local author_email=""
    
    # Try to get from config system
    if command -v get_config_value >/dev/null 2>&1; then
        # Get author name with fallback
        author_name=$(get_config_value "AUTHOR_NAME" "$(git config user.name 2>/dev/null || whoami)" 2>/dev/null)
        author_email=$(get_config_value "AUTHOR_EMAIL" "$(git config user.email 2>/dev/null)" 2>/dev/null)
    else
        # Fallback to git config or system defaults
        author_name="$(git config user.name 2>/dev/null || whoami)"
        author_email="$(git config user.email 2>/dev/null || echo '')"
    fi
    
    # Export for use in subshell
    export GIGEN_AUTHOR_NAME="$author_name"
    export GIGEN_AUTHOR_EMAIL="$author_email"
}

usage() {
    echo "Usage: gigen <command> [options] [templates...]"
    echo ""
    echo "Commands:"
    echo "  init               Initialize .gitignore with development essentials"
    echo "  add <template>     Add template to existing .gitignore"
    echo "  remove <template>  Remove template from .gitignore"
    echo "  update             Update all existing templates to latest version"
    echo "  allow <pattern>    Add pattern to whitelist (exclude from templates)"
    echo "  disallow <pattern> Remove pattern from whitelist"
    echo "  status             Show current templates, custom patterns, and whitelist"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help"
    echo ""
    echo "Templates:"
    echo "  node (nodejs), python (py), go (golang), rust, java, cpp (c++), macos (osx),"
    echo "  linux, windows (win), vscode, idea (intellij), ai, ms (magicscript)"
    echo ""
    echo "Configuration Keys Used:"
    echo "  AUTHOR_NAME        Author name for .gitignore header"  
    echo "  AUTHOR_EMAIL       Author email for .gitignore header"
    echo "  DEFAULT_GIT_BRANCH Default branch name"
    echo ""
    echo "  Set with: ms config set <key> <value>"
    echo ""
    echo "Examples:"
    echo "  gigen init                     # Initialize with dev essentials"
    echo "  gigen add node                 # Add Node.js template"
    echo "  gigen add python go            # Add multiple templates"
    echo "  gigen remove node              # Remove Node.js template"
    echo "  gigen update                   # Update all existing templates"
    echo "  gigen allow '*.log'            # Exclude *.log from all templates"
    echo "  gigen disallow '*.log'         # Stop excluding *.log"
    echo "  gigen status                   # Show current configuration"
}

# Global variables
OUTPUT_FILE=".gitignore"
FIRST_TEMPLATE=true
COMMAND=""
TEMPLATES=""

# Cache directory for template management
CACHE_DIR=".ms-cache"
TEMPLATE_LIST_FILE="$CACHE_DIR/gigen-templates"
PATTERNS_BACKUP_FILE="$CACHE_DIR/gigen-patterns"

# Whitelist file for patterns to allow (exclude from templates)
WHITELIST_FILE=".gigenwhitelist"

# Function to initialize cache directory
init_cache() {
    mkdir -p "$CACHE_DIR"
}

# Function to check if gigen is initialized
is_gigen_initialized() {
    [ -f .gitignore ] && grep -q "^# === [^=]* ===$" .gitignore
}

# Function to initialize whitelist file if it doesn't exist
ensure_whitelist_file() {
    if [ ! -f "$WHITELIST_FILE" ]; then
        echo "# Whitelisted patterns - these will be excluded from .gitignore" > "$WHITELIST_FILE"
        echo "# These patterns will be removed even if they appear in templates" >> "$WHITELIST_FILE"
        echo "" >> "$WHITELIST_FILE"
        echo "Created $WHITELIST_FILE"
    fi
}

# Function to show initialization warning
show_init_warning() {
    echo "Error: GitIgnore generator is not initialized."
    echo "Run 'gigen init' first to initialize .gitignore with development essentials."
    exit 1
}

# Function to load patterns from whitelist
load_whitelisted_patterns() {
    if [ -f "$WHITELIST_FILE" ]; then
        cat "$WHITELIST_FILE"
    fi
}

# Function to add pattern to whitelist
add_whitelisted_pattern() {
    local pattern="$1"
    
    # Create file if it doesn't exist
    if [ ! -f "$WHITELIST_FILE" ]; then
        echo "# Whitelisted patterns - these will be excluded from .gitignore" > "$WHITELIST_FILE"
        echo "# These patterns will be removed even if they appear in templates" >> "$WHITELIST_FILE"
        echo "" >> "$WHITELIST_FILE"
    fi
    
    # Check if pattern already exists
    if grep -Fxq "$pattern" "$WHITELIST_FILE" 2>/dev/null; then
        echo "Pattern '$pattern' is already whitelisted"
        return 0
    fi
    
    # Add pattern
    echo "$pattern" >> "$WHITELIST_FILE"
    echo "Added '$pattern' to whitelist"
}

# Function to remove pattern from whitelist
remove_whitelisted_pattern() {
    local pattern="$1"
    
    if [ ! -f "$WHITELIST_FILE" ]; then
        echo "No whitelist file found"
        return 1
    fi
    
    # Remove pattern using grep -v
    local tmpfile=$(mktemp)
    grep -Fxv "$pattern" "$WHITELIST_FILE" > "$tmpfile" || true
    
    if [ "$(wc -l < "$tmpfile")" = "$(wc -l < "$WHITELIST_FILE")" ]; then
        echo "Pattern '$pattern' not found in whitelist"
        rm -f "$tmpfile"
        return 1
    fi
    
    mv "$tmpfile" "$WHITELIST_FILE"
    echo "Removed '$pattern' from whitelist"
}

# Function to show current configuration status
show_status() {
    echo "=== GitIgnore Generator Status ==="
    echo ""
    
    # Show active templates
    echo "📄 Active Templates:"
    if [ -f .gitignore ]; then
        local templates=$(grep "^# === [^=]* ===$" .gitignore | sed 's/^# === \(.*\) ===$/\1/' | grep -v "(custom)" | grep -v "^custom$")
        if [ -n "$templates" ]; then
            echo "$templates" | while read -r template; do
                echo "  ✓ $template"
            done
        else
            echo "  (none)"
        fi
    else
        echo "  (no .gitignore found)"
    fi
    
    echo ""
    
    # Show whitelisted patterns
    echo "⚪ Whitelisted Patterns (excluded from templates):"
    if [ -f "$WHITELIST_FILE" ]; then
        local patterns=$(grep -v "^#" "$WHITELIST_FILE" | grep -v "^$")
        if [ -n "$patterns" ]; then
            echo "$patterns" | while read -r pattern; do
                echo "  🔸 $pattern"
            done
        else
            echo "  (none)"
        fi
    else
        echo "  (none)"
    fi
    
    echo ""
    
    # Show custom patterns count
    echo "🎨 Custom Patterns:"
    if [ -f .gitignore ] && grep -q "^# === custom ===$" .gitignore; then
        local custom_count=$(awk '
            BEGIN { in_custom = 0; count = 0 }
            /^# === custom ===$/ { in_custom = 1; next }
            /^# === [^=]+ ===$/ && in_custom { in_custom = 0 }
            in_custom && !/^#/ && !/^$/ { count++ }
            END { print count }
        ' .gitignore)
        echo "  📝 $custom_count custom patterns in .gitignore"
    else
        echo "  (no custom section found)"
    fi
    
    echo ""
    
    # Show cache status
    echo "💾 Cache Status:"
    if [ -d "$CACHE_DIR" ]; then
        echo "  📁 Cache directory: $CACHE_DIR"
        [ -f "$TEMPLATE_LIST_FILE" ] && echo "  📋 Templates cached: $(cat "$TEMPLATE_LIST_FILE" | wc -l | tr -d ' ') entries"
        [ -f "$PATTERNS_BACKUP_FILE" ] && echo "  🔄 Patterns backup: $(cat "$PATTERNS_BACKUP_FILE" | wc -l | tr -d ' ') lines"
    else
        echo "  (no cache directory)"
    fi
}

# Function to apply whitelisted patterns to .gitignore
apply_whitelisted_patterns() {
    if [ ! -f "$WHITELIST_FILE" ] || [ ! -f "$OUTPUT_FILE" ]; then
        return 0
    fi
    
    local tmpfile=$(mktemp)
    cp "$OUTPUT_FILE" "$tmpfile"
    
    # Read each pattern from whitelist and remove it from .gitignore
    local removed_count=0
    while IFS= read -r pattern; do
        # Skip comments and empty lines
        if [ -z "$pattern" ] || [ "${pattern#\#}" != "$pattern" ]; then
            continue
        fi
        
        # Escape special characters for sed
        local escaped_pattern=$(printf '%s\n' "$pattern" | sed 's/[[\.*^$()+?{|]/\\&/g')
        
        # Remove the pattern (exact line match)
        if grep -Fxq "$pattern" "$tmpfile"; then
            grep -Fxv "$pattern" "$tmpfile" > "${tmpfile}.tmp" && mv "${tmpfile}.tmp" "$tmpfile"
            removed_count=$((removed_count + 1))
        fi
    done < "$WHITELIST_FILE"
    
    if [ $removed_count -gt 0 ]; then
        mv "$tmpfile" "$OUTPUT_FILE"
        echo "Removed $removed_count whitelisted patterns from .gitignore"
    else
        rm -f "$tmpfile"
    fi
}

# Function to backup existing templates and patterns
backup_existing_content() {
    if [ ! -f .gitignore ]; then
        return
    fi
    
    # Initialize cache directory first
    init_cache
    
    echo "Backing up existing content..."
    
    # Step 1: Extract template headers (remove duplicates)
    grep "^# === [^=]* ===$" .gitignore | sed 's/^# === \(.*\) ===$/\1/' | grep -v "(custom)" | grep -v "^custom$" | sort -u > "$TEMPLATE_LIST_FILE"
    
    # Step 2: Extract all patterns (excluding comments and empty lines, remove duplicates)
    awk '
        !/^#/ && !/^$/ && NF > 0 {
            print $0
        }
    ' .gitignore | sort -u > "$PATTERNS_BACKUP_FILE"
    
    echo "Backup completed:"
    echo "  Templates: $([ -f "$TEMPLATE_LIST_FILE" ] && cat "$TEMPLATE_LIST_FILE" | tr '\n' ' ' || echo 'none')"
    echo "  Patterns: $([ -f "$PATTERNS_BACKUP_FILE" ] && wc -l < "$PATTERNS_BACKUP_FILE" || echo 0) lines"
}

# Function to load template list from cache
load_template_list() {
    if [ -f "$TEMPLATE_LIST_FILE" ]; then
        cat "$TEMPLATE_LIST_FILE"
    fi
}

# Function to load patterns from cache
load_patterns() {
    if [ -f "$PATTERNS_BACKUP_FILE" ]; then
        cat "$PATTERNS_BACKUP_FILE"
    fi
}

# Function to extract all custom patterns from current .gitignore
extract_all_custom_patterns() {
    if [ ! -f .gitignore ]; then
        return
    fi
    
    # Extract patterns that are not part of standard templates
    local all_templates=$(load_template_list)
    local custom_patterns=""
    
    # Get all standard patterns
    local all_standard_patterns=$(mktemp)
    for template in $all_templates; do
        generate_standard_template "$template" >> "$all_standard_patterns"
    done
    
    # Extract custom patterns (lines not in standard templates)
    awk -v standard_file="$all_standard_patterns" '
        BEGIN { 
            # Load standard patterns into array
            while ((getline line < standard_file) > 0) {
                if (line !~ /^#/ && length(line) > 0) {
                    standard_patterns[line] = 1
                }
            }
            close(standard_file)
        }
        !/^# === / && !/^# Generated .gitignore/ && !/^# [A-Z][a-z]/ && NF > 0 {
            if (!(standard_patterns[$0])) {
                print $0
            }
        }
    ' .gitignore
    
    rm -f "$all_standard_patterns"
}

# Function to generate standard template content for comparison
generate_standard_template() {
    local template="$1"
    
    case "$template" in
        macos|osx)
            cat << 'EOF'
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
Icon
Temporary Items
.apdisk
EOF
            ;;
        linux)
            cat << 'EOF'
*~
.fuse_hidden*
.Trash-*
.nfs*
EOF
            ;;
        windows|win)
            cat << 'EOF'
Thumbs.db
Thumbs.db:encryptable
ehthumbs.db
ehthumbs_vista.db
*.stackdump
[Dd]esktop.ini
$RECYCLE.BIN/
*.cab
*.msi
*.msix
*.msm
*.msp
*.lnk
EOF
            ;;
        node|nodejs)
            cat << 'EOF'
node_modules/
jspm_packages/
dist/
build/
*.tsbuildinfo
logs/
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
lerna-debug.log*
pids/
*.pid
*.seed
*.pid.lock
coverage/
*.lcov
.nyc_output/
.env
.env.local
.env.*.local
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store
Thumbs.db
.npm/
.yarn/
.pnp.*
EOF
            ;;
        python|py)
            cat << 'EOF'
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST
venv/
ENV/
env/
.venv
.tox/
.coverage
.coverage.*
.cache
.pytest_cache/
htmlcov/
.ipynb_checkpoints
*.ipynb
.env
*.env
.vscode/
.idea/
*.swp
*.swo
.mypy_cache/
.dmypy.json
dmypy.json
*.db
*.sqlite
*.sqlite3
EOF
            ;;
        go|golang)
            cat << 'EOF'
*.exe
*.exe~
*.dll
*.so
*.dylib
*.test
*.out
go.work
go.work.sum
vendor/
.vscode/
.idea/
*.swp
*.swo
.DS_Store
Thumbs.db
dist/
build/
EOF
            ;;
        rust)
            cat << 'EOF'
target/
Cargo.lock
.vscode/
.idea/
*.swp
*.swo
EOF
            ;;
        java)
            cat << 'EOF'
*.class
*.jar
*.war
*.nar
*.ear
*.zip
*.tar.gz
*.rar
target/
pom.xml.tag
pom.xml.releaseBackup
pom.xml.versionsBackup
pom.xml.next
release.properties
dependency-reduced-pom.xml
buildNumber.properties
.mvn/timing.properties
.mvn/wrapper/maven-wrapper.jar
.gradle
build/
!gradle/wrapper/gradle-wrapper.jar
!**/src/main/**/build/
!**/src/test/**/build/
.vscode/
.idea/
*.iws
*.iml
*.ipr
out/
*.swp
*.swo
.DS_Store
Thumbs.db
EOF
            ;;
        cpp|c++)
            cat << 'EOF'
*.o
*.ko
*.obj
*.elf
*.ilk
*.map
*.exp
*.exe
*.out
*.app
*.i*86
*.x86_64
*.hex
*.lib
*.a
*.la
*.lo
*.dll
*.so
*.dylib
.vscode/
.idea/
*.swp
*.swo
.DS_Store
Thumbs.db
*.dSYM/
*.su
*.idb
*.pdb
EOF
            ;;
        vscode)
            cat << 'EOF'
.vscode/*
!.vscode/settings.json
!.vscode/tasks.json
!.vscode/launch.json
!.vscode/extensions.json
!.vscode/*.code-snippets
.history/
*.vsix
EOF
            ;;
        idea|intellij)
            cat << 'EOF'
.idea/
*.iws
*.iml
*.ipr
out/
.idea_modules/
EOF
            ;;
        ai)
            cat << 'EOF'
.cursorrules
.cursor/
cursor.json
.continue/
continue.json
.copilot/
copilot-suggestions.json
.codeium/
codeium.json
.tabnine/
tabnine.json
.openai/
openai.json
chatgpt-session.json
.claude/
claude.json
anthropic-session.json
*.ai-conversation
*.ai-session
*.ai-context
.ai-cache/
.ai-history/
.ai-temp/
.ai-generated/
ai-prompts.md
ai-context.md
temp_ai_*
.temp-ai/
ai_temp_*
EOF
            ;;
        ms|magicscript)
            cat << 'EOF'
.ms-cache/
EOF
            ;;
        *) 
            # Return empty for templates we haven't defined yet
            ;;
    esac
}

# Function to check if template exists in .gitignore
template_exists() {
    local template="$1"
    [ -f .gitignore ] && grep -q "^# === $template ===" .gitignore
}

# Function to extract custom section content
extract_custom_section() {
    awk '
        BEGIN { in_custom = 0 }
        /^# === custom ===$/ { 
            in_custom = 1 
            next 
        }
        /^# === [^=]+ ===$/ && in_custom { 
            in_custom = 0 
        }
        /^$/ && in_custom {
            # Empty line might end section, continue until next section
        }
        in_custom && !/^# Add your custom patterns below this line$/ && !/^$/ { 
            print $0 
        }
    ' "$OUTPUT_FILE"
}

# Function to check for conflicts between custom section and templates during update
check_custom_conflicts() {
    local templates="$1"
    
    if ! grep -q "^# === custom ===$" "$OUTPUT_FILE"; then
        return  # No custom section, no conflicts
    fi
    
    # Extract custom section content
    local custom_content=$(mktemp)
    extract_custom_section > "$custom_content"
    
    if [ ! -s "$custom_content" ]; then
        rm -f "$custom_content"
        return  # No custom content, no conflicts
    fi
    
    echo ""
    echo "Checking for conflicts between custom patterns and template updates..."
    
    # Collect all standard template patterns
    local all_standard_patterns=$(mktemp)
    for template in $templates; do
        generate_standard_template "$template" >> "$all_standard_patterns"
    done
    
    # Check for conflicts using simple O(n²) comparison
    local conflicts_found=false
    local conflicting_lines=""
    
    while IFS= read -r custom_line; do
        if [ -n "$custom_line" ]; then
            # Simple O(n²) check: see if this line exists in any standard template
            if grep -Fxq "$custom_line" "$all_standard_patterns"; then
                if [ "$conflicts_found" = false ]; then
                    echo ""
                    echo "Conflicts found between custom patterns and template updates:"
                    conflicts_found=true
                fi
                echo "  '$custom_line' (custom) conflicts with template"
                conflicting_lines="$conflicting_lines$custom_line"$'\n'
            fi
        fi
    done < "$custom_content"
    
    rm -f "$custom_content" "$all_standard_patterns"
    
    if [ "$conflicts_found" = true ]; then
        echo ""
        printf "Keep conflicting custom patterns? (y/N) "
        read REPLY < /dev/tty
        case "$REPLY" in
            [yY]|[yY][eE][sS]) 
                echo "Custom patterns will be preserved"
                PRESERVE_CUSTOM_CONFLICTS=true
                ;;
            *) 
                echo "Conflicting custom patterns will be removed"
                PRESERVE_CUSTOM_CONFLICTS=false
                # Store conflicting lines for later removal
                echo "$conflicting_lines" > /tmp/gigen_conflicting_lines
                ;;
        esac
    fi
}

# Function to extract custom content from a template section
extract_custom_content() {
    local template="$1"
    local current_content=$(mktemp)
    local standard_content=$(mktemp)
    
    # Generate standard template to compare against
    generate_standard_template "$template" > "$standard_content"
    
    # Extract current template content (all non-comment lines)
    awk -v template="$template" '
        BEGIN { in_section = 0 }
        /^# === [^=]+ ===$/ {
            if ($3 == template) {
                in_section = 1
                next
            } else {
                in_section = 0
            }
        }
        /^# === [^=]+ ===$/ && in_section && $3 != template {
            in_section = 0
        }
        # Empty line does not end section - only next template header does
        in_section && NF > 0 { 
            # Include all non-empty lines that are not section headers or comments
            if (!/^# === / && !/^# /) {
                print $0 
            }
        }
    ' .gitignore > "$current_content"
    
    # Find lines that are in current but not in standard using simple O(n²) comparison
    while IFS= read -r line; do
        if [ -n "$line" ] && ! grep -Fxq "$line" "$standard_content"; then
            echo "$line"
        fi
    done < "$current_content"
    
    rm -f "$current_content" "$standard_content"
}

# Function to find missing patterns in template section
find_missing_patterns() {
    local template="$1"
    local current_content=$(mktemp)
    local standard_content=$(mktemp)
    
    # Generate standard template to compare against
    generate_standard_template "$template" > "$standard_content"
    
    # Extract current template content (all non-comment lines)
    awk -v template="$template" '
        BEGIN { in_section = 0 }
        /^# === [^=]+ ===$/ {
            if ($3 == template) {
                in_section = 1
                next
            } else {
                in_section = 0
            }
        }
        /^# === [^=]+ ===$/ && in_section && $3 != template {
            in_section = 0
        }
        # Empty line does not end section - only next template header does
        in_section && NF > 0 { 
            # Include all non-empty lines that are not section headers or comments
            if (!/^# === / && !/^# /) {
                print $0 
            }
        }
    ' .gitignore > "$current_content"
    
    # Find lines that are in standard but not in current (missing patterns)
    while IFS= read -r line; do
        if [ -n "$line" ] && ! grep -Fxq "$line" "$current_content"; then
            echo "$line"
        fi
    done < "$standard_content"
    
    rm -f "$current_content" "$standard_content"
}

# Function to check template modifications and ask user
check_template_modifications() {
    local template="$1"
    local added_content=$(mktemp)
    local missing_content=$(mktemp)
    
    # Get added and missing patterns
    extract_custom_content "$template" > "$added_content"
    find_missing_patterns "$template" > "$missing_content"
    
    local has_additions=false
    local has_deletions=false
    
    if [ -s "$added_content" ]; then
        has_additions=true
    fi
    
    if [ -s "$missing_content" ]; then
        has_deletions=true
    fi
    
    if [ "$has_additions" = true ] || [ "$has_deletions" = true ]; then
        echo ""
        echo "Template '$template' has been modified:"
        
        if [ "$has_additions" = true ]; then
            echo "  Added patterns:"
            while IFS= read -r line; do
                if [ -n "$line" ]; then
                    echo "    $line"
                fi
            done < "$added_content"
        fi
        
        if [ "$has_deletions" = true ]; then
            echo "  Missing patterns:"
            while IFS= read -r line; do
                if [ -n "$line" ]; then
                    echo "    $line"
                fi
            done < "$missing_content"
        fi
        
        if [ "$has_additions" = true ]; then
            echo "Added patterns will be moved to custom section"
            MOVE_ADDITIONS_TO_CUSTOM=true
        fi
        
        if [ "$has_deletions" = true ]; then
            echo ""
            printf "Restore missing patterns? (Y/n) "
            read REPLY < /dev/tty
            case "$REPLY" in
                [nN]|[nN][oO]) 
                    echo "Missing patterns will not be restored"
                    RESTORE_MISSING_PATTERNS=false
                    ;;
                *) 
                    echo "Missing patterns will be restored"
                    RESTORE_MISSING_PATTERNS=true
                    ;;
            esac
        fi
    fi
    
    # Store results for later use
    if [ "$has_additions" = true ]; then
        cat "$added_content" > "/tmp/gigen_${template}_additions"
    fi
    
    if [ "$has_deletions" = true ]; then
        cat "$missing_content" > "/tmp/gigen_${template}_missing"
    fi
    
    rm -f "$added_content" "$missing_content"
}

# Function to remove conflicting lines from custom content
remove_conflicting_custom_lines() {
    local custom_file="$1"
    local tmpfile=$(mktemp)
    
    # Get all standard template content for comparison
    local all_standard_content=$(mktemp)
    for template in $TEMPLATES; do
        generate_standard_template "$template" >> "$all_standard_content"
    done
    
    # Keep only non-conflicting lines using simple O(n²) comparison
    while IFS= read -r line; do
        if [ -n "$line" ] && ! grep -Fxq "$line" "$all_standard_content"; then
            echo "$line" >> "$tmpfile"
        fi
    done < "$custom_file"
    
    mv "$tmpfile" "$custom_file"
    rm -f "$all_standard_content"
}

# Function to build .gitignore with new logic
build_gitignore() {
    local templates="$1"
    
    # Initialize cache
    init_cache
    
    # Get author information
    get_author_info
    
    # Create new .gitignore file with config-aware header
    cat > "$OUTPUT_FILE" << EOF
# Generated .gitignore for $templates  
# $(date)
$(if [ -n "$GIGEN_AUTHOR_NAME" ]; then echo "# Author: $GIGEN_AUTHOR_NAME"; fi)
$(if [ -n "$GIGEN_AUTHOR_EMAIL" ]; then echo "# Email: $GIGEN_AUTHOR_EMAIL"; fi)

EOF
    
    # Add each template with its content
    for template in $templates; do
        echo "" >> "$OUTPUT_FILE"
        echo "# === $template ===" >> "$OUTPUT_FILE"
        
        # Add template-specific content
        case "$template" in
            node|nodejs)
                cat >> "$OUTPUT_FILE" << 'EOF'
# Dependencies
node_modules/
jspm_packages/

# Build outputs
dist/
build/
*.tsbuildinfo

# Logs
logs/
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
lerna-debug.log*

# Runtime data
pids/
*.pid
*.seed
*.pid.lock

# Coverage
coverage/
*.lcov
.nyc_output/

# Environment
.env
.env.local
.env.*.local

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Package managers
.npm/
.yarn/
.pnp.*
EOF
                ;;
            ms|magicscript)
                cat >> "$OUTPUT_FILE" << 'EOF'
# Magic Scripts cache
.ms-cache/
EOF
                ;;
            python|py)
                generate_template_content "$template" >> "$OUTPUT_FILE"
                ;;
            go|golang)
                cat >> "$OUTPUT_FILE" << 'EOF'
# Binaries
*.exe
*.exe~
*.dll
*.so
*.dylib

# Test binary
*.test

# Output
*.out

# Go workspace
go.work
go.work.sum

# Vendor
vendor/

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Build
dist/
build/
EOF
                ;;
            rust)
                cat >> "$OUTPUT_FILE" << 'EOF'
# Rust
target/
Cargo.lock

# IDE
.vscode/
.idea/
*.swp
*.swo
EOF
                ;;
            java)
                cat >> "$OUTPUT_FILE" << 'EOF'
# Compiled
*.class

# Package Files
*.jar
*.war
*.nar
*.ear
*.zip
*.tar.gz
*.rar

# Maven
target/
pom.xml.tag
pom.xml.releaseBackup
pom.xml.versionsBackup
pom.xml.next
release.properties
dependency-reduced-pom.xml
buildNumber.properties
.mvn/timing.properties
.mvn/wrapper/maven-wrapper.jar

# Gradle
.gradle
build/
!gradle/wrapper/gradle-wrapper.jar
!**/src/main/**/build/
!**/src/test/**/build/

# IDE
.vscode/
.idea/
*.iws
*.iml
*.ipr
out/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
EOF
                ;;
            cpp|c++)
                cat >> "$OUTPUT_FILE" << 'EOF'
# Compiled
*.o
*.ko
*.obj
*.elf
*.ilk
*.map
*.exp

# Executables
*.exe
*.out
*.app
*.i*86
*.x86_64
*.hex

# Libraries
*.lib
*.a
*.la
*.lo
*.dll
*.so
*.dylib

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Debug files
*.dSYM/
*.su
*.idb
*.pdb
EOF
                ;;
            macos|osx)
                cat >> "$OUTPUT_FILE" << 'EOF'
# macOS
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
# Icon must end with two \r
Icon


# Thumbnails
Temporary Items
.apdisk
EOF
                ;;
            linux)
                cat >> "$OUTPUT_FILE" << 'EOF'
# Linux
*~
.fuse_hidden*
.Trash-*
.nfs*
EOF
                ;;
            windows|win)
                cat >> "$OUTPUT_FILE" << 'EOF'
# Windows
Thumbs.db
Thumbs.db:encryptable
ehthumbs.db
ehthumbs_vista.db
*.stackdump
[Dd]esktop.ini
$RECYCLE.BIN/
*.cab
*.msi
*.msix
*.msm
*.msp
*.lnk
EOF
                ;;
            vscode)
                cat >> "$OUTPUT_FILE" << 'EOF'
# VSCode
.vscode/*
!.vscode/settings.json
!.vscode/tasks.json
!.vscode/launch.json
!.vscode/extensions.json
!.vscode/*.code-snippets
.history/
*.vsix
EOF
                ;;
            idea|intellij)
                cat >> "$OUTPUT_FILE" << 'EOF'
# IntelliJ IDEA
.idea/
*.iws
*.iml
*.ipr
out/
.idea_modules/
EOF
                ;;
            ai)
                cat >> "$OUTPUT_FILE" << 'EOF'
# AI Tools and IDEs
# Cursor AI IDE
.cursorrules
.cursor/
cursor.json

# Continue.dev
.continue/
continue.json

# GitHub Copilot
.copilot/
copilot-suggestions.json

# Codeium
.codeium/
codeium.json

# Tabnine
.tabnine/
tabnine.json

# ChatGPT / OpenAI files
.openai/
openai.json
chatgpt-session.json

# Claude / Anthropic files
.claude/
claude.json
anthropic-session.json

# General AI assistant files
*.ai-conversation
*.ai-session
*.ai-context
.ai-cache/
.ai-history/
.ai-temp/

# AI code generation artifacts
.ai-generated/
ai-prompts.md
ai-context.md

# Temporary AI files
temp_ai_*
.temp-ai/
ai_temp_*
EOF
                ;;
            *)
                echo "# Template $template not fully implemented yet" >> "$OUTPUT_FILE"
                ;;
        esac
    done
    
    # Add existing patterns as custom section (filtering duplicates)
    if [ -f "$PATTERNS_BACKUP_FILE" ]; then
        echo "" >> "$OUTPUT_FILE"
        echo "# === custom ===" >> "$OUTPUT_FILE"
        echo "# Add your custom patterns below this line" >> "$OUTPUT_FILE"
        
        # Add patterns that don't already exist in the file
        while IFS= read -r pattern; do
            if [ -n "$pattern" ] && ! grep -Fxq "$pattern" "$OUTPUT_FILE"; then
                echo "$pattern" >> "$OUTPUT_FILE"
            fi
        done < "$PATTERNS_BACKUP_FILE"
        echo "" >> "$OUTPUT_FILE"
    fi
    
    # Apply whitelisted patterns at the end
    apply_whitelisted_patterns
}

# Function to generate template content (called by awk)
generate_template_content() {
    local template="$1"
    
    case "$template" in
        node|nodejs)
            cat << 'EOF'
# Dependencies
node_modules/
jspm_packages/

# Build outputs
dist/
build/
*.tsbuildinfo

# Logs
logs/
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*
lerna-debug.log*

# Runtime data
pids/
*.pid
*.seed
*.pid.lock

# Coverage
coverage/
*.lcov
.nyc_output/

# Environment
.env
.env.local
.env.*.local

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Package managers
.npm/
.yarn/
.pnp.*
EOF
            ;;
        python|py)
            cat << 'EOF'
# Byte-compiled / optimized
__pycache__/
*.py[cod]
*$py.class
*.so

# Distribution / packaging
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# Virtual environments
venv/
ENV/
env/
.venv

# Testing
.tox/
.coverage
.coverage.*
.cache
.pytest_cache/
htmlcov/
EOF
            ;;
        dev)
            cat << 'EOF'
# Development tools and temporary files
.vscode/
.idea/
*.swp
*.swo
*~

# Logs and debugging
*.log
*.tmp
*.temp

# OS generated files
.DS_Store
Thumbs.db

# Backup files  
*.bak
*.backup

# Cache directories
.cache/
.ms-cache/

# Environment files
.env
.env.local

# Configuration files (add specific ones you want to ignore)
.gigenwhitelist
EOF
            ;;
        # Add other templates as needed  
        *)
            echo "# Template content for $template"
            ;;
    esac
}

# Function to remove duplicate patterns within custom section
remove_duplicate_custom_patterns() {
    local tmpfile=$(mktemp)
    local seen_patterns=$(mktemp)
    
    # Extract custom section and remove duplicates
    awk '
        BEGIN { in_custom = 0; duplicate_count = 0 }
        /^# === custom ===$/ { 
            in_custom = 1 
            print $0
            next 
        }
        /^# === [^=]+ ===$/ && in_custom { 
            in_custom = 0 
            print $0
            next
        }
        in_custom { 
            if (/^# Add your custom patterns below this line$/) {
                print $0
            } else if (NF > 0) {
                # Check if this pattern has been seen before
                if (seen[$0] == 1) {
                    duplicate_count++
                } else {
                    seen[$0] = 1
                    print $0
                }
            } else {
                print $0
            }
        }
        !in_custom { 
            print $0 
        }
        END { 
            if (duplicate_count > 0) {
                printf "Removed %d duplicate patterns from custom section\n", duplicate_count > "/dev/stderr"
            }
        }
    ' .gitignore > "$tmpfile"
    
    mv "$tmpfile" .gitignore
    rm -f "$seen_patterns"
}

# Function to ensure custom section exists at bottom
ensure_custom_section() {
    if [ ! -f "$OUTPUT_FILE" ]; then
        return
    fi
    
    # Check if custom section already exists
    if grep -q "^# === custom ===$" "$OUTPUT_FILE"; then
        # Move existing custom section to bottom
        move_custom_section_to_bottom
    else
        # Add new custom section at bottom
        echo "" >> "$OUTPUT_FILE"
        echo "# === custom ===" >> "$OUTPUT_FILE"
        echo "# Add your custom patterns below this line" >> "$OUTPUT_FILE"
        echo "" >> "$OUTPUT_FILE"
    fi
}

# Function to move custom section to bottom of file
move_custom_section_to_bottom() {
    local tmpfile=$(mktemp)
    local custom_content=$(mktemp)
    
    # Extract custom section content
    awk '
        BEGIN { in_custom = 0; custom_found = 0 }
        /^# === custom ===$/ { 
            in_custom = 1 
            custom_found = 1
            next 
        }
        /^# === [^=]+ ===$/ && in_custom { 
            in_custom = 0 
        }
        /^$/ && in_custom {
            # Empty line might end section, but keep collecting until next section
        }
        in_custom { 
            if (!/^# Add your custom patterns below this line$/) {
                print $0 
            }
        }
        END { 
            if (!custom_found) exit 1 
        }
    ' "$OUTPUT_FILE" > "$custom_content"
    
    # Remove custom section from original file
    awk '
        BEGIN { in_custom = 0; skip_empty = 0 }
        /^# === custom ===$/ { 
            in_custom = 1 
            skip_empty = 1
            next 
        }
        /^# === [^=]+ ===$/ && in_custom { 
            in_custom = 0
            skip_empty = 0
        }
        /^$/ && skip_empty && !in_custom {
            # Skip empty lines immediately after removing custom section
            skip_empty = 0
            next
        }
        !in_custom { 
            print $0
            skip_empty = 0
        }
    ' "$OUTPUT_FILE" > "$tmpfile"
    
    # Add custom section at bottom
    mv "$tmpfile" "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    echo "# === custom ===" >> "$OUTPUT_FILE"
    echo "# Add your custom patterns below this line" >> "$OUTPUT_FILE"
    
    # Add back any existing custom content (with conflict resolution if needed)
    if [ -s "$custom_content" ]; then
        if [ "$PRESERVE_CUSTOM_CONFLICTS" = "false" ]; then
            # Remove conflicting lines from custom content
            remove_conflicting_custom_lines "$custom_content"
        fi
        
        # Only add custom content if there's something left
        if [ -s "$custom_content" ]; then
            cat "$custom_content" >> "$OUTPUT_FILE"
        fi
    fi
    echo "" >> "$OUTPUT_FILE"
    
    rm -f "$custom_content"
}

# Function to add template before custom section
add_template_before_custom() {
    local template="$1"
    local tmpfile=$(mktemp)
    local custom_content=$(mktemp)
    
    # Check if custom section exists
    if grep -q "^# === custom ===$" "$OUTPUT_FILE"; then
        # Extract custom section
        extract_custom_section > "$custom_content"
        
        # Remove custom section from file
        awk '
            BEGIN { in_custom = 0; skip_next_empty = 0 }
            /^# === custom ===$/ { 
                in_custom = 1 
                skip_next_empty = 1
                next 
            }
            /^# === [^=]+ ===$/ && in_custom { 
                in_custom = 0
                skip_next_empty = 0
            }
            /^$/ && skip_next_empty && !in_custom {
                skip_next_empty = 0
                next
            }
            !in_custom { 
                print $0
                skip_next_empty = 0
            }
        ' "$OUTPUT_FILE" > "$tmpfile"
        
        mv "$tmpfile" "$OUTPUT_FILE"
    fi
    
    # Add new template header
    if [ "$FIRST_TEMPLATE" = false ] || [ -f "$OUTPUT_FILE" ]; then
        echo "" >> "$OUTPUT_FILE"
        echo "# === $template ===" >> "$OUTPUT_FILE"
        if [ "$FIRST_TEMPLATE" = true ]; then
            FIRST_TEMPLATE=false
        fi
    fi
    
    # Template content will be added by the case statement
    # Then we'll restore custom section at the end
    TEMP_CUSTOM_CONTENT="$custom_content"
    
    # Check if we need to restore missing patterns for this template
    if [ -f "/tmp/gigen_${template}_missing" ] && [ "$RESTORE_MISSING_PATTERNS" = "true" ]; then
        TEMP_MISSING_PATTERNS="/tmp/gigen_${template}_missing"
        echo "Restoring missing patterns to $template template"
    fi
}

# Function to restore custom section after template addition
restore_custom_section() {
    if [ -n "$TEMP_CUSTOM_CONTENT" ] && [ -f "$TEMP_CUSTOM_CONTENT" ]; then
        # Re-add custom section at bottom
        echo "" >> "$OUTPUT_FILE"
        echo "# === custom ===" >> "$OUTPUT_FILE"
        echo "# Add your custom patterns below this line" >> "$OUTPUT_FILE"
        
        if [ -s "$TEMP_CUSTOM_CONTENT" ]; then
            cat "$TEMP_CUSTOM_CONTENT" >> "$OUTPUT_FILE"
        fi
        
        echo "" >> "$OUTPUT_FILE"
        
        rm -f "$TEMP_CUSTOM_CONTENT"
        TEMP_CUSTOM_CONTENT=""
    fi
    
    # Remove duplicate patterns from custom section
    remove_duplicate_custom_patterns
}

# Function to remove template from .gitignore with custom content preservation
remove_template() {
    local template="$1"
    if [ ! -f .gitignore ]; then
        echo "Error: .gitignore not found"
        return 1
    fi
    
    if ! template_exists "$template"; then
        echo "Warning: Template '$template' not found in .gitignore"
        return 1
    fi
    
    # Check for template modifications before removing
    check_template_modifications "$template"
    
    # Create temporary files
    tmpfile=$(mktemp)
    custom_content=$(mktemp)
    
    # Extract custom content (lines not in standard template)
    extract_custom_content "$template" > "$custom_content"
    
    # Remove entire template section and any orphaned content at the top
    awk -v template="$template" '
        BEGIN { in_section = 0; first_section_found = 0 }
        /^# === [^=]+ ===$/ {
            first_section_found = 1
            if ($3 == template) {
                in_section = 1
                next
            } else {
                in_section = 0
            }
        }
        /^$/ && in_section {
            in_section = 0
            next
        }
        !in_section && (first_section_found || /^# Generated .gitignore/ || /^# [A-Z][a-z]/) { 
            print 
        }
    ' .gitignore > "$tmpfile"
    
    # Keep only content after the first section header (remove orphaned content at top)
    awk '
        BEGIN { first_section_found = 0 }
        /^# === [^=]+ ===$/ {
            first_section_found = 1
        }
        first_section_found { 
            print 
        }
    ' "$tmpfile" > .gitignore
    
    # Handle added patterns based on user choice
    if [ -f "/tmp/gigen_${template}_additions" ]; then
        if [ "$MOVE_ADDITIONS_TO_CUSTOM" = "true" ]; then
            # Move additions to custom section
            if [ -s "$custom_content" ]; then
                echo "" >> "$custom_content"
            fi
            cat "/tmp/gigen_${template}_additions" >> "$custom_content"
        fi
        rm -f "/tmp/gigen_${template}_additions"
    fi
    
    # Add custom content if any exists
    if [ -s "$custom_content" ]; then
        # Ensure custom section exists
        if ! grep -q "^# === custom ===$" "$tmpfile"; then
            echo "" >> "$tmpfile"
            echo "# === custom ===" >> "$tmpfile"
            echo "# Add your custom patterns below this line" >> "$tmpfile"
        fi
        cat "$custom_content" >> "$tmpfile"
        echo "" >> "$tmpfile"
        echo "Custom content from $template template preserved"
    fi
    
    mv "$tmpfile" .gitignore
    rm -f "$custom_content"
    
    # Remove duplicate patterns from custom section
    remove_duplicate_custom_patterns
    
    echo "Removed template: $template"
}

# Parse command
if [ $# -eq 0 ]; then
    echo "Error: No command specified"
    usage
    exit 1
fi

# Handle help options first
case "$1" in
    -h|--help) usage; exit 0 ;;
    -v|--version) echo "gigen v$VERSION"; exit 0 ;;
esac

COMMAND="$1"
shift

# Handle help options in remaining args
for arg in "$@"; do
    case "$arg" in
        -h|--help) usage; exit 0 ;;
    esac
done

# Validate command
case "$COMMAND" in
    init|add|remove|update|allow|disallow|status) ;;
    *) echo "Error: Unknown command '$COMMAND'"; usage; exit 1 ;;
esac

TEMPLATES="$*"

# Handle different commands  
case "$COMMAND" in
    allow)
        if [ -z "$TEMPLATES" ]; then
            echo "Error: No pattern specified for allow command"
            usage
            exit 1
        fi
        # Check if initialized
        if ! is_gigen_initialized; then
            show_init_warning
        fi
        # Ensure whitelist file exists
        ensure_whitelist_file
        # Add each pattern to whitelist
        for pattern in $TEMPLATES; do
            add_whitelisted_pattern "$pattern"
        done
        # Run update to apply changes
        echo ""
        echo "Running update to apply changes..."
        if [ -f .gitignore ]; then
            EXISTING_TEMPLATES=$(grep "^# === [^=]* ===$" .gitignore | sed 's/^# === \(.*\) ===$/\1/' | grep -v "(custom)" | grep -v "^custom$" | tr '\n' ' ')
            if [ -n "$EXISTING_TEMPLATES" ]; then
                TEMPLATES="$EXISTING_TEMPLATES"
                COMMAND="update"
                # Continue to update logic below
            else
                echo "No templates found in .gitignore to update"
                exit 0
            fi
        else
            echo "No .gitignore found. Run 'gigen init' first."
            exit 0
        fi
        ;;
    disallow)
        if [ -z "$TEMPLATES" ]; then
            echo "Error: No pattern specified for disallow command"
            usage
            exit 1
        fi
        # Check if initialized
        if ! is_gigen_initialized; then
            show_init_warning
        fi
        # Ensure whitelist file exists
        ensure_whitelist_file
        # Remove each pattern from whitelist
        for pattern in $TEMPLATES; do
            remove_whitelisted_pattern "$pattern"
        done
        exit 0
        ;;
    status)
        # Check if initialized
        if ! is_gigen_initialized; then
            echo "=== GitIgnore Generator Status ==="
            echo ""
            echo "❌ Not Initialized"
            echo "GitIgnore generator has not been initialized in this directory."
            echo ""
            echo "To initialize, run:"
            echo "  gigen init"
            echo ""
            echo "This will create:"
            echo "  📄 .gitignore with development essentials"  
            echo "  ⚪ .gigenwhitelist for pattern exclusions"
            echo "  💾 .ms-cache/ for template management"
            exit 1
        fi
        # Ensure whitelist file exists
        ensure_whitelist_file
        show_status
        exit 0
        ;;
    init)
        if [ -f .gitignore ]; then
            echo "Warning: .gitignore already exists."
            printf "Overwrite? (y/N) "
            read REPLY < /dev/tty
            case "$REPLY" in
                [yY]|[yY][eE][sS]) rm -f .gitignore ;;
                *) exit 1 ;;
            esac
        fi
        # Create whitelist file for init
        ensure_whitelist_file
        # Set default dev templates for init - use add logic for consistency
        TEMPLATES="ms macos linux windows vscode idea ai"
        # Convert init to add mode for consistent formatting
        COMMAND="add"
        ;;
    update)
        # Check if initialized
        if ! is_gigen_initialized; then
            show_init_warning
        fi
        # Ensure whitelist file exists
        ensure_whitelist_file
        # Extract existing template names from .gitignore (exclude custom section)
        EXISTING_TEMPLATES=$(grep "^# === [^=]* ===$" .gitignore | sed 's/^# === \(.*\) ===$/\1/' | grep -v "(custom)" | grep -v "^custom$" | tr '\n' ' ')
        if [ -z "$EXISTING_TEMPLATES" ]; then
            echo "No templates found in .gitignore"
            exit 0
        fi
        echo "Updating existing templates: $EXISTING_TEMPLATES"
        TEMPLATES="$EXISTING_TEMPLATES"
        ;;
    add)
        if [ -z "$TEMPLATES" ]; then
            echo "Error: No templates specified for add command"
            usage
            exit 1
        fi
        # Check if initialized (for add, allow creating new if none exists)
        if [ ! -f .gitignore ]; then
            echo "No .gitignore found. Creating new file..."
        fi
        # Ensure whitelist file exists
        ensure_whitelist_file
        ;;
    remove)
        if [ -z "$TEMPLATES" ]; then
            echo "Error: No templates specified for remove command"
            usage
            exit 1
        fi
        # Check if initialized
        if ! is_gigen_initialized; then
            show_init_warning
        fi
        # Ensure whitelist file exists
        ensure_whitelist_file
        ;;
esac

# Remove duplicates while preserving order and check for existing templates
UNIQUE_TEMPLATES=""
for template in $TEMPLATES; do
    case " $UNIQUE_TEMPLATES " in
        *" $template "*) 
            echo "Warning: Duplicate template '$template' specified, ignoring..."
            ;;
        *)
            # For add command, check if template already exists
            if [ "$COMMAND" = "add" ] && template_exists "$template"; then
                printf "Template '$template' already exists. Replace? (y/N) "
                read REPLY < /dev/tty
                case "$REPLY" in
                    [yY]|[yY][eE][sS]) 
                        UNIQUE_TEMPLATES="$UNIQUE_TEMPLATES $template"
                        ;;
                    *) 
                        echo "Skipping template: $template"
                        ;;
                esac
            else
                UNIQUE_TEMPLATES="$UNIQUE_TEMPLATES $template"
            fi
            ;;
    esac
done
TEMPLATES="$UNIQUE_TEMPLATES"

# Handle remove command
if [ "$COMMAND" = "remove" ]; then
    for template in $TEMPLATES; do
        remove_template "$template"
    done
    echo ".gitignore updated successfully!"
    exit 0
fi

# Handle add, init, and update commands with new logic
if [ "$COMMAND" = "add" ] || [ "$COMMAND" = "init" ] || [ "$COMMAND" = "update" ]; then
    # Step 1: Backup existing content
    backup_existing_content
    
    # Step 2: Delete existing .gitignore
    rm -f .gitignore
    
    # Step 3: Build new .gitignore
    build_gitignore "$TEMPLATES"
    
    echo ".gitignore created/updated successfully!"
    exit 0
fi
