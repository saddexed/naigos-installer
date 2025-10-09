#!/bin/bash

##############################################################################
# Nagios Core 4.4.14 cd /opt

sudo wget -q -O nagioscore.tar.gz "https://github.com/NagiosEnterprises/nagioscore/archive/nagios-${NAGIOS_VERSION}.tar.gz"
sudo tar xzf nagioscore.tar.gz

cd "nagioscore-nagios-${NAGIOS_VERSION}/"
sudo ./configure --with-httpd-conf=/etc/apache2/sites-available > /dev/null 2>&1
sudo make all > /dev/null 2>&1

print_message "Nagios Core compiled successfully"ctive Installation Script
# This script automates the complete installation of Nagios Core on Ubuntu
##############################################################################

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration variables
NAGIOS_ADMIN_USER="nagiosadmin"
NAGIOS_ADMIN_PASSWORD="nagiosadmin"  # Change this to your desired password
NAGIOS_ADMIN_EMAIL="admin@localhost"  # Change this to your email
NAGIOS_VERSION="4.4.14"
NAGIOS_PLUGINS_VERSION="2.4.6"

# Function to print colored messages
print_message() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root. Please run as a regular user with sudo privileges."
   exit 1
fi

print_message "Starting Nagios Core installation..."

##############################################################################
# Step 2: Update and Install prerequisite tools
##############################################################################
print_message "Step 2: Updating system and installing prerequisite tools..."

# Set environment variable to avoid interactive prompts
export DEBIAN_FRONTEND=noninteractive

# Configure needrestart to avoid interactive prompts for service restarts
sudo mkdir -p /etc/needrestart/conf.d
echo "\$nrconf{restart} = 'a';" | sudo tee /etc/needrestart/conf.d/50local.conf > /dev/null

# Configure apt to avoid interactive prompts for daemon restarts
echo 'DPkg::Post-Invoke { "if [ -d /etc/needrestart/conf.d ]; then echo \$nrconf{restart} = '\"'\"'a'\"'\"'; > /etc/needrestart/conf.d/50local.conf; fi"; };' | sudo tee /etc/apt/apt.conf.d/99needrestart > /dev/null

sudo apt-get update

# Install prerequisites with automatic yes and non-interactive mode
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    autoconf \
    gcc \
    libc6 \
    make \
    wget \
    unzip \
    apache2 \
    php \
    libapache2-mod-php7.4 \
    libgd-dev \
    openssl \
    libssl-dev

print_message "Prerequisites installed successfully"

##############################################################################
# Step 3: Configure Swap (if not exists)
##############################################################################
print_message "Step 3: Configuring swap space..."
if ! sudo swapon --show | grep -q '/root/myswapfile'; then
    sudo dd if=/dev/zero of=/root/myswapfile bs=1M count=1024
    sudo chmod 600 /root/myswapfile
    sudo mkswap /root/myswapfile
    sudo swapon /root/myswapfile
    if ! grep -q '/root/myswapfile' /etc/fstab; then
        echo '/root/myswapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    fi
    
    print_message "Swap space configured successfully"
else
    print_message "Swap already configured, skipping..."
fi

##############################################################################
# Step 4: Move index.php in first position and restart Apache service
##############################################################################
print_message "Step 4: Configuring Apache to prioritize index.php..."

sudo cp /etc/apache2/mods-enabled/dir.conf /etc/apache2/mods-enabled/dir.conf.backup
sudo sed -i 's/DirectoryIndex.*/DirectoryIndex index.php index.html index.cgi index.pl index.xhtml index.htm/' /etc/apache2/mods-enabled/dir.conf
sudo systemctl restart apache2

print_message "Apache configured successfully"

##############################################################################
# Step 5: Download, extract, Compile and Install Nagios Core source
##############################################################################
print_message "Step 5: Downloading and compiling Nagios Core..."

cd /opt

sudo wget -O nagioscore.tar.gz "https://github.com/NagiosEnterprises/nagioscore/archive/nagios-${NAGIOS_VERSION}.tar.gz"
sudo tar xzf nagioscore.tar.gz

cd "nagioscore-nagios-${NAGIOS_VERSION}/"
sudo ./configure --with-httpd-conf=/etc/apache2/sites-available
sudo make all

