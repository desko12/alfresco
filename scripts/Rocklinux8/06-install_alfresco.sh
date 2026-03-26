#!/bin/bash

set -e

ALFRESCO_USER=alfresco
ALFRESCO_GROUP=alfresco
ALFRESCO_HOME=/srv/alfresco

echo "Install unzip command"
sudo dnf -y install unzip

echo "Create support folders and configuration in Tomcat"
mkdir -p $ALFRESCO_HOME/tomcat/shared/classes && mkdir -p $ALFRESCO_HOME/tomcat/shared/lib
sed -i 's|^shared.loader=$|shared.loader=${catalina.base}/shared/classes,${catalina.base}/shared/lib/*.jar|' $ALFRESCO_HOME/tomcat/conf/catalina.properties

echo "Unzip Alfresco ZIP Distribution File"
mkdir -p /tmp/alfresco
unzip ./downloads/alfresco-content-services-community-distribution-23.2.1.zip -d /tmp/alfresco

echo "Copy JDBC driver"
cp /tmp/alfresco/web-server/lib/postgresql-42.6.0.jar $ALFRESCO_HOME/tomcat/shared/lib/

echo "Configure JAR Addons deployment"
mkdir -p $ALFRESCO_HOME/modules/platform && mkdir -p $ALFRESCO_HOME/modules/share && mkdir -p $ALFRESCO_HOME/tomcat/conf/Catalina/localhost
cp /tmp/alfresco/web-server/conf/Catalina/localhost/* $ALFRESCO_HOME/tomcat/conf/Catalina/localhost/

echo "Install Web Applications"
cp /tmp/alfresco/web-server/webapps/* $ALFRESCO_HOME/tomcat/webapps/

echo "Apply configuration"
cp -r /tmp/alfresco/web-server/shared/classes/* $ALFRESCO_HOME/tomcat/shared/classes/
mkdir $ALFRESCO_HOME/keystore && cp -r /tmp/alfresco/keystore/* $ALFRESCO_HOME/keystore/
mkdir $ALFRESCO_HOME/alf_data
cat <<EOL | tee $ALFRESCO_HOME/tomcat/shared/classes/alfresco-global.properties
#
# Custom content and index data location
#
dir.root=${ALFRESCO_HOME}/alf_data
dir.keystore=${ALFRESCO_HOME}/keystore/

#
# Database connection properties
#
db.username=alfresco
db.password=alfresco
db.driver=org.postgresql.Driver
db.url=jdbc:postgresql://localhost:5432/alfresco

#
# Solr Configuration
#
solr.secureComms=secret
solr.sharedSecret=secret
solr.host=localhost
solr.port=8983
index.subsystem.name=solr6

# 
# Transform Configuration
#
localTransform.core-aio.url=http://localhost:8090/

#
# Events Configuration
#
messaging.broker.url=failover:(nio://localhost:61616)?timeout=3000&jms.useCompression=true

#
# URL Generation Parameters
#-------------
alfresco.context=alfresco
alfresco.host=localhost
alfresco.port=8080
alfresco.protocol=http
share.context=share
share.host=localhost
share.port=8080
share.protocol=http
EOL

echo "Apply AMPs"
mkdir $ALFRESCO_HOME/amps && cp -r /tmp/alfresco/amps/* $ALFRESCO_HOME/amps/
mkdir $ALFRESCO_HOME/bin && cp -r /tmp/alfresco/bin/* $ALFRESCO_HOME/bin/
java -jar $ALFRESCO_HOME/bin/alfresco-mmt.jar install $ALFRESCO_HOME/amps $ALFRESCO_HOME/tomcat/webapps/alfresco.war -directory
java -jar $ALFRESCO_HOME/bin/alfresco-mmt.jar list $ALFRESCO_HOME/tomcat/webapps/alfresco.war

echo "Modify alfresco and share logs directory"
mkdir $ALFRESCO_HOME/tomcat/webapps/alfresco && unzip $ALFRESCO_HOME/tomcat/webapps/alfresco.war -d $ALFRESCO_HOME/tomcat/webapps/alfresco
mkdir $ALFRESCO_HOME/tomcat/webapps/share && unzip $ALFRESCO_HOME/tomcat/webapps/share.war -d $ALFRESCO_HOME/tomcat/webapps/share
sed -i "s|^appender\.rolling\.fileName=alfresco\.log|appender.rolling.fileName=${ALFRESCO_HOME}/tomcat/logs/alfresco.log|" $ALFRESCO_HOME/tomcat/webapps/alfresco/WEB-INF/classes/log4j2.properties
sed -i "s|^appender\.rolling\.fileName=share\.log|appender.rolling.fileName=${ALFRESCO_HOME}/tomcat/logs/share.log|" $ALFRESCO_HOME/tomcat/webapps/share/WEB-INF/classes/log4j2.properties

sudo chown -R $ALFRESCO_USER:$ALFRESCO_GROUP $ALFRESCO_HOME

sudo systemctl restart tomcat

echo "Alfresco has been configured" 
