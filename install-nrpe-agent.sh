#!/bin/bash

###########################################
# NRPE Agent Installation Script
# For Remote Linux Host Monitoring
# Based on: https://medium.com/@princeashok069/nagios-practical-028bd64c5c88
###########################################

set -e  # Exit on any error

echo "=========================================="
echo "Starting NRPE Agent Installation"
echo "=========================================="
echo ""
echo "This script will install the NRPE agent on this remote host."
echo "You will need to know the IP address of your Nagios server."
echo ""

# Get Nagios server IP if not provided as argument
if [ -z "$1" ]; then
    echo "Step 1: Enter Nagios Server Information"
    echo "=========================================="
    read -p "Enter the IP address of your Nagios server: " NAGIOS_SERVER_IP
else
    NAGIOS_SERVER_IP=$1
fi

if [ -z "$NAGIOS_SERVER_IP" ]; then
    echo "ERROR: Nagios server IP is required!"
    exit 1
fi

echo "Nagios Server IP: $NAGIOS_SERVER_IP"
echo ""

# Set Debian frontend to noninteractive
export DEBIAN_FRONTEND=noninteractive

echo "Step 2: System Update"
echo "=========================================="
sudo apt-get update -y

echo ""
echo "Step 3: Installing Prerequisites"
echo "=========================================="
sudo apt-get install -y wget tar gzip
sudo apt-get install -y autoconf gcc libc6 make libssl-dev

echo ""
echo "Step 4: Downloading NRPE Agent"
echo "=========================================="
cd /opt
sudo wget http://assets.nagios.com/downloads/nagiosxi/agents/linux-nrpe-agent.tar.gz
sudo tar xzf linux-nrpe-agent.tar.gz

echo ""
echo "Step 5: Installing NRPE Agent"
echo "=========================================="
cd linux-nrpe-agent
# Run fullinstall non-interactively by piping 'y' for all prompts
echo "y" | sudo ./fullinstall || true

# Fullinstall may have issues with xinetd, so we'll configure systemd instead
echo ""
echo "Step 5b: Configuring NRPE with systemd"
echo "=========================================="

# Create systemd service file if it doesn't exist
if [ ! -f /etc/systemd/system/nrpe.service ]; then
    echo "Creating NRPE systemd service..."
    cat << 'SYSTEMD' | sudo tee /etc/systemd/system/nrpe.service > /dev/null
[Unit]
Description=Nagios Remote Plugin Executor
After=syslog.target network.target

[Service]
Type=simple
User=nagios
Group=nagios
ProtectSystem=full
ProtectHome=yes
NoNewPrivileges=yes
ExecStart=/usr/local/nagios/bin/nrpe -c /usr/local/nagios/etc/nrpe.cfg -f
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=nrpe

[Install]
WantedBy=multi-user.target
SYSTEMD
fi

echo ""
echo "Step 6: Configuring NRPE for Nagios Server"
echo "=========================================="
# Update the NRPE config to allow connections from the Nagios server
if [ -f /usr/local/nagios/etc/nrpe.cfg ]; then
    sudo sed -i "s/^allowed_hosts=127.0.0.1/allowed_hosts=127.0.0.1,$NAGIOS_SERVER_IP/" /usr/local/nagios/etc/nrpe.cfg
    echo "✓ NRPE configured to accept connections from: $NAGIOS_SERVER_IP"
else
    echo "WARNING: NRPE config file not found at /usr/local/nagios/etc/nrpe.cfg"
    echo "This may be because the fullinstall script failed."
fi

echo ""
echo "Step 7: Starting NRPE Service"
echo "=========================================="
sudo systemctl daemon-reload
sudo systemctl restart nrpe.service 2>/dev/null || {
    echo "Attempting to start NRPE from installed location..."
    sudo /usr/local/nagios/bin/nrpe -c /usr/local/nagios/etc/nrpe.cfg -f &
    NRPE_PID=$!
    sleep 1
    if ps -p $NRPE_PID > /dev/null; then
        echo "✓ NRPE started (PID: $NRPE_PID)"
    else
        echo "✗ Failed to start NRPE"
    fi
}

