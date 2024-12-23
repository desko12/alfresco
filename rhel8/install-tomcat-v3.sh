#!/bin/bash

# Enable exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Global variables
TOMCAT_USER="tomcat"
TOMCAT_GROUP="tomcat"
TOMCAT_HOME="/opt/tomcat"
TOMCAT_VERSION=""
JAVA_HOME=""
OS=""

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Clean up function
cleanup() {
    log "Cleaning up temporary files..."
    if [ -f "/tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz" ]; then
        rm -f "/tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz"
    fi
}

# Function to detect OS
detect_os() {
    log "Detecting operating system..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION_ID=$VERSION_ID
        log "Detected OS: $OS $VERSION_ID"
        
        # Validate supported OS
        case $OS in
            "debian"|"ubuntu"|"rhel"|"rocky"|"almalinux")
                log "OS is supported"
                ;;
            *)
                error "Unsupported operating system: $OS"
                ;;
        esac
    else
        error "Cannot detect OS. Exiting."
    fi
}

# Function to fetch the latest Tomcat version
fetch_latest_version() {
    log "Fetching latest Tomcat version..."
    local version
    local response
    
    # Try up to 3 times to fetch the version
    for i in {1..3}; do
        response=$(curl -s -f https://dlcdn.apache.org/tomcat/tomcat-10/ 2>/dev/null) && break
        if [ $i -eq 3 ]; then
            error "Failed to fetch Tomcat version after 3 attempts"
        fi
        log "Attempt $i failed, retrying..."
        sleep 2
    done
    
    version=$(echo "$response" | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' | tail -1 | sed 's/v//')
    if [ -z "$version" ]; then
        error "Could not determine latest Tomcat version"
    fi
    
    log "Latest Tomcat version: $version"
    TOMCAT_VERSION="$version"
}

# Function to install Java and dependencies
install_dependencies() {
    log "Installing dependencies for $OS..."
    case $OS in
        "debian"|"ubuntu")
            log "Updating package list..."
            sudo apt update -qq || error "Failed to update package list"
            
            log "Installing OpenJDK 17, curl, and wget..."
            sudo apt install -y curl wget openjdk-17-jdk || error "Failed to install dependencies"
            JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
            ;;
            
        "rhel"|"rocky"|"almalinux")
            log "Installing EPEL repository..."
            sudo dnf install -y epel-release || error "Failed to install EPEL repository"
            
            log "Updating system packages..."
            sudo dnf update -y || error "Failed to update system packages"
            
            log "Installing OpenJDK 17, curl, and wget..."
            sudo dnf install -y curl wget java-17-openjdk-devel || error "Failed to install dependencies"
            JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
            ;;
    esac
    
    # Verify Java installation
    if ! command -v java &> /dev/null; then
        error "Java installation failed"
    fi
    
    log "Dependencies installation completed successfully"
}

# Function to setup users and permissions
setup_users() {
    log "Setting up users and permissions..."
    
    # Create group if it doesn't exist
    if ! getent group $TOMCAT_GROUP >/dev/null; then
        log "Creating group: $TOMCAT_GROUP"
        sudo groupadd $TOMCAT_GROUP || error "Failed to create group $TOMCAT_GROUP"
    else
        log "Group $TOMCAT_GROUP already exists"
    fi
    
    # Create user if it doesn't exist
    if ! getent passwd $TOMCAT_USER >/dev/null; then
        log "Creating user: $TOMCAT_USER"
        sudo useradd -r -g $TOMCAT_GROUP -d $TOMCAT_HOME -s /bin/false $TOMCAT_USER || error "Failed to create user $TOMCAT_USER"
    else
        log "User $TOMCAT_USER already exists"
        # Ensure user has correct group
        sudo usermod -g $TOMCAT_GROUP $TOMCAT_USER || warning "Failed to modify user group"
    fi
    
    # Create and set permissions for TOMCAT_HOME
    if [ ! -d "$TOMCAT_HOME" ]; then
        log "Creating Tomcat home directory: $TOMCAT_HOME"
        sudo mkdir -p $TOMCAT_HOME || error "Failed to create $TOMCAT_HOME"
    fi
    
    sudo chown -R $TOMCAT_USER:$TOMCAT_GROUP $TOMCAT_HOME || error "Failed to set ownership of $TOMCAT_HOME"
}

