#!/bin/bash

set -e

# Detect OS distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION_ID=$VERSION_ID
else
    echo "Cannot detect OS distribution"
    exit 1
fi

# Function to install Node.js on RHEL-based systems
install_nodejs_rhel() {
    echo "Installing Node.js and npm on RHEL-based system..."
    # Install curl if not present
    sudo dnf install -y curl
    
    # Install Node.js repository
    curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
    
    # Install Node.js and development tools
    sudo dnf install -y nodejs gcc-c++ make
}

# Function to install Node.js on Debian-based systems
install_nodejs_debian() {
    echo "Installing Node.js and npm on Debian-based system..."
    # Install curl if not present
    sudo apt-get update
    sudo apt-get install -y curl
    
    # Install Node.js repository
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    
    # Install Node.js and development tools
    sudo apt-get install -y nodejs build-essential
}

# Install Git based on OS
install_git() {
    case $OS in
        "rhel"|"rocky"|"almalinux")
            sudo dnf install -y git
            ;;
        "debian"|"ubuntu")
            sudo apt-get install -y git
            ;;
        *)
            echo "Unsupported operating system"
            exit 1
            ;;
    esac
}

echo "Detected OS: $OS"
echo "Version: $VERSION_ID"

# Install Node.js based on OS
case $OS in
    "rhel"|"rocky"|"almalinux")
        install_nodejs_rhel
        ;;
    "debian"|"ubuntu")
        install_nodejs_debian
        ;;
    *)
        echo "Unsupported operating system"
        exit 1
        ;;
esac

# Install Git
install_git

# Verify Node.js and npm installation
echo "Verifying Node.js and npm installation..."
node -v
npm -v

# Clone the Alfresco Content App repository
echo "Cloning Alfresco Content App repository..."
git clone https://github.com/Alfresco/alfresco-content-app.git
cd alfresco-content-app

# Checkout to the specific version 4.4.1
echo "Checking out version 4.4.1..."
git checkout tags/4.4.1 -b 4.4.1

# Install project dependencies
echo "Installing project dependencies..."
npm install

# Build the application for production
echo "Building the application..."
npm run build

echo "Installation completed successfully!"
