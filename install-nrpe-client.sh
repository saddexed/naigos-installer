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

# Try different service names
if systemctl list-unit-files | grep -q nagios-nrpe-server; then
    echo "Found nagios-nrpe-server service"
    sudo systemctl enable nagios-nrpe-server.service
    sudo systemctl restart nagios-nrpe-server.service
    NRPE_SERVICE="nagios-nrpe-server.service"
elif systemctl list-unit-files | grep -q nrpe; then
    echo "Found nrpe service"
    sudo systemctl enable nrpe.service
    sudo systemctl restart nrpe.service
    NRPE_SERVICE="nrpe.service"
else
    echo "NRPE service not found in systemd. Trying manual startup..."
    if [ -x /etc/init.d/nagios-nrpe-server ]; then
        sudo /etc/init.d/nagios-nrpe-server restart
        NRPE_SERVICE="/etc/init.d/nagios-nrpe-server"
    elif [ -x /etc/init.d/nrpe ]; then
        sudo /etc/init.d/nrpe restart
        NRPE_SERVICE="/etc/init.d/nrpe"
    else
        echo "ERROR: Could not find NRPE service! Please check NRPE installation."
        exit 1
    fi
fi

echo ""
echo "Step 5: Verifying NRPE Service"
echo "=========================================="

if [[ "$NRPE_SERVICE" == *"systemd"* ]] || [[ "$NRPE_SERVICE" == *".service"* ]]; then
    sudo systemctl status "$NRPE_SERVICE" --no-pager -l
else
    sudo "$NRPE_SERVICE" status
fi

echo ""
echo "Testing NRPE locally..."
if [ -x /usr/lib/nagios/plugins/check_nrpe ]; then
    /usr/lib/nagios/plugins/check_nrpe -H 127.0.0.1
elif [ -x /usr/lib64/nagios/plugins/check_nrpe ]; then
    /usr/lib64/nagios/plugins/check_nrpe -H 127.0.0.1
else
    echo "check_nrpe plugin not found in standard locations"
fi

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
echo "If NRPE is not responding, check:"
echo "  - Firewall: sudo ufw status | grep 5666"
echo "  - NRPE config: grep allowed_hosts /etc/nagios/nrpe.cfg"
echo "  - Service status: sudo systemctl status $NRPE_SERVICE"
echo "=========================================="
