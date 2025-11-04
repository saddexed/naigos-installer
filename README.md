# Nagios Installation & Remote Monitoring Setup

Complete automation scripts for Nagios Core installation and remote host monitoring via NRPE.

Based on: [Nagios Practical - Medium Article](https://medium.com/@princeashok069/nagios-practical-028bd64c5c88)

## 📁 Scripts Overview

### 1. `install-nagios.sh` - Nagios Server Installation
Main installation script for the Nagios monitoring server.

**Features:**
- Fully non-interactive installation
- Automatic swap creation (1GB)
- Configures needrestart for automatic service restarts
- Installs Nagios Core 4.4.14 and Plugins 2.4.6
- Complete Apache integration with authentication
- Firewall configuration (UFW)
- Displays server IP for easy access

**Usage:**
```bash
chmod +x install-nagios.sh
sudo ./install-nagios.sh
```

### 2. `install-nrpe-agent.sh` - NRPE Agent for Remote Hosts
Installs the NRPE (Nagios Remote Plugin Executor) agent on remote machines to be monitored.

**Features:**
- Non-interactive NRPE installation
- Configures NRPE to accept connections from Nagios server
- Optional Apache2 installation with sample webpage
- Displays host information for Nagios configuration

**Usage:**
```bash
# With Nagios server IP as argument
chmod +x install-nrpe-agent.sh
sudo ./install-nrpe-agent.sh 203.0.113.45

# Or interactive (prompts for IP)
sudo ./install-nrpe-agent.sh
```

**Parameters:**
- `$1` - (Optional) IP address of Nagios server. If not provided, will prompt interactively.

### 3. `add-nagios-host.sh` - Add Remote Hosts to Nagios
Adds a remote host to Nagios monitoring configuration on the Nagios server.

**Features:**
- Interactive host configuration
- Creates proper Nagios configuration files
- Includes NRPE checks (CPU, Memory, Disk, Swap)
- Includes HTTP check for web services
- Validates configuration before restarting
- Provides immediate feedback and next steps

**Usage:**
```bash
# Run on the Nagios SERVER (not the remote host)
chmod +x add-nagios-host.sh
sudo ./add-nagios-host.sh
```

**Prompts:**
- Host name (e.g., `nagihost`)
- Host IP address (e.g., `10.0.1.50`)
- Host alias/description

### 4. `web-server.sh` - Sample Web Server
Your existing weather app deployment script (already present).

## 🚀 Quick Start Guide

### Step 1: Install Nagios Server

```bash
sudo ./install-nagios.sh
```

This will:
- Update system and create swap
- Install Nagios Core and Plugins
- Set up Apache with authentication
- Display server IP when complete

**Access Nagios:**
```
http://YOUR_SERVER_IP/nagios
Username: nagiosadmin
Password: nagiosadmin (change this!)
```

### Step 2: Install NRPE Agent on Remote Host

On your remote host machine:

```bash
# Get the Nagios server IP first
# Then run:
sudo ./install-nrpe-agent.sh 203.0.113.45
```

This will:
- Install NRPE agent
- Configure it to accept Nagios server connections
- Optionally install Apache2 with a sample page
- Display the remote host's IP

### Step 3: Add Remote Host to Nagios Server

Back on the Nagios server:

```bash
sudo ./add-nagios-host.sh
```

You'll be prompted for:
- **Host name**: `nagihost` (or your choice)
- **Host IP**: The remote host's IP address
- **Alias**: `Remote Monitored Host`

This creates a configuration file at:
```
/usr/local/nagios/etc/servers/nagihost.cfg
```

### Step 4: Verify in Web Interface

1. Go to `http://YOUR_SERVER_IP/nagios`
2. Navigate to **Hosts** section
3. You should see your new host (`nagihost`)
4. After 1-2 minutes, services will appear:
   - CPU Load ✓
   - Memory Usage ✓
   - Disk Usage ✓
   - Swap Usage ✓
   - HTTP (if Apache installed) ✓

## 📋 Configuration Files

### Nagios Server

- **Main Config**: `/usr/local/nagios/etc/nagios.cfg`
- **Commands**: `/usr/local/nagios/etc/objects/commands.cfg`
- **Contacts**: `/usr/local/nagios/etc/objects/contacts.cfg`
- **Host Configs**: `/usr/local/nagios/etc/servers/*.cfg`
- **Apache Config**: `/etc/apache2/sites-enabled/nagios.conf`
- **Service File**: `/etc/systemd/system/nagios.service`

### Remote Host (NRPE Agent)

- **NRPE Config**: `/usr/local/nagios/etc/nrpe.cfg`
- **NRPE Service**: `/etc/systemd/system/nrpe.service`

## 🔧 Common Tasks

### Change Nagios Admin Password

```bash
sudo htpasswd /usr/local/nagios/etc/htpasswd.users nagiosadmin
```

### Restart Nagios Service

```bash
sudo systemctl restart nagios.service
```

### View Nagios Logs

```bash
sudo tail -f /usr/local/nagios/var/nagios.log
```

### Add Another Host

Simply run `add-nagios-host.sh` again with different host information.

### Edit Host Configuration

```bash
sudo vi /usr/local/nagios/etc/servers/nagihost.cfg
sudo systemctl restart nagios.service
```

### Check NRPE Service (on remote host)

```bash
sudo systemctl status nrpe.service
```

### Test NRPE Connection (from Nagios server)

```bash
/usr/local/nagios/libexec/check_nrpe -H <REMOTE_HOST_IP>
```

## 🐛 Troubleshooting

### Services Not Appearing

1. Wait 2-3 minutes for initial check
2. Verify NRPE is running on remote host:
   ```bash
   sudo systemctl status nrpe.service
   ```
3. Test NRPE connection from Nagios server:
   ```bash
   /usr/local/nagios/libexec/check_nrpe -H <HOST_IP>
   ```

### Hosts Show as "PENDING" or "UNKNOWN"

- Check if NRPE agent is running on the remote host
- Verify firewall allows port 5666 (NRPE default port)
- Check if the host IP in config is correct:
   ```bash
   sudo cat /usr/local/nagios/etc/servers/nagihost.cfg
   ```

### Authentication Required But Not Prompting

- Clear browser cache
- Try incognito/private window
- Verify htpasswd file exists:
   ```bash
   ls -l /usr/local/nagios/etc/htpasswd.users
   ```

### Nagios Won't Start

Check configuration syntax:
```bash
sudo /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
```

View service logs:
```bash
sudo journalctl -u nagios.service -n 50
```

### NRPE Installation Fails

Ensure you're using a supported OS (Ubuntu 18.04+):
```bash
lsb_release -a
```

## 🔐 Security Recommendations

1. **Change Default Password**
   ```bash
   sudo htpasswd /usr/local/nagios/etc/htpasswd.users nagiosadmin
   ```

2. **Restrict Firewall** - Only allow your IP:
   ```bash
   sudo ufw delete allow from anywhere to anywhere port 80
   sudo ufw allow from 203.0.113.1 to anywhere port 80
   ```

3. **Enable HTTPS** - Configure SSL certificates in Apache config

4. **Disable NRPE Access** - Restrict NRPE to Nagios server only:
   ```bash
   sudo sed -i 's/^allowed_hosts=.*/allowed_hosts=127.0.0.1,NAGIOS_IP/' /usr/local/nagios/etc/nrpe.cfg
   sudo systemctl restart nrpe.service
   ```

## 📚 Additional Resources

- [Nagios Official Documentation](https://assets.nagios.com/downloads/nagioscore/docs/nagioscore/4.4/en/)
- [NRPE Documentation](https://assets.nagios.com/downloads/nagioscore/docs/nagios-plugins/NRPE.pdf)
- [Original Medium Article](https://medium.com/@princeashok069/nagios-practical-028bd64c5c88)

## 📝 License

MIT License - Feel free to use and modify as needed.

## 🤝 Contributing

Contributions are welcome! Feel free to submit a Pull Request.
