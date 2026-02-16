# Magic Scripts Command Reference

Complete reference for all `ms` user commands.

---

## Core

### `ms help`

Show the help message with all available commands, installed scripts, and usage examples.

**Usage:**

```
ms help
ms --help
ms -h
```

**Example:**

```
ms help
```

---

### `ms version`

Display the Magic Scripts version banner.

**Usage:**

```
ms version
ms --version
ms -v
```

**Example:**

```
ms version
```

---

### `ms status`

Show a summary of the current installation, including installed commands with their versions, directory paths, configuration file status, and PATH configuration.

**Usage:**

```
ms status
```

**Example:**

```
$ ms status
Installed Commands:
  pgadduser    [1.0.0] PostgreSQL user/database setup
  mschecksum   [1.2.0] SHA256 checksum calculator

Directories:
  Magic Scripts directory: /home/user/.local/share/magicscripts
  ...

Total installed: 2 commands
```

---

### `ms doctor`

Run a full system diagnostic. Checks registry status, installed command integrity (including checksum verification), directory structure, PATH configuration, orphaned files, and registry format validation.

**Usage:**

```
ms doctor
ms doctor --fix
```

**Options:**

| Flag | Description |
|------|-------------|
| `--fix` | Attempt to automatically repair detected issues (reinstall corrupt commands, create missing directories, remove orphaned files) |

**Example:**

```
$ ms doctor
Registry Status
  ms: 5 entries

Installed Commands
  pgadduser [1.0.0]: OK
  mschecksum [1.2.0]: OK

System Structure
  /home/user/.local/bin: OK
  ...

Summary
  No issues found! System is healthy.
```

```
$ ms doctor --fix
```

---

## Registry and Search

### `ms upgrade`

Download the latest version of all configured registries. This refreshes the local cache so that `ms search`, `ms install`, and `ms update` can see newly available commands and versions.

**Usage:**

```
ms upgrade
```

**Example:**

```
$ ms upgrade
Updating registry 'ms'... done
```

---

### `ms search`

Search for available commands across all registries. Without a query, lists all available commands.

**Usage:**

```
ms search
ms search [query]
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `query` | Optional search term to filter results by name, description, or category |

**Example:**

```
$ ms search postgres
pgadduser   PostgreSQL user/database setup   database

$ ms search
```

---

### `ms reg list`

List all configured registries and their URLs.

**Usage:**

```
ms reg list
```

**Example:**

```
$ ms reg list
  ms    https://raw.githubusercontent.com/...
```

---

### `ms reg add`

Add a new registry source. The URL must point to a valid `.msreg` file served over HTTPS.

**Usage:**

```
ms reg add <name> <url>
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `name` | Short name for the registry (used in other commands) |
| `url` | HTTPS URL to the `.msreg` registry file |

**Example:**

```
$ ms reg add custom https://example.com/registry/custom.msreg
```

---

### `ms reg remove`

Remove a previously added registry.

**Usage:**

```
ms reg remove <name>
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `name` | Name of the registry to remove |

**Example:**

```
$ ms reg remove custom
```

---

## Package Management

### `ms install`

Install one or more commands from available registries. Supports installing specific versions using the `command:version` syntax, installing from a specific registry with `-r`, and installing all commands from a registry at once.

**Usage:**

```
ms install <command1> [command2...]
ms install <command>:<version>
ms install -r <registry>
ms install -r <registry> <command>
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `command` | Name of the command to install |
| `command:version` | Install a specific version of a command |

**Options:**

| Flag | Description |
|------|-------------|
| `-r`, `--registry` | Target a specific registry. When used alone, installs all commands from that registry. When used with command names, installs those commands from the specified registry. |

**Examples:**

```
$ ms install pgadduser
  Installing pgadduser... done

$ ms install pgadduser mschecksum
  Installing pgadduser... done
  Installing mschecksum... done

$ ms install pgadduser:1.0.0

$ ms install -r ms
  Installing all commands from 'ms' registry...

$ ms install -r ms pgadduser
  Installing pgadduser from ms... done
```

---

### `ms uninstall`

Remove one or more installed commands. When uninstalling the `ms` core command, an interactive confirmation prompt is shown with options to remove only `ms` or all Magic Scripts commands.

