#!/bin/bash

set -e

#variable 
POSTGRES_VERSION=16

echo "Updating package list..."
sudo dnf update -y

echo "enabling PostgreSQL module"
sudo dnf module enable -y postgresql:$POSTGRES_VERSION

echo "Installing PostgreSQL..."
sudo dnf install -y postgresql-server postgresql-contrib

echo "Initializing PostgreSQL database..."
sudo postgresql-setup --initdb

echo "Enable local connections"
sudo sed -i 's/local\s\+all\s\+all\s\+peer/local   all             all                                md5/' /var/lib/pgsql/data/pg_hba.conf
sudo sed -i 's/host\s\+all\s\+all\s\+127.0.0.1\/32\s\+ident/host    all             all             127.0.0.1\/32            md5/' /var/lib/pgsql/data/pg_hba.conf
sudo sed -i 's/host\s\+all\s\+all\s\+::1\/128\s\+ident/host    all             all             ::1\/128                 md5/' /var/lib/pgsql/data/pg_hba.conf


echo "Starting PostgreSQL service..."
sudo systemctl start postgresql

echo "Configuring Alfresco database..."
sudo -u postgres psql -c "CREATE USER alfresco WITH PASSWORD 'alfresco';"
sudo -u postgres psql -c "CREATE DATABASE alfresco OWNER alfresco ENCODING 'UTF8';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE alfresco TO alfresco;"

echo "Enabling PostgreSQL to start on boot..."
sudo systemctl enable postgresql

echo "PostgreSQL installation and setup completed successfully!"
