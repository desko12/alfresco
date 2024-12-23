#!/bin/bash

# Enable exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Function to detect OS
detect_os() {
    log "Detecting operating system..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION_ID=$VERSION_ID
        log "Detected OS: $OS $VERSION_ID"
    else
        error "Cannot detect OS. Exiting."
        exit 1
    fi
}

# Function to fetch the latest Tomcat version
fetch_latest_version() {
    log "Fetching latest Tomcat version..."
    TOMCAT_VERSION=$(curl -s https://dlcdn.apache.org/tomcat/tomcat-10/ | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' | tail -1 | sed 's/v//')
    log "Latest Tomcat version: $TOMCAT_VERSION"
    echo $TOMCAT_VERSION
}

# Function to install Java and dependencies
install_dependencies() {
    log "Installing dependencies for $OS..."
    case $OS in
        "debian"|"ubuntu")
            log "Updating package list..."
            sudo apt update
            
            log "Installing OpenJDK 17, curl, and wget..."
            sudo apt install -y curl wget openjdk-17-jdk
            
            # Verify Java installation
            if ! command -v java &> /dev/null; then
                error "Java installation failed"
                exit 1
            fi
            ;;
            
        "rhel"|"rocky"|"almalinux")
            log "Installing EPEL repository..."
            sudo dnf install -y epel-release
            
            log "Updating system packages..."
            sudo dnf update -y
            
            log "Installing OpenJDK 17, curl, and wget..."
            sudo dnf install -y curl wget java-17-openjdk-devel
            
            # Verify Java installation
            if ! command -v java &> /dev/null; then
                error "Java installation failed"
                exit 1
            fi
            ;;
            
        *)
            error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac
    
    log "Dependencies installation completed"
}

# Function to setup system-specific configurations
setup_system_config() {
    log "Setting up system configurations..."
    case $OS in
        "debian"|"ubuntu")
            JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
            ;;
        "rhel"|"rocky"|"almalinux")
            JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
            ;;
    esac
    
    TOMCAT_USER="tomcat"
    TOMCAT_GROUP="tomcat"
    TOMCAT_HOME="/opt/tomcat"
    
    log "System configuration completed:"
    log "JAVA_HOME: $JAVA_HOME"
    log "TOMCAT_USER: $TOMCAT_USER"
    log "TOMCAT_GROUP: $TOMCAT_GROUP"
    log "TOMCAT_HOME: $TOMCAT_HOME"
}

# Function to create user and group
create_user() {
    log "Setting up Tomcat user and group..."
    
    # Check if group exists
    if ! getent group $TOMCAT_GROUP >/dev/null; then
        log "Creating group: $TOMCAT_GROUP"
        sudo groupadd $TOMCAT_GROUP
    else
        log "Group $TOMCAT_GROUP already exists"
    fi
    
    # Check if user exists
    if ! getent passwd $TOMCAT_USER >/dev/null; then
        log "Creating user: $TOMCAT_USER"
        sudo useradd -r -m -U -d $TOMCAT_HOME -s /bin/false $TOMCAT_USER
    else
        log "User $TOMCAT_USER already exists"
    fi
}

# Function to download and install Tomcat
install_tomcat() {
    log "Starting Tomcat installation..."
    
    # Download Tomcat
    log "Downloading Apache Tomcat $TOMCAT_VERSION..."
    wget https://dlcdn.apache.org/tomcat/tomcat-10/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz -O /tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz
    
    # Verify download
    if [ ! -f /tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz ]; then
        error "Failed to download Tomcat"
        exit 1
    fi
    
    # Create installation directory
    log "Creating Tomcat installation directory..."
    sudo mkdir -p $TOMCAT_HOME
    
    # Extract Tomcat
    log "Extracting Tomcat..."
    sudo tar xzvf /tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz -C $TOMCAT_HOME --strip-components=1
    
    # Set permissions
    log "Setting permissions..."
    sudo chown -R $TOMCAT_USER:$TOMCAT_GROUP $TOMCAT_HOME
    sudo chmod -R u+x $TOMCAT_HOME/bin
    
    # Clean up
    log "Cleaning up downloaded files..."
    rm /tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz
}

# Function to create systemd service
create_systemd_service() {
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
Environment="CATALINA_OPTS=-Xms2048M -Xmx3072M -server -XX:MinRAMPercentage=50 -XX:MaxRAMPercentage=80"
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"
Environment="JAVA_TOOL_OPTIONS=-Dencryption.keystore.type=JCEKS -Dencryption.cipherAlgorithm=DESede/CBC/PKCS5Padding -Dencryption.keyAlgorithm=DESede -Dencryption.keystore.location=$TOMCAT_HOME/keystore/metadata-keystore/keystore -Dmetadata-keystore.password=mp6yc0UD9e -Dmetadata-keystore.aliases=metadata -Dmetadata-keystore.metadata.password=oKIWzVdEdA -Dmetadata-keystore.metadata.algorithm=DESede"

ExecStart=$TOMCAT_HOME/bin/startup.sh
ExecStop=$TOMCAT_HOME/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
EOL

    log "Created systemd service file: /etc/systemd/system/tomcat.service"
}

# Function to setup keystore
setup_keystore() {
    log "Setting up keystore directory..."
    sudo mkdir -p $TOMCAT_HOME/keystore/metadata-keystore
    sudo chown -R $TOMCAT_USER:$TOMCAT_GROUP $TOMCAT_HOME/keystore
    log "Keystore directory created and permissions set"
}

# Function to start and enable Tomcat service
start_tomcat() {
    log "Reloading systemd daemon..."
    sudo systemctl daemon-reload
    
    log "Starting Tomcat service..."
    sudo systemctl start tomcat
    
    log "Enabling Tomcat service on boot..."
    sudo systemctl enable tomcat
    
    # Check service status
    if systemctl is-active --quiet tomcat; then
        log "Tomcat service is running"
    else
        error "Tomcat service failed to start"
        log "Checking logs..."
        journalctl -u tomcat --no-pager | tail -n 50
        exit 1
    fi
}

# Function to verify installation
verify_installation() {
    log "Verifying installation..."
    
    # Check Java version
    log "Java version:"
    java -version
    
    # Check Tomcat version
    log "Tomcat version:"
    $TOMCAT_HOME/bin/version.sh
    
    # Check service status
    log "Service status:"
    systemctl status tomcat --no-pager
    
    # Check port 8080
    log "Checking if Tomcat is listening on port 8080..."
    if command -v netstat >/dev/null; then
        sudo netstat -tulpn | grep :8080
    elif command -v ss >/dev/null; then
        sudo ss -tulpn | grep :8080
    fi
}

# Main installation process
main() {
    log "Starting Tomcat installation process..."
    
    # Check if running as root or with sudo
    if [ "$EUID" -ne 0 ]; then
        error "Please run this script with sudo or as root"
        exit 1
    }
    
    # Step 1: Detect OS
    detect_os
    
    # Step 2: Install dependencies
    install_dependencies
    
    # Step 3: Setup system configuration
    setup_system_config
    
    # Step 4: Create user and group
    create_user
    
    # Step 5: Get Tomcat version
    TOMCAT_VERSION=$(fetch_latest_version)
    
    # Step 6: Install Tomcat
    install_tomcat
    
    # Step 7: Create systemd service
    create_systemd_service
    
    # Step 8: Setup keystore
    setup_keystore
    
    # Step 9: Start Tomcat service
    start_tomcat
    
    # Step 10: Verify installation
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
    echo "======================="
}

# Execute main function
main
