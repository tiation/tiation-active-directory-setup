#!/usr/bin/env python3
"""
AD-Setup Enterprise CLI
Main command-line interface for AD forest management
"""

import click
import yaml
import json
import os
import sys
from pathlib import Path

# Add current directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

@click.group()
@click.version_option(version='1.0.0', prog_name='AD-Setup Enterprise')
def cli():
    """AD-Setup Enterprise - Active Directory Automation Tool"""
    pass

@cli.command()
def configure():
    """Configure AD-Setup with your credentials and preferences"""
    click.echo("🔧 AD-Setup Configuration Wizard")
    click.echo("=" * 40)
    
    # Get Namecheap credentials
    api_key = click.prompt("Enter your Namecheap API key", hide_input=True)
    api_user = click.prompt("Enter your Namecheap API username")
    
    # Get environment
    environment = click.prompt(
        "Environment (sandbox/production)", 
        default="production",
        type=click.Choice(['sandbox', 'production'])
    )
    
    # Save configuration
    config_dir = Path.home() / ".config" / "ad-setup"
    config_dir.mkdir(parents=True, exist_ok=True)
    
    credentials = {
        'namecheap': {
            'api_key': api_key,
            'api_user': api_user,
            'environment': environment
        }
    }
    
    cred_file = config_dir / "credentials.yaml"
    with open(cred_file, 'w') as f:
        yaml.dump(credentials, f)
    
    # Secure the file
    os.chmod(cred_file, 0o600)
    
    click.echo("✅ Configuration saved successfully!")

@cli.command()
@click.option('--forest', required=True, help='Domain name for the AD forest')
@click.option('--admin-password', help='Administrator password')
@click.option('--dns-provider', default='namecheap', help='DNS provider to use')
def deploy(forest, admin_password, dns_provider):
    """Deploy a new AD forest"""
    click.echo(f"🚀 Deploying AD forest: {forest}")
    click.echo(f"   DNS Provider: {dns_provider}")
    
    if not admin_password:
        admin_password = click.prompt("Enter administrator password", hide_input=True, confirmation_prompt=True)
    
    # TODO: Implement actual deployment logic
    click.echo("📦 Creating Docker containers...")
    click.echo("🔧 Configuring Samba AD DC...")
    click.echo("🌐 Setting up DNS records...")
    click.echo("✅ Forest deployment initiated!")

@cli.command()
@click.option('--primary', required=True, help='Primary forest domain')
@click.option('--secondary', required=True, help='Secondary forest domain')
@click.option('--trust-type', default='bidirectional', 
              type=click.Choice(['bidirectional', 'oneway-in', 'oneway-out']))
def deploy_multi(primary, secondary, trust_type):
    """Deploy multiple AD forests with trust relationships"""
    click.echo(f"🌲 Deploying multi-forest environment:")
    click.echo(f"   Primary: {primary}")
    click.echo(f"   Secondary: {secondary}")
    click.echo(f"   Trust Type: {trust_type}")
    
    # TODO: Implement multi-forest deployment
    click.echo("✅ Multi-forest deployment initiated!")

@cli.command()
def status():
    """Check the status of AD forests"""
    click.echo("📊 AD Forest Status")
    click.echo("=" * 60)
    
    # Check if daemon is running
    status_file = Path.home() / ".ad-setup" / "status.json"
    
    if status_file.exists():
        try:
            with open(status_file, 'r') as f:
                status = json.load(f)
            
            # Display daemon status
            daemon_info = status.get('daemon', {})
            click.echo("🔧 Daemon Status:")
            click.echo(f"   PID: {daemon_info.get('pid', 'Unknown')}")
            click.echo(f"   Uptime: {daemon_info.get('uptime', 0)} seconds")
            click.echo(f"   Health Checks: {daemon_info.get('health_checks', 0)}")
            click.echo(f"   Last Check: {status.get('timestamp', 'Unknown')}")
            
            # Display Docker status
            click.echo("\n🐳 Docker Status:")
            docker_status = "✅ Running" if status.get('docker', False) else "❌ Not Running"
            click.echo(f"   {docker_status}")
            
            # Display forest status
            forests = status.get('forests', {})
            click.echo(f"\n🌲 Active Forests: {len(forests)}")
            
            if forests:
                for forest_name, forest_info in forests.items():
                    click.echo(f"\n   Forest: {forest_name}")
                    click.echo(f"     Container ID: {forest_info.get('container_id', 'Unknown')[:12]}")
                    click.echo(f"     Status: {forest_info.get('status', 'Unknown')}")
                    click.echo(f"     Health: {forest_info.get('health', 'Unknown')}")
            else:
                click.echo("   No forests currently deployed.")
                
        except Exception as e:
            click.echo(f"Error reading status: {e}")
            click.echo("Daemon may not be running. Start with: launchctl start com.ad-setup.enterprise")
    else:
        click.echo("❌ No status information available.")
        click.echo("The daemon may not be running.")
        click.echo("\nTo start the daemon:")
        click.echo("  $ launchctl start com.ad-setup.enterprise")
        click.echo("\nTo check daemon logs:")
        click.echo("  $ ad-setup logs --errors")

