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

# Set environment variables
export PORT=8061
export PROJECTS_DIR="/home/jupyter-tj/projects"
export PUBLIC_BASE="https://$DETECTED_IP:8443"
export CADDY_TLS_CERT="$SCRIPT_DIR/certs/server.crt"
export CADDY_TLS_KEY="$SCRIPT_DIR/certs/server.key"
export CADDYFILE_PATH="$SCRIPT_DIR/Caddyfile.generated"
export CADDY_HTTPS_PORT="8443"
export MANAGER_PORT="8061"
export CADDY_MANAGER_PATH="/manager"

echo "🔧 Configuration:"
echo "   Manager Port: $PORT"
echo "   Projects Dir: $PROJECTS_DIR"
echo "   PUBLIC_BASE: $PUBLIC_BASE"
echo ""

# Start the manager
echo "🎬 Starting manager..."
echo ""
node server.js
