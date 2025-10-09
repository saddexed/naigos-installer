#!/bin/bash

###########################################
# Nagios Core Installation Script
# Non-Interactive Installation for Ubuntu
# Based on: https://medium.com/@princeashok069/nagios-practical-028bd64c5c88
###########################################

set -e  # Exit on any error

echo "=========================================="
echo "Starting Nagios Core Installation"
echo "=========================================="

# Configure needrestart to run non-interactively
echo "Configuring needrestart for non-interactive mode..."
if [ -f /etc/needrestart/needrestart.conf ]; then
    sudo sed -i "s/^#\$nrconf{restart} = 'i';/\$nrconf{restart} = 'a';/" /etc/needrestart/needrestart.conf
else
    echo "\$nrconf{restart} = 'a';" | sudo tee /etc/needrestart/needrestart.conf > /dev/null
fi

# Set Debian frontend to noninteractive
export DEBIAN_FRONTEND=noninteractive

echo ""
echo "Step 1: System Update"
echo "=========================================="
sudo apt-get update -y

echo ""
echo "Step 2: Creating Swap File (1GB)"
echo "=========================================="
if [ ! -f /root/myswapfile ]; then
    echo "Creating 1GB swap file..."
    sudo dd if=/dev/zero of=/root/myswapfile bs=1M count=1024
    sudo chmod 600 /root/myswapfile
    sudo mkswap /root/myswapfile
    sudo swapon /root/myswapfile
    
    # Make swap permanent
    if ! grep -q "/root/myswapfile" /etc/fstab; then
        echo "/root/myswapfile none swap sw 0 0" | sudo tee -a /etc/fstab
    fi
    echo "Swap file created and enabled successfully."
else
    echo "Swap file already exists."
fi

echo ""
echo "Step 3: Installing Prerequisites"
echo "=========================================="
sudo apt-get install -y autoconf gcc libc6 make wget unzip apache2 php libapache2-mod-php libgd-dev
sudo apt-get install -y openssl libssl-dev

echo ""
echo "Step 4: Configuring Apache"
echo "=========================================="
# Move index.php to first position in DirectoryIndex
sudo sed -i 's/DirectoryIndex.*/DirectoryIndex index.php index.html index.cgi index.pl index.xhtml index.htm/' /etc/apache2/mods-enabled/dir.conf
sudo systemctl restart apache2

echo ""
echo "Step 5: Downloading Nagios Core"
echo "=========================================="
cd /opt
sudo wget -O nagioscore.tar.gz https://github.com/NagiosEnterprises/nagioscore/archive/nagios-4.4.14.tar.gz
sudo tar xzf nagioscore.tar.gz
cd nagioscore-nagios-4.4.14/

echo ""
echo "Step 6: Compiling Nagios Core"
echo "=========================================="
# Suppress compiler warnings
export CFLAGS="-w"
export CXXFLAGS="-w"
sudo ./configure --with-httpd-conf=/etc/apache2/sites-enabled
sudo make all

echo ""
echo "Step 7: Creating Nagios User and Group"
echo "=========================================="
sudo make install-groups-users
sudo usermod -a -G nagios www-data

echo ""
echo "Step 8: Installing Nagios Binaries and Configuration"
echo "=========================================="
sudo make install
sudo make install-daemoninit
sudo make install-commandmode
sudo make install-config
sudo make install-webconf

echo ""
echo "Step 9: Configuring Nagios"
echo "=========================================="
# Create servers directory for host configurations
sudo mkdir -p /usr/local/nagios/etc/servers

# Uncomment cfg_dir in nagios.cfg
sudo sed -i 's/^#cfg_dir=\/usr\/local\/nagios\/etc\/servers/cfg_dir=\/usr\/local\/nagios\/etc\/servers/' /usr/local/nagios/etc/nagios.cfg

echo ""
echo "Step 10: Configuring check_nrpe Command"
echo "=========================================="
# Add check_nrpe command definition
cat << 'EOF' | sudo tee -a /usr/local/nagios/etc/objects/commands.cfg > /dev/null

# Check NRPE Command
define command{
    command_name check_nrpe
    command_line $USER1$/check_nrpe -H $HOSTADDRESS$ -c $ARG1$
}
EOF

echo ""
echo "Step 11: Enabling Apache Modules"
echo "=========================================="
sudo a2enmod rewrite
sudo a2enmod cgi

echo ""
echo "Step 12: Verifying Apache Configuration"
echo "=========================================="
# Check if make install-webconf created the config
if [ -f /etc/apache2/sites-available/nagios.conf ]; then
    echo "✓ Apache config created successfully by make install-webconf"
else
    echo "✗ Apache config not found - this shouldn't happen!"
    exit 1
fi

# Enable the Nagios site
echo "Enabling Nagios site..."
sudo a2ensite nagios.conf

echo ""
echo "Step 13: Configuring Firewall (UFW)"
echo "=========================================="
sudo ufw --force enable
sudo ufw allow Apache
sudo ufw allow OpenSSH
sudo ufw reload

