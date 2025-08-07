# Dockerfile Generator (`dockergen`)

Generate optimized Dockerfiles for various runtimes.

## Usage

```bash
# Generate for specific runtime
dockergen node
dockergen python
dockergen go
```

## Supported Runtimes

- `node` - Node.js applications
- `python` - Python applications
- `go` - Go applications
- `rust` - Rust applications
- `java` - Java applications

## Features

- Multi-stage builds for production optimization
- Security best practices
- Minimal base images
- Runtime-specific optimizations
- Development and production variants

## Options

- Runtime argument (required) - Specify the runtime/language
- `-h, --help` - Show help message
- `-v, --version` - Show version

## Generated Files

- `Dockerfile` - Production-optimized Dockerfile
- `.dockerignore` - Appropriate ignore patterns for the runtime

## Examples

```bash
# Node.js application
dockergen node
# Creates Dockerfile with Node.js best practices, multi-stage build

# Python application  
dockergen python
# Creates Dockerfile with Python optimizations, pip caching

# Go application
dockergen go
# Creates Dockerfile with Go build optimizations, scratch base image
```

## Installation

```bash
ms install dockergen
```