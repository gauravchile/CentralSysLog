#!/bin/bash
# Centralized Log Aggregation Validation Script
# Run this script on each client and the log-server

ROLE=$1   # client or server
LOG_SERVER="10.41.100.51"   # IP of log-server
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
HOSTNAME=$(hostname)
TEST_TAG="CENTRAL-LOG-TEST"
MESSAGE="Centralized logging test from $HOSTNAME at $TIMESTAMP"

if [ "$ROLE" == "client" ]; then
    echo "[*] Sending test log to $LOG_SERVER..."
    logger -t $TEST_TAG "$MESSAGE"
    echo "[+] Sent log: $MESSAGE"
    echo "[-] Now run this script with 'server' role on the log-server to validate."
elif [ "$ROLE" == "server" ]; then
    echo "[*] Checking logs received on centralized server..."
    sleep 2  # wait a moment for logs to arrive
    grep "$TEST_TAG" /var/log/remote/*/*.log
    if [ $? -eq 0 ]; then
        echo "[+] Validation successful: Test logs found."
    else
        echo "[!] Validation failed: No test logs found."
    fi
else
    echo "Usage: $0 client|server"
    exit 1
fi

