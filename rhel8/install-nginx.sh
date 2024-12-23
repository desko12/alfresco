#!/bin/bash

# Exit script on any error
set -e

# Function to detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
    else
        echo "Cannot detect OS, exiting..."
        exit 1
    fi
}

# Function for RHEL-based systems (RHEL, Rocky Linux, AlmaLinux)
setup_rhel_based() {
    echo "Setting up on RHEL-based system..."
    
    # Update the system
    echo "Updating system..."
    sudo dnf update -y
    
    # Install EPEL repository
    sudo dnf install -y epel-release
    
    # Install Nginx
    echo "Installing Nginx..."
    sudo dnf install -y nginx
    
    # Create nginx config directory if it doesn't exist
    sudo mkdir -p /etc/nginx/sites-available
    sudo mkdir -p /etc/nginx/sites-enabled
    
    # Add sites-enabled include to nginx.conf if not present
    if ! grep -q "include /etc/nginx/sites-enabled/\*;" /etc/nginx/nginx.conf; then
        sudo sed -i '/http {/a \    include /etc/nginx/sites-enabled/*.;' /etc/nginx/nginx.conf
    fi
}

# Function for Debian-based systems
setup_debian_based() {
    echo "Setting up on Debian-based system..."
    
    # Update the system
    echo "Updating system..."
    sudo apt update && sudo apt upgrade -y
    
    # Install Nginx
    echo "Installing Nginx..."
    sudo apt install -y nginx
}

# Common setup function for all distributions
common_setup() {
    # Create directory for the Alfresco Content App
    echo "Creating directory for Alfresco Content App..."
    sudo mkdir -p /var/www/alfresco-content-app
    
    if [ -d "/home/ubuntu/alfresco-content-app/dist/content-ce/" ]; then
        sudo cp -r /opt/alfresco/alfresco-content-app/dist/content-ce/* /var/www/alfresco-content-app
    else
        echo "Warning: Source directory not found. Please manually copy content files to /var/www/alfresco-content-app"
    fi

    # Create nginx systemd service file
    echo "Creating nginx systemd service file..."
    cat <<EOL | sudo tee /etc/systemd/system/nginx.service
[Unit]
Description=A high performance web server and a reverse proxy server
Documentation=man:nginx(8)
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t -q -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -g 'daemon on; master_process on;'
ExecReload=/usr/sbin/nginx -g 'daemon on; master_process on;' -s reload
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOL

    # Configure Nginx to serve the Alfresco Content App
    echo "Configuring Nginx..."
    cat <<EOL | sudo tee /etc/nginx/sites-available/alfresco-content-app
server {
    listen 80;
    server_name localhost;
    client_max_body_size 0;
    set \$allowOriginSite *;
    proxy_pass_request_headers on;
    proxy_pass_header Set-Cookie;
    proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
    proxy_redirect off;
    proxy_buffering off;
    proxy_set_header Host            \$host:\$server_port;
    proxy_set_header X-Real-IP       \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_pass_header Set-Cookie;    
    
    root /var/www/alfresco-content-app;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ /index.html;
    }
    
    location /alfresco/ {
        proxy_pass http://localhost:8090;
    }
    
    location /share/ {
        proxy_pass http://localhost:8090;
    }    
}
EOL

    # Enable the new Nginx configuration
    echo "Enabling Nginx configuration..."
    sudo ln -sf /etc/nginx/sites-available/alfresco-content-app /etc/nginx/sites-enabled/
    
    # Reload systemd daemon
    echo "Reloading systemd daemon..."
    sudo systemctl daemon-reload
    
    # Enable and restart Nginx
    echo "Enabling and starting Nginx service..."
    sudo systemctl enable nginx
    sudo nginx -t
    sudo systemctl restart nginx
}

# Main script execution
echo "Starting installation process..."

# Detect OS
detect_os

# Setup based on OS
case "$OS" in
    *"Red Hat"*|*"Rocky"*|*"AlmaLinux"*)
        setup_rhel_based
        ;;
    *"Debian"*|*"Ubuntu"*)
        setup_debian_based
        ;;
    *)
        echo "Unsupported operating system: $OS"
        exit 1
        ;;
esac

# Run common setup
common_setup

echo "Installation complete!"
echo "Please ensure your Alfresco Content App files are properly placed in /var/www/alfresco-content-app"
echo "You can now access the application through your browser"
