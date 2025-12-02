#!/usr/bin/env node

const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const express = require('express');
const WebSocket = require('ws');
const { URL } = require('url');

// Configuration
const CONFIG_FILE = process.env.CONFIG_FILE || './config-http.json';
const PROJECTS_DIR = process.env.PROJECTS_DIR || null;
const PORT = process.env.PORT || 3000;
const API_TOKEN = process.env.MANAGER_API_TOKEN || null;

// Process registry
const processes = new Map();
const processLogs = new Map();

// Load configuration (cached with mtime check)
let cachedConfig = null;
let cachedConfigMtimeMs = null;

function loadConfig() {
  try {
    if (!fs.existsSync(CONFIG_FILE)) {
      if (cachedConfig) {
        return cachedConfig;
      }

      // Auto-discover projects if PROJECTS_DIR is set
      if (PROJECTS_DIR && fs.existsSync(PROJECTS_DIR)) {
        console.log(`\n🔍 Config file not found. Auto-discovering projects from: ${PROJECTS_DIR}`);
        try {
          const { discoverProjects, generateConfig } = require('./discover-projects');
          const projects = discoverProjects(PROJECTS_DIR);
          const autoConfig = generateConfig(projects);

          // Remove SSL config for HTTP version
          delete autoConfig.ssl;

          fs.writeFileSync(CONFIG_FILE, JSON.stringify(autoConfig, null, 2), 'utf8');
          console.log(`✅ Auto-generated config-http.json with ${projects.length} project(s)\n`);

          cachedConfig = autoConfig;
          cachedConfigMtimeMs = null;
          return autoConfig;
        } catch (err) {
          console.error('❌ Auto-discovery failed:', err.message);
          console.log('   Falling back to empty config. You can manually create config-http.json\n');
        }
      }

      // Fallback default config
      const defaultConfig = {
        hostname: 'localhost',
        programs: []
      };
      cachedConfig = defaultConfig;
      cachedConfigMtimeMs = null;
      return defaultConfig;
    }

    const stats = fs.statSync(CONFIG_FILE);
    if (!cachedConfig || stats.mtimeMs !== cachedConfigMtimeMs) {
      const data = fs.readFileSync(CONFIG_FILE, 'utf8');
      const config = JSON.parse(data);
      validateConfig(config);
      cachedConfig = config;
      cachedConfigMtimeMs = stats.mtimeMs;
    }

    return cachedConfig;
  } catch (err) {
    console.error('Error loading config:', err.message);
    throw err;
  }
}

// Validate configuration
function validateConfig(config) {
  if (!config.programs || !Array.isArray(config.programs)) {
    throw new Error('Config must have a "programs" array');
  }

  const seenIds = new Set();

  config.programs.forEach((program, index) => {
    if (!program.id) {
      throw new Error(`Program at index ${index} is missing required field: "id"`);
    }
    if (!program.name) {
      throw new Error(`Program "${program.id}" is missing required field: "name"`);
    }
    if (!program.path) {
      throw new Error(`Program "${program.id}" is missing required field: "path"`);
    }

    if (seenIds.has(program.id)) {
      throw new Error(`Duplicate program ID found: "${program.id}"`);
    }
    seenIds.add(program.id);

    if (!program.env || typeof program.env !== 'object') {
      program.env = {};
    }
  });

  return true;
}

// Get local IP address
function getLocalIpAddress() {
  const { networkInterfaces } = require('os');
  const nets = networkInterfaces();

  const priorityInterfaces = ['eth0', 'en0', 'wlan0'];

  for (const name of priorityInterfaces) {
    if (nets[name]) {
      for (const net of nets[name]) {
        if (net.family === 'IPv4' && !net.internal) {
          return net.address;
        }
      }
    }
  }

  for (const name of Object.keys(nets)) {
    for (const net of nets[name]) {
      if (net.family === 'IPv4' && !net.internal) {
        return net.address;
      }
    }
  }

  return 'localhost';
}

// Program management
function getProgramConfig(programId, config) {
  const program = config.programs.find(p => p.id === programId);
  if (!program) {
    throw new Error(`Program not found: ${programId}`);
  }
  return program;
}

function getProgramStatus(programId, config) {
  const program = config.programs.find(p => p.id === programId);
  if (!program) {
    return {
      id: programId,
      name: programId,
      status: 'missing',
      url: null,
      pid: null
    };
  }

  const proc = processes.get(programId);
  const isRunning = proc && !proc.killed;

  return {
    id: program.id,
    name: program.name,
    status: isRunning ? 'running' : 'stopped',
    url: generateProgramUrl(program, config),
    pid: isRunning ? proc.pid : null,
    uptime: isRunning && proc.spawnDate ? Date.now() - proc.spawnDate : 0
  };
}

