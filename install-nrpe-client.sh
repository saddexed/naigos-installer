#!/bin/bash

###########################################
# NRPE Client Installation Script
# For remote monitoring by Nagios server
# Created by: saddexed
###########################################

set -e  # Exit on any error

echo "=========================================="
echo "Starting NRPE Client Installation"
echo "=========================================="

export DEBIAN_FRONTEND=noninteractive

echo ""
echo "Step 1: System Update"
echo "=========================================="
sudo apt-get update -y

echo ""
echo "Step 2: Installing NRPE Server and Plugins"
echo "=========================================="
sudo apt-get install -y nagios-nrpe-server nagios-plugins nagios-plugins-contrib

echo ""
echo "Step 3: Configuring NRPE"
echo "=========================================="

# Backup original config
sudo cp /etc/nagios/nrpe.cfg /etc/nagios/nrpe.cfg.bak

# Allow connections from Nagios server (replace with your Nagios server IP)
echo ""
echo "Enter your Nagios server IP address (e.g., 192.168.1.50):"
read NAGIOS_SERVER_IP

# Update allowed_hosts in nrpe.cfg
sudo sed -i "s/^allowed_hosts=127.0.0.1,::1/allowed_hosts=127.0.0.1,::1,$NAGIOS_SERVER_IP/" /etc/nagios/nrpe.cfg

echo "NRPE configured to accept connections from: $NAGIOS_SERVER_IP"

echo ""
echo "Step 4: Enabling and Starting NRPE Service"
echo "=========================================="
sudo systemctl enable nrpe.service
sudo systemctl restart nrpe.service

echo ""
echo "Step 5: Verifying NRPE Service"
echo "=========================================="
sudo systemctl status nrpe.service --no-pager -l

echo ""
echo "Testing NRPE locally..."
/usr/lib/nagios/plugins/check_nrpe -H 127.0.0.1

echo ""
echo "=========================================="
echo "NRPE Client Installation Complete!"
echo "=========================================="
echo ""
echo "NRPE Server is now configured to accept connections from: $NAGIOS_SERVER_IP"
echo "Port: 5666 (UDP)"
echo ""
echo "On your Nagios server, you can now test connectivity with:"
echo "  /usr/local/nagios/libexec/check_nrpe -H <this-server-ip>"
echo ""
echo "=========================================="
