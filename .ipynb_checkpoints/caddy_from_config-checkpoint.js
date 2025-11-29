#!/usr/bin/env node

// Generate a Caddyfile from HTTPS_Server config.json
//
// Usage:
//   node caddy_from_config.js > Caddyfile.generated
//   CADDY_FILE_OUT=/etc/caddy/Caddyfile node caddy_from_config.js
//
// Env vars:
//   CONFIG_FILE   - path to config.json (default ./config.json)
//   PUBLIC_BASE   - fallback public base URL if not present in any program.env
//   MANAGER_PORT  - port of the HTTPS Server Manager UI (default 8061)
//   CADDY_FILE_OUT- path to write Caddyfile (optional; otherwise writes to stdout)

const fs = require('fs');
const path = require('path');

const CONFIG_FILE = process.env.CONFIG_FILE || path.join(__dirname, 'config.json');
const OUTPUT_FILE = process.env.CADDY_FILE_OUT || null;

function loadConfig() {
  try {
    const raw = fs.readFileSync(CONFIG_FILE, 'utf8');
    return JSON.parse(raw);
  } catch (err) {
    console.error('[caddy_from_config] Failed to read config file:', CONFIG_FILE);
    console.error(err.message);
    process.exit(1);
  }
}

function pickPublicBase(config) {
  // Prefer PUBLIC_BASE from any program
  if (config && Array.isArray(config.programs)) {
    for (const prog of config.programs) {
      if (prog && prog.env && prog.env.PUBLIC_BASE) {
        return String(prog.env.PUBLIC_BASE).trim();
      }
    }
  }

  if (process.env.PUBLIC_BASE) {
    return String(process.env.PUBLIC_BASE).trim();
  }

  // Fallback to your current setup
  return 'https://192.168.1.245:8443';
}

function parseHostAndPort(publicBase) {
  let host = '192.168.1.245';
  let httpsPort = '8443';

  try {
    const u = new URL(publicBase);
    if (u.hostname) host = u.hostname;
    if (u.port) {
      httpsPort = u.port;
    } else if (u.protocol === 'https:') {
      httpsPort = '443';
    }
  } catch (err) {
    console.warn('[caddy_from_config] Warning: unable to parse PUBLIC_BASE, using defaults:', publicBase);
  }

  return { host, httpsPort };
}

function derivePathPrefix(urlValue) {
  if (!urlValue) return null;
  let u = String(urlValue).trim();

  // If full URL, extract pathname
  if (u.startsWith('http://') || u.startsWith('https://')) {
    try {
      const parsed = new URL(u);
      u = parsed.pathname || '/';
    } catch {
      // leave as-is
    }
  }

  if (!u.startsWith('/')) u = '/' + u;
  if (u === '/') return null;

  return u;
}

function buildCaddyfile(config) {
  const publicBase = pickPublicBase(config);
  const { host, httpsPort } = parseHostAndPort(publicBase);
  const managerPort = process.env.MANAGER_PORT || '8061';

  const lines = [];

  lines.push('{');
  lines.push('    auto_https off');
  lines.push(`    https_port ${httpsPort}`);
  lines.push('}');
  lines.push('');
  lines.push(`https://${host} {`);
  lines.push('    tls /etc/ssl/caddy/nuc-selfsign.crt /etc/ssl/caddy/nuc-selfsign.key');
  lines.push('');

  // HTTPS Server Manager UI itself
  lines.push('    # HTTPS Server Manager UI');
  lines.push('    handle_path /manager* {');
  lines.push(`        reverse_proxy 127.0.0.1:${managerPort}`);
  lines.push('    }');
  lines.push('');

  if (config && Array.isArray(config.programs)) {
    for (const prog of config.programs) {
      if (!prog || !prog.id) continue;
      const env = prog.env || {};
      const port = env.PORT;
      const urlValue = prog.url;

      if (!port || !urlValue) {
        // Without PORT or URL we cannot generate a proxy block
        continue;
      }

      const prefix = derivePathPrefix(urlValue);
      if (!prefix) continue;

      const displayName = prog.name || prog.id;
      lines.push(`    # ${displayName}`);
      lines.push(`    handle_path ${prefix}* {`);
      lines.push(`        reverse_proxy 127.0.0.1:${port}`);
      lines.push('    }');
      lines.push('');
    }
  }

  lines.push('}');
  lines.push('');

  return lines.join('\n');
}

function main() {
  const config = loadConfig();
  const caddyText = buildCaddyfile(config);

  if (OUTPUT_FILE) {
    try {
      fs.writeFileSync(OUTPUT_FILE, caddyText, 'utf8');
      console.log(`[caddy_from_config] Wrote Caddyfile to ${OUTPUT_FILE}`);
    } catch (err) {
      console.error('[caddy_from_config] Failed to write Caddyfile:', OUTPUT_FILE);
      console.error(err.message);
      process.exit(1);
    }
  } else {
    process.stdout.write(caddyText);
  }
}

if (require.main === module) {
  main();
}

module.exports = { buildCaddyfileFromConfig: buildCaddyfile };
