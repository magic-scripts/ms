#!/bin/sh

# Set script identity for config system security
export MS_SCRIPT_ID="dockergen"

VERSION="0.0.1"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Try to load config system
if [ -f "$SCRIPT_DIR/../core/config.sh" ]; then
    . "$SCRIPT_DIR/../core/config.sh"
elif [ -f "$HOME/.local/share/magicscripts/core/config.sh" ]; then
    . "$HOME/.local/share/magicscripts/core/config.sh"
fi

usage() {
    echo "Usage: dockergen <runtime> [options]"
    echo ""
    echo "Runtimes:"
    echo "  node       Node.js application"
    echo "  python     Python application"
    echo "  go         Go application"
    echo "  java       Java application"
    echo "  rust       Rust application"
    echo ""
    echo "Options:"
    echo "  -p <port>  Application port (default: runtime-specific)"
    echo "  -o <file>  Output file (default: Dockerfile)"
    echo "  -h         Show this help"
    echo ""
    echo "Configuration Keys Used:"
    echo "  DEFAULT_NODE_VERSION   Default Node.js version"
    echo "  DEFAULT_PYTHON_VERSION Default Python version"
    echo ""
    echo "Examples:"
    echo "  dockergen node                    # Generate Node.js Dockerfile"
    echo "  dockergen python -p 8000         # Generate Python Dockerfile on port 8000"
    echo "  dockergen go -o Dockerfile.go    # Generate Go Dockerfile to custom file"
}

if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
    exit 0
fi

# Handle version flag first
case "$1" in
    -v|--version) echo "dockergen v$VERSION"; exit 0 ;;
    -h|--help) usage; exit 0 ;;
esac

RUNTIME="$1"
shift

# Load configuration values
if command -v get_config_value >/dev/null 2>&1; then
    NODE_VERSION=$(get_config_value "DEFAULT_NODE_VERSION" "18" 2>/dev/null)
    PYTHON_VERSION=$(get_config_value "DEFAULT_PYTHON_VERSION" "3.11" 2>/dev/null)
else
    NODE_VERSION="18"
    PYTHON_VERSION="3.11"
fi

# Default values based on runtime
case "$RUNTIME" in
    node) DEFAULT_PORT=3000 ;;
    python) DEFAULT_PORT=8000 ;;
    go) DEFAULT_PORT=8080 ;;
    java) DEFAULT_PORT=8080 ;;
    rust) DEFAULT_PORT=8080 ;;
    *) echo "Error: Unsupported runtime: $RUNTIME"; usage; exit 1 ;;
esac

PORT="$DEFAULT_PORT"
OUTPUT="Dockerfile"

# Parse options
while [ $# -gt 0 ]; do
    case $1 in
        -p) PORT="$2"; shift 2 ;;
        -o) OUTPUT="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        -v|--version) echo "dockergen v$VERSION"; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# Generate Dockerfile based on runtime
case "$RUNTIME" in
    node)
        cat > "$OUTPUT" << EOF
# Node.js Dockerfile
FROM node:${NODE_VERSION}-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy application code
COPY . .

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \\
    adduser -S nextjs -u 1001

# Change ownership of app directory
RUN chown -R nextjs:nodejs /app
USER nextjs

# Expose port
EXPOSE $PORT

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
    CMD node healthcheck.js || exit 1

# Start application
CMD ["npm", "start"]
EOF
        ;;
    python)
        cat > "$OUTPUT" << EOF
# Python Dockerfile
FROM python:${PYTHON_VERSION}-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update \\
    && apt-get install -y --no-install-recommends \\
        build-essential \\
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user
RUN adduser --disabled-password --gecos '' appuser
RUN chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE $PORT

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
    CMD python healthcheck.py || exit 1

# Start application
CMD ["python", "app.py"]
EOF
        ;;
    go)
        cat > "$OUTPUT" << EOF
# Go Dockerfile - Multi-stage build
FROM golang:1.21-alpine AS builder

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Final stage
FROM alpine:latest

# Install ca-certificates for HTTPS requests
RUN apk --no-cache add ca-certificates

# Set working directory
WORKDIR /root/

# Copy binary from builder
COPY --from=builder /app/main .

# Expose port
EXPOSE $PORT

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
    CMD ./main --health-check || exit 1

# Start application
CMD ["./main"]
EOF
        ;;
    java)
        cat > "$OUTPUT" << EOF
# Java Dockerfile - Multi-stage build
FROM maven:3.9-openjdk-17 AS builder

# Set working directory
WORKDIR /app

# Copy pom.xml first for better caching
COPY pom.xml .

# Download dependencies
RUN mvn dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the application
RUN mvn clean package -DskipTests

# Final stage
FROM openjdk:17-jre-slim

# Set working directory
WORKDIR /app

# Copy jar from builder
COPY --from=builder /app/target/*.jar app.jar

# Create non-root user
RUN addgroup --system javauser && adduser --system --group javauser
USER javauser

# Expose port
EXPOSE $PORT

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
    CMD java -cp app.jar HealthCheck || exit 1

# Start application
CMD ["java", "-jar", "app.jar"]
EOF
        ;;
    rust)
        cat > "$OUTPUT" << EOF
# Rust Dockerfile - Multi-stage build
FROM rust:1.75 AS builder

# Set working directory
WORKDIR /app

# Copy Cargo files
COPY Cargo.toml Cargo.lock ./

# Create dummy main.rs to build dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs

# Build dependencies
RUN cargo build --release

# Copy source code
COPY src ./src

# Build the application
RUN cargo build --release

# Final stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update \\
    && apt-get install -y --no-install-recommends \\
        ca-certificates \\
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/target/release/* ./

# Create non-root user
RUN adduser --disabled-password --gecos '' rustuser
USER rustuser

# Expose port
EXPOSE $PORT

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
    CMD ./healthcheck || exit 1

# Start application
CMD ["./main"]
EOF
        ;;
esac

echo "✅ Generated $RUNTIME Dockerfile: $OUTPUT"
echo "📝 Port: $PORT"
echo ""
echo "Next steps:"
echo "  1. Review and customize the generated Dockerfile"
echo "  2. Create a .dockerignore file to exclude unnecessary files"
echo "  3. Build: docker build -t $RUNTIME-app ."
echo "  4. Run: docker run -p $PORT:$PORT $RUNTIME-app"