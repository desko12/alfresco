#!/bin/bash

set -e

echo "Updating system..."
sudo dnf update -y

# Enable EPEL repository
sudo dnf install -y epel-release

# Install Nginx
echo "Installing Nginx..."
sudo dnf install -y nginx

# Create directory for the Alfresco Content App
echo "Creating directory for Alfresco Content App..."
sudo mkdir -p /var/www/alfresco-content-app
sudo cp -r /srv/alfresco/alfresco-content-app/dist/content-ce/* /var/www/alfresco-content-app

# Configure SELinux for Nginx
echo "Configuring SELinux..."
sudo setsebool -P httpd_can_network_connect 1
sudo chcon -R -t httpd_sys_content_t /var/www/alfresco-content-app

# Configure Nginx
echo "Configuring Nginx..."
sudo mkdir -p /etc/nginx/conf.d

### Nginx Global Configuration 
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.back

cat <<'EOL' | sudo tee /etc/nginx/nginx.conf
# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/
#   * Official Russian Documentation: http://nginx.org/ru/docs/

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;
# Settings for a TLS enabled server.
#
#    server {
#        listen       443 ssl http2 default_server;
#        listen       [::]:443 ssl http2 default_server;
#        server_name  _;
#        root         /usr/share/nginx/html;
#
#        ssl_certificate "/etc/pki/nginx/server.crt";
#        ssl_certificate_key "/etc/pki/nginx/private/server.key";
#        ssl_session_cache shared:SSL:1m;
#        ssl_session_timeout  10m;
#        ssl_ciphers PROFILE=SYSTEM;
#        ssl_prefer_server_ciphers on;
#
#        # Load configuration files for the default server block.
#        include /etc/nginx/default.d/*.conf;
#
#        location / {
#        }
#
#        error_page 404 /404.html;
#            location = /40x.html {
#        }
#
#        error_page 500 502 503 504 /50x.html;
#            location = /50x.html {
#        }
#    }

}
EOL

###Alfresco Content App vhost configuration file
cat <<EOL | sudo tee /etc/nginx/conf.d/alfresco-content-app.conf
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
       proxy_pass http://localhost:8080;
   }

   location /share/ {
       proxy_pass http://localhost:8080;
   }    
}
EOL

# Configure firewall
echo "Configuring firewall..."
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload

# Start and enable Nginx
echo "Starting Nginx..."
sudo systemctl enable nginx
sudo systemctl start nginx

echo "Nginx setup complete."
