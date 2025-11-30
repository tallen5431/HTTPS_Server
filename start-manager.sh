#!/bin/bash

echo "🚀 Starting HTTPS Server Manager"
echo "================================="
echo ""

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Detect IP address
DETECTED_IP=$(node -e "const {getPrimaryIpAddress} = require('./caddy_from_config'); console.log(getPrimaryIpAddress());")
echo "📡 Server IP: $DETECTED_IP"

# Set environment variables with smart defaults
export PORT="${PORT:-8061}"

# Auto-detect PROJECTS_DIR if not already set
if [ -z "$PROJECTS_DIR" ]; then
    # Try common locations
    if [ -d "$HOME/projects" ]; then
        export PROJECTS_DIR="$HOME/projects"
    elif [ -d "/home/jupyter-tj/projects" ]; then
        export PROJECTS_DIR="/home/jupyter-tj/projects"
    elif [ -d "$SCRIPT_DIR/../projects" ]; then
        export PROJECTS_DIR="$SCRIPT_DIR/../projects"
    else
        echo "⚠️  PROJECTS_DIR not set and no default found"
        echo "   Set it with: export PROJECTS_DIR=/path/to/your/projects"
        echo "   Or you can configure projects later via the UI"
    fi
fi

export PUBLIC_BASE="${PUBLIC_BASE:-https://$DETECTED_IP:8443}"
export CADDY_TLS_CERT="${CADDY_TLS_CERT:-$SCRIPT_DIR/certs/server.crt}"
export CADDY_TLS_KEY="${CADDY_TLS_KEY:-$SCRIPT_DIR/certs/server.key}"
export CADDYFILE_PATH="${CADDYFILE_PATH:-$SCRIPT_DIR/Caddyfile.generated}"
export CADDY_HTTPS_PORT="${CADDY_HTTPS_PORT:-8443}"
export MANAGER_PORT="${MANAGER_PORT:-8061}"
export CADDY_MANAGER_PATH="${CADDY_MANAGER_PATH:-/manager}"

echo "🔧 Configuration:"
echo "   Manager Port: $PORT"
if [ -n "$PROJECTS_DIR" ]; then
    echo "   Projects Dir: $PROJECTS_DIR"
fi
echo "   PUBLIC_BASE: $PUBLIC_BASE"
echo ""

# Start the manager
echo "🎬 Starting manager..."
echo ""
node server.js
