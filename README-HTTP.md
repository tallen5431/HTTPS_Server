# HTTP Server Manager (Simplified Version)

A simplified HTTP-only version of the Server Manager without SSL certificates or Caddy reverse proxy requirements.

## Why Use the HTTP Version?

The HTTP version is ideal if you're:
- Having issues with HTTPS/SSL certificates
- Running locally and don't need encryption
- Want a simpler setup without Caddy
- Testing or developing applications
- Running behind a separate reverse proxy that handles HTTPS

## Quick Start

### 1. Install Dependencies

```bash
npm install
```

### 2. Create Configuration

Copy the example configuration:

```bash
cp config-http.example.json config-http.json
```

Edit `config-http.json` to add your applications:

```json
{
  "hostname": "localhost",
  "programs": [
    {
      "id": "my-app",
      "name": "My Application",
      "path": "/absolute/path/to/your/app",
      "env": {
        "PORT": "8080",
        "HOST": "0.0.0.0"
      }
    }
  ]
}
```

### 3. Start the Server

```bash
./start-http.sh
```

Or manually:

```bash
node server-http.js
```

The manager will be available at `http://localhost:3000`

## Configuration

### Basic Structure

```json
{
  "hostname": "localhost",
  "programs": [
    {
      "id": "unique-id",
      "name": "Display Name",
      "path": "/path/to/app",
      "url": "http://localhost:8080",  // Optional
      "env": {
        "PORT": "8080",
        "HOST": "0.0.0.0"
      }
    }
  ]
}
```

### Configuration Fields

- **hostname**: Hostname or IP to use for auto-generated URLs (default: "localhost")
- **programs**: Array of applications to manage

#### Program Fields

- **id**: Unique identifier (required)
- **name**: Display name in the UI (required)
- **path**: Absolute path to the application directory (required)
- **url**: Direct URL to the application (optional - auto-generated from PORT if not specified)
- **env**: Environment variables to pass to the application

## Environment Variables

### Server Configuration

- `PORT` - Manager web UI port (default: 3000)
- `CONFIG_FILE` - Path to config file (default: ./config-http.json)
- `PROJECTS_DIR` - Directory to auto-discover projects from
- `MANAGER_API_TOKEN` - Optional API authentication token

### Auto-Discovery

If you set `PROJECTS_DIR`, the manager will automatically scan for projects with `Start.sh` files and generate a configuration:

```bash
PROJECTS_DIR=/path/to/projects node server-http.js
```

## Features

- **Simple HTTP** - No certificates or SSL configuration needed
- **Process Management** - Start, stop, and restart applications
- **Live Logs** - Real-time log streaming via WebSocket
- **Auto-Discovery** - Automatically find and configure projects
- **Web UI** - Clean interface to manage all applications
- **Status Monitoring** - See which apps are running and their uptime

## API Endpoints

### Get Programs Status
```bash
curl http://localhost:3000/api/programs
```

### Start a Program
```bash
curl -X POST http://localhost:3000/api/programs/my-app/start
```

### Stop a Program
```bash
curl -X POST http://localhost:3000/api/programs/my-app/stop
```

### Restart a Program
```bash
curl -X POST http://localhost:3000/api/programs/my-app/restart
```

### Get Logs
```bash
curl http://localhost:3000/api/programs/my-app/logs?lines=100
```

## Differences from HTTPS Version

The HTTP version is simplified and removes:
- SSL/TLS certificate generation and management
- Caddy reverse proxy integration
- Caddyfile generation and watching
- PUBLIC_BASE environment variable injection
- HTTPS-specific configuration options

## Upgrading to HTTPS

If you want to use HTTPS later, you can:
1. Use the full `server.js` with `USE_HTTPS=true`
2. Set up Caddy as a reverse proxy
3. Use a tool like nginx or Apache in front of this server
4. Deploy behind a cloud provider's load balancer with SSL termination

## Requirements

- Node.js (v14 or later recommended)
- npm (comes with Node.js)
- Bash (for running Start.sh scripts)

## Troubleshooting

### Port Already in Use

If port 3000 is already in use:

```bash
PORT=8000 node server-http.js
```

### Application Won't Start

1. Check that the `Start.sh` file exists in the application directory
2. Make sure `Start.sh` is executable: `chmod +x Start.sh`
3. Check the logs in the web UI for error messages
4. Verify environment variables are set correctly

### Can't Access from Other Devices

1. Make sure your firewall allows connections on the port
2. Set `hostname` in config to your local IP address (e.g., "192.168.1.100")
3. Ensure applications bind to `0.0.0.0` not just `localhost`

## Example Use Cases

### Local Development
Run multiple dev servers and manage them from one interface.

### Testing Suite
Start and stop test environments easily.

### Demo Applications
Quickly show multiple projects to clients or team members.

### Personal Projects
Manage your hobby projects on a local server.

## Support

For issues or questions:
1. Check the logs in the web UI
2. Review the configuration file format
3. Ensure all paths are absolute, not relative
4. Verify Node.js and npm are properly installed

## License

Same as the main HTTPS Server Manager project.
