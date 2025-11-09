#!/bin/bash

############################################################
# Weather App + Ansible Auto-Update Installer
#
# This script installs and configures the components needed
# to host the Weather-App static site, keep it in sync with
# GitHub via Ansible every 10 minutes, and expose it through
# Nginx. Designed for Ubuntu 20.04+/Debian-based systems.
#
# Prerequisites: run as root (or with sudo).
############################################################

set -euo pipefail

REPO_URL="https://github.com/saddexed/Weather-App.git"
BASE_DIR="/opt/weather-app"
SRC_DIR="$BASE_DIR/source"
ANSIBLE_DIR="$BASE_DIR/ansible"
WEB_ROOT="/var/www/weather-app"
PLAYBOOK_PATH="$ANSIBLE_DIR/deploy-weather-app.yml"
ANSIBLE_LOG="/var/log/weather-app-update.log"
SERVICE_FILE="/etc/systemd/system/weather-app-update.service"
TIMER_FILE="/etc/systemd/system/weather-app-update.timer"
APACHE_SITE="/etc/apache2/sites-available/weather-app.conf"
UFW_RULE_NAME="Apache Full"
NAGIOS_PLUGIN="/usr/local/nagios/libexec/check_weather_app_update.sh"
NAGIOS_COMMANDS="/usr/local/nagios/etc/objects/commands.cfg"
NAGIOS_SERVICE_CFG="/usr/local/nagios/etc/servers/weather-app-update.cfg"
NAGIOS_CFG="/usr/local/nagios/etc/nagios.cfg"

log() {
    echo -e "\n=========================================="
    echo "$1"
    echo "=========================================="
}

ensure_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo "This script must be run as root. Try: sudo $0" >&2
        exit 1
    fi
}

install_packages() {
    log "Installing required packages"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y git ansible apache2 rsync curl
}

prepare_directories() {
    log "Preparing directories"
    mkdir -p "$SRC_DIR" "$ANSIBLE_DIR" "$WEB_ROOT"
    chown -R root:root "$BASE_DIR"
    chown -R www-data:www-data "$WEB_ROOT"
}

write_ansible_playbook() {
    log "Creating Ansible playbook"
    cat <<'EOF' > "$PLAYBOOK_PATH"
---
- hosts: localhost
  connection: local
  become: true
  vars:
    repo_url: "https://github.com/saddexed/Weather-App.git"
    repo_path: "/opt/weather-app/source"
    web_root: "/var/www/weather-app"
  tasks:
    - name: Ensure base directories exist
      ansible.builtin.file:
        path: "{{ item }}"
        state: directory
        owner: root
        group: root
        mode: "0755"
      loop:
        - "{{ repo_path }}"
        - "{{ web_root }}"

    - name: Fetch Weather-App repository (shallow clone)
      ansible.builtin.git:
        repo: "{{ repo_url }}"
        dest: "{{ repo_path }}"
        version: main
        depth: 1
        update: yes

    - name: Sync static site into web root
      ansible.builtin.synchronize:
        src: "{{ repo_path }}/"
        dest: "{{ web_root }}/"
        delete: true
        recursive: true
        rsync_opts:
          - "--exclude=.git"
          - "--exclude=.github"
          - "--exclude=LICENSE"
          - "--exclude=README.md"

    - name: Ensure web root ownership for Nginx
      ansible.builtin.file:
        path: "{{ web_root }}"
        state: directory
        owner: www-data
        group: www-data
        recurse: true

    - name: Create health check endpoint
      ansible.builtin.copy:
        dest: "{{ web_root }}/health.html"
        content: "<html><body>OK</body></html>\n"
        owner: www-data
        group: www-data
        mode: "0644"
EOF
    chown root:root "$PLAYBOOK_PATH"
    chmod 0644 "$PLAYBOOK_PATH"
}

