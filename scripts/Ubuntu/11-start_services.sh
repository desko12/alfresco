#!/bin/bash

set -e

TOMCAT_USER=alfresco
TOMCAT_GROUP=alfresco
ALFRESCO_HOME=/srv/alfresco
## RECOMMENDATION: run this sequence of commands manually, waiting between one command and the next one to ensure service dependencies are met.

chown -R $TOMCAT_USER:$TOMCAT_GROUP $ALFRESCO_HOME

echo "Starting postgresql"
sudo systemctl start postgresql

echo "Starting activemq"
sudo systemctl start activemq

echo "Starting transform"
sudo systemctl start transform

echo "Starting tomcat"
sudo systemctl start tomcat

echo "Starting solr"
sudo systemctl start solr

echo "Starting nginx"
sudo systemctl start nginx


echo "Services have been started successfully!"
