#!/bin/bash

set -e

# Function to detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION_ID=$VERSION_ID
    else
        echo "Cannot detect OS. Exiting..."
        exit 1
    fi
}

# Function to install packages based on OS
install_dependencies() {
    case $OS in
        "debian"|"ubuntu")
            echo "Installing dependencies for Debian/Ubuntu..."
            sudo apt-get update
            sudo apt-get install -y imagemagick libreoffice exiftool openjdk-17-jdk
            JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
            ;;
        "rhel"|"rocky"|"almalinux")
            echo "Installing dependencies for RHEL/Rocky/AlmaLinux..."
            sudo dnf update -y
            sudo dnf install -y epel-release
            sudo dnf install -y ImageMagick libreoffice perl-Image-ExifTool java-17-openjdk-devel
            JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
            ;;
        *)
            echo "Unsupported OS: $OS"
            exit 1
            ;;
    esac
}

# Function to create system user if it doesn't exist
create_system_user() {
    if ! id "transform" &>/dev/null; then
        case $OS in
            "debian"|"ubuntu")
                sudo useradd -r -m -d /opt/alfresco/transform transform
                ;;
            "rhel"|"rocky"|"almalinux")
                sudo useradd -r -m -d /opt/alfresco/transform transform
                ;;
        esac
    fi
}

echo "Detecting OS..."
detect_os
echo "Detected OS: $OS"

echo "Installing Transform dependencies..."
install_dependencies

echo "Installing Alfresco PDF Renderer..."
curl -L -o /tmp/alfresco-pdf-renderer-1.2-linux.tgz https://nexus.alfresco.com/nexus/repository/releases/org/alfresco/alfresco-pdf-renderer/1.2/alfresco-pdf-renderer-1.2-linux.tgz
sudo tar xf /tmp/alfresco-pdf-renderer-1.2-linux.tgz -C /usr/bin

echo "Configuring Transform server..."
# Create dedicated user and set up directory structure
create_system_user

TRANSFORM_USER=transform
TRANSFORM_GROUP=transform
TRANSFORM_HOME=/opt/alfresco/transform

# Create necessary directories
sudo mkdir -p $TRANSFORM_HOME
sudo chown $TRANSFORM_USER:$TRANSFORM_GROUP $TRANSFORM_HOME

# Copy JAR file to transform home
sudo cp downloads/alfresco-transform-core-aio-5.1.0.jar $TRANSFORM_HOME/
sudo chown $TRANSFORM_USER:$TRANSFORM_GROUP $TRANSFORM_HOME/alfresco-transform-core-aio-5.1.0.jar

echo "Creating Transform systemd service file..."
cat <<EOL | sudo tee /etc/systemd/system/transform.service
[Unit]
Description=Transform Application Container
After=network.target

[Service]
Type=simple

User=$TRANSFORM_USER
Group=$TRANSFORM_GROUP

Environment="JAVA_HOME=$JAVA_HOME"
Environment="LIBREOFFICE_HOME=/usr/lib/libreoffice"

WorkingDirectory=$TRANSFORM_HOME
ExecStart=$JAVA_HOME/bin/java -jar $TRANSFORM_HOME/alfresco-transform-core-aio-5.1.0.jar
ExecStop=/bin/kill -15 \$MAINPID

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL

echo "Setting correct permissions..."
sudo chown root:root /etc/systemd/system/transform.service
sudo chmod 644 /etc/systemd/system/transform.service

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Starting Transform service..."
sudo systemctl start transform

echo "Enabling Transform service to start on boot..."
sudo systemctl enable transform

echo "Transform service status:"
sudo systemctl status transform

echo "Transform has been configured successfully"
