#!/bin/sh

# Set script identity for config system security
export MS_SCRIPT_ID="dcwinit"
VERSION="0.0.1"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Try to load config system
if [ -f "$SCRIPT_DIR/../core/config.sh" ]; then
    . "$SCRIPT_DIR/../core/config.sh"
elif [ -f "$HOME/.local/share/magicscripts/core/config.sh" ]; then
    . "$HOME/.local/share/magicscripts/core/config.sh"
fi

usage() {
    echo "Usage: dcwinit [options]"
    echo ""
    echo "Options:"
    echo "  -n <name>      Project name (default: current directory name)"
    echo "  -s <services>  Comma-separated services (web,db,redis,nginx)"
    echo "  -p <port>      Web service port (default: 3000)"
    echo "  --no-ports     Disable port exposure (internal only)"
    echo "  --network      Create custom network"
    echo "  --network-name Custom network name (default: projectname_network)"
    echo "  -h, --help     Show this help"
    echo "  -v, --version  Show version"
    echo ""
    echo "Configuration:"
    echo "  Docker settings are read from Magic Scripts config."
    echo "  Run 'ms config setup' to configure defaults."
}

PROJECT_NAME=$(basename "$(pwd)")
SERVICES="web,db"
WEB_PORT=3000
EXPOSE_PORTS=""
CREATE_NETWORK=""
NETWORK_NAME=""

while [ $# -gt 0 ]; do
    case $1 in
        -n) PROJECT_NAME="$2"; shift 2 ;;
        -s) SERVICES="$2"; shift 2 ;;
        -p) WEB_PORT="$2"; shift 2 ;;
        --no-ports) EXPOSE_PORTS="false"; shift ;;
        --network) CREATE_NETWORK="true"; shift ;;
        --network-name) NETWORK_NAME="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        -v|--version) echo "dcwinit v$VERSION"; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# Load configuration values
if command -v get_config_value >/dev/null 2>&1; then
    COMPOSE_VERSION=$(get_config_value "DOCKER_COMPOSE_VERSION" "3.8" 2>/dev/null)
    [ -z "$EXPOSE_PORTS" ] && EXPOSE_PORTS=$(get_config_value "DOCKER_EXPOSE_PORTS" "true" 2>/dev/null)
    [ -z "$CREATE_NETWORK" ] && CREATE_NETWORK=$(get_config_value "DOCKER_CREATE_NETWORK" "false" 2>/dev/null)
else
    COMPOSE_VERSION="3.8"
    [ -z "$EXPOSE_PORTS" ] && EXPOSE_PORTS="true"
    [ -z "$CREATE_NETWORK" ] && CREATE_NETWORK="false"
fi
[ -z "$NETWORK_NAME" ] && NETWORK_NAME="${PROJECT_NAME}_network"

cat > docker-compose.yml << EOF
version: '$COMPOSE_VERSION'

services:
EOF

if echo "$SERVICES" | grep -q "web"; then
    cat >> docker-compose.yml << EOF
  web:
    build: .
EOF
    
    if [ "$EXPOSE_PORTS" = "true" ]; then
        cat >> docker-compose.yml << EOF
    ports:
      - "$WEB_PORT:$WEB_PORT"
EOF
    fi
    
    cat >> docker-compose.yml << EOF
    environment:
      - NODE_ENV=development
    volumes:
      - .:/app
      - /app/node_modules
EOF

    if echo "$SERVICES" | grep -q "db"; then
        cat >> docker-compose.yml << EOF
    depends_on:
      - db
EOF
    fi

    if [ "$CREATE_NETWORK" = "true" ]; then
        cat >> docker-compose.yml << EOF
    networks:
      - $NETWORK_NAME
EOF
    fi

    echo "" >> docker-compose.yml
fi

if echo "$SERVICES" | grep -q "db"; then
    cat >> docker-compose.yml << EOF
  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: \${DB_USER:-user}
      POSTGRES_PASSWORD: \${DB_PASSWORD:-password}
      POSTGRES_DB: \${DB_NAME:-$PROJECT_NAME}
    volumes:
      - postgres_data:/var/lib/postgresql/data
EOF

    if [ "$EXPOSE_PORTS" = "true" ]; then
        cat >> docker-compose.yml << EOF
    ports:
      - "5432:5432"
EOF
    fi

    if [ "$CREATE_NETWORK" = "true" ]; then
        cat >> docker-compose.yml << EOF
    networks:
      - $NETWORK_NAME
EOF
    fi

    echo "" >> docker-compose.yml
fi

if echo "$SERVICES" | grep -q "redis"; then
    cat >> docker-compose.yml << EOF
  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
EOF

    if [ "$EXPOSE_PORTS" = "true" ]; then
        cat >> docker-compose.yml << EOF
    ports:
      - "6379:6379"
EOF
    fi

    if [ "$CREATE_NETWORK" = "true" ]; then
        cat >> docker-compose.yml << EOF
    networks:
      - $NETWORK_NAME
EOF
    fi

    echo "" >> docker-compose.yml
fi

if echo "$SERVICES" | grep -q "nginx"; then
    cat >> docker-compose.yml << EOF
  nginx:
    image: nginx:alpine
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
EOF

    if [ "$EXPOSE_PORTS" = "true" ]; then
        cat >> docker-compose.yml << EOF
    ports:
      - "80:80"
      - "443:443"
EOF
    fi

    if echo "$SERVICES" | grep -q "web"; then
        cat >> docker-compose.yml << EOF
    depends_on:
      - web
EOF
    fi

    if [ "$CREATE_NETWORK" = "true" ]; then
        cat >> docker-compose.yml << EOF
    networks:
      - $NETWORK_NAME
EOF
    fi

    echo "" >> docker-compose.yml
fi

echo "" >> docker-compose.yml
echo "volumes:" >> docker-compose.yml

if echo "$SERVICES" | grep -q "db"; then
    echo "  postgres_data:" >> docker-compose.yml
fi

if echo "$SERVICES" | grep -q "redis"; then
    echo "  redis_data:" >> docker-compose.yml
fi

if [ "$CREATE_NETWORK" = "true" ]; then
    echo "" >> docker-compose.yml
    echo "networks:" >> docker-compose.yml
    echo "  $NETWORK_NAME:" >> docker-compose.yml
    echo "    driver: bridge" >> docker-compose.yml
fi

if echo "$SERVICES" | grep -q "web"; then
    cat > Dockerfile << EOF
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE $WEB_PORT

CMD ["npm", "start"]
EOF
fi

if echo "$SERVICES" | grep -q "nginx"; then
    cat > nginx.conf << EOF
events {
    worker_connections 1024;
}

http {
    upstream app {
        server web:$WEB_PORT;
    }

    server {
        listen 80;
        server_name localhost;

        location / {
            proxy_pass http://app;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOF
fi

cat > .env.docker << EOF
# Docker Compose Environment Variables
DB_USER=user
DB_PASSWORD=password
DB_NAME=$PROJECT_NAME
DB_HOST=db
DB_PORT=5432

# Redis
REDIS_HOST=redis
REDIS_PORT=6379

# Application
NODE_ENV=development
PORT=$WEB_PORT
EOF

echo "Docker Compose files created successfully!"
echo ""
echo "Files created:"
echo "  - docker-compose.yml"
[ -f "Dockerfile" ] && echo "  - Dockerfile"
[ -f "nginx.conf" ] && echo "  - nginx.conf"
echo "  - .env.docker"
echo ""
echo "To start services: docker-compose up"