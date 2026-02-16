# Configuration Guide

Magic Scripts provides a configuration system that lets you store and reuse values across commands. This guide covers how to view, set, and manage configuration as a user.

## Basic Usage

### Listing Configuration

To see all configuration values you have set:

```
ms config list
```

To see all available configuration keys defined by installed commands (registry defaults):

```
ms config list -r
```

To see configuration keys specific to a particular command:

```
ms config list -c pgadduser
```

### Setting Values

Use `ms config set` to store a configuration value:

```
ms config set AUTHOR_NAME "Your Name"
ms config set AUTHOR_EMAIL "your@email.com"
ms config set DB_HOST "localhost"
```

### Getting Values

Retrieve a single configuration value:

```
ms config get AUTHOR_NAME
```

### Removing Values

Remove a configuration value you no longer need:

```
ms config remove AUTHOR_NAME
```

## Configuration Storage Locations

Configuration is stored in two locations:

| Location | Path | Scope |
|----------|------|-------|
| Global config | `~/.local/share/magicscripts/config` | Applies to all projects and commands |
| Local config | `.msconfig` in your project directory | Applies only to the current project |

Global configuration is shared across your entire system. Local configuration lives in a `.msconfig` file in the root of a project directory and applies only when you run commands from within that project.

## Priority Order

When the same key is defined in multiple places, Magic Scripts uses this precedence (highest to lowest):

1. **Local project config** (`.msconfig`) -- highest priority
2. **Global user config** (`~/.local/share/magicscripts/config`)
3. **Registry defaults** -- lowest priority

This means a value in your project `.msconfig` will always override the same key in your global config, which in turn overrides the default defined by the command's registry entry.

## Common Configuration Categories

### Author Information

Used by commands that generate files or templates:

| Key | Description | Example |
|-----|-------------|---------|
| `AUTHOR_NAME` | Your full name | `"Jane Smith"` |
| `AUTHOR_EMAIL` | Your email address | `"jane@example.com"` |

### Database Settings

Used by database-related commands such as `pgadduser`:

| Key | Description | Example |
|-----|-------------|---------|
| `DB_HOST` | Database host | `"localhost"` |
| `DB_USER` | Database username | `"admin"` |
| `POSTGRES_ADMIN` | PostgreSQL admin username | `"postgres"` |

### Project Defaults

General-purpose defaults used across multiple commands:

| Key | Description | Example |
|-----|-------------|---------|
| `DEFAULT_LICENSE` | Default license type | `"MIT"` |

To discover all available keys for your installed commands, run `ms config list -r`.

## Project-Specific Configuration with .msconfig

You can create a `.msconfig` file in any project directory to define configuration values that apply only to that project. This is useful when different projects require different settings (for example, different database hosts or author identities).

Create the file manually or set values from within the project directory:

```
ms config set DB_HOST "staging-db.internal" --local
```

The `.msconfig` file uses a simple `KEY=VALUE` format:

```
DB_HOST=staging-db.internal
DB_USER=deploy
AUTHOR_NAME=Project Team
```

Because local config takes the highest priority, any values defined here will override your global settings whenever you run commands from within that project directory.

**Tip:** Add `.msconfig` to your `.gitignore` if it contains environment-specific values that should not be shared across your team. Alternatively, commit it if the values represent shared project defaults.
