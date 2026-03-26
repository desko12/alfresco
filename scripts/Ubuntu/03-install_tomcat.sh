#!/bin/bash

set -e

# Variables
TOMCAT_USER=alfresco
TOMCAT_GROUP=alfresco
ALFRESCO_HOME=/srv/alfresco
TOMCAT_HOME=$ALFRESCO_HOME/tomcat

# Function to fetch the latest Tomcat version
fetch_latest_version() {
  curl -s https://dlcdn.apache.org/tomcat/tomcat-10/ | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' | tail -1 | sed 's/v//'
}

# Automatically fetch the latest Tomcat version
TOMCAT_VERSION=$(fetch_latest_version)

echo "Using Tomcat version: $TOMCAT_VERSION"

echo "Updating package list..."
sudo apt update

echo "Downloading Apache Tomcat..."
wget https://dlcdn.apache.org/tomcat/tomcat-10/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz -O /tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz

echo "create alfresco user"

# Check if the 'alfresco' group exists
if ! getent group alfresco > /dev/null; then
    echo "Creating group 'alfresco'..."
    sudo groupadd $TOMCAT_GROUP
else
    echo "Group 'alfresco' already exists, skipping..."
fi

# Check if the 'alfresco' user exists
if ! id -u alfresco > /dev/null 2>&1; then
    echo "Creating user 'alfresco'..."
    #useradd -m -g alfresco alfresco
    sudo useradd -r -s /sbin/nologin -g $TOMCAT_GROUP $TOMCAT_USER
else
    echo "User 'alfresco' already exists, skipping..."
fi

#sudo groupadd $TOMCAT_GROUP
#sudo useradd -r -s /sbin/nologin -g $TOMCAT_GROUP $TOMCAT_USER

echo "Extracting Tomcat..."
sudo mkdir -p $TOMCAT_HOME
sudo tar xzvf /tmp/apache-tomcat-$TOMCAT_VERSION.tar.gz -C $TOMCAT_HOME --strip-components=1

echo "Setting permissions for Tomcat directories..."
sudo chown -R $TOMCAT_USER:$TOMCAT_GROUP $ALFRESCO_HOME/tomcat
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

Environment="JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64"
Environment="CATALINA_PID=$TOMCAT_HOME/temp/tomcat.pid"
Environment="CATALINA_HOME=$TOMCAT_HOME"
Environment="CATALINA_BASE=$TOMCAT_HOME"
Environment="CATALINA_OPTS=-Xms2048M -Xmx3072M -server -XX:MinRAMPercentage=50 -XX:MaxRAMPercentage=80"
Environment="JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom"
Environment="JAVA_TOOL_OPTIONS=-Dencryption.keystore.type=JCEKS -Dencryption.cipherAlgorithm=DESede/CBC/PKCS5Padding -Dencryption.keyAlgorithm=DESede -Dencryption.keystore.location=$ALFRESCO_HOME/keystore/metadata-keystore/keystore -Dmetadata-keystore.password=mp6yc0UD9e -Dmetadata-keystore.aliases=metadata -Dmetadata-keystore.metadata.password=oKIWzVdEdA -Dmetadata-keystore.metadata.algorithm=DESede"

ExecStart=$TOMCAT_HOME/bin/startup.sh
ExecStop=$TOMCAT_HOME/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
EOL

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Starting Tomcat service..."
sudo systemctl start tomcat

echo "Stopping Tomcat service..."
sudo systemctl stop tomcat

echo "Enabling Tomcat service to start on boot..."
sudo systemctl enable tomcat

echo "Apache Tomcat installation and setup completed successfully!"