write_ansible_cfg() {
    log "Creating Ansible configuration"
    cat <<'EOF' > "$ANSIBLE_DIR/ansible.cfg"
[defaults]
inventory = localhost,
host_key_checking = False
log_path = /var/log/weather-app-update.log
retry_files_enabled = False
EOF
    chown root:root "$ANSIBLE_DIR/ansible.cfg"
    chmod 0644 "$ANSIBLE_DIR/ansible.cfg"
    touch "$ANSIBLE_LOG"
    chown root:root "$ANSIBLE_LOG"
    chmod 0644 "$ANSIBLE_LOG"
}

disable_nginx_if_present() {
    if systemctl list-unit-files | grep -q '^nginx.service'; then
        log "Disabling Nginx service to avoid port conflicts"
        systemctl disable --now nginx || true
    fi
}

configure_apache() {
    log "Configuring Apache for Weather-App"
    local apache_log_dir="${APACHE_LOG_DIR:-/var/log/apache2}"

    cat <<EOF > "$APACHE_SITE"
<VirtualHost *:80>
    ServerName _
    DocumentRoot $WEB_ROOT

    <Directory $WEB_ROOT>
        Options FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>

    ErrorLog ${apache_log_dir}/weather-app-error.log
    CustomLog ${apache_log_dir}/weather-app-access.log combined

    Alias /health $WEB_ROOT/health.html
    <Location /health>
        Require all granted
    </Location>
</VirtualHost>
EOF

    if [[ -f /etc/apache2/sites-enabled/000-default.conf ]]; then
        a2dissite 000-default.conf >/dev/null 2>&1 || true
    fi

    a2ensite weather-app.conf >/dev/null 2>&1
    systemctl enable apache2 >/dev/null 2>&1
    if systemctl is-active --quiet apache2; then
        systemctl reload apache2
    else
        systemctl start apache2
    fi
}

configure_firewall() {
    if command -v ufw >/dev/null 2>&1; then
        log "Updating UFW firewall rules"
        ufw allow "$UFW_RULE_NAME" || true
    fi
}

install_nagios_check() {
    if [[ ! -x /usr/local/nagios/bin/nagios ]]; then
        log "Nagios not detected; skipping monitoring integration"
        return
    fi

    log "Installing Nagios check for Weather App updater"

    cat <<'EOF' > "$NAGIOS_PLUGIN"
#!/bin/bash
set -euo pipefail

WARN=${1:-900}
CRIT=${2:-1800}
SERVICE="weather-app-update.service"
TIMER="weather-app-update.timer"

if ! systemctl list-unit-files "$SERVICE" >/dev/null 2>&1; then
    echo "CRITICAL - unit $SERVICE not found"
    exit 2
fi

if ! systemctl list-unit-files "$TIMER" >/dev/null 2>&1; then
    echo "CRITICAL - unit $TIMER not found"
    exit 2
fi

service_state=$(systemctl show "$SERVICE" -p ActiveState --value 2>/dev/null || echo "unknown")
service_result=$(systemctl show "$SERVICE" -p Result --value 2>/dev/null || echo "unknown")
exec_status=$(systemctl show "$SERVICE" -p ExecMainStatus --value 2>/dev/null || echo "unknown")
last_trigger=$(systemctl show "$TIMER" -p LastTriggerUSec --value 2>/dev/null || echo "0")

if [[ "$service_state" == "failed" ]]; then
    echo "CRITICAL - $SERVICE state is failed"
    exit 2
fi

if [[ "$service_result" != "success" && "$service_result" != "n/a" ]]; then
    echo "CRITICAL - last run result is $service_result"
    exit 2
fi

if [[ "$exec_status" != "0" && "$exec_status" != "n/a" ]]; then
    echo "CRITICAL - last exit code $exec_status"
    exit 2
fi

age_sec=-1
if [[ "$last_trigger" =~ ^[0-9]+$ ]] && [[ "$last_trigger" != "0" ]]; then
    now=$(date +%s)
    last_trigger_sec=$(( last_trigger / 1000000 ))
    age_sec=$(( now - last_trigger_sec ))
fi

if [[ $age_sec -ge 0 ]]; then
    if [[ $age_sec -ge $CRIT ]]; then
        echo "CRITICAL - last run ${age_sec}s ago (>=${CRIT}s) | age=${age_sec}s;${WARN};${CRIT};0"
        exit 2
    elif [[ $age_sec -ge $WARN ]]; then
        echo "WARNING - last run ${age_sec}s ago (>=${WARN}s) | age=${age_sec}s;${WARN};${CRIT};0"
        exit 1
    else
        echo "OK - last run ${age_sec}s ago, result ${service_result} | age=${age_sec}s;${WARN};${CRIT};0"
        exit 0
    fi
else
    echo "OK - timer has not triggered yet | age=0s;${WARN};${CRIT};0"
    exit 0
fi
EOF

    chown nagios:nagios "$NAGIOS_PLUGIN"
    chmod 0755 "$NAGIOS_PLUGIN"

    if [[ -f "$NAGIOS_COMMANDS" ]] && ! grep -q "check_weather_app_update" "$NAGIOS_COMMANDS"; then
        cat <<'EOF' >> "$NAGIOS_COMMANDS"

# Weather App update check
define command{
    command_name    check_weather_app_update
    command_line    /usr/local/nagios/libexec/check_weather_app_update.sh $ARG1$ $ARG2$
}
EOF
    fi

    mkdir -p "$(dirname "$NAGIOS_SERVICE_CFG")"
    cat <<'EOF' > "$NAGIOS_SERVICE_CFG"
define service{
    use                     local-service
    host_name               localhost
    service_description     Weather App Updater
    check_command           check_weather_app_update!900!1800
    check_interval          5
    retry_interval          1
}
EOF
    chown nagios:nagios "$NAGIOS_SERVICE_CFG"
    chmod 0644 "$NAGIOS_SERVICE_CFG"
}

