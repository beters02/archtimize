#!/bin/bash
set -Eeuo pipefail

# move cleanup script
mv /usr/local/bin/archtimize/cleanup/archtimize-cleanup.sh /usr/local/bin/archtimize-cleanup.sh
chmod +x /usr/local/bin/archtimize-cleanup.sh

# move cleanup service
mv /usr/local/bin/archtimize/cleanup/archtimize-cleanup.service /etc/systemd/system/archtimize-cleanup.service

systemctl daemon-reload
systemctl enable archtimize-cleanup.service