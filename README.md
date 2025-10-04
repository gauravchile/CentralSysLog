# Centralized Log Aggregation with Rsyslog

##  Project Goal
Set up a centralized log server to collect system logs from multiple virtual machines (VMs) and configure clients to forward logs to the server. Implement log rotation and retention using `logrotate`, and optionally integrate a frontend log analyzer (LogAnalyzer) for visualization.

---

##  Project Components

### 1. Central Log Server
- **Rsyslog** configured to receive logs over TCP/UDP.
- Stores incoming logs in `/var/log/syslog` or custom directories.
- **Log rotation** implemented via `logrotate` to manage disk space and retention.
- Optional frontend: [LogAnalyzer](https://loganalyzer.adiscon.com/) for viewing and analyzing logs.

### 2. Client VMs
- Forward system logs to the central log server.
- Use `rsyslog` configuration for TCP/UDP forwarding.
- Examples: Web server VM, Database server VM, Proxy server VM.

---

##  Installation & Configuration

### Central Server Setup

run script below

 ./setup_rsyslog.sh

for confirmation run this script on client and server

 ./validate_logging.sh

# Frontend: LogAnalyzer

Install LogAnalyzer on the central server (/var/www/html/loganalyzer).

Access via web browser to visualize and filter logs.

LogAnalyzer automatically imports and analyzes syslog files once configured.

./loganalyzer.sh
