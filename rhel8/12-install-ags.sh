#!/bin/bash

set -e

# Variables
ALFRESCO_HOME=/srv/alfresco
AMPS_SHARE=$ALFRESCO_HOME/amps_share

# create amps_share directory
mkdir -p $AMPS_SHARE

curl -L -o $ALFRESCO_HOME/amps/alfresco-governance-services-community-repo-23.2.0.1.amp https://nexus.alfresco.com/nexus/repository/releases/org/alfresco/alfresco-governance-services-community-repo/23.2.0.1/alfresco-governance-services-community-repo-23.2.0.1.amp

curl -L -o $AMPS_SHARE/alfresco-governance-services-community-share-23.2.0.1.amp https://nexus.alfresco.com/nexus/repository/releases/org/alfresco/alfresco-governance-services-community-share/23.2.0.1/alfresco-governance-services-community-share-23.2.0.1.amp




echo "Configure Transform server"
mkdir -p $ALFRESCO_HOME/transform

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Starting Transform service..."
sudo systemctl start transform

echo "Stopping Transform service..."
sudo systemctl stop transform

echo "Enabling Transform service to start on boot..."
sudo systemctl enable transform

echo "Starting transform service..."
sudo systemctl start transform

echo "Transform has been configured"
