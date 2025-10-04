#!/bin/bash
# ===========================================
# Centralized Logging Setup with Rsyslog
# Supports: Debian/Ubuntu + RHEL/CentOS
# Role: server or client
# Adds firewall rules automatically
# ===========================================

set -e

echo "======================================"
echo " Centralized Logging Setup (rsyslog) "
echo "======================================"

# Detect OS family
if [ -f /etc/debian_version ]; then
    OS_FAMILY="debian"
    PKG_UPDATE="apt update -y"
    PKG_INSTALL="apt install -y"
    FIREWALL_CMD="ufw"
elif [ -f /etc/redhat-release ]; then
    OS_FAMILY="rhel"
    PKG_UPDATE="yum makecache -y"
    PKG_INSTALL="yum install -y"
    FIREWALL_CMD="firewalld"
else
    echo "[!] Unsupported OS."
    exit 1
fi

read -p "Is this machine a log server or client? (server/client): " ROLE

# Install rsyslog
echo "[*] Installing rsyslog..."
$PKG_UPDATE >/dev/null
$PKG_INSTALL rsyslog >/dev/null

systemctl enable --now rsyslog

# -----------------------------
# SERVER CONFIGURATION
# -----------------------------
if [ "$ROLE" == "server" ]; then
    echo "[*] Configuring rsyslog as SERVER..."

    cat > /etc/rsyslog.d/remote.conf <<EOF
# Enable UDP and TCP syslog reception
module(load="imudp")
input(type="imudp" port="514")

module(load="imtcp")
input(type="imtcp" port="514")

# Store logs per host
template(name="RemoteLogs" type="string"
         string="/var/log/remote/%HOSTNAME%/%PROGRAMNAME%.log")

*.* ?RemoteLogs
& stop
EOF

    mkdir -p /var/log/remote
    chown -R www-data:adm /var/log/remote/ || true
    chmod 750 /var/log/remote

    # Add log rotation for remote logs
    cat > /etc/logrotate.d/remote_logs <<EOF
/var/log/remote/*/*.log {
    daily
    rotate 14
    compress
    missingok
    notifempty
    create 0640 syslog adm
    sharedscripts
    postrotate
        systemctl restart rsyslog >/dev/null 2>&1 || true
    endscript
}
EOF

    # Firewall rules
    echo "[*] Configuring firewall for UDP/TCP 514..."
    if [ "$OS_FAMILY" = "debian" ]; then
        ufw allow 514/tcp
        ufw allow 514/udp
    else
        systemctl enable --now firewalld || true
        firewall-cmd --permanent --add-port=514/tcp
        firewall-cmd --permanent --add-port=514/udp
        firewall-cmd --reload
    fi

    echo "[+] Rsyslog SERVER configured! Logs will be stored in /var/log/remote/<hostname>/"

# -----------------------------
# CLIENT CONFIGURATION
# -----------------------------
elif [ "$ROLE" == "client" ]; then
    read -p "Enter Log Server IP: " SERVER_IP
    echo "[*] Configuring rsyslog as CLIENT to forward logs to $SERVER_IP"

    # Forward logs over UDP (can change to TCP with @@)
    echo "*.* @$SERVER_IP:514" >> /etc/rsyslog.conf

    # Firewall (optional for clients, only outbound needed)
    if [ "$OS_FAMILY" = "debian" ]; then
        ufw allow out 514/tcp
        ufw allow out 514/udp
    else
        systemctl enable --now firewalld || true
        firewall-cmd --permanent --add-port=514/tcp
        firewall-cmd --permanent --add-port=514/udp
        firewall-cmd --reload
    fi

    echo "[+] Rsyslog CLIENT configured! Forwarding logs to $SERVER_IP"

else
    echo "[!] Invalid choice. Please enter 'server' or 'client'."
    exit 1
fi

systemctl restart rsyslog
echo "[] Setup complete!"

