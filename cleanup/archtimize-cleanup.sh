#!/bin/bash
set -e

remove_cloned_dir() {
    [[ -f "/var/lib/archtimize/clonedpath" ]] || return 0

    local p
    p="$(cat "/var/lib/archtimize/clonedpath" | tr -d '\n')"

    [[ -n "$p" ]] || return 0
    [[ "$p" == /* ]] || return 0

    echo "Removing $p"
    rm -rf "$p"
}

patch_default_panel() {
(
    local p
    p="/usr/share/plasma/plasmoids/org.kde.plasma.taskmanager/contents/config/main.xml"
    if [ -f $p ]; then
        rm -f "$p"
    fi
    mv /usr/local/bin/archtimize/taskmanager/main.xml "$p"
) || true
}

echo "==> Patching default panel..."
patch_default_panel

echo "==> Cleaning installer files..."
remove_cloned_dir || true
rm -rf /usr/local/bin/archtimize
rm -rf /var/lib/archtimize
rm -rf /home/*/.config/archtimize 2>/dev/null || true
rm -rf /CachyOS-Settings 2>/dev/null || true
rm -rf /cachyos-repo* 2>/dev/null || true

echo "==> Cleaning archtimize-login.service..."
systemctl disable archtimize-login.service || true
rm -f /etc/systemd/system/archtimize-login.service

echo "==> Done."