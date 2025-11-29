# HTTPS Server Manager - Quick Start Guide

## 🚀 Quick Setup (3 Steps)

### Step 1: Install Caddy (if not installed)

```bash
# Ubuntu/Debian
sudo apt install caddy

# RHEL/CentOS
sudo yum install caddy

# macOS
brew install caddy

# Or download from: https://caddyserver.com/download
```

### Step 2: Run the Setup Script

```bash
cd /home/user/HTTPS_Server
./setup-caddy.sh
```

This will:
- ✅ Auto-detect your server IP
- ✅ Generate SSL certificates
- ✅ Create Caddyfile with correct configuration
- ✅ Start Caddy reverse proxy

### Step 3: Start the Manager

```bash
./start-manager.sh
```

Or manually:
```bash
PROJECTS_DIR=/home/jupyter-tj/projects PORT=8061 node server.js
```

## 📋 Access Your Applications

After setup, your apps will be available at:

- **Manager UI**: `https://<your-ip>:8443/manager`
- **Your Apps**: `https://<your-ip>:8443/appname`

Example:
- `https://192.168.1.21:8443/manager`
- `https://192.168.1.21:8443/camscan`
- `https://192.168.1.21:8443/codesmith`

**Note**: Your browser will show a security warning because it's a self-signed certificate. Click "Advanced" → "Proceed" to continue.

## 🔧 Troubleshooting

### SSL Error / Connection Failed

**Problem**: "Secure Connection Failed" or SSL_ERROR_INTERNAL_ERROR_ALERT

**Solution**:
```bash
# Check if Caddy is running
ps aux | grep caddy

# If not running, restart setup
./setup-caddy.sh

# Check Caddyfile was generated correctly
cat Caddyfile.generated | head -20
```

### Wrong IP Address

**Problem**: Caddyfile shows wrong IP address

**Solution**:
```bash
# Regenerate with current IP
node caddy_from_config.js

# Or re-run setup
./setup-caddy.sh
```

### Programs Not Showing in UI

**Problem**: Manager UI shows no programs or is empty

**Solution**:
```bash
# Rediscover projects
node discover-projects.js /home/jupyter-tj/projects

# Or click "🔍 Rediscover" button in web UI
```

### Caddy Won't Start

**Problem**: Caddy fails to start

**Possible causes**:
1. Port 8443 already in use
2. Certificate files missing
3. Caddyfile has syntax errors

**Solution**:
```bash
# Check what's using port 8443
sudo lsof -i :8443
# Or
sudo netstat -tulpn | grep 8443

# Kill other process if needed
sudo kill <PID>

# Check Caddyfile syntax
caddy validate --config Caddyfile.generated --adapter caddyfile

# Re-run setup
./setup-caddy.sh
```

## 📝 Manual Configuration

If you prefer manual setup:

### 1. Set Environment Variables

```bash
export PUBLIC_BASE="https://192.168.1.21:8443"
export CADDY_TLS_CERT="./certs/server.crt"
export CADDY_TLS_KEY="./certs/server.key"
export PROJECTS_DIR="/home/jupyter-tj/projects"
export MANAGER_PORT="8061"
```

### 2. Generate Certificates

```bash
mkdir -p ./certs
openssl req -x509 -newkey rsa:4096 \
  -keyout "./certs/server.key" \
  -out "./certs/server.crt" \
  -days 365 -nodes \
  -subj "/CN=192.168.1.21" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1,IP:192.168.1.21"
```

### 3. Generate Caddyfile

```bash
node caddy_from_config.js
```

### 4. Start Caddy

```bash
caddy run --config Caddyfile.generated --adapter caddyfile &
```

### 5. Start Manager

```bash
node server.js
```

## 🎯 Common Commands

```bash
# Stop everything
pkill caddy
pkill node

# Restart Caddy
pkill caddy
./setup-caddy.sh

# Restart Manager
pkill -f "node server.js"
./start-manager.sh

# View Caddy logs
caddy run --config Caddyfile.generated --adapter caddyfile

# Reload Caddy config (without restart)
caddy reload --config Caddyfile.generated --adapter caddyfile

# Check what's running
ps aux | grep caddy
ps aux | grep "node server"
```

## 🔍 Verification

Check everything is working:

```bash
# 1. Check Caddy is running
ps aux | grep caddy

# 2. Check Manager is running
ps aux | grep "node server"

# 3. Test Caddy is listening
curl -k https://localhost:8443/manager

# 4. Test Manager UI
curl http://localhost:8061

# 5. Check generated config
cat config.json

# 6. Check Caddyfile
cat Caddyfile.generated
```

## 📚 More Help

- Full documentation: `README.md`
- Auto-discovery: `node discover-projects.js --help`
- Environment variables: See `README.md` Environment Variables section
