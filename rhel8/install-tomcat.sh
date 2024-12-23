#!/bin/bash

set -e

# Function to detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION_ID=$VERSION_ID
    else
        echo "Cannot detect OS. Exiting."
        exit 1
    fi
}

# Function to fetch the latest Tomcat version
fetch_latest_version() {
    curl -s https://dlcdn.apache.org/tomcat/tomcat-10/ | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' | tail -1 | sed 's/v//'
}

# Function to setup system-specific configurations
setup_system_config() {
    case $OS in
        "debian"|"ubuntu")
            JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
            TOMCAT_USER="tomcat"
            TOMCAT_GROUP="tomcat"
            
            # Update package list and install dependencies
            sudo apt update
            sudo apt install -y curl wget openjdk-17-jdk
            ;;
            
        "rhel"|"rocky"|"almalinux")
            JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
            TOMCAT_USER="tomcat"
            TOMCAT_GROUP="tomcat"
            
            # Install EPEL repository and dependencies
            sudo dnf install -y epel-release
            sudo dnf update -y
            sudo dnf install -y curl wget java-17-openjdk-devel
            ;;
            
        *)
            echo "Unsupported operating system: $OS"
            exit 1
            ;;
    esac
}

# Function to create user and group
create_user() {
    # Check if group exists
    if ! getent group $TOMCAT_GROUP >/dev/null; then
        sudo groupadd $TOMCAT_GROUP
    fi
    
    # Check if user exists
    if ! getent passwd $TOMCAT_USER >/dev/null; then
        sudo useradd -r -m -U -d /opt/tomcat -s /bin/false $TOMCAT_USER
    fi
}

# Main script execution starts here
echo "Detecting operating system..."
detect_os
echo "Detected OS: $OS"

# Setup system-specific configurations
setup_system_config

# Create Tomcat user and group
create_user

# Variables
TOMCAT_HOME="/opt/tomcat"
TOMCAT_VERSION=$(fetch_latest_version)

echo "Using Tomcat version: $TOMCAT_VERSION"

echo "Downloading Apache Tomcat..."
wget https://dlcdn.apache.org/tomcat/tomcat-10/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz -O /tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz

echo "Extracting Tomcat..."
sudo mkdir -p $TOMCAT_HOME
sudo tar xzvf /tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz -C $TOMCAT_HOME --strip-components=1

echo "Setting permissions for Tomcat directories..."
sudo chown -R $TOMCAT_USER:$TOMCAT_GROUP $TOMCAT_HOME
sudo chmod -R u+x $TOMCAT_HOME/bin

echo "Creating Tomcat systemd service file..."
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
Environment="JAVA_TOOL_OPTIONS=-Dencryption.keystore.type=JCEKS -Dencryption.cipherAlgorithm=DESede/CBC/PKCS5Padding -Dencryption.keyAlgorithm=DESede -Dencryption.keystore.location=/opt/tomcat/keystore/metadata-keystore/keystore -Dmetadata-keystore.password=mp6yc0UD9e -Dmetadata-keystore.aliases=metadata -Dmetadata-keystore.metadata.password=oKIWzVdEdA -Dmetadata-keystore.metadata.algorithm=DESede"

ExecStart=$TOMCAT_HOME/bin/startup.sh
ExecStop=$TOMCAT_HOME/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
EOL

# Create keystore directory
sudo mkdir -p $TOMCAT_HOME/keystore/metadata-keystore
sudo chown -R $TOMCAT_USER:$TOMCAT_GROUP $TOMCAT_HOME/keystore

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Starting Tomcat service..."
sudo systemctl start tomcat

echo "Enabling Tomcat service to start on boot..."
sudo systemctl enable tomcat

echo "Apache Tomcat installation and setup completed successfully!"

# Print installation summary
echo -e "\nInstallation Summary:"
echo "====================="
echo "OS Type: $OS"
echo "Tomcat Version: $TOMCAT_VERSION"
echo "Java Home: $JAVA_HOME"
echo "Tomcat Home: $TOMCAT_HOME"
echo "Tomcat User: $TOMCAT_USER"
echo "Tomcat Service: enabled and started"
echo "====================="

# Verify installation
if systemctl is-active --quiet tomcat; then
    echo "Tomcat is running successfully!"
else
    echo "Warning: Tomcat service is not running. Please check the logs with: journalctl -u tomcat"
fi
