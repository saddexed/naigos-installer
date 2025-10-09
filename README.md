# Nagios Core - Non-Interactive Installation Script

This repository contains a fully automated, non-interactive installation script for Nagios Core on Ubuntu systems.

## Features

- ✅ **Fully Non-Interactive**: No prompts during installation
- ✅ **Automatic Swap Creation**: Creates 1GB swap file immediately after system update
- ✅ **needrestart Configuration**: Automatically configured to avoid service restart prompts
- ✅ **Complete Nagios Setup**: Installs Nagios Core 4.4.14 and plugins
- ✅ **Apache Integration**: Fully configured web interface
- ✅ **UFW Firewall**: Automatically configured

## Quick Start

```bash
# Download the script
wget https://raw.githubusercontent.com/saddexed/naigos-installer/master/install-nagios.sh
chmod +x install-nagios.sh
./install-nagios.sh
```

## What Gets Installed

1. **System Configuration**
   - needrestart configured for non-interactive mode
   - 1GB swap file at `/root/myswapfile`
   - System updates and prerequisites

2. **Nagios Core 4.4.14**
   - Full Nagios installation at `/usr/local/nagios`
   - Nagios user and group creation
   - System service configuration

3. **Nagios Plugins 2.4.6**
   - All standard monitoring plugins
   - NRPE support for remote monitoring

4. **Apache Web Server**
   - Apache2 with PHP support
   - Nagios web interface at `/nagios`
   - Configured Apache modules (rewrite, cgi)

5. **Firewall Configuration**
   - UFW enabled
   - Apache and SSH allowed

## Post-Installation

### Access Nagios Web Interface

1. Open your browser and navigate to:
   ```
   http://YOUR_SERVER_IP/nagios
   ```

2. Login with default credentials:
   - **Username**: `nagiosadmin`
   - **Password**: `nagiosadmin`

### **⚠️ IMPORTANT: Change Default Password**

Immediately after installation, change the default password:

```bash
sudo htpasswd /usr/local/nagios/etc/htpasswd.users nagiosadmin
```

### Verify Services

Check if Nagios is running:
```bash
sudo systemctl status nagios.service
```

Check if Apache is running:
```bash
sudo systemctl status apache2.service
```

### Verify Swap

Check if swap is active:
```bash
sudo swapon --show
free -h
```

## System Requirements

- **OS**: Ubuntu 20.04 or later
- **Memory**: Minimum 1GB RAM (2GB+ recommended)
- **Disk**: At least 2GB free space
- **Permissions**: Root or sudo access required

## Installation Steps Overview

The script performs the following steps in order:

1. Configure needrestart for non-interactive mode
2. Update system packages
3. Create and enable 1GB swap file
4. Install prerequisites (Apache, PHP, build tools)
5. Configure Apache with PHP priority
6. Download and compile Nagios Core
7. Create Nagios user and groups
8. Install Nagios binaries and configuration
9. Configure Nagios monitoring directories
10. Add NRPE command support
11. Enable required Apache modules
12. Configure UFW firewall
13. Create systemd service
14. Create default admin user
15. Install Nagios plugins
16. Start all services

## Troubleshooting

### Nagios Service Won't Start

Check the configuration:
```bash
sudo /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
```

### Can't Access Web Interface

1. Check if Apache is running:
   ```bash
   sudo systemctl status apache2
   ```

2. Check firewall rules:
   ```bash
   sudo ufw status
   ```

3. Verify the Nagios site is enabled:
   ```bash
   ls -l /etc/apache2/sites-enabled/nagios.conf
   ```

### Swap Not Working

Check swap status:
```bash
sudo swapon --show
cat /proc/swaps
```

To manually enable swap:
```bash
sudo swapon /root/myswapfile
```

## Configuration Files

- **Nagios Main Config**: `/usr/local/nagios/etc/nagios.cfg`
- **Nagios Commands**: `/usr/local/nagios/etc/objects/commands.cfg`
- **Nagios Contacts**: `/usr/local/nagios/etc/objects/contacts.cfg`
- **Server Configs**: `/usr/local/nagios/etc/servers/`
- **Apache Config**: `/etc/apache2/sites-available/nagios.conf`
- **Service File**: `/etc/systemd/system/nagios.service`

## Customization

### Change Email Notifications

Edit the contacts configuration:
```bash
sudo vi /usr/local/nagios/etc/objects/contacts.cfg
```

### Add Remote Hosts

Create host configuration files in:
```bash
sudo vi /usr/local/nagios/etc/servers/hostname.cfg
```

Then restart Nagios:
```bash
sudo systemctl restart nagios.service
```

## Uninstallation

To remove Nagios:

```bash
# Stop services
sudo systemctl stop nagios
sudo systemctl disable nagios

# Remove files
sudo rm -rf /usr/local/nagios
sudo rm /etc/systemd/system/nagios.service
sudo rm /etc/apache2/sites-enabled/nagios.conf
sudo rm /etc/apache2/sites-available/nagios.conf

# Remove user/group
sudo userdel nagios
sudo groupdel nagios

# Remove swap (optional)
sudo swapoff /root/myswapfile
sudo rm /root/myswapfile
sudo sed -i '/myswapfile/d' /etc/fstab

# Reload systemd
sudo systemctl daemon-reload
```

## Credits

Based on the excellent guide by Prince Ashok:
- [Nagios Practical - Medium Article](https://medium.com/@princeashok069/nagios-practical-028bd64c5c88)

## License

MIT License - Feel free to use and modify as needed.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.