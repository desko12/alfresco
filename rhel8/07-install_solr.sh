#!/bin/bash

set -e

# Variables
SOLR_USER=alfresco
SOLR_GROUP=alfresco
ALFRESCO_HOME=/srv/alfresco
SOLR_HOME=$ALFRESCO_HOME/alfresco-search-services


echo "Unzip SOLR ZIP Distribution File"
mkdir -p /tmp/solr
unzip downloads/alfresco-search-services-2.0.9.1.zip -d /tmp/solr
mv /tmp/solr/alfresco-search-services $ALFRESCO_HOME

chown -R $SOLR_USER: $SOLR_HOME

echo "Creating SOLR systemd service file..."
cat <<EOL | sudo tee /etc/systemd/system/solr.service
[Unit]
Description=Apache SOLR Web Application Container
After=network.target

[Service]
Type=forking

User=$SOLR_USER
Group=$SOLR_GROUP

Environment="JAVA_HOME=/usr/lib/jvm/java-17-openjdk"

ExecStart=$ALFRESCO_HOME/alfresco-search-services/solr/bin/solr start -a "-Dcreate.alfresco.defaults=alfresco,archive -Dalfresco.secureComms=secret -Dalfresco.secureComms.secret=secret"
ExecStop=$ALFRESCO_HOME/alfresco-search-services/solr/bin/solr stop

[Install]
WantedBy=multi-user.target
EOL

echo "setting selinux context"
sudo semanage fcontext -a -t bin_t "$SOLR_HOME/solr/bin(/.*)?" && sudo restorecon -Rv $SOLR_HOME/solr/bin 

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Starting Solr service..."
sudo systemctl start solr

echo "Stopping Solr service..."
sudo systemctl stop solr

echo "Enabling Solr service to start on boot..."
sudo systemctl enable solr

echo "Starting Solr service..."
sudo systemctl start solr

echo "SOLR has been configured"
