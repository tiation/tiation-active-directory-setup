#!/bin/bash

###############################################################
#           AD-Setup Enterprise Installer for macOS           #
#              Production-Grade Installation Script           #
###############################################################

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation variables for macOS
INSTALL_DIR="$HOME/.ad-setup"
CONFIG_DIR="$HOME/.config/ad-setup"
LOG_DIR="$HOME/Library/Logs/ad-setup"
DATA_DIR="$HOME/Library/Application Support/ad-setup"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

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
    
    # Check if macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        error "This installer is for macOS only. Please use install.sh for Linux."
        exit 1
    fi
    
    # Check macOS version
    macos_version=$(sw_vers -productVersion)
    log "Detected macOS version: $macos_version"
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        warning "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for Apple Silicon Macs
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi
    
    log "Prerequisites check completed"
}

install_dependencies() {
    log "Installing dependencies via Homebrew..."
    
    # Update Homebrew
    brew update
    
    # Install required packages
    brew_packages=(
        "docker"
        "docker-compose"
        "python@3.11"
        "curl"
        "jq"
        "git"
        "make"
    )
    
    for package in "${brew_packages[@]}"; do
        if brew list "$package" &>/dev/null; then
            log "$package is already installed"
        else
            log "Installing $package..."
            brew install "$package"
        fi
    done
    
    # Install Docker Desktop for Mac if not already installed
    if ! [ -d "/Applications/Docker.app" ]; then
        warning "Docker Desktop not found. Please install Docker Desktop for Mac from:"
        echo "https://www.docker.com/products/docker-desktop/"
        echo ""
        read -p "Press Enter after installing Docker Desktop to continue..."
    fi
    
    # Start Docker Desktop
    if ! docker info &>/dev/null; then
        log "Starting Docker Desktop..."
        open -a Docker
        echo "Waiting for Docker to start..."
        while ! docker info &>/dev/null; do
            sleep 2
        done
        log "Docker is running"
    fi
    
    log "Dependencies installed successfully"
}

