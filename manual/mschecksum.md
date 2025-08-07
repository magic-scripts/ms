# SHA256 Checksum Calculator (`mschecksum`)

Simple tool for calculating SHA256 checksums in Magic Scripts format.

## Usage

```bash
# Calculate checksum for a file
mschecksum ./scripts/my-script.sh

# Show version
mschecksum --version

# Show help
mschecksum --help
```

## Output Format

```
File: <file_path>
SHA256 (first 8 chars): <checksum>
```

## Features

- **SHA256 checksums** using first 8 characters (Magic Scripts standard)
- **Cross-platform** compatibility (Linux, macOS, Unix)
- **Auto-detection** of available tools (sha256sum, shasum, openssl)
- **Clean output** format for easy parsing

## Examples

```bash
$ mschecksum hello.sh
File: hello.sh
SHA256 (first 8 chars): 2c26b46b

$ mschecksum --version
mschecksum v0.1.0
```

## Use Cases

- Calculate checksums for `.msver` files
- Verify file integrity during development
- Batch checksum processing in scripts

## Installation

```bash
ms install mschecksum
```