print_message "Nagios Core compiled successfully"

##############################################################################
# Step 6: Create User And Group
##############################################################################
print_message "Step 6: Creating Nagios user and group..."

sudo make install-groups-users > /dev/null 2>&1
sudo usermod -a -G nagios www-data > /dev/null 2>&1

print_message "User and group created successfully"

##############################################################################
# Step 7: Install Binaries, Service/Daemon, Command Mode, Configuration Files
##############################################################################
print_message "Step 7: Installing Nagios binaries and configuration files..."

sudo make install > /dev/null 2>&1
sudo make install-daemoninit > /dev/null 2>&1
sudo make install-commandmode > /dev/null 2>&1
sudo make install-config > /dev/null 2>&1
sudo make install-webconf > /dev/null 2>&1

print_message "Nagios binaries and configuration installed successfully"

##############################################################################
# Step 8: Configure Nagios
##############################################################################
print_message "Step 8: Configuring Nagios..."

sudo cp /usr/local/nagios/etc/nagios.cfg /usr/local/nagios/etc/nagios.cfg.backup
sudo sed -i 's|#cfg_dir=/usr/local/nagios/etc/servers|cfg_dir=/usr/local/nagios/etc/servers|g' /usr/local/nagios/etc/nagios.cfg
sudo mkdir -p /usr/local/nagios/etc/servers

print_message "Nagios configuration updated successfully"

##############################################################################
# Step 9: Configure Nagios Contacts
##############################################################################
print_message "Step 9: Configuring Nagios contacts..."

sudo cp /usr/local/nagios/etc/objects/contacts.cfg /usr/local/nagios/etc/objects/contacts.cfg.backup
sudo sed -i "s/email.*nagios@localhost.*/email ${NAGIOS_ADMIN_EMAIL}/" /usr/local/nagios/etc/objects/contacts.cfg

print_message "Nagios contacts configured successfully"

##############################################################################
# Step 10: Configure check_nrpe Command
##############################################################################
print_message "Step 10: Configuring check_nrpe command..."

sudo cp /usr/local/nagios/etc/objects/commands.cfg /usr/local/nagios/etc/objects/commands.cfg.backup
sudo bash -c 'cat >> /usr/local/nagios/etc/objects/commands.cfg << EOF
define command{
    command_name check_nrpe
    command_line \$USER1\$/check_nrpe -H \$HOSTADDRESS\$ -c \$ARG1\$
}
EOF'

print_message "check_nrpe command configured successfully"

##############################################################################
# Step 11: Configure Apache
##############################################################################
print_message "Step 11: Configuring Apache modules..."

sudo a2enmod rewrite
sudo a2enmod cgi
sudo systemctl reload apache2

print_message "Apache modules enabled successfully"

##############################################################################
# Step 11: Configure Firewall
##############################################################################
print_message "Step 11: Configuring firewall..."

if command -v ufw &> /dev/null; then
    sudo ufw allow Apache
    sudo ufw allow OpenSSH
    echo "y" | sudo ufw enable
    sudo ufw reload
    print_message "Firewall configured successfully"
else
    print_warning "UFW not installed, skipping firewall configuration"
fi

##############################################################################
# Step 13: Configure Nagios service
##############################################################################
print_message "Step 13: Configuring Nagios systemd service..."
sudo bash -c 'cat > /etc/systemd/system/nagios.service << EOF
[Unit]
Description=Nagios
BindTo=network.target

[Install]
WantedBy=multi-user.target

[Service]
Type=simple
User=nagios
Group=nagios
ExecStart=/usr/local/nagios/bin/nagios /usr/local/nagios/etc/nagios.cfg
EOF'
sudo systemctl daemon-reload

print_message "Nagios systemd service configured successfully"

##############################################################################
# Step 14: Create nagiosadmin User password and enable Nagios site
##############################################################################
print_message "Step 14: Creating Nagios admin user and enabling Nagios site..."
echo "${NAGIOS_ADMIN_PASSWORD}" | sudo htpasswd -c -i /usr/local/nagios/etc/htpasswd.users ${NAGIOS_ADMIN_USER}

# Enable the Nagios Apache site configuration
if [ -f /etc/apache2/sites-available/nagios.conf ]; then
    sudo a2ensite nagios
    print_message "Nagios site enabled successfully"
