#!/bin/bash

# Exit on any error
set -e

# Function to log messages with different levels
log() {
    local level=$1
    local message=$2
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')
    case $level in
        "INFO")  echo -e "[\033[0;32m${timestamp}\033[0m] ${message}" ;;
        "WARN")  echo -e "[\033[0;33m${timestamp}\033[0m] ${message}" ;;
        "ERROR") echo -e "[\033[0;31m${timestamp}\033[0m] ${message}" ;;
        *)       echo -e "[${timestamp}] ${message}" ;;
    esac
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check system requirements
check_system_requirements() {
    log "INFO" "Checking system requirements..."
    
    # Check available disk space (minimum 2GB free)
    local free_space=$(df -h / | awk 'NR==2 {print $4}' | sed 's/G//')
    if (( $(echo "$free_space < 2" | bc -l) )); then
        log "ERROR" "Insufficient disk space. At least 2GB required"
        exit 1
    fi
    log "INFO" "Disk space check passed: ${free_space}GB available"

    # Check available memory (minimum 1GB)
    local total_mem=$(free -m | awk 'NR==2 {print $2}')
    if [ "$total_mem" -lt 1024 ]; then
        log "ERROR" "Insufficient memory. At least 1GB required"
        exit 1
    fi
    log "INFO" "Memory check passed: ${total_mem}MB available"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log "ERROR" "This script must be run as root"
        exit 1
    fi
    log "INFO" "Running with root privileges"
}

# Function to detect OS with version
detect_os() {
    log "INFO" "Detecting operating system..."
    
    if [ -f /etc/redhat-release ]; then
        local version=$(cat /etc/redhat-release)
        if grep -q "Red Hat Enterprise Linux 8" /etc/redhat-release || \
           grep -q "CentOS Linux 8" /etc/redhat-release; then
            log "INFO" "Detected RHEL/CentOS 8: $version"
            echo "rhel8"
        else
            log "ERROR" "Unsupported RHEL/CentOS version: $version"
            exit 1
        fi
    elif [ -f /etc/debian_version ]; then
        local version=$(cat /etc/debian_version)
        log "INFO" "Detected Debian version: $version"
        echo "debian"
    else
        log "ERROR" "Unsupported operating system"
        exit 1
    fi
}

# Function to backup existing Java configuration
backup_existing_java() {
    log "INFO" "Backing up existing Java configuration..."
    
    local backup_dir="/root/java_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup alternatives configuration
    if [ -d /etc/alternatives ]; then
        cp -r /etc/alternatives/java* "$backup_dir/" 2>/dev/null || true
    fi
    
    # Backup profile settings
    if [ -f /etc/profile.d/java.sh ]; then
        cp /etc/profile.d/java.sh "$backup_dir/" 2>/dev/null || true
    fi
    
    log "INFO" "Backup created at: $backup_dir"
}

# Function to install Java on RHEL 8
install_java_rhel8() {
    log "INFO" "Starting Java 17 installation on RHEL/CentOS 8..."
    
    # Step 1: Enable repositories
    log "INFO" "Step 1/7: Enabling required repositories..."
    dnf -y install dnf-plugins-core
    dnf -y config-manager --set-enabled powertools || \
    dnf -y config-manager --set-enabled codeready-builder-for-rhel-8-$(arch)-rpms || \
    dnf -y config-manager --set-enabled crb
    
    # Step 2: Clean DNF cache
    log "INFO" "Step 2/7: Cleaning package manager cache..."
    dnf clean all
    
    # Step 3: Update system
    log "INFO" "Step 3/7: Updating system packages..."
    dnf -y update
    
    # Step 4: Install Java packages
    log "INFO" "Step 4/7: Installing Java 17 packages..."
    dnf -y install java-17-openjdk java-17-openjdk-devel
    
    # Step 5: Set alternatives
    log "INFO" "Step 5/7: Configuring Java alternatives..."
    alternatives --set java java-17-openjdk.$(arch)
    alternatives --set javac java-17-openjdk.$(arch)
    
    # Step 6: Set JAVA_HOME
    log "INFO" "Step 6/7: Setting JAVA_HOME environment variable..."
    echo "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk" > /etc/profile.d/java.sh
    chmod +x /etc/profile.d/java.sh
    
    # Step 7: Verify installation
    log "INFO" "Step 7/7: Verifying installation..."
    source /etc/profile.d/java.sh
    verify_java_installation
}

