#!/bin/bash

# Exit on any error
set -e

# Function to log messages
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log "Error: This script must be run as root"
        exit 1
    fi
}

# Function to detect OS
detect_os() {
    if [ -f /etc/redhat-release ] || [ -f /etc/almalinux-release ] || [ -f /etc/rocky-release ]; then
        # Check for RHEL 8 or compatible versions (Rocky, Alma, CentOS)
        if grep -q -E '^(Red Hat|CentOS|Rocky|AlmaLinux).* 8' /etc/*-release; then
            echo "rhel8"
        else
            log "Error: This script only supports RHEL 8 and compatible distributions"
            exit 1
        fi
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    else
        log "Error: Unsupported operating system"
        exit 1
    fi
}

# Function to install Java on RHEL 8 and derivatives
install_java_rhel8() {
    log "Installing Java 17 on RHEL 8 compatible system..."
    
    # Enable CodeReady Builder/PowerTools repository
    if dnf repolist | grep -qi "powertools"; then
        dnf -y config-manager --set-enabled powertools
    elif dnf repolist | grep -qi "crb"; then
        dnf -y config-manager --set-enabled crb
    elif dnf repolist | grep -qi "codeready-builder"; then
        dnf -y config-manager --set-enabled codeready-builder-for-rhel-8-$(arch)-rpms
    fi
    
    # Update system
    dnf -y update
    
    # Install Java 17
    dnf -y install java-17-openjdk java-17-openjdk-devel
    
    # Set Java 17 as default
    alternatives --set java java-17-openjdk.$(arch)
    alternatives --set javac java-17-openjdk.$(arch)
    
    # Set JAVA_HOME
    echo "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk" > /etc/profile.d/java.sh
    chmod +x /etc/profile.d/java.sh
}

# Function to install Java on Debian
install_java_debian() {
    log "Installing Java 17 on Debian..."
    
    # Update package lists
    apt-get update
    
    # Install Java 17
    DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-17-jdk
    
    # Set Java 17 as default
    update-alternatives --install /usr/bin/java java /usr/lib/jvm/java-17-openjdk-amd64/bin/java 1
    update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/java-17-openjdk-amd64/bin/javac 1
    update-alternatives --set java /usr/lib/jvm/java-17-openjdk-amd64/bin/java
    update-alternatives --set javac /usr/lib/jvm/java-17-openjdk-amd64/bin/javac
    
    # Set JAVA_HOME
    echo "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64" > /etc/profile.d/java.sh
    chmod +x /etc/profile.d/java.sh
}

# Function to verify Java installation
verify_java() {
    log "Verifying Java installation..."
    
    # Source the JAVA_HOME
    source /etc/profile.d/java.sh
    
    # Check Java version
    if java -version 2>&1 | grep -q "openjdk version \"17"; then
        log "Java 17 is successfully installed and configured"
        java -version 2>&1
        log "JAVA_HOME is set to: $JAVA_HOME"
    else
        log "Error: Java 17 installation verification failed"
        exit 1
    fi
}

# Main installation function
main() {
    log "Starting Java 17 installation..."
    
    # Check if running as root
    check_root
    
    # Detect OS
    OS_TYPE=$(detect_os)
    log "Detected OS: $OS_TYPE"
    
    # Perform installation based on OS
    case $OS_TYPE in
        "rhel8")
            install_java_rhel8
            ;;
        "debian")
            install_java_debian
            ;;
    esac
    
    # Verify installation
    verify_java
    
    log "Java 17 installation and setup completed successfully!"
}

# Run main function
main "$@"
