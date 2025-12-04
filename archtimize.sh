#!/bin/bash
set -euo pipefail

INSTALL_DIR="/usr/local/bin/archtimize"
INSTALLER_TARGET="$INSTALL_DIR/archtimize.sh"
STATE_FILE="/var/lib/archtimize/state"
REALUSER="${SUDO_USER:-$USER}"
GREEN_BOLD="\e[1;32m"
RESET="\e[0m"

# REQUIRE ROOT
if [[ $EUID -ne 0 ]]; then
    echo -e "\e[1;31mThis installer must be run with sudo or as root.${RESET}"
    echo -e "\e[4;32mUnsafe commands will automatically be ran in non-sudo.${RESET}"
    exit 1
fi

# COPY INSTALLER DIRECTORY INTO /usr/local/bin
copy_installer_dir() {
    echo -e "${GREEN_BOLD} ==> Preparing installer directory...${RESET}"

    mkdir -p "$INSTALL_DIR"

    # Copy entire folder containing this script
    local src_dir
    src_dir="$(cd "$(dirname "$0")" && pwd)"

    cp -r "$src_dir"/* "$INSTALL_DIR"/

    # Ensure main script is executable
    chmod +x "$INSTALLER_TARGET"
}

# CREATE SYSTEMD SERVICE
create_systemd_service() {
    echo -e "${GREEN_BOLD} ==> Creating systemd auto-resume service...${RESET}"

    cat <<EOF > /etc/systemd/system/archtimize.service
[Unit]
Description=Archtimize Installer After Reboot
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$INSTALLER_TARGET
StandardOutput=tty
StandardError=tty
TTYPath=/dev/tty1
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable archtimize.service
}

# STATES
create_state_file() {
    mkdir -p /var/lib/archtimize
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "1" > "$STATE_FILE"
    fi
}

set_stage() {
    echo "$1" > "$STATE_FILE"
}

get_stage() {
    cat "$STATE_FILE"
}

# MKINITCPIO MODULES
add_modules_to_mkinitcpio() {
    echo -e "${GREEN_BOLD} ==> Adding CRC32C modules to mkinitcpio.conf...${RESET}"

    MODULES=("crc32c")

    if ! grep -q "^MODULES=" /etc/mkinitcpio.conf; then
        echo "MODULES=()" >> /etc/mkinitcpio.conf
    fi

    for mod in "${MODULES[@]}"; do
        if ! grep -q "$mod" /etc/mkinitcpio.conf; then
            sed -i "s/^MODULES=(/MODULES=($mod /" /etc/mkinitcpio.conf
        fi
    done
}

cleanup_installer() {
    echo -e "${GREEN_BOLD} ==> Cleaning up installer files...${RESET}"

    # Remove installer directory
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
    fi

    # Remove state directory
    if [[ -d /var/lib/archtimize ]]; then
        rm -rf /var/lib/archtimize
    fi

    # Remove leftover CachyOS repo folders
    rm -rf cachyos-repo* 2>/dev/null || true
    rm -rf CachyOS-Settings 2>/dev/null || true

    echo -e "${GREEN_BOLD} ==> Cleanup complete.${RESET}"
}

# STAGE 1
stage_1() {
    echo -e "${GREEN_BOLD} ==> Stage 1: Kernel + Drivers Setup${RESET}"
    echo -e "${GREEN_BOLD} ==> Starting in 3 seconds...${RESET}"
    sleep 3

    echo -e "${GREEN_BOLD} ==> Installing CachyOS repositories...${RESET}"
    sudo -u "$REALUSER" curl -L https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz
    sudo -u "$REALUSER" tar xvf cachyos-repo.tar.xz
    cd cachyos-repo
    ./cachyos-repo.sh
    cd ..

    pacman -Syu --noconfirm

    echo -e "${GREEN_BOLD} ==> Installing CachyOS kernel...${RESET}"
    pacman -S --noconfirm linux-cachyos linux-cachyos-headers

    echo -e "${GREEN_BOLD} ==> Installing chwd & detecting graphics hardware...${RESET}"
    pacman -S --noconfirm chwd
    chwd -a

    echo -e "${GREEN_BOLD} ==> Updating mkinitcpio modules...${RESET}"
    add_modules_to_mkinitcpio

    echo -e "${GREEN_BOLD} ==> Regenerating initramfs...${RESET}"
    mkinitcpio -P

    echo -e "${GREEN_BOLD} ==> Updating grub...${RESET}"
    grub-mkconfig -o /boot/grub/grub.cfg

    echo -e "${GREEN_BOLD} ==> Stage 1 complete — rebooting in 3 seconds...${RESET}"
    set_stage 2
    sleep 3
    reboot
}

# STAGE 2
stage_2() {
    echo -e "${GREEN_BOLD} ==> Stage 2: GUI + Packages + CachyOS Settings${RESET}"
    echo -e "${GREEN_BOLD} ==> Starting in 3 seconds...${RESET}"
    sleep 3

    echo -e "${GREEN_BOLD} ==> Installing plasma, wayland and sddm...${RESET}"
    pacman -S --noconfirm plasma-desktop sddm
    systemctl enable sddm

    echo -e "${GREEN_BOLD} ==> Making some choices for you...${RESET}"
    pacman -S --noconfirm konsole kate spectacle ark gwenview kde-system firefox nano

    echo -e "${GREEN_BOLD} ==> Installing yay...${RESET}"
    pacman -S --needed --noconfirm git base-devel
    sudo -u "$REALUSER" git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    sudo -u "$REALUSER" makepkg -si --noconfirm
    cd ..
    rm -rf yay-bin

    echo -e "${GREEN_BOLD} ==> Installing Lune...${RESET}"
    sudo -u "$REALUSER" yay -S --noconfirm lune-bin

    echo -e "${GREEN_BOLD} ==> Running CachyOS settings installer...${RESET}"
    cd install-cachyos-settings
    lune run main.luau
    cd ..

    echo -e "${GREEN_BOLD} ==> Cleaning up systemd service...${RESET}"
    systemctl disable archtimize.service
    rm /etc/systemd/system/archtimize.service
    systemctl daemon-reload

    echo -e "${GREEN_BOLD} ==> Installation complete — rebooting into KDE!${RESET}"

    echo -e "${GREEN_BOLD} ==> Cleaning systemd service...${RESET}"
    systemctl disable archtimize.service
    rm /etc/systemd/system/archtimize.service
    systemctl daemon-reload

    echo -e "${GREEN_BOLD} ==> Running final cleanup...${RESET}"
    cleanup_installer

    echo -e "${GREEN_BOLD} ==> Installation fully complete — rebooting into KDE!${RESET}"
    set_stage done
    reboot
}

# MAIN
stage=$(get_stage)

if [[ stage == "1" ]]; then
    copy_installer_dir
    create_systemd_service
    create_state_file
fi

case "$(get_stage)" in
    1) stage_1 ;;
    2) stage_2 ;;
    done)
        echo -e "${GREEN_BOLD}Archtimize installation is complete.${RESET}"
        ;;
    *)
        echo "Unknown installer state."
        exit 1
        ;;
esac