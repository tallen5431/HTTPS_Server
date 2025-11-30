#!/bin/bash

# HTTPS Server Manager - One-Command Setup Script
# ==================================================
# This script handles everything needed to get your HTTPS server running
#
# Usage:
#   ./setup.sh [projects-directory]
#
# Examples:
#   ./setup.sh                          # Uses ~/projects by default
#   ./setup.sh /path/to/your/projects   # Custom projects directory

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

print_header "HTTPS Server Manager - Complete Setup"

# ==================================================
# Step 1: Check Dependencies
# ==================================================
echo -e "${BLUE}Step 1/7: Checking dependencies...${NC}"
echo ""

MISSING_DEPS=0

# Check Node.js
if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed"
    echo "   Install from: https://nodejs.org/"
    echo "   Or use: sudo apt install nodejs (Ubuntu/Debian)"
    MISSING_DEPS=1
else
    NODE_VERSION=$(node --version)
    print_success "Node.js installed: $NODE_VERSION"
fi

# Check npm
if ! command -v npm &> /dev/null; then
    print_error "npm is not installed"
    echo "   Install from: https://nodejs.org/"
    echo "   Or use: sudo apt install npm (Ubuntu/Debian)"
    MISSING_DEPS=1
else
    NPM_VERSION=$(npm --version)
    print_success "npm installed: $NPM_VERSION"
fi

# Check OpenSSL
if ! command -v openssl &> /dev/null; then
    print_error "openssl is not installed"
    echo "   Install: sudo apt install openssl (Ubuntu/Debian)"
    MISSING_DEPS=1
else
    print_success "openssl installed"
fi

# Check Caddy
if ! command -v caddy &> /dev/null; then
    print_warning "Caddy is not installed (optional but recommended for HTTPS)"
    echo ""
    echo "   To install Caddy:"
    echo "   - Ubuntu/Debian: sudo apt install caddy"
    echo "   - macOS: brew install caddy"
    echo "   - Or download from: https://caddyserver.com/download"
    echo ""
    echo "   You can skip Caddy for now and run in HTTP-only mode"
    echo ""
    read -p "   Continue without Caddy? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    USE_CADDY=false
else
    CADDY_VERSION=$(caddy version | head -1)
    print_success "Caddy installed: $CADDY_VERSION"
    USE_CADDY=true
fi

echo ""

if [ $MISSING_DEPS -eq 1 ]; then
    print_error "Missing required dependencies. Please install them and try again."
    exit 1
fi

# ==================================================
# Step 2: Install npm Dependencies
# ==================================================
echo -e "${BLUE}Step 2/7: Installing npm dependencies...${NC}"
echo ""

if [ ! -d "node_modules" ] || [ ! -f "node_modules/.package-lock.json" ]; then
    print_info "Installing Node.js packages..."
    npm install
    print_success "Dependencies installed"
else
    print_success "Dependencies already installed"
fi

echo ""

# ==================================================
# Step 3: Detect or Configure Projects Directory
# ==================================================
echo -e "${BLUE}Step 3/7: Configuring projects directory...${NC}"
echo ""

# Use argument, environment variable, or default
if [ -n "$1" ]; then
    PROJECTS_DIR="$1"
elif [ -n "$PROJECTS_DIR" ]; then
    # Already set in environment
    PROJECTS_DIR="$PROJECTS_DIR"
else
    # Default to ~/projects
    PROJECTS_DIR="$HOME/projects"
fi

# Convert to absolute path
PROJECTS_DIR="$(realpath "$PROJECTS_DIR" 2>/dev/null || echo "$PROJECTS_DIR")"

if [ -d "$PROJECTS_DIR" ]; then
    print_success "Projects directory: $PROJECTS_DIR"

    # Count projects with Start.sh
    PROJECT_COUNT=$(find "$PROJECTS_DIR" -maxdepth 2 -name "Start.sh" -type f 2>/dev/null | wc -l)
    if [ $PROJECT_COUNT -gt 0 ]; then
        print_info "Found $PROJECT_COUNT project(s) with Start.sh"
    else
        print_warning "No projects with Start.sh found in $PROJECTS_DIR"
        print_info "You can add projects later and use the 'Rediscover' button in the UI"
    fi
