#!/bin/bash

echo "🔧 HTTPS Server Manager - Complete Setup"
echo "========================================="
echo ""

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Detect IP address
echo "📡 Detecting server IP address..."
DETECTED_IP=$(node -e "const {getPrimaryIpAddress} = require('./caddy_from_config'); console.log(getPrimaryIpAddress());")
echo "   Detected IP: $DETECTED_IP"
echo ""

# Stop system Caddy service if running
echo "🛑 Stopping system Caddy service (if running)..."
sudo systemctl stop caddy 2>/dev/null || echo "   No systemd service to stop"
sudo pkill -9 caddy 2>/dev/null || echo "   No running Caddy processes"
sleep 1
echo ""

# Create certs directory with proper permissions
echo "📁 Creating certificates directory..."
mkdir -p "$SCRIPT_DIR/certs"
chmod 755 "$SCRIPT_DIR/certs"
echo "   ✓ Created $SCRIPT_DIR/certs"
echo ""

# Generate self-signed certificate
echo "🔐 Generating self-signed SSL certificate..."
if [ ! -f "$SCRIPT_DIR/certs/server.crt" ] || [ ! -f "$SCRIPT_DIR/certs/server.key" ]; then
  openssl req -x509 -newkey rsa:4096 \
    -keyout "$SCRIPT_DIR/certs/server.key" \
    -out "$SCRIPT_DIR/certs/server.crt" \
    -days 365 -nodes \
    -subj "/CN=$DETECTED_IP" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:$DETECTED_IP" 2>/dev/null

  chmod 644 "$SCRIPT_DIR/certs/server.crt"
  chmod 644 "$SCRIPT_DIR/certs/server.key"

  echo "   ✓ Generated SSL certificate for $DETECTED_IP"
else
  echo "   ✓ SSL certificate already exists"
  chmod 644 "$SCRIPT_DIR/certs/server.crt" 2>/dev/null
  chmod 644 "$SCRIPT_DIR/certs/server.key" 2>/dev/null
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
node caddy_from_config.js > /dev/null 2>&1
echo "   ✓ Caddyfile.generated updated"
echo ""

# Check Caddyfile
echo "📋 Caddyfile summary:"
grep -E "^https://" Caddyfile.generated | head -1 | sed 's/^/   /'
grep -E "tls " Caddyfile.generated | head -1 | sed 's/^/   /'
PROGRAM_COUNT=$(grep -c "reverse_proxy" Caddyfile.generated)
echo "   Programs configured: $PROGRAM_COUNT"
echo ""

# Check if Caddy is installed
if ! command -v caddy &> /dev/null; then
  echo "❌ Caddy is not installed!"
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

# Start Caddy in background as current user
echo "🚀 Starting Caddy as current user..."
nohup caddy run --config "$SCRIPT_DIR/Caddyfile.generated" --adapter caddyfile > "$SCRIPT_DIR/caddy.log" 2>&1 &
CADDY_PID=$!
sleep 2

if ps -p $CADDY_PID > /dev/null 2>&1; then
  echo "   ✓ Caddy started successfully (PID: $CADDY_PID)"
  echo "   📝 Logs: $SCRIPT_DIR/caddy.log"
else
  echo "   ❌ Caddy failed to start. Check the logs:"
  cat "$SCRIPT_DIR/caddy.log"
  exit 1
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 Access your apps:"
echo "   Manager UI:  https://$DETECTED_IP:8443/manager"
echo ""
echo "🔗 Your Programs:"
grep "# " Caddyfile.generated | grep -v "^#" | grep -v "Auto-Generated" | grep -v "Application programs" | sed 's/^/   /'
echo ""
echo "⚠️  Accept the self-signed certificate warning in your browser"
echo ""
echo "ℹ️  Next steps:"
echo "   1. Start the manager: ./start-manager.sh"
echo "   2. Or manually: PROJECTS_DIR=/path/to/your/projects PORT=8061 node server.js"
echo ""
echo "📝 View Caddy logs: tail -f $SCRIPT_DIR/caddy.log"
echo "🛑 Stop Caddy: pkill caddy"
