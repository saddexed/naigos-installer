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

## Monitoring Remote Servers with NRPE

This repository includes scripts to monitor remote servers using NRPE (Nagios Remote Plugin Executor).

### Setup Overview

**Step 1: Install NRPE Agent on Remote Server**

On the weather app server (or any remote server you want to monitor):

```bash
wget https://raw.githubusercontent.com/saddexed/naigos-installer/master/install-nrpe-client.sh
chmod +x install-nrpe-client.sh
./install-nrpe-client.sh
```

When prompted, enter your Nagios server's IP address.

**Step 2: Configure Nagios Server to Monitor the Remote Host**

On the Nagios server, download the weather app configuration:

```bash
wget https://raw.githubusercontent.com/saddexed/naigos-installer/master/weatherapp.cfg
```

Edit the configuration file to replace `WEATHERAPP_SERVER_IP` with your weather app server's actual IP address:

```bash
sudo sed -i 's/WEATHERAPP_SERVER_IP/192.168.1.100/g' weatherapp.cfg
```

Then move it to the Nagios configuration directory:

```bash
sudo mv weatherapp.cfg /usr/local/nagios/etc/servers/
sudo chown nagios:nagios /usr/local/nagios/etc/servers/weatherapp.cfg
```

**Step 3: Verify Nagios Configuration**

Verify the configuration syntax:
```bash
sudo /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
```

Restart Nagios to apply changes:
```bash
sudo systemctl restart nagios.service
```

### What Gets Monitored

The weather app server monitoring configuration includes:

- **HTTP Service** - Checks if the web application is responding
- **Nginx Service** - TCP port 80 connectivity
- **CPU Load** - Server CPU usage
- **Memory Usage** - RAM utilization
- **Disk Space** - Disk usage
- **Total Processes** - Number of running processes
- **SSH Service** - Server accessibility via SSH

### Monitoring Multiple Servers

To monitor additional remote servers:

1. Run `install-nrpe-client.sh` on each remote server
2. Copy `weatherapp.cfg` and customize it for each server:
   ```bash
   cp weatherapp.cfg myserver.cfg
   sudo nano myserver.cfg  # Update host_name and address
   sudo mv myserver.cfg /usr/local/nagios/etc/servers/
   ```
3. Restart Nagios

### Troubleshooting

**NRPE Connection Issues**

Test NRPE connectivity from the Nagios server:
```bash
/usr/local/nagios/libexec/check_nrpe -H <remote-server-ip>
```

If connection fails:
- Verify the remote server has NRPE running: `sudo systemctl status nrpe.service`
- Check firewall allows UDP port 5666: `sudo ufw status`
- Verify allowed_hosts in `/etc/nagios/nrpe.cfg` includes the Nagios server IP

**Nagios Not Picking Up New Configuration**

- Verify syntax: `sudo /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg`
- Restart Nagios: `sudo systemctl restart nagios.service`
- Check Nagios status: `sudo systemctl status nagios.service`

## Credits

Based on the excellent guide by Prince Ashok:
- [Nagios Practical - Medium Article](https://medium.com/@princeashok069/nagios-practical-028bd64c5c88)

## License

MIT License - Feel free to use and modify as needed.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.