else
    print_error "Nagios Apache configuration not found in /etc/apache2/sites-available/!"
    print_error "This may prevent the web interface from working."
fi

sudo ln -sf /etc/init.d/nagios /etc/rcS.d/S99nagios

# Test Apache configuration
print_message "Testing Apache configuration..."
sudo apache2ctl configtest

print_message "Nagios admin user created and site enabled successfully"

##############################################################################
# Step 15: Restart Apache and start Nagios services
##############################################################################
print_message "Step 15: Starting Nagios services..."

sudo systemctl restart apache2.service
sudo systemctl enable nagios.service
sudo systemctl start nagios.service

print_message "Nagios services started successfully"

##############################################################################
# Step 16: Install Nagios Plugins prerequisites
##############################################################################
print_message "Step 16: Installing Nagios Plugins prerequisites..."

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    autoconf \
    gcc \
    libc6 \
    libmcrypt-dev \
    make \
    libssl-dev \
    wget \
    bc \
    gawk \
    dc \
    build-essential \
    snmp \
    libnet-snmp-perl \
    gettext

print_message "Nagios Plugins prerequisites installed successfully"

##############################################################################
# Step 17: Download, Extract, Compile and Install the Plugins package
##############################################################################
print_message "Step 17: Downloading and installing Nagios Plugins..."

cd /opt
sudo wget -q --no-check-certificate -O nagios-plugins.tar.gz "https://github.com/nagios-plugins/nagios-plugins/archive/release-${NAGIOS_PLUGINS_VERSION}.tar.gz"
sudo tar xzf nagios-plugins.tar.gz

cd "nagios-plugins-release-${NAGIOS_PLUGINS_VERSION}/"
sudo ./tools/setup > /dev/null 2>&1
sudo ./configure > /dev/null 2>&1
sudo make > /dev/null 2>&1
sudo make install > /dev/null 2>&1

print_message "Nagios Plugins installed successfully"

##############################################################################
# Final verification
##############################################################################
print_message "Verifying Nagios installation..."

# Check Nagios service
if sudo systemctl is-active --quiet nagios.service; then
    print_message "✓ Nagios service is running"
else
    print_error "✗ Nagios service is not running"
    sudo systemctl status nagios.service
fi

# Check Apache service
if sudo systemctl is-active --quiet apache2.service; then
    print_message "✓ Apache service is running"
else
    print_error "✗ Apache service is not running"
    sudo systemctl status apache2.service
fi

# Check Apache configuration
print_message "Checking Apache Nagios configuration..."
if [ -f /etc/apache2/conf-enabled/nagios.conf ] || [ -f /etc/apache2/sites-enabled/nagios.conf ]; then
    print_message "✓ Nagios Apache configuration is enabled"
else
    print_warning "⚠ Nagios Apache configuration not found in expected locations"
fi

# Check if CGI module is loaded
if sudo apache2ctl -M | grep -q cgi; then
    print_message "✓ Apache CGI module is loaded"
else
    print_warning "⚠ Apache CGI module might not be loaded"
fi

# List enabled Apache configurations
print_message "Enabled Apache configurations:"
ls -la /etc/apache2/conf-enabled/ | grep nagios || print_warning "No nagios config in conf-enabled"
ls -la /etc/apache2/sites-enabled/ | grep nagios || print_warning "No nagios config in sites-enabled"

##############################################################################
# Installation Complete
##############################################################################
echo ""
echo "=========================================================================="
echo -e "${GREEN}Nagios Core installation completed successfully!${NC}"
echo "=========================================================================="
echo ""
echo "Access Nagios at: http://YOUR_SERVER_IP/nagios"
echo "Username: ${NAGIOS_ADMIN_USER}"
echo "Password: ${NAGIOS_ADMIN_PASSWORD}"
echo ""
echo "Important: Change the default password after first login!"
echo ""
echo "To check service status:"
echo "  sudo systemctl status nagios"
echo "  sudo systemctl status apache2"
echo ""
echo "Configuration files location:"
echo "  /usr/local/nagios/etc/"
echo ""
echo "Log files location:"
echo "  /usr/local/nagios/var/"
echo ""
echo "=========================================================================="
