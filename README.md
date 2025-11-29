# HTTPS Server Manager

A secure, self-configuring HTTPS server manager that automatically detects your network configuration and manages multiple applications with zero manual IP configuration. Perfect for hosting web applications over LAN and internet with automatic Caddy reverse proxy integration.

## Features

- **🎯 Automatic IP Detection**: Zero-configuration setup - automatically detects your server's network IP
- **🔄 Auto Caddy Integration**: Generates Caddy reverse proxy configuration automatically from your programs
- **🔐 HTTPS Support**: Secure connections with automatic self-signed certificate generation
- **⚡ Process Management**: Start, stop, and restart programs with a single click
- **📡 Real-time Updates**: WebSocket-based live status updates
- **📋 Log Viewing**: View and search program logs directly in the web interface
- **🔗 Smart URL Generation**: Automatic URL generation that works from anywhere (localhost, LAN, internet)
- **🎨 Clean Web UI**: Modern, responsive interface that works on desktop and mobile
- **🌐 Multi-program Support**: Manage multiple applications from a single interface
- **📦 PUBLIC_BASE Auto-Injection**: Automatically provides apps with correct base URL for reverse proxy

## Prerequisites

...

## Configuration

### Hostname Configuration

At the root level of `config.json`, you can optionally specify a hostname for URL generation:

- **hostname**: Hostname to use for auto-generated program URLs (optional)
  - `"auto"` (default): Automatically detects the server's primary network IP address
  - Specific IP/hostname: Use a custom value (e.g., `"192.168.1.100"` or `"myserver.local"`)
  - Can also be set via `HOST` environment variable

The hostname is used when auto-generating URLs from PORT environment variables. The manager intelligently detects your server's network IP (prioritizing eth0, en0, wlan0) so that URLs work whether you access the manager from:
- The local machine: `http://localhost:3000`
- Other devices on your network: `http://192.168.1.100:3000`
- A domain name: `http://myserver.local:3000`

### Programs

Each program in the `programs` array should have:

- **id**: Unique identifier for the program (required)
- **name**: Display name shown in the web interface (required)
- **path**: Absolute path to the program directory containing Start.sh (required)
- **url**: URL where the program can be accessed (optional)
  - If provided, this URL will be used
  - If NOT provided, the URL will be **auto-generated** from the PORT environment variable
  - Auto-generated format: `http://<hostname>:PORT` where hostname is your configured/detected IP
  - Can be HTTP or HTTPS (e.g., `http://localhost:8001` or `https://myapp.com`)
  - When a URL exists (manual or auto-generated), the program name becomes clickable and an "Open" button appears
- **env**: Environment variables to pass to the program (optional)
  - If you set a `PORT` variable here, a URL will be automatically generated using the configured hostname

#### Auto-Generated URLs

The manager can automatically generate URLs for your programs! Here's how it works:

**With PORT environment variable (auto-generated):**
```json
{
  "id": "my-app",
  "name": "My Application",
  "path": "/path/to/your/app",
  "env": {
    "PORT": "8001"
  }
}
```
→ Auto-generates URL: `http://<detected-ip>:8001` (e.g., `http://192.168.1.100:8001`)
→ The URL adapts based on how you access the manager (localhost when local, network IP when remote)

**With manual URL override:**
```json
{
  "id": "my-app",
  "name": "My Application",
  "path": "/path/to/your/app",
  "url": "https://myapp.example.com",
  "env": {
    "PORT": "8001"
  }
}
```
→ Uses manual URL: `https://myapp.example.com`

**Without PORT or URL (no clickable link):**
```json
{
  "id": "my-app",
  "name": "My Application",
  "path": "/path/to/your/app"
}
```
→ No URL available (program still works, just no link)

> When you use `caddy_from_config.js`, only programs with a `url` are turned into `handle_path` blocks. If you want a path like `/codesmith` on your HTTPS endpoint, make sure the program has a `url` whose path is `/codesmith` (for example, `"/codesmith"` or `"/codesmith"`).

### Automatic IP Detection

The HTTPS Server Manager automatically detects your server's network IP address, eliminating the need for manual configuration:

**What's Auto-Detected:**
- Server's primary network IP (prioritizes eth0, en0, wlan0 interfaces)
- Automatically used for:
  - Program URL generation (shown in web UI)
  - Caddy reverse proxy configuration
  - PUBLIC_BASE environment variable injection

**How It Works:**
1. **Network IP Detection**: Scans network interfaces to find your primary IPv4 address
2. **Caddy Configuration**: Auto-generates `Caddyfile.generated` with detected IP
3. **PUBLIC_BASE Injection**: Automatically injects `PUBLIC_BASE=https://<detected-ip>:8443` into each program's environment
4. **Client URL Resolution**: Web UI rewrites localhost to actual hostname for remote access

