#!/bin/bash

# HTTP Server Manager Start Script
# Simple HTTP version - no SSL certificates or Caddy required

echo "Starting HTTP Server Manager..."
echo "================================"
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Error: Node.js is not installed"
    echo "   Please install Node.js to continue"
    exit 1
fi

# Check if npm packages are installed
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
    echo ""
fi

# Default port
PORT=${PORT:-3000}

# Check if config file exists, if not use example
if [ ! -f "config-http.json" ]; then
    if [ -f "config-http.example.json" ]; then
        echo "⚠️  No config-http.json found, creating from example..."
        cp config-http.example.json config-http.json
        echo "   Please edit config-http.json to add your applications"
        echo ""
    fi
fi

echo "🚀 Starting HTTP server on port $PORT..."
echo "   Access the manager at: http://localhost:$PORT"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Start the HTTP server
node server-http.js
