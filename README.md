# Nagios Core - Non-Interactive Installation Script

This repository contains a fully automated, non-interactive installation script for Nagios Core on Ubuntu systems. Based on a medium article linked below

## Quick Start

### Nagios Core Installer
```bash
wget https://raw.githubusercontent.com/saddexed/naigos-installer/master/install-nagios.sh
chmod +x install-nagios.sh
./install-nagios.sh
```
Or in a single command if you prefer
```bash
wget https://raw.githubusercontent.com/saddexed/naigos-installer/master/install-nagios.sh && chmod +x install-nagios.sh && ./install-nagios.sh
```

### Weather-App Auto-Deploy Stack
```bash
wget https://raw.githubusercontent.com/saddexed/naigos-installer/master/install-weather-stack.sh
chmod +x install-weather-stack.sh
sudo ./install-weather-stack.sh
```
Single command
```bash
wget https://raw.githubusercontent.com/saddexed/naigos-installer/master/install-weather-stack.sh && chmod +x install-weather-stack.sh && sudo ./install-weather-stack.sh
```
What the script does:
- Installs Ansible, Git, Apache, and rsync
- Clones the [Weather-App](https://github.com/saddexed/Weather-App) repo into `/opt/weather-app`
- Serves the static site via Apache from `/var/www/weather-app`
- Creates an Ansible playbook and runs it immediately
- Registers a systemd timer that re-runs the playbook every 10 minutes to pull the latest commit
- Adds a Nagios service check (`Weather App Updater`) to watch the automation job

After installation you can verify everything with:
```bash
systemctl status apache2
systemctl status weather-app-update.timer
systemctl status weather-app-update.service
curl -I http://localhost/health
/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
```

In the Nagios UI, look for the **Weather App Updater** service on `localhost`. It reports the age of the last successful deploy run and will warn after 15 minutes or alert after 30 minutes without a successful execution.



## Post-Installation

### Access Nagios Web Interface
**Username**: `admin`  
**Password**: `admin123`

If you wish to change the password, run:

```bash
sudo htpasswd /usr/local/nagios/etc/htpasswd.users admin
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