create_directory_structure() {
    log "Creating directory structure..."
    
    directories=(
        "$INSTALL_DIR"
        "$INSTALL_DIR/bin"
        "$INSTALL_DIR/lib"
        "$CONFIG_DIR"
        "$LOG_DIR"
        "$DATA_DIR"
        "$DATA_DIR/forests"
        "$DATA_DIR/backups"
        "$DATA_DIR/certificates"
        "$LAUNCH_AGENTS_DIR"
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
    cp -r src/* "$INSTALL_DIR/lib/" 2>/dev/null || mkdir -p "$INSTALL_DIR/lib"
    cp -r scripts/* "$INSTALL_DIR/scripts/" 2>/dev/null || mkdir -p "$INSTALL_DIR/scripts"
    cp -r ci-cd "$INSTALL_DIR/" 2>/dev/null || true
    
    # Create Python virtual environment
    python3 -m venv "$INSTALL_DIR/venv"
    source "$INSTALL_DIR/venv/bin/activate"
    
    # Install Python dependencies
    pip install --upgrade pip
    
    # Install from requirements.txt if it exists
    if [ -f "$SCRIPT_DIR/../requirements.txt" ]; then
        pip install -r "$SCRIPT_DIR/../requirements.txt"
    else
        # Fallback to direct installation
        pip install PyYAML requests docker prometheus-client click python-dotenv colorama tabulate cryptography
    fi
    
    # Make scripts executable
    find "$INSTALL_DIR/scripts" -name "*.sh" -exec chmod +x {} \;
    
    log "Application installed"
}

create_cli_wrapper() {
    log "Creating CLI wrapper..."
    
    # Create the CLI wrapper
    cat > "$INSTALL_DIR/bin/ad-setup" << EOF
#!/bin/bash
source "$INSTALL_DIR/venv/bin/activate"
python3 "$INSTALL_DIR/lib/cli.py" "\$@"
EOF
    
    chmod +x "$INSTALL_DIR/bin/ad-setup"
    
    # Add to PATH in shell profiles
    shell_profiles=(
        "$HOME/.zshrc"
        "$HOME/.bash_profile"
        "$HOME/.bashrc"
    )
    
    path_line="export PATH=\"\$PATH:$INSTALL_DIR/bin\""
    
    for profile in "${shell_profiles[@]}"; do
        if [ -f "$profile" ]; then
            if ! grep -q "$INSTALL_DIR/bin" "$profile"; then
                echo "" >> "$profile"
                echo "# AD-Setup Enterprise" >> "$profile"
                echo "$path_line" >> "$profile"
                log "Added AD-Setup to PATH in $profile"
            fi
        fi
    done
    
    log "CLI wrapper created. Restart your terminal or run: source ~/.zshrc"
}

create_launch_agent() {
    log "Creating Launch Agent for background service..."
    
    plist_file="$LAUNCH_AGENTS_DIR/com.ad-setup.enterprise.plist"
    
    cat > "$plist_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ad-setup.enterprise</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/venv/bin/python</string>
        <string>$INSTALL_DIR/lib/daemon.py</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/ad-setup.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/ad-setup-error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$INSTALL_DIR/bin</string>
        <key>AD_SETUP_HOME</key>
        <string>$INSTALL_DIR</string>
    </dict>
</dict>
</plist>
EOF
    
    # Load the launch agent
    launchctl load -w "$plist_file" 2>/dev/null || true
    
    log "Launch Agent created and loaded"
}

create_default_config() {
    log "Creating default configuration..."
    
    cat > "$CONFIG_DIR/config.yaml" << EOF
# AD-Setup Enterprise Configuration for macOS
version: 1.0

general:
  log_level: INFO
  api_port: 8080
  enable_metrics: true
  metrics_port: 9090
  platform: macos

docker:
  network_name: ad-network
  image: sambaorg/samba-ad-dc
  restart_policy: unless-stopped
  # macOS-specific Docker settings
  docker_host: unix:///var/run/docker.sock
  use_docker_desktop: true

paths:
  install_dir: $INSTALL_DIR
  config_dir: $CONFIG_DIR
  log_dir: $LOG_DIR
  data_dir: $DATA_DIR

security:
  enable_ssl: true
  cert_path: $DATA_DIR/certificates
  enable_audit_log: true
  # Use macOS Keychain for credential storage
  use_keychain: true
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
  destination: $DATA_DIR/backups
  # Optional: Use Time Machine integration
  time_machine_integration: false

monitoring:
  health_check_interval: 60
  alert_email: admin@example.com
  enable_prometheus: true
  # macOS notification support
  enable_notifications: true

integrations:
  # macOS-specific integrations
  use_bonjour: true
  directory_utility_compatible: true
EOF
    
    chmod 600 "$CONFIG_DIR/config.yaml"
    
    log "Default configuration created"
}

setup_macos_specific() {
    log "Setting up macOS-specific features..."
    
    # Create an Automator app for GUI access (optional)
    if command -v osacompile &> /dev/null; then
        log "Creating macOS app bundle..."
        
        app_dir="$HOME/Applications/AD-Setup.app"
        mkdir -p "$app_dir/Contents/MacOS"
        
        # Create a simple AppleScript launcher
        cat > "$app_dir/Contents/MacOS/launcher.sh" << EOF
#!/bin/bash
osascript -e 'tell application "Terminal" to do script "ad-setup ui"'
EOF
        chmod +x "$app_dir/Contents/MacOS/launcher.sh"
        
        # Create Info.plist
        cat > "$app_dir/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>launcher.sh</string>
    <key>CFBundleIdentifier</key>
    <string>com.ad-setup.enterprise</string>
    <key>CFBundleName</key>
    <string>AD-Setup</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
</dict>
</plist>
EOF
        
        log "macOS app bundle created at $app_dir"
    fi
    
    # Setup macOS Keychain integration
    log "Setting up Keychain integration..."
    security add-generic-password -a "ad-setup" -s "AD-Setup Enterprise" -w "" 2>/dev/null || true
    
    log "macOS-specific setup completed"
}

print_next_steps() {
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${GREEN}AD-Setup Enterprise Installation Complete! (macOS)${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Restart your terminal or run:"
    echo "   $ source ~/.zshrc"
    echo ""
    echo "2. Configure your Namecheap API credentials:"
    echo "   $ ad-setup configure"
    echo ""
    echo "3. Start the AD-Setup service:"
    echo "   $ launchctl start com.ad-setup.enterprise"
    echo ""
    echo "4. Deploy your first AD forest:"
    echo "   $ ad-setup deploy --forest yourdomain.com"
    echo ""
    echo "5. Access the web UI (if enabled):"
    echo "   http://localhost:8080"
    echo ""
    echo "Optional: Find AD-Setup app in ~/Applications/"
    echo ""
    echo "For more information, visit:"
    echo "https://github.com/yourusername/ad-setup"
    echo ""
}

# Main installation flow
main() {
    echo -e "${BLUE}AD-Setup Enterprise Installer for macOS${NC}"
    echo "======================================="
    echo ""
    
    check_prerequisites
    install_dependencies
    create_directory_structure
    install_application
    create_cli_wrapper
    create_launch_agent
    create_default_config
    setup_macos_specific
    print_next_steps
}

# Run main function
main "$@"
