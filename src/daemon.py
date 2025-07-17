#!/usr/bin/env python3
"""
AD-Setup Enterprise Daemon
Background service for monitoring and managing AD forests
"""

import os
import sys
import time
import signal
import logging
import yaml
import json
from pathlib import Path
from datetime import datetime
from typing import Dict, Any
import threading

# Setup logging
def setup_logging():
    """Configure logging for the daemon"""
    if sys.platform == "darwin":
        log_dir = Path.home() / "Library" / "Logs" / "ad-setup"
    else:
        log_dir = Path("/var/log/ad-setup")
    
    log_dir.mkdir(parents=True, exist_ok=True)
    
    # Configure main logger
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_dir / "ad-setup.log"),
            logging.StreamHandler(sys.stdout)
        ]
    )
    
    return logging.getLogger(__name__)

class ADSetupDaemon:
    """Main daemon class for AD-Setup Enterprise"""
    
    def __init__(self):
        self.logger = setup_logging()
        self.running = False
        self.config = self.load_config()
        self.forests = {}
        self.metrics = {
            'uptime': 0,
            'forests_monitored': 0,
            'health_checks': 0,
            'last_check': None
        }
        
    def load_config(self) -> Dict[str, Any]:
        """Load configuration from file"""
        config_path = Path.home() / ".config" / "ad-setup" / "config.yaml"
        
        if config_path.exists():
            with open(config_path, 'r') as f:
                config = yaml.safe_load(f)
                self.logger.info("Configuration loaded successfully")
                return config
        else:
            self.logger.warning("No configuration file found, using defaults")
            return {
                'general': {
                    'log_level': 'INFO',
                    'health_check_interval': 60
                },
                'monitoring': {
                    'enable_notifications': True
                }
            }
    
    def signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully"""
        self.logger.info(f"Received signal {signum}, shutting down...")
        self.running = False
    
    def check_docker_status(self) -> bool:
        """Check if Docker is running"""
        try:
            import docker
            client = docker.from_env()
            client.ping()
            return True
        except Exception as e:
            self.logger.error(f"Docker check failed: {e}")
            return False
    
    def monitor_forests(self):
        """Monitor active AD forests"""
        try:
            import docker
            client = docker.from_env()
            
            # Look for AD containers
            containers = client.containers.list(
                filters={"label": "ad-setup.forest"}
            )
            
            self.forests = {}
            for container in containers:
                forest_name = container.labels.get("ad-setup.forest.name", "unknown")
                self.forests[forest_name] = {
                    'container_id': container.id,
                    'status': container.status,
                    'started': container.attrs['State']['StartedAt'],
                    'health': 'healthy' if container.status == 'running' else 'unhealthy'
                }
            
            self.metrics['forests_monitored'] = len(self.forests)
            self.logger.info(f"Monitoring {len(self.forests)} forests")
            
        except Exception as e:
            self.logger.error(f"Forest monitoring error: {e}")
    
    def perform_health_check(self):
        """Perform health checks on all components"""
        self.logger.debug("Performing health check...")
        
        health_status = {
            'timestamp': datetime.now().isoformat(),
            'docker': self.check_docker_status(),
            'forests': self.forests,
            'daemon': {
                'uptime': self.metrics['uptime'],
                'pid': os.getpid(),
                'health_checks': self.metrics['health_checks']
            }
        }
        
        # Write health status to file
        status_file = Path.home() / ".ad-setup" / "status.json"
        status_file.parent.mkdir(parents=True, exist_ok=True)
        
        with open(status_file, 'w') as f:
            json.dump(health_status, f, indent=2)
        
        self.metrics['health_checks'] += 1
        self.metrics['last_check'] = datetime.now().isoformat()
        
        # Log summary
        if health_status['docker']:
            self.logger.info("Health check completed: Docker ✓")
        else:
            self.logger.warning("Health check completed: Docker ✗")
    
    def cleanup_logs(self):
        """Rotate and cleanup old logs"""
        try:
            if sys.platform == "darwin":
                log_dir = Path.home() / "Library" / "Logs" / "ad-setup"
            else:
                log_dir = Path("/var/log/ad-setup")
            
            # Simple log rotation - keep only last 1MB
            log_file = log_dir / "ad-setup.log"
            if log_file.exists() and log_file.stat().st_size > 1024 * 1024:  # 1MB
                backup_file = log_dir / "ad-setup.log.old"
                if backup_file.exists():
                    backup_file.unlink()
                log_file.rename(backup_file)
                self.logger.info("Log file rotated")
                
        except Exception as e:
            self.logger.error(f"Log cleanup error: {e}")
    
    def run(self):
        """Main daemon loop"""
        self.logger.info("AD-Setup Daemon starting...")
        self.logger.info(f"PID: {os.getpid()}")
        
        # Set up signal handlers
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)
        
        self.running = True
        start_time = time.time()
        
        # Initial checks
        self.perform_health_check()
        self.monitor_forests()
        
        check_interval = self.config.get('general', {}).get('health_check_interval', 60)
        
        while self.running:
            try:
                # Update uptime
                self.metrics['uptime'] = int(time.time() - start_time)
                
                # Perform periodic tasks
                self.monitor_forests()
                self.perform_health_check()
                
                # Cleanup logs occasionally
                if self.metrics['health_checks'] % 100 == 0:
                    self.cleanup_logs()
                
                # Sleep until next check
                self.logger.debug(f"Sleeping for {check_interval} seconds...")
                time.sleep(check_interval)
                
            except Exception as e:
                self.logger.error(f"Daemon error: {e}", exc_info=True)
                time.sleep(10)  # Brief pause on error
        
        self.logger.info("AD-Setup Daemon stopped")

def main():
    """Entry point for the daemon"""
    daemon = ADSetupDaemon()
    
    try:
        daemon.run()
    except KeyboardInterrupt:
        daemon.logger.info("Daemon interrupted by user")
    except Exception as e:
        daemon.logger.error(f"Fatal error: {e}", exc_info=True)
        sys.exit(1)

if __name__ == "__main__":
    main()
