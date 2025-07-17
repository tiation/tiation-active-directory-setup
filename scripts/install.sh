#!/bin/bash

###############################################################
#                AD-Setup Enterprise Installer                #
#              Cross-Platform Installation Script             #
###############################################################

set -euo pipefail

# Detect operating system and redirect to appropriate installer
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Detected macOS. Redirecting to macOS installer..."
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    exec "$SCRIPT_DIR/install-mac.sh" "$@"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation variables
INSTALL_DIR="/opt/ad-setup"
CONFIG_DIR="/etc/ad-setup"
LOG_DIR="/var/log/ad-setup"
DATA_DIR="/var/lib/ad-setup"
SYSTEMD_DIR="/etc/systemd/system"

# Functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check OS
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot determine OS. This installer requires Ubuntu 20.04+ or RHEL 8+"
        exit 1
    fi
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
    
    # Check required commands
    local required_commands=("docker" "python3" "curl" "jq")
    for cmd in "${required_commands[@]}"; do
        if ! command -v $cmd &> /dev/null; then
            warning "$cmd not found. Will install during setup."
        fi
    done
    
    log "Prerequisites check completed"
}

install_dependencies() {
    log "Installing dependencies..."
    
    # Detect package manager
    if command -v apt-get &> /dev/null; then
        apt-get update
        apt-get install -y \
            docker.io \
            docker-compose \
            python3-pip \
            python3-venv \
            curl \
            jq \
            git \
            make \
            build-essential
    elif command -v yum &> /dev/null; then
        yum install -y \
            docker \
            docker-compose \
            python3 \
            python3-pip \
            curl \
            jq \
            git \
            make \
            gcc
    else
        error "Unsupported package manager"
        exit 1
    fi
    
    # Start Docker service
    systemctl enable docker
    systemctl start docker
    
    log "Dependencies installed successfully"
}

create_directory_structure() {
    log "Creating directory structure..."
    
    directories=(
        "$INSTALL_DIR"
        "$CONFIG_DIR"
        "$LOG_DIR"
        "$DATA_DIR"
        "$DATA_DIR/forests"
        "$DATA_DIR/backups"
        "$DATA_DIR/certificates"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
        chmod 755 "$dir"
    done
    
    # Set proper permissions
    chmod 700 "$DATA_DIR/certificates"
    
    log "Directory structure created"
}

install_application() {
    log "Installing AD-Setup application..."
    
    # Copy application files
    cp -r src/* "$INSTALL_DIR/"
    cp -r scripts/* "$INSTALL_DIR/scripts/"
    cp -r ci-cd "$INSTALL_DIR/"
    
    # Create Python virtual environment
    python3 -m venv "$INSTALL_DIR/venv"
    source "$INSTALL_DIR/venv/bin/activate"
    
    # Install Python dependencies
    pip install --upgrade pip
    pip install namecheap pyyaml requests docker prometheus-client
    
    # Make scripts executable
    chmod +x "$INSTALL_DIR/scripts/"*.sh
    chmod +x "$INSTALL_DIR/scripts/deployment/"*.sh
    
    log "Application installed"
}

create_cli_wrapper() {
    log "Creating CLI wrapper..."
    
    cat > /usr/local/bin/ad-setup << 'EOF'
#!/bin/bash
source /opt/ad-setup/venv/bin/activate
python3 /opt/ad-setup/cli.py "$@"
EOF
    
    chmod +x /usr/local/bin/ad-setup
    
    log "CLI wrapper created. You can now use 'ad-setup' command."
}

create_systemd_service() {
    log "Creating systemd service..."
    
    cat > "$SYSTEMD_DIR/ad-setup.service" << EOF
[Unit]
Description=AD-Setup Enterprise Service
After=docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=/opt/ad-setup/venv/bin/python /opt/ad-setup/daemon.py
Restart=always
RestartSec=10
StandardOutput=append:$LOG_DIR/ad-setup.log
StandardError=append:$LOG_DIR/ad-setup-error.log
Environment="PATH=/opt/ad-setup/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable ad-setup.service
    
    log "Systemd service created"
}

setup_logging() {
    log "Setting up logging..."
    
    # Create log rotation config
    cat > /etc/logrotate.d/ad-setup << EOF
$LOG_DIR/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0640 root root
    sharedscripts
    postrotate
        systemctl reload ad-setup.service > /dev/null 2>&1 || true
    endscript
}
EOF
    
    log "Logging configured"
}

create_default_config() {
    log "Creating default configuration..."
    
    cat > "$CONFIG_DIR/config.yaml" << EOF
# AD-Setup Enterprise Configuration
version: 1.0

general:
  log_level: INFO
  api_port: 8080
  enable_metrics: true
  metrics_port: 9090

docker:
  network_name: ad-network
  image: sambaorg/samba-ad-dc
  restart_policy: unless-stopped

security:
  enable_ssl: true
  cert_path: /var/lib/ad-setup/certificates
  enable_audit_log: true
  password_policy:
    min_length: 12
    require_uppercase: true
    require_lowercase: true
    require_numbers: true
    require_special: true

backup:
  enabled: true
  schedule: "0 2 * * *"  # Daily at 2 AM
  retention_days: 30
  destination: /var/lib/ad-setup/backups

monitoring:
  health_check_interval: 60
  alert_email: admin@example.com
  enable_prometheus: true
EOF
    
    chmod 600 "$CONFIG_DIR/config.yaml"
    
    log "Default configuration created"
}

print_next_steps() {
    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${GREEN}AD-Setup Enterprise Installation Complete!${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Configure your Namecheap API credentials:"
    echo "   $ ad-setup configure"
    echo ""
    echo "2. Start the AD-Setup service:"
    echo "   $ systemctl start ad-setup"
    echo ""
    echo "3. Deploy your first AD forest:"
    echo "   $ ad-setup deploy --forest yourdomain.com"
    echo ""
    echo "4. Access the web UI (if enabled):"
    echo "   http://localhost:8080"
    echo ""
    echo "For more information, visit:"
    echo "https://github.com/yourusername/ad-setup"
    echo ""
}

# Main installation flow
main() {
    echo -e "${BLUE}AD-Setup Enterprise Installer${NC}"
    echo "=============================="
    echo ""
    
    check_prerequisites
    install_dependencies
    create_directory_structure
    install_application
    create_cli_wrapper
    create_systemd_service
    setup_logging
    create_default_config
    print_next_steps
}

# Run main function
main "$@"