function generateProgramUrl(program, config) {
  // If a URL is explicitly provided, use it
  if (program.url) {
    return program.url;
  }

  // Generate from PORT
  const port = program.env && (program.env.PORT || program.env.port);
  if (port) {
    const hostname = config.hostname || getLocalIpAddress();
    return `http://${hostname}:${port}`;
  }

  return null;
}

function getAllProgramsStatus(config) {
  return config.programs.map(p => getProgramStatus(p.id, config));
}

function getProgramLogs(programId, lines = 100) {
  const logs = processLogs.get(programId) || [];
  return logs.slice(-lines);
}

// WebSocket broadcast
const wsClients = new Set();

function broadcastStatus() {
  const config = loadConfig();
  const status = getAllProgramsStatus(config);
  const message = JSON.stringify({ type: 'status', data: status });

  wsClients.forEach(client => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(message);
    }
  });
}

// Express app
const app = express();
app.use(express.json());
app.use(express.static('public'));

// Simple token-based authentication
function getRequestToken(req) {
  const header = req.headers['authorization'] || '';
  if (header.startsWith('Bearer ')) {
    return header.slice(7).trim();
  }
  if (req.query && typeof req.query.token === 'string') {
    return req.query.token;
  }
  if (req.body && typeof req.body.token === 'string') {
    return req.body.token;
  }
  return null;
}

function requireApiToken(req, res, next) {
  if (!API_TOKEN) {
    return next();
  }
  const token = getRequestToken(req);
  if (token === API_TOKEN) {
    return next();
  }
  res.status(401).json({ success: false, error: 'Unauthorized' });
}

// API Routes
app.get('/api/programs', (req, res) => {
  const config = loadConfig();
  const status = getAllProgramsStatus(config);
  res.json(status);
});

app.post('/api/programs/:id/start', requireApiToken, (req, res) => {
  try {
    const config = loadConfig();
    const result = startProgram(req.params.id, config);
    res.json({ success: true, data: result });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
});

app.post('/api/programs/:id/stop', requireApiToken, (req, res) => {
  try {
    const result = stopProgram(req.params.id);
    res.json({ success: true, data: result });
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
});

app.post('/api/programs/:id/restart', requireApiToken, (req, res) => {
  try {
    const config = loadConfig();
    stopProgram(req.params.id);

    setTimeout(() => {
      const result = startProgram(req.params.id, config);
      res.json({ success: true, data: result });
    }, 1000);
  } catch (err) {
    res.status(400).json({ success: false, error: err.message });
  }
});

app.get('/api/programs/:id/logs', (req, res) => {
  const lines = parseInt(req.query.lines) || 100;
  const logs = getProgramLogs(req.params.id, lines);
  res.json(logs);
});

app.get('/api/config', (req, res) => {
  const config = loadConfig();
  res.json(config);
});

app.get('/api/stats', (req, res) => {
  const config = loadConfig();
  const programs = getAllProgramsStatus(config);

  const stats = {
    total: programs.length,
    running: programs.filter(p => p.status === 'running').length,
    stopped: programs.filter(p => p.status === 'stopped').length,
    uptime: programs
      .filter(p => p.status === 'running')
      .reduce((sum, p) => sum + (p.uptime || 0), 0)
  };

  res.json(stats);
});

app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString()
  });
});

// Rediscover projects
app.post('/api/rediscover', requireApiToken, (req, res) => {
  console.log('[manager] Rediscovery requested via /api/rediscover');

  try {
    const projectsDir = req.body.projectsDir || PROJECTS_DIR;

    if (!projectsDir) {
      return res.status(400).json({
        success: false,
        error: 'No projects directory specified. Set PROJECTS_DIR environment variable or provide projectsDir in request body.'
      });
    }

    if (!fs.existsSync(projectsDir)) {
      return res.status(404).json({
        success: false,
        error: `Projects directory not found: ${projectsDir}`
      });
    }

    if (fs.existsSync(CONFIG_FILE)) {
      const backupFile = CONFIG_FILE + '.backup.' + Date.now();
      fs.copyFileSync(CONFIG_FILE, backupFile);
      console.log(`[manager] Backed up config to: ${backupFile}`);
    }

    const { discoverProjects, generateConfig } = require('./discover-projects');
    const projects = discoverProjects(projectsDir);
    const newConfig = generateConfig(projects);

    // Remove SSL config for HTTP version
    delete newConfig.ssl;

    fs.writeFileSync(CONFIG_FILE, JSON.stringify(newConfig, null, 2), 'utf8');
    console.log(`[manager] Regenerated config with ${projects.length} project(s)`);

    cachedConfig = null;
    cachedConfigMtimeMs = null;

    res.json({
      success: true,
      message: `Rediscovered ${projects.length} project(s)`,
      projectCount: projects.length
    });

    setTimeout(() => broadcastStatus(), 500);
  } catch (err) {
    console.error('[manager] Rediscovery failed:', err);
    res.status(500).json({
      success: false,
      error: err.message
    });
  }
});

