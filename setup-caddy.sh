#!/bin/bash

echo "🔧 HTTPS Server Manager - Caddy Setup Script"
echo "=============================================="
echo ""

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Detect IP address
echo "📡 Detecting server IP address..."
DETECTED_IP=$(node -e "const {getPrimaryIpAddress} = require('./caddy_from_config'); console.log(getPrimaryIpAddress());")
echo "   Detected IP: $DETECTED_IP"
echo ""

# Create certs directory
echo "📁 Creating certificates directory..."
mkdir -p ./certs
echo "   ✓ Created ./certs"
echo ""

# Generate self-signed certificate
echo "🔐 Generating self-signed SSL certificate..."
if [ ! -f "./certs/server.crt" ] || [ ! -f "./certs/server.key" ]; then
  openssl req -x509 -newkey rsa:4096 \
    -keyout "./certs/server.key" \
    -out "./certs/server.crt" \
    -days 365 -nodes \
    -subj "/CN=$DETECTED_IP" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:$DETECTED_IP"

  echo "   ✓ Generated SSL certificate for $DETECTED_IP"
else
  echo "   ✓ SSL certificate already exists"
fi
echo ""

# Set environment variables for Caddy
echo "🔧 Configuring Caddy environment..."
export PUBLIC_BASE="https://$DETECTED_IP:8443"
export CADDY_TLS_CERT="$SCRIPT_DIR/certs/server.crt"
export CADDY_TLS_KEY="$SCRIPT_DIR/certs/server.key"
export CADDYFILE_PATH="$SCRIPT_DIR/Caddyfile.generated"
export CADDY_HTTPS_PORT="8443"
export MANAGER_PORT="8061"

echo "   PUBLIC_BASE=$PUBLIC_BASE"
echo "   CADDY_TLS_CERT=$CADDY_TLS_CERT"
echo "   CADDY_TLS_KEY=$CADDY_TLS_KEY"
echo ""

# Regenerate Caddyfile with correct settings
echo "📝 Regenerating Caddyfile with correct IP and certificates..."
node caddy_from_config.js > /dev/null
echo "   ✓ Caddyfile.generated updated"
echo ""

# Check Caddyfile
echo "📋 Caddyfile summary:"
echo "   Domain: https://$DETECTED_IP"
grep -E "^https://" Caddyfile.generated | head -1 | sed 's/^/   /'
grep -E "tls " Caddyfile.generated | head -1 | sed 's/^/   /'
echo ""

# Check if Caddy is installed
if ! command -v caddy &> /dev/null; then
  echo "⚠️  Caddy is not installed!"
  echo ""
  echo "To install Caddy:"
  echo "  Ubuntu/Debian: sudo apt install caddy"
  echo "  RHEL/CentOS:   sudo yum install caddy"
  echo "  macOS:         brew install caddy"
  echo "  Or download from: https://caddyserver.com/download"
  echo ""
  exit 1
fi

echo "✅ Caddy is installed: $(caddy version)"
echo ""

# Check if Caddy is already running
if pgrep -x "caddy" > /dev/null; then
  echo "🔄 Caddy is already running. Reloading configuration..."
  caddy reload --config "$SCRIPT_DIR/Caddyfile.generated" --adapter caddyfile 2>&1
  if [ $? -eq 0 ]; then
    echo "   ✓ Caddy reloaded successfully"
  else
    echo "   ❌ Failed to reload Caddy"
    echo "   Trying to restart..."
    pkill caddy
    sleep 2
    caddy run --config "$SCRIPT_DIR/Caddyfile.generated" --adapter caddyfile &
    echo "   ✓ Caddy restarted"
  fi
else
  echo "🚀 Starting Caddy..."
  caddy run --config "$SCRIPT_DIR/Caddyfile.generated" --adapter caddyfile &
  CADDY_PID=$!
  sleep 2

  if ps -p $CADDY_PID > /dev/null; then
    echo "   ✓ Caddy started successfully (PID: $CADDY_PID)"
  else
    echo "   ❌ Caddy failed to start. Check the logs:"
    caddy run --config "$SCRIPT_DIR/Caddyfile.generated" --adapter caddyfile
    exit 1
  fi
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 Access your apps:"
echo "   Manager UI:  https://$DETECTED_IP:8443/manager"
echo "   CamScan:     https://$DETECTED_IP:8443/camscan"
echo "   CodeSmith:   https://$DETECTED_IP:8443/codesmith"
echo "   ... and more (see config.json)"
echo ""
echo "ℹ️  Accept the self-signed certificate warning in your browser"
echo ""
echo "To stop Caddy: pkill caddy"
echo "To reload Caddy: caddy reload --config $SCRIPT_DIR/Caddyfile.generated --adapter caddyfile"
