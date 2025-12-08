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

# Fix the applications on kde task manager (get rid of discover app)
fix_kde_task_manager() {
(
    set +e

    local homepath
    homepath="$(cat "/var/lib/archtimize/homepath" | tr -d '\n')"
    CONFIG_FILE="$homepath/.config/plasma-org.kde.plasma.desktop-appletsrc"

    mkdir -p "$(dirname "$CONFIG_FILE")"
    touch "$CONFIG_FILE"

    local header
    local data
    header="[Containments][3][Applets][6][Configuration][General]"
    data="launchers=applications:systemsettings.desktop,preferred://filemanager,preferred://browser,applications:org.kde.konsole.desktop"

    # look for task manager header
    local esc_header
    esc_header=$(printf '%s\n' "$header" | sed 's/[][\\/.*^$]/\\&/g')

    # delete header and it's block
    if grep -qF "$header" "$CONFIG_FILE"; then
        sed -i "/^$esc_header$/,/^\[/d" "$CONFIG_FILE"
    fi

    # append new header and block
    printf "\n%s\n%s\n" "$header" "$data" >> "$CONFIG_FILE"
) || true
}

echo "==> Fixing KDE Task Manager..."
fix_kde_task_manager

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