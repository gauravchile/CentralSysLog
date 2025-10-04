#!/bin/bash
# ==========================================
# LogAnalyzer Installer (Debian/RHEL)
# ==========================================
# This script installs and configures:
# - Apache + PHP
# - MariaDB/MySQL
# - Rsyslog with MySQL support
# - LogAnalyzer web interface
#
# Usage: sudo ./install_loganalyzer.sh
# ==========================================

set -e

# Detect OS family
if [ -f /etc/debian_version ]; then
  OS_FAMILY="debian"
  PKG_UPDATE="apt update -y"
  PKG_INSTALL="apt install -y"
  WEB_USER="www-data"
elif [ -f /etc/redhat-release ]; then
  OS_FAMILY="rhel"
  PKG_UPDATE="yum -y update"
  PKG_INSTALL="yum install -y"
  WEB_USER="apache"
else
  echo "[!] Unsupported OS"
  exit 1
fi

echo "[*] Updating packages..."
$PKG_UPDATE

echo "[*] Installing dependencies..."
if [ "$OS_FAMILY" = "debian" ]; then
  $PKG_INSTALL apache2 mariadb-server  php libapache2-mod-php wget unzip
  systemctl enable --now apache2
else
  $PKG_INSTALL httpd mariadb-server php php-mysql wget unzip
  systemctl enable --now httpd
fi
systemctl enable --now mariadb
systemctl enable --now rsyslog

# Create MySQL database for rsyslog
echo "[*] Configuring MySQL..."
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS Syslog;
CREATE USER IF NOT EXISTS 'rsyslog'@'localhost' IDENTIFIED BY 'StrongPass123!';
GRANT ALL PRIVILEGES ON Syslog.* TO 'rsyslog'@'localhost';
FLUSH PRIVILEGES;
EOF

# Import rsyslog schema
echo "[*] Importing rsyslog schema..."
 sql="syslog.sql"
cat > $sql << EOF
-- Rsyslog MySQL schema

CREATE DATABASE IF NOT EXISTS Syslog;

USE Syslog;

CREATE TABLE SystemEvents
(
    ID BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    CustomerID BIGINT,
    ReceivedAt datetime NULL,
    DeviceReportedTime datetime NULL,
    Facility smallint NULL,
    Priority smallint NULL,
    FromHost varchar(60) NULL,
    Message text,
    NTSeverity int NULL,
    Importance int NULL,
    EventSource varchar(60),
    EventUser varchar(60),
    EventCategory int NULL,
    EventID int NULL,
    EventBinaryData text,
    MaxAvailable int NULL,
    CurrUsage int NULL,
    MinUsage int NULL,
    MaxUsage int NULL,
    InfoUnitID int NULL,
    SysLogTag varchar(60),
    EventLogType varchar(60),
    GenericFileName VarChar(60),
    SystemID int NULL,
    PRIMARY KEY (ID)
);

CREATE TABLE SystemEventsProperties
(
    ID BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    SystemEventID BIGINT UNSIGNED NOT NULL,
    ParamName varchar(255) NULL,
    ParamValue text NULL,
    PRIMARY KEY (ID)
);
EOF

MYSQL_ROOT_PASS="StrongPass123!"  # change to your root password

echo "[*] Importing syslog database schema..."
mysql -u root -p"$MYSQL_ROOT_PASS" < create_syslog.sql

# Configure rsyslog to log into MySQL
echo "[*] Configuring rsyslog..."
RSYS_CONF="/etc/rsyslog.d/mysql.conf"
cat > $RSYS_CONF <<EOF
module(load="ommysql")
*.* :ommysql:127.0.0.1,Syslog,rsyslog,StrongPass123!
EOF
systemctl restart rsyslog

# Install LogAnalyzer
echo "[*] Installing LogAnalyzer..."
cd /tmp
wget https://download.adiscon.com/loganalyzer/loganalyzer-4.1.13.tar.gz -O loganalyzer.tar.gz
tar -xzf loganalyzer.tar.gz
mkdir -p /var/www/html/loganalyzer
cp -r loganalyzer-*/src/* /var/www/html/loganalyzer/
chown -R $WEB_USER:$WEB_USER /var/www/html/loganalyzer

# Logrotate policy for syslog DB
echo "[*] Configuring log rotation..."
cat > /etc/logrotate.d/mysql-syslog <<EOF
/var/log/mysql/mysql.log {
    daily
    rotate 7
    missingok
    compress
    delaycompress
    notifempty
    create 640 mysql adm
    sharedscripts
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
EOF

echo "[+] Installation complete!"
echo "------------------------------------------------------"
echo "Open in browser: http://<server-ip>/loganalyzer"
echo "MySQL Database: Syslog"
echo "User: rsyslog  Password: StrongPass123!"
echo "------------------------------------------------------"