reload_nagios() {
    if [[ ! -x /usr/local/nagios/bin/nagios ]]; then
        return
    fi

    log "Validating Nagios configuration"
    local verify_log="/tmp/weather-app-nagios-verify.log"
    if /usr/local/nagios/bin/nagios -v "$NAGIOS_CFG" > "$verify_log" 2>&1; then
        log "Reloading Nagios"
        if systemctl reload nagios.service; then
            rm -f "$verify_log"
        else
            log "Reload not supported; restarting Nagios"
            systemctl restart nagios.service
            rm -f "$verify_log"
        fi
    else
        log "Nagios configuration check failed; see $verify_log"
        cat "$verify_log"
    fi
}

write_systemd_units() {
    log "Creating systemd service and timer"
    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Update Weather-App static site via Ansible
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/ansible-playbook -i localhost, -c local $PLAYBOOK_PATH
WorkingDirectory=$ANSIBLE_DIR
Environment=ANSIBLE_CONFIG=$ANSIBLE_DIR/ansible.cfg
StandardOutput=append:$ANSIBLE_LOG
StandardError=append:$ANSIBLE_LOG
EOF

    cat <<'EOF' > "$TIMER_FILE"
[Unit]
Description=Run Weather-App update every 10 minutes

[Timer]
OnBootSec=2min
OnUnitInactiveSec=10min
AccuracySec=1min
Persistent=true
Unit=weather-app-update.service

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable --now weather-app-update.timer
}

run_initial_deploy() {
    log "Running initial Ansible deployment"
    ANSIBLE_CONFIG="$ANSIBLE_DIR/ansible.cfg" ansible-playbook -i localhost, -c local "$PLAYBOOK_PATH"
}

show_summary() {
    log "Installation complete"
    local host_ip
    host_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [[ -z "$host_ip" ]]; then
        host_ip="localhost"
    fi
    echo "Weather-App is served from: http://$host_ip/"
    echo "Health endpoint: http://$host_ip/health"
    echo "Ansible playbook: $PLAYBOOK_PATH"
    echo "Systemd timer: weather-app-update.timer (runs every 10 minutes)"
    echo "Logs: $ANSIBLE_LOG"
}

main() {
    ensure_root
    install_packages
    prepare_directories
    write_ansible_playbook
    write_ansible_cfg
    disable_nginx_if_present
    configure_apache
    configure_firewall
    run_initial_deploy
    write_systemd_units
    install_nagios_check
    reload_nagios
    show_summary
}

main "$@"