# Function to install Java on Debian
install_java_debian() {
    log "INFO" "Starting Java 17 installation on Debian..."
    
    # Step 1: Update package lists
    log "INFO" "Step 1/7: Updating package lists..."
    apt-get update
    
    # Step 2: Install required packages
    log "INFO" "Step 2/7: Installing prerequisites..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y wget gnupg software-properties-common
    
    # Step 3: Clean APT cache
    log "INFO" "Step 3/7: Cleaning package manager cache..."
    apt-get clean
    
    # Step 4: Install Java
    log "INFO" "Step 4/7: Installing Java 17 packages..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-17-jdk
    
    # Step 5: Set alternatives
    log "INFO" "Step 5/7: Configuring Java alternatives..."
    update-alternatives --install /usr/bin/java java /usr/lib/jvm/java-17-openjdk-amd64/bin/java 1
    update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/java-17-openjdk-amd64/bin/javac 1
    update-alternatives --set java /usr/lib/jvm/java-17-openjdk-amd64/bin/java
    update-alternatives --set javac /usr/lib/jvm/java-17-openjdk-amd64/bin/javac
    
    # Step 6: Set JAVA_HOME
    log "INFO" "Step 6/7: Setting JAVA_HOME environment variable..."
    echo "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64" > /etc/profile.d/java.sh
    chmod +x /etc/profile.d/java.sh
    
    # Step 7: Verify installation
    log "INFO" "Step 7/7: Verifying installation..."
    source /etc/profile.d/java.sh
    verify_java_installation
}

# Function to verify Java installation
verify_java_installation() {
    log "INFO" "Performing detailed installation verification..."
    
    # Check Java binary
    if ! command_exists java; then
        log "ERROR" "Java binary not found in PATH"
        exit 1
    fi
    
    # Check Java version
    local java_version=$(java -version 2>&1)
    if ! echo "$java_version" | grep -q "openjdk version \"17"; then
        log "ERROR" "Incorrect Java version installed"
        log "ERROR" "Found version: $java_version"
        exit 1
    fi
    
    # Check JAVA_HOME
    if [ -z "$JAVA_HOME" ]; then
        log "ERROR" "JAVA_HOME is not set"
        exit 1
    fi
    
    # Check if JAVA_HOME directory exists
    if [ ! -d "$JAVA_HOME" ]; then
        log "ERROR" "JAVA_HOME directory does not exist: $JAVA_HOME"
        exit 1
    fi
    
    # Check if java compiler exists
    if ! command_exists javac; then
        log "ERROR" "Java compiler (javac) not found"
        exit 1
    fi
    
    # Print verification results
    log "INFO" "Java version information:"
    java -version 2>&1 | while read -r line; do
        log "INFO" "  $line"
    done
    
    log "INFO" "Java compiler version:"
    javac -version 2>&1 | while read -r line; do
        log "INFO" "  $line"
    done
    
    log "INFO" "JAVA_HOME is set to: $JAVA_HOME"
    log "INFO" "Java binaries location:"
    log "INFO" "  java: $(which java)"
    log "INFO" "  javac: $(which javac)"
    
    log "INFO" "All verification checks passed successfully"
}

# Function to create installation summary
create_installation_summary() {
    local summary_file="/root/java_installation_summary.txt"
    
    {
        echo "Java Installation Summary"
        echo "========================"
        echo "Installation Date: $(date)"
        echo "Operating System: $(cat /etc/*release | grep "PRETTY_NAME" | cut -d= -f2- | tr -d '"')"
        echo ""
        echo "Java Version:"
        java -version 2>&1
        echo ""
        echo "Java Compiler Version:"
        javac -version 2>&1
        echo ""
        echo "JAVA_HOME: $JAVA_HOME"
        echo ""
        echo "Environment Configuration:"
        echo "-------------------------"
        cat /etc/profile.d/java.sh
        echo ""
        echo "Installation Paths:"
        echo "------------------"
        echo "java: $(which java)"
        echo "javac: $(which javac)"
    } > "$summary_file"
    
    log "INFO" "Installation summary created at: $summary_file"
}

# Main installation function
main() {
    log "INFO" "Starting Java 17 installation process..."
    
    # Step 1: Check root privileges
    check_root
    
    # Step 2: Check system requirements
    check_system_requirements
    
    # Step 3: Detect OS
    OS_TYPE=$(detect_os)
    
    # Step 4: Backup existing configuration
    backup_existing_java
    
    # Step 5: Perform installation based on OS
    case $OS_TYPE in
        "rhel8")
            install_java_rhel8
            ;;
        "debian")
            install_java_debian
            ;;
    esac
    
    # Step 6: Create installation summary
    create_installation_summary
    
    log "INFO" "Java 17 installation and setup completed successfully!"
    log "INFO" "Please check /root/java_installation_summary.txt for installation details"
}

# Run main function
main "$@"