**Usage:**

```
ms uninstall <command1> [command2...]
ms uninstall --all
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `command` | Name of the command to uninstall |

**Options:**

| Flag | Description |
|------|-------------|
| `--all` | Remove the entire Magic Scripts installation, including all commands and data |

**Examples:**

```
$ ms uninstall pgadduser

$ ms uninstall pgadduser mschecksum

$ ms uninstall --all
```

---

### `ms update`

Update installed commands to their latest versions. When run without arguments, updates all installed commands and then updates the Magic Scripts core. Pinned commands are skipped. When given a specific command name, updates only that command.

**Usage:**

```
ms update
ms update <command>
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `command` | Optional. Name of a specific command to update. Use `ms` to update the core system only. |

**Examples:**

```
$ ms update
Updating all installed commands...
  Updating pgadduser... done (v1.0.0 -> v1.1.0)
  Updating mschecksum... already latest (v1.2.0)

$ ms update pgadduser

$ ms update ms
Updating Magic Scripts core...
```

---

### `ms reinstall`

Force reinstall a command, downloading and replacing it even if the same version is already installed. Useful for repairing corrupted installations.

**Usage:**

```
ms reinstall <command>
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `command` | Name of the command to reinstall. Use `ms` to reinstall the core system. |

**Examples:**

```
$ ms reinstall pgadduser
  Reinstalling pgadduser:1.0.0... done

$ ms reinstall ms
```

---

### `ms versions`

Show available versions for a command. Can also display version information for all installed commands or all commands in a specific registry.

**Usage:**

```
ms versions <command>
ms versions --all
ms versions -r <registry>
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `command` | Name of the command to show versions for |

**Options:**

| Flag | Description |
|------|-------------|
| `--all` | Show installed vs. registry versions for all installed commands |
| `-r <registry>` | Show versions for all commands in the specified registry |

**Examples:**

```
$ ms versions pgadduser
Version information for pgadduser:
  Installed: 1.0.0
  Latest:    1.1.0

Available versions:
  1.1.0      https://...
  1.0.0      https://... (installed)

$ ms versions --all
Command      Installed    Registry
-------      ---------    --------
pgadduser    1.0.0        1.1.0
mschecksum   1.2.0        1.2.0

$ ms versions -r ms
```

---

### `ms info`

Show detailed package information for a command, including description, category, author, license, stability, repository URL, available versions, and configuration keys.

**Usage:**

```
ms info <command>
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `command` | Name of the command to inspect |

**Example:**

```
$ ms info pgadduser

  pgadduser

  Description:  PostgreSQL user/database setup
  Category:     database
  Author:       Magic Scripts
  License:      MIT
  Stability:    stable

  Versions:
    1.1.0
    1.0.0 (installed)

  Configuration keys:
    DB_HOST                   Database host (default: localhost)
```

---

## Maintenance

### `ms outdated`

List installed commands that have newer versions available in registries. Pinned commands are shown but marked as pinned.

**Usage:**

```
ms outdated
```

**Example:**

```
$ ms outdated
Checking for updates...

  pgadduser            v1.0.0     -> v1.1.0

1 command(s) can be updated.
Run 'ms update' to update all.
```

---

### `ms which`

Show the file paths associated with an installed command: wrapper script, main script, metadata file, version, pin status, and man page (if available).

**Usage:**

```
ms which <command>
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `command` | Name of the installed command |

**Example:**

```
$ ms which pgadduser

pgadduser

  Wrapper:   /home/user/.local/bin/ms/pgadduser
  Script:    /home/user/.local/share/magicscripts/scripts/pgadduser.sh
  Metadata:  /home/user/.local/share/magicscripts/installed/pgadduser.msmeta
  Version:   v1.0.0
```

---

### `ms pin`

Pin a command to its currently installed version. Pinned commands are skipped during `ms update`.

**Usage:**

```
ms pin <command>
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `command` | Name of the command to pin |

**Example:**

```
$ ms pin pgadduser
Pinned 'pgadduser' at v1.0.0
  Hint: This command will be skipped during 'ms update'
