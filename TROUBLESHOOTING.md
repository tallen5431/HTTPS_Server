# HTTPS Server Manager - Troubleshooting Guide

## 🔴 Quick Fix: Start from Scratch

If you're having issues, run this to reset everything:

```bash
cd ~/HTTPS_Server  # Or wherever your HTTPS_Server directory is

# Stop everything
sudo systemctl stop caddy 2>/dev/null
sudo pkill -9 caddy
pkill -f "node server.js"

# Clean start
./setup-complete.sh
```

Then in another terminal:
```bash
cd ~/HTTPS_Server
./start-manager.sh
```

---

## Common Issues

### 1. "Permission Denied" when accessing certificates

**Error:**
```
open /home/jupyter-tj/HTTPS_Server/certs/server.crt: permission denied
```

**Cause:** System Caddy service (running as `caddy` user) can't access your home directory.

**Solution:**
```bash
# Stop system Caddy service
sudo systemctl stop caddy
sudo systemctl disable caddy  # Prevent auto-start

# Run the complete setup
./setup-complete.sh

# This runs Caddy as your current user with proper permissions
```

---

### 2. "Can't kill Caddy" / "Operation not permitted"

**Error:**
```
pkill: killing pid 6879 failed: Operation not permitted
```

**Cause:** Caddy is running as a different user (system service).

**Solution:**
```bash
# Use sudo to stop system Caddy
sudo systemctl stop caddy
sudo pkill -9 caddy

# Then run setup
./setup-complete.sh
```

---

### 3. Port 8443 Already in Use

**Error:**
```
address already in use
```

**Solution:**
```bash
# Find what's using port 8443
sudo lsof -i :8443
# or
sudo netstat -tulpn | grep 8443

# If it's Caddy, kill it
sudo pkill -9 caddy

# If it's something else, either:
# 1. Stop that service, or
# 2. Change the port in your config:
export CADDY_HTTPS_PORT=8444  # Use a different port
./setup-complete.sh
```

---

### 4. SSL Certificate Warnings in Browser

**What you see:**
"Your connection is not private" or "NET::ERR_CERT_AUTHORITY_INVALID"

**This is NORMAL!**

**Why:** You're using a self-signed certificate (not from a trusted authority).

**Solution:**
1. Click "Advanced"
2. Click "Proceed to <ip-address> (unsafe)" or "Accept the Risk and Continue"

