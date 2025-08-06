#!/bin/sh

# Set script identity for config system security
export MS_SCRIPT_ID="pgadduser"

VERSION="0.0.1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Try to load config system
if [ -f "$SCRIPT_DIR/../core/config.sh" ]; then
    . "$SCRIPT_DIR/../core/config.sh"
elif [ -f "$HOME/.local/share/magicscripts/core/config.sh" ]; then
    . "$HOME/.local/share/magicscripts/core/config.sh"
fi

COMMAND_NAME="pgadduser"

usage() {
    echo "Usage: $COMMAND_NAME -u <username> -p <password> [-d <database_name>]"
    echo ""
    echo "Options:"
    echo "  -u <username>      PostgreSQL username (required)"
    echo "  -p <password>      PostgreSQL user password (required)"
    echo "  -d <database_name> Database name (default: same as username)"
    echo "  --help             Show this help message"
    echo ""
    echo "Configuration Keys Used:"
    echo "  POSTGRES_HOST     PostgreSQL host (default: localhost)"
    echo "  POSTGRES_PORT     PostgreSQL port (default: 5432)"
    echo "  POSTGRES_ADMIN    PostgreSQL admin user (default: postgres)"
    echo "  POSTGRES_PASSWORD PostgreSQL admin password"
    echo ""
    echo "  Set with: ms config set <key> <value>"
    echo ""
    echo "Examples:"
    echo "  $COMMAND_NAME -u john -p pass123"
    echo "  $COMMAND_NAME -u john -p pass123 -d myapp_db"
    exit 1
}

# Load database configuration
get_db_config() {
    if command -v get_config_value >/dev/null 2>&1; then
        POSTGRES_HOST=$(get_config_value "POSTGRES_HOST" "localhost" 2>/dev/null)
        POSTGRES_PORT=$(get_config_value "POSTGRES_PORT" "5432" 2>/dev/null)
        POSTGRES_ADMIN=$(get_config_value "POSTGRES_ADMIN" "postgres" 2>/dev/null)
        POSTGRES_PASSWORD=$(get_config_value "POSTGRES_PASSWORD" "" 2>/dev/null)
    else
        echo "Warning: Config system not available, using defaults" >&2
        POSTGRES_HOST="localhost"
        POSTGRES_PORT="5432" 
        POSTGRES_ADMIN="postgres"
        POSTGRES_PASSWORD=""
    fi
    
    # Export for use
    export POSTGRES_HOST POSTGRES_PORT POSTGRES_ADMIN POSTGRES_PASSWORD
}

# Load configuration
get_db_config

while [ $# -gt 0 ]; do
    case $1 in
        -u) DB_USER="$2"; shift 2 ;;
        -p) DB_PASSWORD="$2"; shift 2 ;;
        -d) DB_NAME="$2"; shift 2 ;;
        --help) usage ;;
        --version|-v) echo "pgadduser v$VERSION"; exit 0 ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

if [ -z "$DB_USER" ] || [ -z "$DB_PASSWORD" ]; then
    echo "Error: Required parameters missing."
    usage
fi

[ -z "$DB_NAME" ] && DB_NAME="$DB_USER"

echo "========================================="
echo "PostgreSQL Configuration:"
echo "========================================="
echo "Database Host: $POSTGRES_HOST"
echo "Database Port: $POSTGRES_PORT"
echo "Database Name: $DB_NAME"
echo "Username: $DB_USER"
echo "Admin Account: $POSTGRES_ADMIN"
echo "========================================="
echo ""

printf "Continue with these settings? (y/N) "
read REPLY < /dev/tty
echo ""
case "$REPLY" in
    [yY]|[yY][eE][sS]) ;;
    *) echo "Operation cancelled."; exit 1 ;;
esac

echo "1. Creating PostgreSQL user: $DB_USER"
if [ -n "$POSTGRES_PASSWORD" ]; then
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_ADMIN" <<EOF
else
    sudo -u $POSTGRES_ADMIN psql <<EOF
fi
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = '$DB_USER') THEN
        CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
        RAISE NOTICE 'User $DB_USER created successfully';
    ELSE
        ALTER USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
        RAISE NOTICE 'User $DB_USER already exists, password updated';
    END IF;
END
\$\$;
EOF

[ $? -ne 0 ] && { echo "Error: Failed to create PostgreSQL user"; exit 1; }

echo ""
echo "2. Creating database: $DB_NAME with owner: $DB_USER"
if [ -n "$POSTGRES_PASSWORD" ]; then
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_ADMIN" <<EOF
else
    sudo -u $POSTGRES_ADMIN psql <<EOF
fi
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DB_NAME') THEN
        CREATE DATABASE $DB_NAME WITH OWNER = $DB_USER;
        RAISE NOTICE 'Database $DB_NAME created successfully with owner $DB_USER';
    ELSE
        ALTER DATABASE $DB_NAME OWNER TO $DB_USER;
        RAISE NOTICE 'Database $DB_NAME already exists, owner changed to $DB_USER';
    END IF;
END
\$\$;
EOF

[ $? -ne 0 ] && { echo "Error: Failed to create/modify database"; exit 1; }

echo ""
echo "3. Granting all privileges to user $DB_USER on database $DB_NAME"
if [ -n "$POSTGRES_PASSWORD" ]; then
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_ADMIN" -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
else
    sudo -u $POSTGRES_ADMIN psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
fi

[ $? -ne 0 ] && { echo "Error: Failed to grant database privileges"; exit 1; }

echo ""
echo "4. Granting schema privileges in database $DB_NAME"
if [ -n "$POSTGRES_PASSWORD" ]; then
    PGPASSWORD="$POSTGRES_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_ADMIN" -d "$DB_NAME" <<EOF
else
    sudo -u $POSTGRES_ADMIN psql -d $DB_NAME <<EOF
fi
GRANT ALL ON SCHEMA public TO $DB_USER;
GRANT CREATE ON SCHEMA public TO $DB_USER;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TYPES TO $DB_USER;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO $DB_USER;
EOF

[ $? -ne 0 ] && { echo "Error: Failed to grant schema privileges"; exit 1; }

echo ""
echo "5. Testing connection..."
PGPASSWORD=$DB_PASSWORD psql -h $POSTGRES_HOST -p $POSTGRES_PORT -U $DB_USER -d $DB_NAME -c "SELECT current_database(), current_user, version();" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    CONNECTION_STATUS="✅ Connection successful"
else
    CONNECTION_STATUS="❌ Connection failed (please check credentials and network)"
fi

echo ""
echo "========================================="
echo "✅ PostgreSQL setup completed!"
echo "========================================="
echo ""
echo "Database Details:"
echo "  Host: $POSTGRES_HOST"
echo "  Port: $POSTGRES_PORT"
echo "  Database: $DB_NAME"
echo "  Owner: $DB_USER"
echo "  Status: $CONNECTION_STATUS"
echo ""
echo "Connection commands:"
echo "  psql:   PGPASSWORD='$DB_PASSWORD' psql -h $POSTGRES_HOST -p $POSTGRES_PORT -U $DB_USER -d $DB_NAME"
echo "  URL:    postgresql://$DB_USER:$DB_PASSWORD@$POSTGRES_HOST:$POSTGRES_PORT/$DB_NAME"