else
    print_warning "Projects directory does not exist: $PROJECTS_DIR"
    read -p "   Create it now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$PROJECTS_DIR"
        print_success "Created: $PROJECTS_DIR"
        print_info "Add your projects there with Start.sh files"
    else
        print_info "Continuing without projects directory"
        print_info "You can configure it later with: PROJECTS_DIR=/path/to/projects node server.js"
    fi
fi

echo ""

# ==================================================
# Step 4: Detect IP Address
# ==================================================
echo -e "${BLUE}Step 4/7: Detecting network configuration...${NC}"
echo ""

DETECTED_IP=$(node -e "const {getPrimaryIpAddress} = require('./caddy_from_config'); console.log(getPrimaryIpAddress());")
print_success "Server IP: $DETECTED_IP"

echo ""

# ==================================================
# Step 5: Generate SSL Certificates
# ==================================================
echo -e "${BLUE}Step 5/7: Setting up SSL certificates...${NC}"
echo ""

mkdir -p "$SCRIPT_DIR/certs"
chmod 755 "$SCRIPT_DIR/certs"

if [ ! -f "$SCRIPT_DIR/certs/server.crt" ] || [ ! -f "$SCRIPT_DIR/certs/server.key" ]; then
    print_info "Generating self-signed SSL certificate..."

    openssl req -x509 -newkey rsa:4096 \
        -keyout "$SCRIPT_DIR/certs/server.key" \
        -out "$SCRIPT_DIR/certs/server.crt" \
        -days 365 -nodes \
        -subj "/CN=$DETECTED_IP" \
        -addext "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:$DETECTED_IP" 2>/dev/null || {
        print_warning "Could not add subjectAltName (old OpenSSL version)"
        openssl req -x509 -newkey rsa:4096 \
            -keyout "$SCRIPT_DIR/certs/server.key" \
            -out "$SCRIPT_DIR/certs/server.crt" \
            -days 365 -nodes \
            -subj "/CN=$DETECTED_IP"
    }

    chmod 644 "$SCRIPT_DIR/certs/server.crt"
    chmod 644 "$SCRIPT_DIR/certs/server.key"

    print_success "SSL certificate generated for $DETECTED_IP"
else
    print_success "SSL certificates already exist"
    chmod 644 "$SCRIPT_DIR/certs/server.crt" 2>/dev/null || true
    chmod 644 "$SCRIPT_DIR/certs/server.key" 2>/dev/null || true
fi

echo ""

# ==================================================
# Step 6: Generate Configuration
# ==================================================
echo -e "${BLUE}Step 6/7: Generating configuration...${NC}"
echo ""

# Generate config.json if it doesn't exist
if [ ! -f "$SCRIPT_DIR/config.json" ]; then
    if [ -d "$PROJECTS_DIR" ]; then
        print_info "Auto-discovering projects..."
        node discover-projects.js "$PROJECTS_DIR"
        print_success "Configuration generated"
    else
        print_info "Creating default configuration..."
        cat > "$SCRIPT_DIR/config.json" << EOF
{
  "hostname": "auto",
  "programs": [],
  "ssl": {
    "cert": "./certs/server.crt",
    "key": "./certs/server.key",
    "autoGenerate": true
  }
}
EOF
        print_success "Default configuration created"
        print_info "Add projects later using the Rediscover button in the UI"
    fi
else
    print_success "Configuration already exists"
fi

# Generate Caddyfile if using Caddy
if [ "$USE_CADDY" = true ]; then
    print_info "Generating Caddyfile..."

    export PUBLIC_BASE="https://$DETECTED_IP:8443"
    export CADDY_TLS_CERT="$SCRIPT_DIR/certs/server.crt"
    export CADDY_TLS_KEY="$SCRIPT_DIR/certs/server.key"
    export CADDYFILE_PATH="$SCRIPT_DIR/Caddyfile.generated"
    export CADDY_HTTPS_PORT="8443"
    export MANAGER_PORT="8061"

    node caddy_from_config.js

    print_success "Caddyfile generated"
