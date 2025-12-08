#!/bin/bash
set -e

remove_cloned_path() {
    [[ -f "/var/lib/archtimize/clonedpath" ]] || return 0

    local p
    p="$(cat "/var/lib/archtimize/clonedpath" | tr -d '\n')"

    [[ -n "$p" ]] || return 0
    [[ "$p" == /* ]] || return 0

    echo "Removing $p"
    rm -rf "$p"
}

echo "==> Cleaning installer files..."
remove_cloned_path || true
rm -rf /usr/local/bin/archtimize
rm -rf /var/lib/archtimize
rm -rf /home/*/.config/archtimize 2>/dev/null || true
rm -rf /CachyOS-Settings 2>/dev/null || true
rm -rf /cachyos-repo* 2>/dev/null || true

echo "==> Cleaning archtimize-login.service..."
systemctl disable archtimize-login.service || true
rm -f /etc/systemd/system/archtimize-login.service

echo "==> Done."