**Benefits:**
- ✅ Works immediately on any network without manual IP configuration
- ✅ Programs receive correct PUBLIC_BASE automatically (no hardcoded IPs in config)
- ✅ Caddy reverse proxy configuration updates automatically
- ✅ Access from anywhere: localhost, LAN, or internet (with port forwarding)

**Example:** If your server's IP is `192.168.1.100`, the system automatically:
- Generates Caddyfile with `https://192.168.1.100 { ... }`
- Injects `PUBLIC_BASE=https://192.168.1.100:8443` into program environments
- Shows clickable URLs as `https://192.168.1.100:8443/yourapp`

### Caddy Reverse Proxy Integration

The manager can automatically generate Caddy configuration from your `config.json`:

**Auto-Generation:**
```bash
# Automatically generates Caddyfile.generated on startup
node server.js
```

**Manual Generation:**
```bash
# Generate Caddyfile and write to default location
CADDYFILE_PATH=./Caddyfile.generated node caddy_from_config.js

# Or output to stdout
node caddy_from_config.js > Caddyfile
```

**Environment Variables for Caddy:**
- `PUBLIC_BASE`: Override auto-detected IP (e.g., `https://myserver.com:8443`)
- `CADDYFILE_PATH`: Output path for generated Caddyfile (default: `./Caddyfile.generated`)
- `CADDY_TLS_CERT`: TLS certificate path (default: `/etc/ssl/caddy/nuc-selfsign.crt`)
- `CADDY_TLS_KEY`: TLS key path (default: `/etc/ssl/caddy/nuc-selfsign.key`)
- `CADDY_HTTPS_PORT`: HTTPS port for Caddy (default: `8443`)
- `MANAGER_PORT`: Manager UI port (default: `8061`)
- `CADDY_MANAGER_PATH`: Manager UI path (default: `/manager`)
- `CADDY_RELOAD_CMD`: Shell command to reload Caddy after config changes

**Program Configuration for Caddy:**

For apps behind Caddy reverse proxy, set both `url` and appropriate environment variables:

```json
{
  "id": "my-app",
  "name": "My Application",
  "path": "/path/to/app",
  "url": "/myapp",
  "env": {
    "HOST": "0.0.0.0",
    "PORT": "8080",
    "URL_PREFIX": "/myapp"
  }
}
```

- `url`: Path where Caddy serves the app (required for Caddy integration)
- `URL_PREFIX` / `SCRIPT_NAME` / `PATH_BASE`: Tells app it's behind reverse proxy
- `PUBLIC_BASE`: Auto-injected by manager (no need to specify in config)

**Prefix Handling:**
- Apps with `URL_PREFIX`/`SCRIPT_NAME`/`PATH_BASE` → Uses `handle` (keeps prefix)
- Apps without prefix awareness → Uses `handle_path` (strips prefix)
- Override with `strip_prefix: true/false` in program config

### SSL Configuration

- **cert**: Path to SSL certificate file (default: `./certs/server.crt`)
- **key**: Path to SSL private key file (default: `./certs/server.key`)
- **autoGenerate**: Automatically generate self-signed certificate if files don't exist (default: `true`)

### Environment Variables

**Manager Configuration:**
- `PORT`: Manager web UI port (default: `3000`)
- `CONFIG_FILE`: Path to config file (default: `./config.json`)
- `USE_HTTPS`: Enable/disable HTTPS for manager (default: `true`)
- `HOST`: Hostname override for auto-generated program URLs (overrides config.hostname)
- `MANAGER_API_TOKEN`: Optional shared secret; when set, write APIs (start/stop/restart/program restart-manager) and WebSocket clients must present this token

**Caddy Integration (see Caddy section above for details):**
- `PUBLIC_BASE`: Override auto-detected IP for PUBLIC_BASE injection
- `CADDYFILE_PATH`: Output path for generated Caddyfile
- `CADDY_TLS_CERT`: TLS certificate path for Caddy
- `CADDY_TLS_KEY`: TLS key path for Caddy
- `CADDY_HTTPS_PORT`: HTTPS port for Caddy (default: `8443`)
- `MANAGER_PORT`: Internal port where manager runs for Caddy reverse proxy (default: `8061`)
- `CADDY_MANAGER_PATH`: URL path for manager in Caddy (default: `/manager`)
- `CADDY_RELOAD_CMD`: Shell command to reload Caddy after config changes

## Usage

### Starting the Server

```bash
npm start
```

Or for development:

```bash
node server.js
```

### Using HTTP Instead of HTTPS

If you prefer HTTP (for local development):

```bash
USE_HTTPS=false npm start
```

...
