#!/bin/bash

set -e

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION_ID=$VERSION_ID
else
    echo "Cannot detect OS"
    exit 1
fi

# Cleanup function for error handling
cleanup() {
    echo "Cleaning up temporary files..."
    rm -rf /tmp/alfresco
}

# Trap errors and call cleanup
trap cleanup ERR

# Initial cleanup of any existing temporary files
echo "Cleaning up any existing temporary files..."
rm -rf /tmp/alfresco

# Install unzip command based on OS
echo "Installing unzip command..."
if [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
    sudo apt-get update
    sudo apt-get -y install unzip
elif [[ "$OS" == "rhel" || "$OS" == "almalinux" || "$OS" == "rocky" ]]; then
    sudo dnf -y install unzip
else
    echo "Unsupported OS: $OS"
    exit 1
fi

# Create base directory
echo "Creating base directory structure..."
sudo mkdir -p /opt/alfresco
sudo chown -R $(whoami):$(whoami) /opt/alfresco

echo "Creating support folders and configuration in Tomcat..."
mkdir -p /opt/alfresco/tomcat/shared/classes
mkdir -p /opt/alfresco/tomcat/shared/lib
mkdir -p /opt/alfresco/tomcat/conf

# Check if catalina.properties exists before trying to modify it
if [ ! -f /opt/alfresco/tomcat/conf/catalina.properties ]; then
    echo "Error: catalina.properties not found. Please ensure Tomcat is properly installed."
    exit 1
fi

sed -i 's|^shared.loader=$|shared.loader=${catalina.base}/shared/classes,${catalina.base}/shared/lib/*.jar|' /opt/alfresco/tomcat/conf/catalina.properties

echo "Creating temporary directory and unzipping Alfresco..."
mkdir -p /tmp/alfresco
if [ ! -f downloads/alfresco-content-services-community-distribution-23.2.1.zip ]; then
    echo "Error: Alfresco distribution ZIP file not found in downloads directory"
    exit 1
fi

unzip -o downloads/alfresco-content-services-community-distribution-23.2.1.zip -d /tmp/alfresco

echo "Copying JDBC driver..."
cp /tmp/alfresco/web-server/lib/postgresql-42.6.0.jar /opt/alfresco/tomcat/shared/lib/

echo "Configuring JAR Addons deployment..."
mkdir -p /opt/alfresco/modules/platform
mkdir -p /opt/alfresco/modules/share
mkdir -p /opt/alfresco/tomcat/conf/Catalina/localhost
cp /tmp/alfresco/web-server/conf/Catalina/localhost/* /opt/alfresco/tomcat/conf/Catalina/localhost/

echo "Installing Web Applications..."
mkdir -p /opt/alfresco/tomcat/webapps
cp /tmp/alfresco/web-server/webapps/* /opt/alfresco/tomcat/webapps/

echo "Applying configuration..."
cp -r /tmp/alfresco/web-server/shared/classes/* /opt/alfresco/tomcat/shared/classes/
mkdir -p /opt/alfresco/keystore
cp -r /tmp/alfresco/keystore/* /opt/alfresco/keystore/
mkdir -p /opt/alfresco/alf_data

cat <<EOL | tee /opt/alfresco/tomcat/shared/classes/alfresco-global.properties
#
# Custom content and index data location
#
dir.root=/opt/alfresco/alf_data
dir.keystore=/opt/alfresco/keystore/

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

echo "Applying AMPs..."
mkdir -p /opt/alfresco/amps
cp -r /tmp/alfresco/amps/* /opt/alfresco/amps/
mkdir -p /opt/alfresco/bin
cp -r /tmp/alfresco/bin/* /opt/alfresco/bin/
java -jar /opt/alfresco/bin/alfresco-mmt.jar install /opt/alfresco/amps /opt/alfresco/tomcat/webapps/alfresco.war -directory
java -jar /opt/alfresco/bin/alfresco-mmt.jar list /opt/alfresco/tomcat/webapps/alfresco.war

echo "Modifying alfresco and share logs directory..."
mkdir -p /opt/alfresco/tomcat/webapps/alfresco
mkdir -p /opt/alfresco/tomcat/webapps/share
unzip -o /opt/alfresco/tomcat/webapps/alfresco.war -d /opt/alfresco/tomcat/webapps/alfresco
unzip -o /opt/alfresco/tomcat/webapps/share.war -d /opt/alfresco/tomcat/webapps/share

# Create logs directory
mkdir -p /opt/alfresco/tomcat/logs

# Update log file locations
sed -i 's|^appender\.rolling\.fileName=alfresco\.log|appender.rolling.fileName=/opt/alfresco/tomcat/logs/alfresco.log|' /opt/alfresco/tomcat/webapps/alfresco/WEB-INF/classes/log4j2.properties
sed -i 's|^appender\.rolling\.fileName=share\.log|appender.rolling.fileName=/opt/alfresco/tomcat/logs/share.log|' /opt/alfresco/tomcat/webapps/share/WEB-INF/classes/log4j2.properties

# Final cleanup
cleanup

echo "Alfresco has been configured in /opt/alfresco"
echo "Please ensure you have:"
echo "1. PostgreSQL installed and running"
echo "2. Java installed and JAVA_HOME set"
echo "3. Required ports available (8080, 8983, 8090, 61616)"
