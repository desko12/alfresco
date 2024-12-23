#!/bin/bash

set -e

# Variables
ACTIVEMQ_VERSION=""
JAVA_HOME=""

# Function to detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION_ID=$VERSION_ID
        echo "Detected OS: $OS $VERSION_ID"
    else
        echo "Cannot detect OS, exiting..."
        exit 1
    fi
}

# Function to fetch the latest ActiveMQ version
fetch_latest_version() {
    # Fetches the latest version 5.*.*
    ACTIVEMQ_VERSION=$(curl -s https://dlcdn.apache.org/activemq/ | grep -oP '5+\.[0-9]+\.[0-9]+' | tail -1 | sed 's/v//')
    echo "Latest ActiveMQ version: $ACTIVEMQ_VERSION"
}

# Function to setup users and groups
setup_user_and_group() {
    if ! getent group activemq >/dev/null; then
        sudo groupadd activemq
    fi
    if ! getent passwd activemq >/dev/null; then
        sudo useradd -r -g activemq -d /opt/activemq -s /bin/false activemq
    fi
}

# Function to install Java for RHEL-based systems
install_java_rhel() {
    echo "Installing OpenJDK 17 for RHEL-based system..."
    sudo dnf -y install java-17-openjdk java-17-openjdk-devel
    JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
    echo "JAVA_HOME set to: $JAVA_HOME"
}

# Function to install Java for Debian-based systems
install_java_debian() {
    echo "Installing OpenJDK 17 for Debian-based system..."
    sudo apt-get update
    sudo apt-get install -y openjdk-17-jdk
    JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
    echo "JAVA_HOME set to: $JAVA_HOME"
}

# Function to install dependencies for RHEL-based systems
install_deps_rhel() {
    echo "Installing dependencies for RHEL-based system..."
    sudo dnf -y install wget curl tar
}

# Function to install dependencies for Debian-based systems
install_deps_debian() {
    echo "Installing dependencies for Debian-based system..."
    sudo apt-get update
    sudo apt-get install -y wget curl tar
}

# Main installation function
install_activemq() {
    # Create installation directory
    sudo mkdir -p /opt/activemq
    
    echo "Downloading ActiveMQ..."
    wget "https://dlcdn.apache.org/activemq/$ACTIVEMQ_VERSION/apache-activemq-$ACTIVEMQ_VERSION-bin.tar.gz" -O "/tmp/apache-activemq-$ACTIVEMQ_VERSION-bin.tar.gz"
    
    echo "Extracting ActiveMQ..."
    sudo tar xzf "/tmp/apache-activemq-$ACTIVEMQ_VERSION-bin.tar.gz" -C /opt/activemq --strip-components=1
    
    echo "Setting permissions..."
    sudo chown -R activemq:activemq /opt/activemq
    sudo chmod -R 755 /opt/activemq
}

# Function to create systemd service
create_systemd_service() {
    echo "Creating ActiveMQ systemd service file..."
    cat <<EOL | sudo tee /etc/systemd/system/activemq.service
[Unit]
Description=Apache ActiveMQ
After=network.target

[Service]
Type=forking

User=activemq
Group=activemq

Environment="JAVA_HOME=$JAVA_HOME"
Environment="ACTIVEMQ_HOME=/opt/activemq"
Environment="ACTIVEMQ_BASE=/opt/activemq"
Environment="ACTIVEMQ_CONF=/opt/activemq/conf"
Environment="ACTIVEMQ_DATA=/opt/activemq/data"

ExecStart=/opt/activemq/bin/activemq start
ExecStop=/opt/activemq/bin/activemq stop

[Install]
WantedBy=multi-user.target
EOL

    sudo systemctl daemon-reload
    sudo systemctl enable activemq
    sudo systemctl start activemq
}

# Function to configure firewall
configure_firewall() {
    case $OS in
        "Red Hat Enterprise Linux" | "Rocky Linux" | "AlmaLinux")
            echo "Configuring firewall for RHEL-based system..."
            sudo firewall-cmd --permanent --add-port=8161/tcp
            sudo firewall-cmd --permanent --add-port=61616/tcp
            sudo firewall-cmd --reload
            ;;
        "Debian GNU/Linux" | "Ubuntu")
            echo "Configuring UFW firewall..."
            sudo ufw allow 8161/tcp
            sudo ufw allow 61616/tcp
            ;;
    esac
}

# Main execution
echo "Starting ActiveMQ installation script..."

# Detect OS
detect_os

# Install dependencies and Java based on OS
case $OS in
    "Red Hat Enterprise Linux" | "Rocky Linux" | "AlmaLinux")
        if [ "$VERSION_ID" != "8" ]; then
            echo "This script is designed for version 8. Current version: $VERSION_ID"
            exit 1
        fi
        install_deps_rhel
        install_java_rhel
        ;;
    "Debian GNU/Linux")
        install_deps_debian
        install_java_debian
        ;;
    *)
        echo "Unsupported operating system: $OS"
        exit 1
        ;;
esac

# Fetch latest ActiveMQ version
fetch_latest_version

# Setup user and group
setup_user_and_group

# Install ActiveMQ
install_activemq

# Create systemd service
create_systemd_service

# Configure firewall
configure_firewall

echo "Installation complete! ActiveMQ is now running as a service."
echo "Web Console: http://localhost:8161"
echo "Default credentials - username: admin, password: admin"
echo "Please change the default credentials in conf/jetty-realm.properties"

# Verify installation
echo "Service status:"
sudo systemctl status activemq

# Cleanup
echo "Cleaning up temporary files..."
rm -f "/tmp/apache-activemq-$ACTIVEMQ_VERSION-bin.tar.gz"
