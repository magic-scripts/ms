# License Generator (`licgen`)

Generate license files for various open source licenses.

## Usage

```bash
# Generate MIT license
licgen mit

# Generate with custom author
licgen -a "John Doe" apache

# Generate to custom file
licgen -o LICENSE.txt gpl3
```

## Supported License Types

- `mit` - MIT License
- `apache` - Apache License 2.0
- `gpl3` - GNU General Public License v3.0
- `bsd3` - BSD 3-Clause License
- `bsd2` - BSD 2-Clause License
- `unlicense` - The Unlicense
- `lgpl` - GNU Lesser General Public License
- `mpl` - Mozilla Public License 2.0
- `cc0` - Creative Commons Zero v1.0 Universal
- `agpl` - GNU Affero General Public License v3.0

## Options

- `-a, --author` - Override default author name
- `-o, --output` - Specify output file (default: LICENSE)
- `-h, --help` - Show help message
- `-v, --version` - Show version

## Configuration

- `AUTHOR_NAME` - Your name for license files
- `AUTHOR_EMAIL` - Your email for license files
- `DEFAULT_LICENSE` - Default license type for new projects (default: mit)

## Installation

```bash
ms install licgen
```