echo ""
echo "Step 14: Creating Nagios Service"
echo "=========================================="
cat << 'EOF' | sudo tee /etc/systemd/system/nagios.service > /dev/null
[Unit]
Description=Nagios
BindsTo=network.target

[Install]
WantedBy=multi-user.target

[Service]
Type=simple
User=nagios
Group=nagios
ExecStart=/usr/local/nagios/bin/nagios /usr/local/nagios/etc/nagios.cfg
EOF

sudo systemctl daemon-reload
sudo systemctl enable nagios.service

echo ""
echo "Step 15: Creating Nagios Admin User"
echo "=========================================="
# Create nagiosadmin user with default password (change this!)
echo "Creating nagiosadmin user with password: nagiosadmin"
echo "IMPORTANT: Change this password after installation!"
sudo htpasswd -bc /usr/local/nagios/etc/htpasswd.users nagiosadmin nagiosadmin

# Set correct permissions on htpasswd file
sudo chown nagios:nagios /usr/local/nagios/etc/htpasswd.users
sudo chmod 640 /usr/local/nagios/etc/htpasswd.users

# Verify the password file was created
if [ -f /usr/local/nagios/etc/htpasswd.users ]; then
    echo "Password file created successfully."
    ls -l /usr/local/nagios/etc/htpasswd.users
else
    echo "ERROR: Password file was not created!"
    exit 1
fi

echo ""
echo "Step 16: Setting Up Nagios Command File Permissions"
echo "=========================================="
# Create the command file directory with proper permissions
sudo mkdir -p /usr/local/nagios/var/rw
sudo chown nagios:www-data /usr/local/nagios/var/rw
sudo chmod 2710 /usr/local/nagios/var/rw

# Ensure Apache user is in nagios group
sudo usermod -a -G nagios www-data

echo ""
echo "Step 17: Creating Nagios Init Symlink"
echo "=========================================="
sudo ln -sf /etc/init.d/nagios /etc/rcS.d/S99nagios

echo ""
echo "Step 18: Installing Nagios Plugins Prerequisites"
echo "=========================================="
sudo apt-get install -y autoconf gcc libc6 libmcrypt-dev make libssl-dev wget bc gawk dc build-essential snmp libnet-snmp-perl gettext

echo ""
echo "Step 19: Downloading and Installing Nagios Plugins"
echo "=========================================="
cd /opt
sudo wget --no-check-certificate -O nagios-plugins.tar.gz https://github.com/nagios-plugins/nagios-plugins/archive/release-2.4.6.tar.gz
sudo tar xzf nagios-plugins.tar.gz
cd nagios-plugins-release-2.4.6/
# Suppress compiler warnings for plugins
export CFLAGS="-w"
export CXXFLAGS="-w"
sudo ./tools/setup
sudo ./configure
sudo make
sudo make install

echo ""
echo "Step 20: Final Permissions and Configuration Check"
echo "=========================================="
echo "Setting final permissions..."
sudo chown -R nagios:nagios /usr/local/nagios
sudo chmod -R 755 /usr/local/nagios/sbin
sudo chmod -R 755 /usr/local/nagios/share
sudo chmod -R 755 /usr/local/nagios/libexec

# Ensure command file permissions are correct
sudo mkdir -p /usr/local/nagios/var/rw
sudo chown -R nagios:www-data /usr/local/nagios/var/rw
sudo chmod 2710 /usr/local/nagios/var/rw

echo ""
echo "Step 21: Verifying and Starting Services"
echo "=========================================="
echo "Testing Apache configuration..."
sudo apache2ctl configtest

echo ""
echo "Restarting Apache to apply all changes..."
sudo systemctl restart apache2.service

echo ""
echo "Starting Nagios..."
sudo systemctl start nagios.service

# Give services a moment to start
sleep 2

echo ""
echo "Service Status:"
echo "==============="
sudo systemctl status apache2.service --no-pager -l
echo ""
sudo systemctl status nagios.service --no-pager -l

echo ""
echo "Verifying authentication configuration..."
if [ -f /usr/local/nagios/etc/htpasswd.users ]; then
    echo "✓ Password file exists"
    ls -l /usr/local/nagios/etc/htpasswd.users
else
    echo "✗ WARNING: Password file missing!"
fi

echo ""
echo "Verifying Apache config..."
if [ -f /etc/apache2/sites-enabled/nagios.conf ]; then
    echo "✓ Nagios site is enabled"
else
    echo "✗ WARNING: Nagios site not enabled!"
fi

echo ""
echo "Fetching server IP address..."
SERVER_IP=$(curl -s https://ipapi.co/ip || echo "host-ip")

echo ""
echo "=========================================="
echo "Nagios Installation Complete!"
echo "=========================================="
echo ""
echo "Access nagios at: http://$SERVER_IP/nagios"
echo "  Username: nagiosadmin"
echo "  Password: nagiosadmin"
echo "Change your password using: sudo htpasswd /usr/local/nagios/etc/htpasswd.users nagiosadmin"
echo "Additional Information:"
echo "  - Swap file: /root/myswapfile (1GB)"
if [ "$SERVER_IP" != "host-ip" ]; then
    echo "  - Server IP: $SERVER_IP"
fi
echo "=========================================="
