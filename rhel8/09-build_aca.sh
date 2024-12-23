#!/bin/bash

set -e

# Install Node.js and npm (LTS version)

sudo dnf install -y gcc-c++ make git

echo "Installing Node.js and npm..."
#curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -

sudo dnf install -y nodejs

# Verify Node.js and npm installation
echo "Verifying Node.js and npm installation..."
node -v
npm -v
cd /srv/alfresco

# Clone the Alfresco Content App repository
git clone https://github.com/Alfresco/alfresco-content-app.git

cd alfresco-content-app

# Checkout to the specific version 4.4.1
git checkout tags/4.4.1 -b 4.4.1

# Install project dependencies
npm install

# Build the application for production
npm run build
