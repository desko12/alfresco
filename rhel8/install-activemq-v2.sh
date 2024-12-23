#!/bin/bash

# Color codes for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
ACTIVEMQ_USER=activemq
ACTIVEMQ_GROUP=activemq
ACTIVEMQ_HOME=/opt/activemq
LOG_FILE="activemq_installation.log"

# Function to log messages
log_message() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} - $1" | tee -a "$LOG_FILE"
}

# Function to detect OS
detect_os() {
    if [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ]; then
        echo "redhat"
    else
        echo "unsupported"
        exit 1
    fi
}

# Function to check root privileges
check_root() {
    if [ "$(id -u)" != "0" ]; then
        log_message "${RED}This script must be run as root${NC}"
        exit 1
    fi
}

# Function to fetch the latest ActiveMQ version
fetch_latest_version() {
    curl -s https://dlcdn.apache.org/activemq/ | grep -oP '5+\.[0-9]+\.[0-9]+' | tail -1 | sed 's/v//'
}

# Function to check system requirements
check_system_requirements() {
    log_message "${BLUE}Checking system requirements...${NC}"
    
    # Check CPU
    CPU_CORES=$(nproc)
    if [ "$CPU_CORES" -lt 2 ]; then
        log_message "${YELLOW}Warning: Recommended minimum 2 CPU cores. Current: $CPU_CORES${NC}"
    else
        log_message "${GREEN}CPU cores: $CPU_CORES - OK${NC}"
    fi

    # Check RAM
    TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$TOTAL_RAM" -lt 2 ]; then
        log_message "${YELLOW}Warning: Recommended minimum 2GB RAM. Current: ${TOTAL_RAM}GB${NC}"
    else
        log_message "${GREEN}RAM: ${TOTAL_RAM}GB - OK${NC}"
    fi

    # Check Disk Space
    FREE_SPACE=$(df -h / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "${FREE_SPACE%.*}" -lt 10 ]; then
        log_message "${YELLOW}Warning: Recommended minimum 10GB free space. Current: ${FREE_SPACE}GB${NC}"
    else
        log_message "${GREEN}Free space: ${FREE_SPACE}GB - OK${NC}"
    fi
}

# Function to install Java
install_java() {
    local os_type=$1
    log_message "${BLUE}Installing Java...${NC}"
    
    if [ "$os_type" = "debian" ]; then
        apt update
        apt install -y openjdk-17-jdk
        JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
    elif [ "$os_type" = "redhat" ]; then
        dnf install -y java-17-openjdk-devel
        JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
    fi
    
    log_message "${GREEN}Java installation completed${NC}"
    java -version
}

# Function to create user and group
create_user() {
    log_message "${BLUE}Setting up ActiveMQ user and group...${NC}"
    if ! getent group $ACTIVEMQ_GROUP >/dev/null; then
        groupadd $ACTIVEMQ_GROUP
    fi
    if ! getent passwd $ACTIVEMQ_USER >/dev/null; then
        useradd -r -g $ACTIVEMQ_GROUP -d $ACTIVEMQ_HOME -s /bin/false $ACTIVEMQ_USER
    fi
    log_message "${GREEN}User and group setup completed${NC}"
}

# Function to install ActiveMQ
install_activemq() {
    local version=$1
    log_message "${BLUE}Installing ActiveMQ version $version...${NC}"
    
    wget "https://dlcdn.apache.org/activemq/$version/apache-activemq-$version-bin.tar.gz" -O "/tmp/apache-activemq-$version-bin.tar.gz"
    mkdir -p $ACTIVEMQ_HOME
    tar xzf "/tmp/apache-activemq-$version-bin.tar.gz" -C $ACTIVEMQ_HOME --strip-components=1
    chown -R $ACTIVEMQ_USER:$ACTIVEMQ_GROUP $ACTIVEMQ_HOME
    chmod -R 755 $ACTIVEMQ_HOME
    
    log_message "${GREEN}ActiveMQ installation completed${NC}"
}

# Function to configure ActiveMQ
configure_activemq() {
    log_message "${BLUE}Configuring ActiveMQ...${NC}"
    
    # Create systemd service file
    cat <<EOL > /etc/systemd/system/activemq.service
[Unit]
Description=Apache ActiveMQ
After=network.target

[Service]
Type=forking

User=$ACTIVEMQ_USER
Group=$ACTIVEMQ_GROUP

Environment="JAVA_HOME=$JAVA_HOME"
Environment="ACTIVEMQ_HOME=$ACTIVEMQ_HOME"
Environment="ACTIVEMQ_BASE=$ACTIVEMQ_HOME"
Environment="ACTIVEMQ_CONF=$ACTIVEMQ_HOME/conf"
Environment="ACTIVEMQ_DATA=$ACTIVEMQ_HOME/data"

ExecStart=$ACTIVEMQ_HOME/bin/activemq start
ExecStop=$ACTIVEMQ_HOME/bin/activemq stop
Restart=always

[Install]
WantedBy=multi-user.target
EOL

    systemctl daemon-reload
    log_message "${GREEN}ActiveMQ configuration completed${NC}"
}

