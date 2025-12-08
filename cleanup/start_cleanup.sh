#!/bin/bash
set -Eeuo pipefail

# move cleanup script
echo "1"
mv /usr/local/bin/archtimize/cleanup/archtimize-cleanup.sh /usr/local/bin/archtimize-cleanup.sh
chmod +x /usr/local/bin/archtimize-cleanup.sh

echo "1"
# move cleanup service
mv /usr/local/bin/archtimize/cleanup/archtimize-cleanup.service /etc/systemd/system/archtimize-cleanup.service

echo "1"
systemctl daemon-reload
systemctl enable archtimize-cleanup.service