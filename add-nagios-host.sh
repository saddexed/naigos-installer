#!/bin/bash

###########################################
# Nagios Host Configuration Script
# Adds remote hosts to Nagios monitoring
# Based on: https://medium.com/@princeashok069/nagios-practical-028bd64c5c88
###########################################

set -e  # Exit on any error

echo "=========================================="
echo "Nagios Host Configuration"
echo "=========================================="
echo ""
echo "This script adds a remote host to Nagios monitoring."
echo ""

# Get host information
read -p "Enter host name (e.g., nagihost): " HOST_NAME
read -p "Enter host IP address: " HOST_IP
read -p "Enter host alias/description (e.g., Remote Monitored Host): " HOST_ALIAS

if [ -z "$HOST_NAME" ] || [ -z "$HOST_IP" ]; then
    echo "ERROR: Host name and IP are required!"
    exit 1
fi

echo ""
echo "Creating host configuration file..."
echo "=========================================="

CONFIG_FILE="/usr/local/nagios/etc/servers/${HOST_NAME}.cfg"

# Create the configuration file
sudo tee "$CONFIG_FILE" > /dev/null << EOF
# Host configuration for $HOST_NAME
# Created on $(date)

define host {
    use                 linux-server
    host_name           $HOST_NAME
    alias               $HOST_ALIAS
    address             $HOST_IP
    max_check_attempts  5
    check_period        24x7
    notification_interval 30
    notification_period 24x7
}

# Service definitions for NRPE checks
define service {
    use                 generic-service
    host_name           $HOST_NAME
    service_description CPU Load
    check_command       check_nrpe!check_load
}

define service {
    use                 generic-service
    host_name           $HOST_NAME
    service_description Memory Usage
    check_command       check_nrpe!check_mem
}

define service {
    use                 generic-service
    host_name           $HOST_NAME
    service_description Disk Usage
    check_command       check_nrpe!check_disk
}

define service {
    use                 generic-service
    host_name           $HOST_NAME
    service_description Swap Usage
    check_command       check_nrpe!check_swap
}

# HTTP check (if Apache is running on the host)
define service {
    use                 generic-service
    host_name           $HOST_NAME
    service_description HTTP
    check_command       check_http
}

EOF

echo "✓ Configuration file created: $CONFIG_FILE"
echo ""

# Verify Nagios configuration
echo "Step 2: Verifying Nagios Configuration"
echo "=========================================="
echo "Checking Nagios config syntax..."

if sudo /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg > /tmp/nagios-check.log 2>&1; then
    echo "✓ Configuration syntax is valid"
else
    echo "✗ Configuration has errors!"
    echo "Check /tmp/nagios-check.log for details"
    cat /tmp/nagios-check.log
    exit 1
fi

echo ""
echo "Step 3: Restarting Nagios Service"
echo "=========================================="

sudo systemctl restart nagios.service

echo "✓ Nagios service restarted"

echo ""
echo "Step 4: Waiting for service to stabilize..."
sleep 3

# Check service status
if sudo systemctl is-active --quiet nagios.service; then
    echo "✓ Nagios service is running"
else
    echo "✗ Nagios service failed to start!"
    echo "Check logs with: sudo journalctl -u nagios.service -n 50"
    exit 1
fi

echo ""
echo "=========================================="
echo "Host Configuration Complete!"
echo "=========================================="
echo ""
echo "Host Details:"
echo "  - Host Name: $HOST_NAME"
echo "  - IP Address: $HOST_IP"
echo "  - Configuration: $CONFIG_FILE"
echo ""
echo "Services Added:"
echo "  • CPU Load (via NRPE)"
echo "  • Memory Usage (via NRPE)"
echo "  • Disk Usage (via NRPE)"
echo "  • Swap Usage (via NRPE)"
echo "  • HTTP (Apache)"
echo ""
echo "Next Steps:"
echo "1. Access Nagios Web Interface"
echo "2. Go to Hosts section"
echo "3. Look for host: $HOST_NAME"
echo "4. Services should appear within 1-2 minutes"
echo ""
echo "To manually trigger a check:"
echo "  sudo systemctl restart nagios.service"
echo ""
echo "To view logs:"
echo "  sudo tail -f /usr/local/nagios/var/nagios.log"
echo ""
echo "To edit this host configuration later:"
echo "  sudo vi $CONFIG_FILE"
echo ""
echo "=========================================="
