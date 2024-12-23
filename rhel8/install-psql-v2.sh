#!/bin/bash

# Configuration variables
PGDATA_BASE="/opt/postgresql"  # Base directory for PostgreSQL data
PGDATA_DIR="${PGDATA_BASE}/data"  # Actual data directory
PGLOGS_DIR="${PGDATA_BASE}/logs"  # Directory for logs

# Function to create PostgreSQL directories with proper permissions
create_postgresql_directories() {
    local user=$1
    local group=$2
    
    echo "Creating PostgreSQL directories..."
    sudo mkdir -p "${PGDATA_DIR}"
    sudo mkdir -p "${PGLOGS_DIR}"
    
    echo "Setting proper ownership and permissions..."
    sudo chown -R ${user}:${group} "${PGDATA_BASE}"
    sudo chmod 700 "${PGDATA_DIR}"
}

# Debian PostgreSQL Installation Script
install_postgresql_debian() {
    echo "Running Debian PostgreSQL installation..."
    
    set -e

    echo "Updating package list..."
    sudo apt update

    echo "Installing PostgreSQL..."
    sudo apt install -y postgresql postgresql-contrib

    # Create directories
    create_postgresql_directories postgres postgres

    # Get PostgreSQL version
    PG_VERSION=$(psql --version | awk '{print $3}' | cut -d. -f1)
    
    # Stop PostgreSQL service before making changes
    echo "Stopping PostgreSQL service..."
    sudo systemctl stop postgresql

    # Update PostgreSQL configuration to use new data directory
    echo "Updating PostgreSQL data directory..."
    sudo sed -i "s|data_directory = '/var/lib/postgresql/${PG_VERSION}/main'|data_directory = '${PGDATA_DIR}'|" /etc/postgresql/${PG_VERSION}/main/postgresql.conf

    # Initialize the new data directory
    echo "Initializing new PostgreSQL data directory..."
    sudo -u postgres initdb -D "${PGDATA_DIR}"

    echo "Enable local connections"
    sudo sed -i 's/local\s\+all\s\+postgres\s\+peer/local   all             postgres                                trust/' "${PGDATA_DIR}/pg_hba.conf"
    sudo sed -i 's/local\s\+all\s\+all\s\+peer/local   all             all                                md5/' "${PGDATA_DIR}/pg_hba.conf"

    echo "Starting PostgreSQL service..."
    sudo systemctl start postgresql

    echo "Configuring Alfresco database..."
    sudo -u postgres psql -c "CREATE USER alfresco WITH PASSWORD 'alfresco';"
    sudo -u postgres psql -c "CREATE DATABASE alfresco OWNER alfresco ENCODING 'UTF8';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE alfresco TO alfresco;"

    echo "Stopping PostgreSQL service..."
    sudo systemctl stop postgresql

    echo "Enabling PostgreSQL to start on boot..."
    sudo systemctl enable postgresql

    echo "PostgreSQL installation and setup completed successfully on Debian!"
}

# RHEL 8 PostgreSQL Installation Script
install_postgresql_rhel8() {
    echo "Running RHEL 8 PostgreSQL installation..."
    
    set -e

    echo "Enabling PostgreSQL module..."
    sudo dnf module enable -y postgresql:13

    echo "Installing PostgreSQL..."
    sudo dnf install -y postgresql-server postgresql-contrib

    # Create directories
    create_postgresql_directories postgres postgres

    # Update environment file
    echo "Updating PostgreSQL environment..."
    sudo bash -c "cat > /etc/sysconfig/postgresql << EOF
PGDATA=${PGDATA_DIR}
EOF"

    echo "Initializing PostgreSQL database..."
    sudo postgresql-setup --initdb --pgdata="${PGDATA_DIR}" --unit postgresql

    echo "Enable local connections"
    sudo sed -i 's/local\s\+all\s\+all\s\+ident/local   all             all                                md5/' "${PGDATA_DIR}/pg_hba.conf"
    sudo sed -i 's/local\s\+all\s\+postgres\s\+ident/local   all             postgres                                trust/' "${PGDATA_DIR}/pg_hba.conf"

    echo "Starting PostgreSQL service..."
    sudo systemctl start postgresql

    echo "Configuring Alfresco database..."
    sudo -u postgres psql -c "CREATE USER alfresco WITH PASSWORD 'alfresco';"
    sudo -u postgres psql -c "CREATE DATABASE alfresco OWNER alfresco ENCODING 'UTF8';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE alfresco TO alfresco;"

    echo "Stopping PostgreSQL service..."
    sudo systemctl stop postgresql

    # Update systemd service file to use custom data directory
    echo "Updating systemd service file..."
    sudo mkdir -p /etc/systemd/system/postgresql.service.d/
    sudo bash -c "cat > /etc/systemd/system/postgresql.service.d/override.conf << EOF
[Service]
Environment=PGDATA=${PGDATA_DIR}
EOF"

    sudo systemctl daemon-reload

    echo "Enabling PostgreSQL to start on boot..."
    sudo systemctl enable postgresql

    echo "PostgreSQL installation and setup completed successfully on RHEL 8!"
}

# Check if running as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root or with sudo privileges" 
   exit 1
fi

# Create base directory if it doesn't exist
if [ ! -d "$PGDATA_BASE" ]; then
    echo "Creating base directory: $PGDATA_BASE"
    mkdir -p "$PGDATA_BASE"
fi

# Detect OS and run appropriate installation
if [ -f /etc/debian_version ]; then
    install_postgresql_debian
elif [ -f /etc/redhat-release ]; then
    if grep -q "release 8" /etc/redhat-release; then
        install_postgresql_rhel8
    else
        echo "This script only supports RHEL 8. Your version is not supported."
        exit 1
    fi
else
    echo "This script only supports Debian and RHEL 8 systems."
    exit 1
fi

echo "PostgreSQL data directory is set to: ${PGDATA_DIR}"
echo "PostgreSQL logs directory is set to: ${PGLOGS_DIR}"