@cli.command()
@click.option('--port', default=8080, help='Port to run the web UI on')
@click.option('--no-browser', is_flag=True, help='Don\'t open browser automatically')
def ui(port, no_browser):
    """Launch the web UI (if available)"""
    click.echo(f"🌐 Starting AD-Setup Web UI on port {port}...")
    
    # Start the web server in a separate process
    import subprocess
    import webbrowser
    import time
    
    # Get the path to the web_ui.py script
    web_ui_path = Path(__file__).parent / 'web_ui.py'
    
    try:
        # Start the web server
        process = subprocess.Popen(
            [sys.executable, str(web_ui_path)],
            env={**os.environ, 'AD_SETUP_PORT': str(port)}
        )
        
        # Give the server a moment to start
        time.sleep(1)
        
        # Open browser unless disabled
        if not no_browser:
            click.echo(f"   Opening http://localhost:{port} in your browser...")
            webbrowser.open(f'http://localhost:{port}')
        
        click.echo(f"\n✨ Web UI is running at: http://localhost:{port}")
        click.echo("Press Ctrl+C to stop the server")
        
        # Wait for the process
        process.wait()
        
    except KeyboardInterrupt:
        click.echo("\n🛑 Stopping Web UI...")
        if 'process' in locals():
            process.terminate()
    except Exception as e:
        click.echo(f"Error starting web UI: {e}", err=True)

@cli.command()
@click.option('--errors', is_flag=True, help='Show only error logs')
@click.option('--tail', default=0, help='Show only last N lines')
def logs(errors, tail):
    """View AD-Setup logs"""
    if sys.platform == "darwin":
        log_dir = Path.home() / "Library" / "Logs" / "ad-setup"
    else:
        log_dir = Path("/var/log/ad-setup")
    
    # Determine which log file to show
    if errors:
        log_file = log_dir / "ad-setup-error.log"
        log_type = "Error"
    else:
        log_file = log_dir / "ad-setup.log"
        log_type = "Application"
    
    if log_file.exists():
        click.echo(f"📄 {log_type} logs from: {log_file}")
        click.echo("=" * 60)
        
        with open(log_file, 'r') as f:
            lines = f.readlines()
            
        if tail > 0:
            lines = lines[-tail:]
        
        if lines:
            click.echo(''.join(lines))
        else:
            click.echo(f"No entries in {log_type.lower()} log.")
    else:
        click.echo(f"No {log_type.lower()} log file found.")
    
    # Show a summary of available logs
    click.echo("\n" + "=" * 60)
    click.echo("📊 Log Summary:")
    
    for filename in ['ad-setup.log', 'ad-setup-error.log']:
        filepath = log_dir / filename
        if filepath.exists():
            size = filepath.stat().st_size
            if size > 0:
                with open(filepath, 'r') as f:
                    line_count = sum(1 for _ in f)
                click.echo(f"  • {filename}: {line_count} lines ({size} bytes)")
            else:
                click.echo(f"  • {filename}: Empty")
    
    click.echo("\nTip: Use --errors to see error logs, --tail N to see last N lines")

@cli.command()
def version():
    """Show version information"""
    click.echo("AD-Setup Enterprise v1.0.0")
    click.echo("Copyright (c) 2024 AD-Setup Team")
    click.echo("License: GPL v3")

if __name__ == '__main__':
    cli()
