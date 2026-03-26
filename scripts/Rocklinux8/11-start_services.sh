#!/bin/bash

set -e

TOMCAT_USER=alfresco
TOMCAT_GROUP=alfresco
ALFRESCO_HOME=/srv/alfresco
## RECOMMENDATION: run this sequence of commands manually, waiting between one command and the next one to ensure service dependencies are met.

chown -R $TOMCAT_USER:$TOMCAT_GROUP $ALFRESCO_HOME

echo "Starting postgresql"
sudo systemctl restart postgresql

echo "Starting activemq"
sudo systemctl restart activemq

echo "Starting transform"
sudo systemctl restart transform

echo "Starting tomcat"
sudo systemctl restart tomcat

echo "Starting solr"
sudo systemctl restart solr

echo "Starting nginx"
sudo systemctl restart nginx


echo "Services have been started successfully!"