# Function to configure firewall
configure_firewall() {
    log_message "${BLUE}Configuring firewall...${NC}"
    
    local os_type=$1
    if [ "$os_type" = "debian" ]; then
        if command -v ufw >/dev/null; then
            ufw allow 8161/tcp
            ufw allow 61616/tcp
            log_message "${GREEN}UFW firewall configured${NC}"
        fi
    elif [ "$os_type" = "redhat" ]; then
        if command -v firewall-cmd >/dev/null; then
            firewall-cmd --permanent --add-port=8161/tcp
            firewall-cmd --permanent --add-port=61616/tcp
            firewall-cmd --reload
            log_message "${GREEN}FirewallD configured${NC}"
        fi
    fi
}

# Function to start ActiveMQ
start_activemq() {
    log_message "${BLUE}Starting ActiveMQ service...${NC}"
    systemctl start activemq
    systemctl enable activemq
    log_message "${GREEN}ActiveMQ service started and enabled${NC}"
}

# Function to verify installation
verify_installation() {
    log_message "${BLUE}Verifying ActiveMQ installation...${NC}"
    
    # Check if service is running
    if systemctl is-active --quiet activemq; then
        log_message "${GREEN}ActiveMQ service is running${NC}"
    else
        log_message "${RED}ActiveMQ service is not running${NC}"
        return 1
    fi

    # Check if ports are listening
    if command -v netstat >/dev/null; then
        if netstat -tuln | grep -q ":8161"; then
            log_message "${GREEN}Web console port (8161) is listening${NC}"
        else
            log_message "${RED}Web console port (8161) is not listening${NC}"
            return 1
        fi
        
        if netstat -tuln | grep -q ":61616"; then
            log_message "${GREEN}OpenWire port (61616) is listening${NC}"
        else
            log_message "${RED}OpenWire port (61616) is not listening${NC}"
            return 1
        fi
    fi

    return 0
}

# Function to display the menu
show_menu() {
    clear
    echo -e "${BLUE}=== ActiveMQ Installation Menu ===${NC}"
    echo "1. Check System Requirements"
    echo "2. Install Java"
    echo "3. Create ActiveMQ User and Group"
    echo "4. Install ActiveMQ"
    echo "5. Configure ActiveMQ"
    echo "6. Configure Firewall"
    echo "7. Start ActiveMQ Service"
    echo "8. Verify Installation"
    echo "9. Perform Complete Installation"
    echo "10. Show Installation Log"
    echo "0. Exit"
}

# Main script
check_root
OS_TYPE=$(detect_os)
# Initialize log file with proper encoding
echo "=== ActiveMQ Installation Log Started $(date '+%Y-%m-%d %H:%M:%S') ===" > "$LOG_FILE"
chmod 644 "$LOG_FILE"

while true; do
    show_menu
    read -p "Enter your choice (0-10): " choice
    
    case $choice in
        1)
            check_system_requirements
            ;;
        2)
            install_java $OS_TYPE
            ;;
        3)
            create_user
            ;;
        4)
            ACTIVEMQ_VERSION=$(fetch_latest_version)
            install_activemq $ACTIVEMQ_VERSION
            ;;
        5)
            configure_activemq
            ;;
        6)
            configure_firewall $OS_TYPE
            ;;
        7)
            start_activemq
            ;;
        8)
            verify_installation
            ;;
        9)
            log_message "${BLUE}Starting complete installation...${NC}"
            check_system_requirements
            install_java $OS_TYPE
            create_user
            ACTIVEMQ_VERSION=$(fetch_latest_version)
            install_activemq $ACTIVEMQ_VERSION
            configure_activemq
            configure_firewall $OS_TYPE
            start_activemq
            verify_installation
            log_message "${GREEN}Complete installation finished${NC}"
            ;;
        10)
            if [ -f "$LOG_FILE" ]; then
                if command -v less >/dev/null 2>&1; then
                    less "$LOG_FILE"
                else
                    cat "$LOG_FILE" | more
                fi
            else
                echo -e "${RED}Log file not found${NC}"
            fi
            ;;
        0)
            log_message "Installation script terminated by user"
            exit 0
            ;;
        *)
            log_message "${RED}Invalid option${NC}"
            ;;
    esac
    
    echo -e "${YELLOW}Press Enter to continue...${NC}"
read -r
done
