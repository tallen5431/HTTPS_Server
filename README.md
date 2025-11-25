# HTTPS Server Manager

A secure HTTPS-based web application for managing and monitoring multiple programs on your system. Easily start, stop, restart, and view logs of your applications through a clean web interface.

## Features

- **HTTPS Support**: Secure connections with automatic self-signed certificate generation
- **Process Management**: Start, stop, and restart programs with a single click
- **Real-time Updates**: WebSocket-based live status updates
- **Log Viewing**: View program logs directly in the web interface
- **Multi-program Support**: Manage multiple programs from a single interface
- **LAN & Internet Access**: Access from any device on your network or over the internet
- **Clean Web UI**: Modern, responsive interface that works on desktop and mobile

## Prerequisites

- Node.js (v14 or higher)
- OpenSSL (for SSL certificate generation)
- Bash (for running Start.sh scripts)

## Installation

1. Clone or download this repository

2. Install dependencies:
```bash
npm install
```

3. Create your configuration file:
```bash
cp config.example.json config.json
```

4. Edit `config.json` to add your programs:
```json
{
  "programs": [
    {
      "id": "my-app",
      "name": "My Application",
      "path": "/path/to/your/app",
      "url": "http://localhost:8001",
      "env": {
        "NODE_ENV": "production",
        "PORT": "8001"
      }
    }
  ],
  "ssl": {
    "cert": "./certs/server.crt",
    "key": "./certs/server.key",
    "autoGenerate": true
  }
}
```

## Configuration

### Programs

Each program in the `programs` array should have:

- **id**: Unique identifier for the program (required)
- **name**: Display name shown in the web interface (required)
- **path**: Absolute path to the program directory containing Start.sh (required)
- **url**: URL where the program can be accessed (optional)
  - If provided, the program name becomes clickable and an "Open" button appears
  - Can be HTTP or HTTPS (e.g., `http://localhost:8001` or `https://myapp.com`)
  - Useful for quickly accessing your applications from the manager interface
- **env**: Environment variables to pass to the program (optional)

### SSL Configuration

- **cert**: Path to SSL certificate file (default: `./certs/server.crt`)
- **key**: Path to SSL private key file (default: `./certs/server.key`)
- **autoGenerate**: Automatically generate self-signed certificate if files don't exist (default: `true`)

### Environment Variables

You can override configuration using environment variables:

- `PORT`: Server port (default: 3000)
- `CONFIG_FILE`: Path to config file (default: `./config.json`)
- `USE_HTTPS`: Enable/disable HTTPS (default: `true`)

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

If you prefer HTTP (not recommended for production):

```bash
USE_HTTPS=false npm start
```

### Accessing the Web Interface

After starting the server, you'll see output like:

```
HTTPS Server Manager
===================
✓ Self-signed certificate generated
✓ HTTPS enabled
✓ Server running on https://localhost:3000
✓ Loaded 2 program(s)

Access the web interface at:
  https://localhost:3000
  https://192.168.1.100:3000
```

Open any of these URLs in your web browser.

**Note**: If using a self-signed certificate, your browser will show a security warning. This is normal - click "Advanced" and "Proceed" to continue.

## Program Requirements

Each program you want to manage must:

1. Be in its own directory
2. Have a `Start.sh` file in the root of that directory
3. The `Start.sh` file should be executable

Example `Start.sh`:

```bash
#!/bin/bash
node server.js
```

or

```bash
#!/bin/bash
python3 app.py
```

Make it executable:

```bash
chmod +x Start.sh
```

### Do My Programs Need HTTPS?

**No!** Your individual programs do NOT need to be modified to use HTTPS. Here's what you need to know:

- **The HTTPS Server Manager** runs on HTTPS (port 3000 by default) - this is just the management interface
- **Your individual programs** can run on HTTP on their own ports (8001, 8002, etc.)
- The manager simply starts/stops your programs - it doesn't proxy traffic to them
- Each program is accessed directly on its own port and protocol

**Example Setup:**
```
HTTPS Server Manager:  https://localhost:3000  (management interface)
Your App 1:           http://localhost:8001   (runs as-is, no changes needed)
Your App 2:           http://localhost:8002   (runs as-is, no changes needed)
```

**If You Want HTTPS for Your Apps:**

If you want your individual applications to be accessible over HTTPS, you have a few options:

1. **Configure each app individually** - Set up SSL/TLS in each application's code
2. **Use a reverse proxy** - Tools like Nginx or Caddy can handle HTTPS and forward to your HTTP apps
3. **Keep them on HTTP** - For local/LAN access, HTTP is usually fine

The HTTPS Server Manager will work with your apps regardless of whether they use HTTP or HTTPS!

## Web Interface

The web interface provides:

- **Program Cards**: Each program displays its status, path, PID, and URL (if configured)
- **Clickable Program Names**: If a URL is configured, click the program name to open it in a new tab
- **Start/Stop/Restart Buttons**: Control programs with one click
- **Open Button**: Appears when a URL is configured - click to open the program in a new tab
- **Log Viewer**: Click "Logs" to view the last 100 lines of output
- **Real-time Status**: Status updates automatically via WebSocket connection

### Button States

- **Green (Start)**: Start a stopped program
- **Red (Stop)**: Stop a running program
- **Blue (Restart)**: Restart a running program
- **Cyan (Open)**: Open the program's URL in a new browser tab
- **Gray (Logs)**: View program logs

## Network Access

### LAN Access

To access from other devices on your local network:

1. Find your server's IP address (shown in the startup output)
2. On other devices, navigate to `https://YOUR_IP:3000`
3. Accept the security warning for the self-signed certificate

### Internet Access

To access over the internet, you'll need to:

1. **Configure your router** to forward port 3000 to your server
2. **Find your public IP** (search "what is my ip" on Google)
3. **Access via** `https://YOUR_PUBLIC_IP:3000`

**Security Note**: When exposing to the internet, consider:
- Using proper SSL certificates (Let's Encrypt)
- Adding authentication
- Using a firewall
- Keeping the system updated

## API Endpoints

The server provides a REST API:

- `GET /api/programs` - List all programs
- `POST /api/programs/:id/start` - Start a program
- `POST /api/programs/:id/stop` - Stop a program
- `POST /api/programs/:id/restart` - Restart a program
- `GET /api/programs/:id/logs?lines=100` - Get program logs
- `GET /api/config` - Get configuration

## WebSocket

Connect to the WebSocket for real-time updates:

```javascript
const ws = new WebSocket('wss://localhost:3000');

ws.onmessage = (event) => {
  const message = JSON.parse(event.data);
  if (message.type === 'status') {
    console.log('Programs status:', message.data);
  }
};
```

## Troubleshooting

### Port Already in Use

Change the port:

```bash
PORT=3001 npm start
```

### SSL Certificate Errors

If auto-generation fails, manually create certificates:

```bash
mkdir -p certs
openssl req -x509 -newkey rsa:4096 -keyout certs/server.key -out certs/server.crt -days 365 -nodes -subj "/CN=localhost"
```

### Program Won't Start

Check that:
1. The path in config.json is correct
2. Start.sh exists and is executable
3. The program doesn't require additional dependencies
4. Check the logs in the web interface for error messages

### Can't Access from Other Devices

1. Check your firewall allows connections on port 3000
2. Verify you're using the correct IP address
3. Make sure both devices are on the same network

## License

MIT

## Contributing

Feel free to submit issues and pull requests!