fi

echo ""

# ==================================================
# Step 7: Start Services
# ==================================================
echo -e "${BLUE}Step 7/7: Starting services...${NC}"
echo ""

# Stop any existing Caddy processes
if [ "$USE_CADDY" = true ]; then
    print_info "Stopping any existing Caddy processes..."

    # Try to stop systemd service (needs sudo)
    if command -v systemctl &> /dev/null; then
        sudo systemctl stop caddy 2>/dev/null && print_success "Stopped system Caddy service" || true
    fi

    # Kill any user Caddy processes
    pkill -u "$USER" caddy 2>/dev/null && print_success "Stopped user Caddy processes" || true

    sleep 1

    # Start Caddy
    print_info "Starting Caddy..."
    nohup caddy run --config "$SCRIPT_DIR/Caddyfile.generated" --adapter caddyfile > "$SCRIPT_DIR/caddy.log" 2>&1 &
    CADDY_PID=$!
    sleep 2

    if ps -p $CADDY_PID > /dev/null 2>&1; then
        print_success "Caddy started (PID: $CADDY_PID)"
        echo "   Logs: tail -f $SCRIPT_DIR/caddy.log"
    else
        print_error "Caddy failed to start. Check logs:"
        cat "$SCRIPT_DIR/caddy.log"
        exit 1
    fi
fi

echo ""

# ==================================================
# Setup Complete!
# ==================================================
print_header "Setup Complete!"

echo -e "${GREEN}Your HTTPS Server Manager is ready!${NC}"
echo ""

if [ "$USE_CADDY" = true ]; then
    echo -e "${BLUE}Access your manager:${NC}"
    echo "  🌐 https://$DETECTED_IP:8443/manager"
    echo "  🌐 https://localhost:8443/manager (from this machine)"
    echo ""
    echo -e "${YELLOW}Note: Accept the self-signed certificate warning in your browser${NC}"
    echo ""
fi

echo -e "${BLUE}Next steps:${NC}"
echo ""
echo "1. Start the manager in another terminal:"
echo -e "   ${GREEN}cd $SCRIPT_DIR${NC}"
if [ -d "$PROJECTS_DIR" ]; then
    echo -e "   ${GREEN}PROJECTS_DIR=\"$PROJECTS_DIR\" PORT=8061 node server.js${NC}"
else
    echo -e "   ${GREEN}PORT=8061 node server.js${NC}"
fi
echo ""
echo "   Or use the start script:"
echo -e "   ${GREEN}./start-manager.sh${NC}"
echo ""

if [ "$USE_CADDY" = true ]; then
    echo "2. Open https://$DETECTED_IP:8443/manager in your browser"
else
    echo "2. Open http://localhost:3000 in your browser"
fi
echo ""
echo "3. Use the UI to start/stop your applications"
echo ""

echo -e "${BLUE}Useful commands:${NC}"
if [ "$USE_CADDY" = true ]; then
    echo "  Stop Caddy:    pkill caddy"
    echo "  View logs:     tail -f caddy.log"
    echo "  Restart Caddy: ./setup-caddy.sh"
fi
echo "  Stop manager:  pkill -f 'node server.js'"
if [ -d "$PROJECTS_DIR" ]; then
    echo "  Rediscover:    node discover-projects.js \"$PROJECTS_DIR\""
fi
echo ""

# Create a simple start script for convenience
cat > "$SCRIPT_DIR/start.sh" << EOF
#!/bin/bash
cd "$SCRIPT_DIR"
PROJECTS_DIR="$PROJECTS_DIR" PORT=8061 node server.js
EOF
chmod +x "$SCRIPT_DIR/start.sh"

print_success "Created convenience script: ./start.sh"
echo ""

echo -e "${GREEN}Setup complete! 🎉${NC}"