**To avoid this in the future:**
- Option 1: Use Let's Encrypt (requires public domain)
- Option 2: Import your self-signed cert into your browser's trusted certificates
- Option 3: Just accept it each time (it's safe for local network use)

---

### 5. Manager UI Shows "No Programs"

**Cause:** Config file is empty or projects directory not set.

**Solution:**
```bash
# Option 1: Auto-discover from projects folder
node discover-projects.js /home/jupyter-tj/projects

# Option 2: Click "🔍 Rediscover" button in web UI

# Option 3: Set PROJECTS_DIR when starting
PROJECTS_DIR=/home/jupyter-tj/projects node server.js
```

---

### 6. Wrong IP Address in Caddyfile

**Symptom:** Caddyfile shows `192.168.1.245` but your IP is `192.168.1.21`

**Solution:**
```bash
# Regenerate with current IP
node caddy_from_config.js

# Or run complete setup
./setup-complete.sh
```

---

### 7. Programs Won't Start / "Start.sh not found"

**Error:**
```
Start script not found for program: myapp
```

**Cause:** Program path is wrong or Start.sh doesn't exist.

**Solution:**
```bash
# Check if Start.sh exists
ls -la /home/jupyter-tj/projects/YourApp/Start.sh

# If it doesn't exist, create one:
cat > /home/jupyter-tj/projects/YourApp/Start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
# Your start command here, for example:
# python app.py
# or
# npm start
EOF

chmod +x /home/jupyter-tj/projects/YourApp/Start.sh

# Then rediscover projects
node discover-projects.js /home/jupyter-tj/projects
```

---

### 8. Caddy Won't Start / Fails Immediately

**Solution:**
```bash
# Check Caddyfile syntax
caddy validate --config Caddyfile.generated --adapter caddyfile

# If there are errors, regenerate:
node caddy_from_config.js

# Check Caddy logs
tail -50 caddy.log

# Or run Caddy in foreground to see errors:
caddy run --config Caddyfile.generated --adapter caddyfile
```

---

### 9. Can't Access Apps from Other Devices

**Symptom:** Manager works from server but not from other computers.

**Possible causes:**

**1. Firewall blocking port 8443:**
```bash
# Ubuntu/Debian
sudo ufw allow 8443/tcp

# RHEL/CentOS
sudo firewall-cmd --permanent --add-port=8443/tcp
sudo firewall-cmd --reload

# Check if port is open
sudo netstat -tulpn | grep 8443
```

**2. Wrong IP in Caddyfile:**
```bash
# Check what IP Caddy is using
head -10 Caddyfile.generated

# Should match your server's IP
ip addr show | grep "inet "

# If wrong, regenerate:
./setup-complete.sh
```

**3. Accessing with wrong URL:**
```
❌ Wrong: https://localhost:8443/manager
❌ Wrong: https://127.0.0.1:8443/manager
✅ Right: https://192.168.1.21:8443/manager
```

---

### 10. Programs Show as "Stopped" but are Running

**Cause:** Program started outside the manager.

**Solution:**
```bash
# Stop all instances
pkill -f "python app.py"  # Or whatever your program is

# Use the manager to start them
# Click "Start" in the web UI
```

---

## Verification Checklist

Run these commands to check everything is working:

```bash
cd ~/HTTPS_Server

# 1. Check Caddy is running
ps aux | grep caddy | grep -v grep
# Should show: caddy run --config Caddyfile.generated

# 2. Check Manager is running
ps aux | grep "node server" | grep -v grep
# Should show: node server.js

# 3. Check ports are listening
sudo netstat -tulpn | grep -E ":(8443|8061)"
# Should show:
# :8443 - Caddy
# :8061 - Manager

# 4. Test Caddy (should return HTML)
curl -k https://localhost:8443/manager | head -5

# 5. Test Manager directly
curl http://localhost:8061 | head -5

# 6. Check config was discovered
cat config.json | jq '.programs[].name'

# 7. View recent logs
tail -20 caddy.log
```

---

## Clean Restart Procedure

If things are really messed up:

```bash
# 1. Stop EVERYTHING
sudo systemctl stop caddy 2>/dev/null
sudo pkill -9 caddy
pkill -f "node server"
pkill -f "Start.sh"

# 2. Remove old artifacts
rm -rf certs/ Caddyfile.generated caddy.log

# 3. Fresh setup
./setup-complete.sh

# 4. In another terminal, start manager
./start-manager.sh

# 5. Open in browser
# https://192.168.1.21:8443/manager
```

---

## Still Having Issues?

1. **Check the logs:**
   ```bash
   # Caddy logs
   tail -100 caddy.log

   # Manager output (if running in terminal)
   # Will show program start/stop events and errors
   ```

2. **Run in debug mode:**
   ```bash
   # Run Caddy in foreground to see all output
   caddy run --config Caddyfile.generated --adapter caddyfile

   # Run Manager with debug output
   DEBUG=* node server.js
   ```

3. **Check file permissions:**
   ```bash
   ls -la certs/
   # Should be readable: -rw-r--r--

   ls -la config.json
   # Should exist and be readable
   ```

4. **Verify your setup:**
   ```bash
   # Your directory structure should look like:
   tree -L 1
   # HTTPS_Server/
   # ├── certs/
   # ├── config.json
   # ├── Caddyfile.generated
   # ├── server.js
   # ├── discover-projects.js
   # ├── setup-complete.sh
   # └── start-manager.sh
   ```

---

## Environment-Specific Issues

### Running on Ubuntu/Debian

```bash
# If Caddy service keeps auto-starting
sudo systemctl disable caddy
sudo systemctl stop caddy
```

### Running in Docker/Container

The scripts expect to run on bare metal. For Docker, you'll need to:
1. Expose ports: `-p 8443:8443 -p 8061:8061`
2. Mount volumes for certs and config
3. Run with proper user permissions

### Running on macOS

Same instructions work, but use `brew install caddy` to install Caddy.

---

## Getting Help

If you're still stuck:

1. Check the main README.md for detailed configuration options
2. Review QUICKSTART.md for setup steps
3. Look at the generated files:
   - `config.json` - Your programs
   - `Caddyfile.generated` - Caddy configuration
   - `caddy.log` - Caddy errors

4. Common environment variables to check:
   ```bash
   echo $PROJECTS_DIR  # Should be /home/jupyter-tj/projects
   echo $PORT          # Should be 8061
   echo $PUBLIC_BASE   # Should be https://192.168.1.21:8443
   ```
