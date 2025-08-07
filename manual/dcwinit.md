# Docker Compose Initializer (`dcwinit`)

Generate Docker Compose configurations for development.

## Usage

```bash
# Basic web + database setup
dcwinit

# Custom services and port
dcwinit -s "web,db,redis" -p 8080

# With custom network
dcwinit --network --network-name mynet
```

## Options

- `-s, --services` - Comma-separated list of services (default: web,db)
- `-p, --port` - Main service port (default: 3000)
- `--network` - Create custom network
- `--network-name` - Custom network name (default: app-network)
- `-h, --help` - Show help message
- `-v, --version` - Show version

## Available Services

- `web` - Web application service
- `db` - PostgreSQL database
- `redis` - Redis cache
- `nginx` - Nginx reverse proxy
- `mongo` - MongoDB database

## Configuration

- `DOCKER_COMPOSE_VERSION` - Docker Compose file version (default: 3.8)
- `DOCKER_EXPOSE_PORTS` - Expose ports by default in Docker services (default: true)
- `DOCKER_CREATE_NETWORK` - Create custom networks by default (default: false)

## Features

- Generates complete docker-compose.yml
- Includes environment variables template
- Sets up proper networking between services
- Creates development-friendly configurations

## Installation

```bash
ms install dcwinit
```