```

---

### `ms unpin`

Remove the version pin from a command, allowing it to be updated again.

**Usage:**

```
ms unpin <command>
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `command` | Name of the command to unpin |

**Example:**

```
$ ms unpin pgadduser
Unpinned 'pgadduser'
  Hint: This command will now be updated with 'ms update'
```

---

### `ms clean`

Clean up registry cache files, orphaned metadata, and temporary files.

**Usage:**

```
ms clean
ms clean --dry-run
```

**Options:**

| Flag | Description |
|------|-------------|
| `--dry-run` | Show what would be removed without actually deleting anything |

**Examples:**

```
$ ms clean
Cleaning Magic Scripts cache...

  Registry cache: 1 file(s)
  Orphaned metadata: 0 file(s)
  Temp files: 0 file(s)

Cleaned 1 file(s).

$ ms clean --dry-run
Cleaning Magic Scripts cache...

  Would remove: /home/user/.local/share/magicscripts/reg/ms.msreg

Dry run: 1 file(s) would be cleaned.
```

---

### `ms run`

Download and execute a command without permanently installing it. The script is downloaded, its checksum is verified, it is executed with any provided arguments, and then it is cleaned up.

**Usage:**

```
ms run <command> [args...]
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `command` | Name of the command to run |
| `args` | Optional arguments passed through to the command |

**Example:**

```
$ ms run mschecksum checksum myfile.sh
Downloading mschecksum... done

a1b2c3d4
```

---

## Data

### `ms export`

Export a list of installed commands to stdout. The output can be redirected to a file and later used with `ms import` to replicate the installation on another machine.

**Usage:**

```
ms export
ms export --full
```

**Options:**

| Flag | Description |
|------|-------------|
| `--full` | Include registry source information in the export (`name:version@registry` format) |

**Examples:**

```
$ ms export
# Magic Scripts export
# Date: 2026-02-16
pgadduser:1.0.0
mschecksum:1.2.0

$ ms export --full
# Magic Scripts export (full)
# Date: 2026-02-16
pgadduser:1.0.0@ms
mschecksum:1.2.0@ms

$ ms export > my-commands.txt
```

---

### `ms import`

Install commands from a previously exported file. Skips commands that are already installed at the same version.

**Usage:**

```
ms import <file>
ms import --file <file>
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `file` | Path to the export file |

**File format (one entry per line):**

```
command:version
command:version@registry
```

Lines starting with `#` are treated as comments and ignored.

**Example:**

```
$ ms import my-commands.txt
Importing commands from my-commands.txt...

  pgadduser: already installed (v1.0.0)
  mschecksum: installing... done
```

---

## Configuration

### `ms config list`

List configuration values. Without flags, shows all currently set values. With flags, shows available configuration keys from registries or specific commands.

**Usage:**

```
ms config list
ms config list -r
ms config list -r <registry>
ms config list -c <command>
```

**Options:**

| Flag | Description |
|------|-------------|
| `-r` | Show all available configuration keys from all registries |
| `-r <registry>` | Show configuration keys from a specific registry |
| `-c <command>` | Show configuration keys for a specific command |

**Examples:**

```
$ ms config list

$ ms config list -r

$ ms config list -r ms

$ ms config list -c pgadduser
```

---

### `ms config set`

Set a configuration value. When called with a key and value, sets the value directly. When called with only a command name or key, launches interactive setup. When called with no arguments, shows an interactive setup menu.

**Usage:**

```
ms config set <key> <value>
ms config set <command>
ms config set <key>
ms config set
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `key` | Configuration key name |
| `value` | Value to assign to the key |
| `command` | Command name for interactive config setup |

**Examples:**

```
$ ms config set DB_HOST localhost

$ ms config set pgadduser

$ ms config set
```

---

### `ms config get`

Retrieve the current value of a configuration key.

**Usage:**

```
ms config get <key>
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `key` | Configuration key to look up |

**Example:**

```
$ ms config get DB_HOST
DB_HOST = localhost
```

---

### `ms config remove`

Remove a configuration value, reverting it to the default (if one is defined in the package manifest).

**Usage:**

```
ms config remove <key>
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `key` | Configuration key to remove |

**Example:**

```
$ ms config remove DB_HOST
```