app.post('/api/restart-manager', requireApiToken, (req, res) => {
  console.log('[manager] Restart requested via /api/restart-manager');

  res.json({
    success: true,
    message: 'HTTP Server Manager restarting…'
  });

  setTimeout(() => {
    console.log('[manager] Exiting process for restart');
    process.exit(0);
  }, 1000);
});

// Start program
function startProgram(programId, config) {
  const program = getProgramConfig(programId, config);
  const existingProcess = processes.get(programId);

  if (existingProcess && !existingProcess.killed) {
    throw new Error('Program is already running');
  }

  const startScript = path.join(program.path, 'Start.sh');

  if (!fs.existsSync(startScript)) {
    console.warn(`Start script not found for program: ${programId}`);
  }

  const env = {
    ...process.env,
    ...program.env
  };

  const proc = spawn('bash', [startScript], {
    cwd: program.path,
    env
  });

  const logs = [];
  processLogs.set(programId, logs);

  proc.stdout.on('data', (data) => {
    const lines = data.toString().split('\n').filter(Boolean);
    lines.forEach(line => {
      logs.push({ time: new Date().toISOString(), text: line });
      if (logs.length > 1000) {
        logs.shift();
      }
    });
    broadcastStatus();
  });

  proc.stderr.on('data', (data) => {
    const lines = data.toString().split('\n').filter(Boolean);
    lines.forEach(line => {
      logs.push({ time: new Date().toISOString(), text: `[ERR] ${line}` });
      if (logs.length > 1000) {
        logs.shift();
      }
    });
    broadcastStatus();
  });

  proc.on('exit', (code) => {
    const line = `[system] Process exited with code ${code}`;
    logs.push({ time: new Date().toISOString(), text: line });
    broadcastStatus();
  });

  proc.spawnDate = Date.now();
  processes.set(programId, proc);

  return {
    id: programId,
    name: program.name,
    status: 'running',
    pid: proc.pid
  };
}

function stopProgram(programId) {
  const proc = processes.get(programId);
  if (!proc || proc.killed) {
    throw new Error('Program is not running');
  }

  proc.kill('SIGTERM');

  setTimeout(() => {
    if (!proc.killed) {
      proc.kill('SIGKILL');
    }
  }, 10000);

  return {
    id: programId,
    status: 'stopping'
  };
}

// Start server
async function startServer() {
  const config = loadConfig();

  console.log('HTTP Server Manager');
  console.log('===================');
  console.log('Simple HTTP version (no SSL/certificates required)');
  console.log('');

  const server = http.createServer(app);

  // WebSocket server
  const wss = new WebSocket.Server({ server });

  wss.on('connection', (ws, req) => {
    if (API_TOKEN) {
      try {
        const url = new URL(req.url, 'http://localhost');
        const token = url.searchParams.get('token');
        if (token !== API_TOKEN) {
          ws.close(1008, 'Unauthorized');
          return;
        }
      } catch (err) {
        ws.close(1008, 'Unauthorized');
        return;
      }
    }

    wsClients.add(ws);
    console.log('WebSocket client connected');

    const status = getAllProgramsStatus(loadConfig());
    ws.send(JSON.stringify({ type: 'status', data: status }));

    ws.on('close', () => {
      wsClients.delete(ws);
      console.log('WebSocket client disconnected');
    });
  });

  server.listen(PORT, () => {
    console.log(`✓ Server running on http://localhost:${PORT}`);
    const activeConfig = loadConfig();
    console.log(`✓ Loaded ${activeConfig.programs.length} program(s)`);
    console.log('\nAccess the web interface at:');
    console.log(`  http://localhost:${PORT}`);

    // Get local IP addresses
    const { networkInterfaces } = require('os');
    const nets = networkInterfaces();

    Object.keys(nets).forEach((name) => {
      nets[name].forEach((net) => {
        if (net.internal || net.family !== 'IPv4') return;
        console.log(`  http://${net.address}:${PORT}`);
      });
    });
  });

  // Graceful shutdown
  process.on('SIGINT', () => {
    console.log('\nShutting down server...');

    server.close(() => {
      console.log('Server stopped');
      process.exit(0);
    });

    for (const [id, proc] of processes.entries()) {
      if (!proc.killed) {
        console.log(`Stopping ${id}...`);
        proc.kill('SIGTERM');
      }
    }
  });
}

// Start the server
startServer().catch(err => {
  console.error('Failed to start server:', err);
  process.exit(1);
});