# Function to install Tomcat
install_tomcat() {
    log "Starting Tomcat installation..."
    local download_url="https://dlcdn.apache.org/tomcat/tomcat-10/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz"
    local temp_file="/tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz"
    
    # Download Tomcat
    log "Downloading Apache Tomcat $TOMCAT_VERSION..."
    if ! wget -q "$download_url" -O "$temp_file"; then
        error "Failed to download Tomcat"
    fi
    
    # Verify download
    if [ ! -f "$temp_file" ]; then
        error "Downloaded file not found"
    fi
    
    # Extract Tomcat
    log "Extracting Tomcat..."
    sudo tar xf "$temp_file" -C $TOMCAT_HOME --strip-components=1 || error "Failed to extract Tomcat"
    
    # Set permissions
    log "Setting permissions..."
    sudo chown -R $TOMCAT_USER:$TOMCAT_GROUP $TOMCAT_HOME
    sudo chmod -R u+x $TOMCAT_HOME/bin
    
    # Cleanup
    cleanup
}

# Function to create systemd service
create_service() {
    log "Creating Tomcat systemd service..."
    
    cat <<EOL | sudo tee /etc/systemd/system/tomcat.service
[Unit]
Description=Apache Tomcat Web Application Container
After=network.target

[Service]
Type=forking

User=$TOMCAT_USER
Group=$TOMCAT_GROUP

Environment="JAVA_HOME=$JAVA_HOME"
Environment="CATALINA_PID=$TOMCAT_HOME/temp/tomcat.pid"
Environment="CATALINA_HOME=$TOMCAT_HOME"
Environment="CATALINA_BASE=$TOMCAT_HOME"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"

ExecStart=$TOMCAT_HOME/bin/startup.sh
ExecStop=$TOMCAT_HOME/bin/shutdown.sh

RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOL

    log "Created systemd service file: /etc/systemd/system/tomcat.service"
    
    # Reload systemd
    sudo systemctl daemon-reload || error "Failed to reload systemd daemon"
}

# Function to configure Tomcat
configure_tomcat() {
    log "Configuring Tomcat..."
    
    # Create basic directories if they don't exist
    local dirs=("conf" "logs" "temp" "webapps" "work")
    for dir in "${dirs[@]}"; do
        if [ ! -d "$TOMCAT_HOME/$dir" ]; then
            sudo mkdir -p "$TOMCAT_HOME/$dir"
            sudo chown -R $TOMCAT_USER:$TOMCAT_GROUP "$TOMCAT_HOME/$dir"
        fi
    done
    
    # Backup original configuration files
    local timestamp=$(date +%Y%m%d_%H%M%S)
    if [ -f "$TOMCAT_HOME/conf/server.xml" ]; then
        sudo cp "$TOMCAT_HOME/conf/server.xml" "$TOMCAT_HOME/conf/server.xml.backup_$timestamp"
    fi
}

# Function to start Tomcat
start_tomcat() {
    log "Starting Tomcat service..."
    
    sudo systemctl start tomcat || error "Failed to start Tomcat service"
    sudo systemctl enable tomcat || warning "Failed to enable Tomcat service"
    
    # Wait for service to start
    log "Waiting for Tomcat to start..."
    sleep 5
    
    if systemctl is-active --quiet tomcat; then
        log "Tomcat service is running"
    else
        error "Tomcat service failed to start"
    fi
}

# Function to verify installation
verify_installation() {
    log "Verifying installation..."
    
    # Check Java version
    log "Java version:"
    java -version
    
    # Check service status
    log "Service status:"
    systemctl status tomcat --no-pager
    
    # Check port 8080
    log "Checking if Tomcat is listening on port 8080..."
    sleep 2
    if command -v netstat >/dev/null; then
        if ! netstat -tulpn | grep -q ':8080'; then
            warning "Tomcat is not listening on port 8080"
        fi
    elif command -v ss >/dev/null; then
        if ! ss -tulpn | grep -q ':8080'; then
            warning "Tomcat is not listening on port 8080"
        fi
    fi
}

# Main installation process
main() {
    log "Starting Tomcat installation process..."
    
    # Check if running as root or with sudo
    if [ "$EUID" -ne 0 ]; then
        error "Please run this script with sudo or as root"
    fi
    
    # Trap cleanup function
    trap cleanup EXIT
    
    # Installation steps
    detect_os
    install_dependencies
    fetch_latest_version
    setup_users
    install_tomcat
    configure_tomcat
    create_service
    start_tomcat
    verify_installation
    
    log "Installation completed successfully!"
    
    # Print installation summary
    echo -e "\n${GREEN}Installation Summary:${NC}"
    echo "======================="
    echo "OS Type: $OS"
    echo "Tomcat Version: $TOMCAT_VERSION"
    echo "Java Home: $JAVA_HOME"
    echo "Tomcat Home: $TOMCAT_HOME"
    echo "Tomcat User: $TOMCAT_USER"
    echo "Tomcat Service: enabled and started"
    echo "Tomcat Web Interface: http://localhost:8080"
    echo "Verify by visiting: http://localhost:8080 or http://YOUR_SERVER_IP:8080"
    echo "======================="
}

# Execute main function
main "$@"
