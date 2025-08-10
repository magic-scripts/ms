# Configuration System

Magic Scripts uses a unified configuration system that allows commands to share configuration values while maintaining security and proper access controls.

## Basic Usage

### Viewing Configuration

```bash
# List all configuration values
ms config list

# Show configuration keys available from registries
ms config list -r

# Show config keys for specific command
ms config list -c gigen

# Show config keys by category
ms config list auth
ms config list project
ms config list database
```

### Setting Values

```bash
# Set a configuration value
ms config set AUTHOR_NAME "Your Name"
ms config set AUTHOR_EMAIL "your@email.com"
ms config set DB_HOST "localhost"

# Interactive configuration wizard
ms config set

# Set global configuration (system-wide)
ms config set -g GLOBAL_KEY "value"
```

### Getting Values

```bash
# Get a specific configuration value
ms config get AUTHOR_NAME

# Show detailed information about a config key
ms config info AUTHOR_NAME
```

### Removing Values

```bash
# Remove a configuration value
ms config remove AUTHOR_NAME
```

## Configuration Storage

- **Global Config**: `$HOME/.local/share/magicscripts/config`
- **Local Config**: `$PWD/.msconfig` (project-specific, takes precedence)
- **Config Registry**: `$HOME/.local/share/magicscripts/reg/config_registry` (available keys)

## Configuration Categories

### 1. Author Information
- `AUTHOR_NAME`: Your full name
- `AUTHOR_EMAIL`: Your email address

### 2. Database Settings
- `DB_HOST`: Database host
- `DB_USER`: Database username
- `POSTGRES_ADMIN`: PostgreSQL admin username

### 3. Project Defaults
- `DEFAULT_LICENSE`: Default license type (mit, apache, gpl, etc.)
- `DEFAULT_FRAMEWORK`: Default project framework

### 4. Development Tools
- `EDITOR`: Preferred text editor
- `SHELL`: Preferred shell

## Advanced Usage

### Script Access to Configuration

Scripts can access configuration using the config system:

```bash
#!/bin/sh
export MS_SCRIPT_ID="mycommand"

# Load config system
. "$HOME/.local/share/magicscripts/config.sh"

# Get configuration value with fallback
AUTHOR=$(get_config_value "AUTHOR_NAME" "Anonymous" 2>/dev/null)
```

### Configuration Key Registration

Commands can register their configuration keys via their `.msver` files:

```
config|AUTHOR_NAME||Author's full name|author|mycommand
config|DB_HOST|localhost|Database host|database|pgadduser
```

Format: `config|key|default_value|description|category|scripts`

## Security Model

- Scripts can only access configuration keys they have registered
- The `ms` command has full access to all registered keys
- Unregistered keys are rejected with appropriate error messages
- Local project config (`.msconfig`) takes precedence over global config

## Examples

### Basic Setup
```bash
ms config set AUTHOR_NAME "John Doe"
ms config set AUTHOR_EMAIL "john@example.com"
ms config set DEFAULT_LICENSE "mit"
```

### Database Configuration
```bash
ms config set DB_HOST "production.db.com"
ms config set DB_USER "app_user"
ms config set POSTGRES_ADMIN "postgres"
```

### Project-Specific Configuration
```bash
# In your project directory
echo "DB_HOST=localhost" > .msconfig
echo "DEBUG=true" >> .msconfig
```