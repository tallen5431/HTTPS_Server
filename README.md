# HTTPS Server Manager

A secure HTTPS-based web application for managing and monitoring...nd view logs of your applications through a clean web interface.

## Features

- **HTTPS Support**: Secure connections with automatic self-signed certificate generation
- **Process Management**: Start, stop, and restart programs with a single click
- **Real-time Updates**: WebSocket-based live status updates
- **Log Viewing**: View program logs directly in the web interface
- **Multi-program Support**: Manage multiple programs from a single interface
- **LAN & Internet Access**: Access from any device on your network or over the internet
- **Clean Web UI**: Modern, responsive interface that works on desktop and mobile

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

> When you use `caddy_from_config.js`, only programs with a `url` are turned into `handle_path` blocks. If you want a path like `/codesmith` on your HTTPS endpoint, make sure the program has a `url` whose path is `/codesmith` (for example, `"/codesmith"` or `"https://192.168.1.245:8443/codesmith"`).

### SSL Configuration

- **cert**: Path to SSL certificate file (default: `./certs/server.crt`)
- **key**: Path to SSL private key file (default: `./certs/server.key`)
- **autoGenerate**: Automatically generate self-signed certificate if files don't exist (default: `true`)

### Environment Variables

You can override configuration using environment variables:

- `PORT`: Server port (default: 3000)
- `CONFIG_FILE`: Path to config file (default: `./config.json`)
- `USE_HTTPS`: Enable/disable HTTPS (default: `true`)
- `HOST`: Hostname override for auto-generated program URLs (overrides config.hostname)
- `MANAGER_API_TOKEN`: Optional shared secret; when set, write APIs (start/stop/restart/program restart-manager) and WebSocket clients must present this token.

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
