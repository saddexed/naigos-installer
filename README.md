# Nagios Core - Non-Interactive Installation Script

This repository contains a fully automated, non-interactive installation script for Nagios Core on Ubuntu systems. Based on a medium article linked below

## Quick Start

### Installation
```bash
wget https://raw.githubusercontent.com/saddexed/naigos-installer/master/install-nagios.sh
chmod +x install-nagios.sh
./install-nagios.sh
```
Or in a single command if you prefer
```bash
wget https://raw.githubusercontent.com/saddexed/naigos-installer/master/install-nagios.sh && chmod +x install-nagios.sh && ./install-nagios.sh
```



## Post-Installation

### Access Nagios Web Interface
**Username**: `nagiosadmin`  
**Password**: `nagiosadmin`

If you wish to change the password, run:

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

## Customization

### Change Email Notifications

Edit the contacts configuration:
```bash
sudo nano /usr/local/nagios/etc/objects/contacts.cfg
```

### Add Remote Hosts

Create host configuration files in:
```bash
sudo nano /usr/local/nagios/etc/servers/hostname.cfg
```

Then restart Nagios:
```bash
sudo systemctl restart nagios.service
```

## Credits

Based on the excellent guide by Prince Ashok:
- [Nagios Practical - Medium Article](https://medium.com/@princeashok069/nagios-practical-028bd64c5c88)

## License

MIT License - Feel free to use and modify as needed.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.