# Try to enable and start via systemd if available
if systemctl list-unit-files | grep -q nrpe.service; then
    sudo systemctl enable nrpe.service
fi

echo ""
echo "Step 8: Installing Apache Web Server (Optional)"
echo "=========================================="
read -p "Do you want to install Apache2 web server for HTTP monitoring? (y/n): " INSTALL_APACHE

if [ "$INSTALL_APACHE" = "y" ] || [ "$INSTALL_APACHE" = "Y" ]; then
    sudo apt-get install -y apache2
    sudo systemctl start apache2.service
    sudo systemctl enable apache2.service
    
    echo ""
    echo "Step 9: Deploying Sample Webpage"
    echo "=========================================="
    cd /var/www/html
    sudo rm -f index.html
    
    # Get this host's IP for the webpage
    HOST_IP=$(hostname -I | awk '{print $1}')
    
    cat << 'EOF' | sudo tee index.html > /dev/null
<!DOCTYPE html>
<html>
<head>
    <title>Nagios Monitored Host</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 50px; background-color: #f0f0f0; }
        .container { background-color: white; padding: 20px; border-radius: 5px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
        h1 { color: #333; }
        .status { color: #28a745; font-weight: bold; }
        .info { margin: 20px 0; padding: 10px; background-color: #e7f3ff; border-left: 4px solid #2196F3; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to Apache2 Web Server</h1>
        <p>This host is being monitored by Nagios.</p>
        <div class="info">
            <strong>Host Status:</strong> <span class="status">Online</span>
        </div>
        <div class="info">
            <strong>Host IP:</strong> HOSTIP_PLACEHOLDER
        </div>
        <div class="info">
            <strong>Services:</strong> HTTP (Apache2) ✓
        </div>
        <p>If you can see this page, the web server is running correctly.</p>
    </div>
</body>
</html>
EOF
    
    # Replace placeholder with actual IP
    sudo sed -i "s/HOSTIP_PLACEHOLDER/$HOST_IP/g" index.html
    
    echo "✓ Sample webpage deployed"
else
    echo "Skipping Apache2 installation."
fi

echo ""
echo "Step 10: Displaying Host Information"
echo "=========================================="
echo "This host's IP address:"
HOST_IP=$(hostname -I | awk '{print $1}')
echo "$HOST_IP"

echo ""
echo "NRPE Service Status:"
if systemctl list-unit-files | grep -q nrpe.service; then
    sudo systemctl status nrpe.service --no-pager -l
else
    echo "NRPE is running but not via systemd"
    ps aux | grep nrpe | grep -v grep || echo "NRPE process not found"
fi

echo ""
echo "Verifying NRPE is listening on port 5666:"
sudo netstat -tlnp 2>/dev/null | grep 5666 || echo "Checking if port 5666 is open..."

echo ""
echo "=========================================="
echo "NRPE Agent Installation Complete!"
echo "=========================================="
echo ""
echo "Next Steps on Nagios Server:"
echo ""
echo "1. Get this host's IP address: $HOST_IP"
echo ""
echo "2. Create a host configuration file at:"
echo "   sudo vi /usr/local/nagios/etc/servers/nagihost.cfg"
echo ""
echo "3. Add this configuration:"
cat << 'EOF'

define host {
    use                 linux-server
    host_name           nagihost
    alias               Remote Monitored Host
    address             <THIS_HOST_IP>
    max_check_attempts  5
    check_period        24x7
    notification_interval 30
    notification_period 24x7
}

define service {
    use                 generic-service
    host_name           nagihost
    service_description CPU Load
    check_command       check_nrpe!check_load
}

define service {
    use                 generic-service
    host_name           nagihost
    service_description Memory Usage
    check_command       check_nrpe!check_mem
}

define service {
    use                 generic-service
    host_name           nagihost
    service_description Disk Usage
    check_command       check_nrpe!check_disk
}

EOF

echo ""
echo "4. Restart Nagios on the server:"
echo "   sudo systemctl restart nagios.service"
echo ""
echo "=========================================="
