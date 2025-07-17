#!/usr/bin/env python3
"""
AD-Setup Enterprise Web UI
Simple web interface for AD forest management
"""

import json
import os
import sys
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ADSetupWebHandler(BaseHTTPRequestHandler):
    """HTTP request handler for AD-Setup Web UI"""
    
    def do_GET(self):
        """Handle GET requests"""
        path = urlparse(self.path).path
        
        if path == '/':
            self.serve_homepage()
        elif path == '/api/status':
            self.serve_status()
        elif path == '/api/logs':
            self.serve_logs()
        else:
            self.send_error(404, "Page not found")
    
    def serve_homepage(self):
        """Serve the main web UI page"""
        html = """
<!DOCTYPE html>
<html>
<head>
    <title>AD-Setup Enterprise</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 0;
            background: #f5f5f5;
        }
        .header {
            background: #2c3e50;
            color: white;
            padding: 20px;
            text-align: center;
        }
        .container {
            max-width: 1200px;
            margin: 20px auto;
            padding: 0 20px;
        }
        .card {
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            padding: 20px;
            margin-bottom: 20px;
        }
        .status-ok { color: #27ae60; }
        .status-error { color: #e74c3c; }
        .status-item {
            display: flex;
            justify-content: space-between;
            padding: 10px 0;
            border-bottom: 1px solid #eee;
        }
        .button {
            background: #3498db;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 4px;
            cursor: pointer;
            text-decoration: none;
            display: inline-block;
        }
        .button:hover {
            background: #2980b9;
        }
        pre {
            background: #f4f4f4;
            padding: 10px;
            border-radius: 4px;
            overflow-x: auto;
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🌲 AD-Setup Enterprise</h1>
        <p>Active Directory Forest Management</p>
    </div>
    
    <div class="container">
        <div class="card">
            <h2>System Status</h2>
            <div id="status-content">Loading...</div>
        </div>
        
        <div class="card">
            <h2>Quick Actions</h2>
            <button class="button" onclick="alert('Deploy forest feature coming soon!')">
                Deploy New Forest
            </button>
            <button class="button" onclick="refreshStatus()">
                Refresh Status
            </button>
            <button class="button" onclick="viewLogs()">
                View Logs
            </button>
        </div>
        
        <div class="card" id="logs-card" style="display:none;">
            <h2>Recent Logs</h2>
            <pre id="logs-content">Loading logs...</pre>
        </div>
    </div>
    
    <script>
        async function refreshStatus() {
            try {
                const response = await fetch('/api/status');
                const data = await response.json();
                
                let statusHtml = '<div class="status-item">';
                statusHtml += '<span>Daemon Status</span>';
                statusHtml += '<span class="' + (data.daemon ? 'status-ok">Running' : 'status-error">Stopped') + '</span>';
                statusHtml += '</div>';
                
                statusHtml += '<div class="status-item">';
                statusHtml += '<span>Docker Status</span>';
                statusHtml += '<span class="' + (data.docker ? 'status-ok">Running' : 'status-error">Stopped') + '</span>';
                statusHtml += '</div>';
                
                statusHtml += '<div class="status-item">';
                statusHtml += '<span>Active Forests</span>';
                statusHtml += '<span>' + data.forest_count + '</span>';
                statusHtml += '</div>';
                
                if (data.daemon && data.daemon.uptime) {
                    statusHtml += '<div class="status-item">';
                    statusHtml += '<span>Uptime</span>';
                    statusHtml += '<span>' + formatUptime(data.daemon.uptime) + '</span>';
                    statusHtml += '</div>';
                }
                
                document.getElementById('status-content').innerHTML = statusHtml;
            } catch (error) {
                document.getElementById('status-content').innerHTML = 
                    '<p class="status-error">Error loading status: ' + error + '</p>';
            }
        }
        
        async function viewLogs() {
            const logsCard = document.getElementById('logs-card');
            logsCard.style.display = 'block';
            
            try {
                const response = await fetch('/api/logs');
                const data = await response.json();
                document.getElementById('logs-content').textContent = data.logs;
            } catch (error) {
                document.getElementById('logs-content').textContent = 'Error loading logs: ' + error;
            }
        }
        
        function formatUptime(seconds) {
            const days = Math.floor(seconds / 86400);
            const hours = Math.floor((seconds % 86400) / 3600);
            const minutes = Math.floor((seconds % 3600) / 60);
            
            if (days > 0) return `${days}d ${hours}h ${minutes}m`;
            if (hours > 0) return `${hours}h ${minutes}m`;
            return `${minutes}m`;
        }
        
        // Load status on page load
        refreshStatus();
        
        // Auto-refresh every 30 seconds
        setInterval(refreshStatus, 30000);
    </script>
</body>
</html>
        """
        
        self.send_response(200)
        self.send_header('Content-Type', 'text/html')
        self.end_headers()
        self.wfile.write(html.encode())
    
    def serve_status(self):
        """Serve status information as JSON"""
        status_file = Path.home() / ".ad-setup" / "status.json"
        
        response_data = {
            'daemon': False,
            'docker': False,
            'forest_count': 0,
            'forests': {}
        }
        
        if status_file.exists():
            try:
                with open(status_file, 'r') as f:
                    status = json.load(f)
                    response_data['daemon'] = status.get('daemon')
                    response_data['docker'] = status.get('docker', False)
                    response_data['forests'] = status.get('forests', {})
                    response_data['forest_count'] = len(response_data['forests'])
            except Exception as e:
                logger.error(f"Error reading status: {e}")
        
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(response_data).encode())
    
    def serve_logs(self):
        """Serve recent log entries"""
        if sys.platform == "darwin":
            log_file = Path.home() / "Library" / "Logs" / "ad-setup" / "ad-setup.log"
        else:
            log_file = Path("/var/log/ad-setup/ad-setup.log")
        
        logs = "No logs available"
        
        if log_file.exists():
            try:
                with open(log_file, 'r') as f:
                    lines = f.readlines()
                    # Get last 50 lines
                    logs = ''.join(lines[-50:])
            except Exception as e:
                logs = f"Error reading logs: {e}"
        
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps({'logs': logs}).encode())
    
    def log_message(self, format, *args):
        """Override to suppress request logging"""
        return

def run_server(port=8080):
    """Run the web UI server"""
    server_address = ('', port)
    httpd = HTTPServer(server_address, ADSetupWebHandler)
    
    logger.info(f"AD-Setup Web UI running on http://localhost:{port}")
    logger.info("Press Ctrl+C to stop")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        logger.info("Web UI stopped")
        httpd.server_close()

if __name__ == "__main__":
    run_server()
