#!/bin/bash

set -e

#java version variable 
JAVA_VERSION=17

echo "Updating package list..."
sudo dnf update -y

# Enable CodeReady Builder/PowerTools repository
if sudo dnf repolist | grep -qi "powertools"; then
   sudo dnf -y config-manager --set-enabled powertools
elif sudo dnf repolist | grep -qi "crb"; then
   sudo dnf -y config-manager --set-enabled crb
elif sudo dnf repolist | grep -qi "codeready-builder"; then
   sudo dnf -y config-manager --set-enabled codeready-builder-for-rhel-8-$(arch)-rpms
fi

echo "Installing Java JDK $JAVA_VERSION..."
sudo dnf -y install java-$JAVA_VERSION-openjdk java-$JAVA_VERSION-openjdk-devel

echo "Setting Java $JAVA_VERSION as default..."
sudo alternatives --set java java-$JAVA_VERSION-openjdk.$(arch)
sudo alternatives --set javac java-$JAVA_VERSION-openjdk.$(arch)

# Set JAVA_HOME
echo "Setting JAVA_HOME..."
sudo echo "export JAVA_HOME=/usr/lib/jvm/java-$JAVA_VERSION-openjdk" > /etc/profile.d/java.sh
sudo chmod +x /etc/profile.d/java.sh

# Source the JAVA_HOME
source /etc/profile.d/java.sh

echo "Checking Java version..."
java -version

echo "Java JDK $JAVA_VERSION installation and setup completed successfully!"
echo "$JAVA_HOME"
