# PostgreSQL User Manager (`pgadduser`)

Create PostgreSQL users and databases with proper permissions.

## Usage

```bash
# Configure database connection first
ms config set POSTGRES_HOST "production.db.com"
ms config set POSTGRES_ADMIN "admin"
ms config set POSTGRES_PASSWORD "admin_password"

# Create user with database
pgadduser -u john -p pass123
pgadduser -u john -p pass123 -d myapp_db
```

## Options

- `-u, --user` - Username for new PostgreSQL user
- `-p, --password` - Password for new user
- `-d, --database` - Database name to create (optional)
- `-h, --help` - Show help message
- `-v, --version` - Show version

## Configuration

Required configuration keys:
- `POSTGRES_HOST` - PostgreSQL server hostname or IP address (default: localhost)
- `POSTGRES_PORT` - PostgreSQL server port number (default: 5432)
- `POSTGRES_ADMIN` - PostgreSQL admin username (default: postgres)
- `POSTGRES_PASSWORD` - PostgreSQL admin password

## Features

- Creates PostgreSQL user with proper permissions
- Optionally creates database owned by the user
- Validates connection before making changes
- Provides detailed error messages

## Installation

```bash
ms install pgadduser
```