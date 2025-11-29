#!/usr/bin/env bash
set -euo pipefail

UNIT_FILE="/etc/systemd/system/https-server.service"
BACKUP_SUFFIX="$(date +%Y%m%d-%H%M%S)"

echo "=== Updating ${UNIT_FILE} for HTTPS_Server ==="

# Backup existing unit if present
if [ -f "${UNIT_FILE}" ]; then
  BACKUP_FILE="${UNIT_FILE}.bak-${BACKUP_SUFFIX}"
  echo "Backing up existing unit to ${BACKUP_FILE}"
  sudo cp "${UNIT_FILE}" "${BACKUP_FILE}"
else
  echo "No existing unit file found at ${UNIT_FILE}, creating a new one."
fi

echo "Writing updated unit file..."
sudo tee "${UNIT_FILE}" >/dev/null << 'EOF'
[Unit]
Description=HTTPS Server Manager (UI + launcher)
After=network.target

[Service]
Type=simple

User=jupyter-tj
WorkingDirectory=/home/jupyter-tj/HTTPS_Server

ExecStart=/usr/bin/npm start
Environment=NODE_ENV=production

# Make the Node app bind to 8061 instead of the default 3000
Environment=PORT=8061

# Restart even on clean exit (needed for Restart Manager button)
Restart=always
RestartSec=3

# Path to config.json for the HTTPS server
Environment=CONFIG_FILE=/home/jupyter-tj/HTTPS_Server/config.json

# Tell Caddy generator where the manager listens internally
Environment=MANAGER_PORT=8061

# Where caddy_from_config.js should write the generated Caddyfile
Environment=CADDYFILE_PATH=/home/jupyter-tj/HTTPS_Server/Caddyfile.generated

# Optional: if you want automatic Caddy reloads when the Caddyfile regenerates,
# uncomment this and configure sudoers so jupyter-tj can run it without a password.
# Environment=CADDY_RELOAD_CMD=/usr/bin/sudo /usr/bin/systemctl reload caddy

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd..."
sudo systemctl daemon-reload

echo "Enabling https-server.service on boot..."
sudo systemctl enable https-server.service

echo "Restarting https-server.service..."
sudo systemctl restart https-server.service

echo "Showing status:"
sudo systemctl status https-server.service --no-pager
