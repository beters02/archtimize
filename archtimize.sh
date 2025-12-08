#!/bin/bash
set -euo pipefail

INSTALL_DIR="/usr/local/bin/archtimize"
INSTALLER_TARGET="$INSTALL_DIR/archtimize.sh"
STATE_FILE="/var/lib/archtimize/state"
REALUSER="${SUDO_USER:-$USER}"
REALUSER_HOME="$(eval echo ~"$REALUSER")"
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

    # manually copy bashrc since its the only dotfile we need
    cp "$src_dir/.bashrc" "$INSTALL_DIR/.bashrc"

    # Ensure main script is executable
    chmod +x "$INSTALLER_TARGET"
}

# CREATE SYSTEMD SERVICE
create_systemd_service() {
    echo -e "${GREEN_BOLD} ==> Creating systemd auto-resume service...${RESET}"

    REALUSER="${SUDO_USER:-$USER}"
    USER_UID=$(id -u "$REALUSER")

    cat <<EOF >/etc/systemd/system/archtimize-login.service
[Unit]
Description=Archtimize Resume After User Login
After=user@${USER_UID}.service
PartOf=user@${USER_UID}.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/archtimize/archtimize.sh
RemainAfterExit=yes
StandardOutput=tty
StandardError=tty
TTYPath=/dev/tty1

[Install]
WantedBy=user@${USER_UID}.service
EOF

    systemctl daemon-reload
    systemctl enable archtimize-login.service
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

# SNAPPER SETUP
setup_snapper() {
    echo -e "${GREEN_BOLD} ==> Getting filesystem type...${RESET}"
    FILESYSTEM_TYPE=$(findmnt -n -o FSTYPE "/")

    echo -e "${GREEN_BOLD} ==> Filesystem type is ${FILESYSTEM_TYPE}...${RESET}"

    if [[ $FILESYSTEM_TYPE == "btrfs" ]]; then
        echo -e "${GREEN_BOLD} ==> Checking if snapper needs to be set up...${RESET}"
        if ! pacman -Q "snapper" &> /dev/null; then
            echo -e "${GREEN_BOLD} ==> Installing snapper...${RESET}"
            pacman -S --noconfirm --needed snapper

            echo -e "${GREEN_BOLD} ==> Creating snapper configuration for root and home...${RESET}"
            snapper -c root create-config /
            snapper -c home create-config /home
        fi

        echo -e "${GREEN_BOLD} ==> Creating snapper backup of root and home...${RESET}"
        snapper -c root create --description "Pre Archtimize Backup"
        snapper -c home create --description "Pre Archtimize Backup"
    fi
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

# SAFE CHWD
safe_chwd_driver_setup() {
    echo -e "${GREEN_BOLD} ==> Preparing safe graphics driver setup (chwd)...${RESET}"

    # 1. Make sure chwd is installed
    echo -e "${GREEN_BOLD} ==> Verifying installation of chwd...${RESET}"
    if ! command -v chwd &>/dev/null; then
        echo -e "${GREEN_BOLD} ==> Installing chwd hardware detection tool...${RESET}"
        pacman -S --noconfirm --needed chwd
    fi

    # 2. Check that linux-cachyos + headers are installed
    echo -e "${GREEN_BOLD} ==> Verifying installation of kernel and headers...${RESET}"
    if ! pacman -Q linux-cachyos linux-cachyos-headers &>/dev/null; then
        echo -e "\e[1;31m[ERROR]\e[0m linux-cachyos and linux-cachyos-headers are not both installed."
        echo "       Archtimize will NOT run chwd -a to avoid broken driver modules."
        echo "       Fix: pacman -S linux-cachyos linux-cachyos-headers, reboot, Archtimize will start again automatically after logging in.${RESET}"
        exit 1
    fi

    # 3. Check that the *running* kernel is actually the CachyOS one
    echo -e "${GREEN_BOLD} ==> Verifying CachyOS kernel is running...${RESET}"
    current_kernel="$(uname -r)"
    if ! grep -qi "cachyos" <<<"$current_kernel"; then
        echo -e "\e[1;31m[ERROR]\e[0m Currently running kernel is '$current_kernel' (not a CachyOS kernel)."
        echo "       If you just installed linux-cachyos, you must reboot into it before installing drivers."
        echo "       Fix: reboot, boot the linux-cachyos entry, Archtimize will start again automatically after logging in.${RESET}"
        exit 1
    fi

    # 4. Optional sanity check: versions of kernel vs headers match
    echo -e "${GREEN_BOLD} ==> Verfying versions of kernel and headers match...${RESET}"
    kver="$(pacman -Q linux-cachyos | awk '{print $2}')"
    hver="$(pacman -Q linux-cachyos-headers | awk '{print $2}')"
    if [[ "$kver" != "$hver" ]]; then
        echo -e "\e[1;31m[ERROR]\e[0m linux-cachyos ($kver) and linux-cachyos-headers ($hver) versions do not match."
        echo "       This can cause 'unknown module nvidia, nvidia_drm, ...' and broken initramfs."
        echo "       Fix: pacman -S linux-cachyos linux-cachyos-headers, reboot, Archtimize will start again automatically after logging in."
        exit 1
    fi

    echo -e "${GREEN_BOLD} ==> All pre-checks passed. Running chwd -a to install graphics drivers...${RESET}"
    chwd -a
}

# WAIT FOR INTERNET (for cases where networkmanager isnt completely started.)
wait_for_internet() {
    echo -e "${GREEN_BOLD} ==> Waiting for internet connection...${RESET}"

    # Try up to 20 times (~20 seconds)
    for i in {1..20}; do
        if ping -c1 archlinux.org &>/dev/null; then
            echo -e "${GREEN_BOLD} ==> Internet is online!${RESET}"
            return 0
        fi
        echo "   Still offline... retrying ($i/20)"
        sleep 1
    done

    echo -e "\e[1;31m[ERROR]\e[0m Internet not available after waiting."
    echo "Make sure your network is connected and rerun the installer."
    echo "To rerun, do: sudo ./usr/local/bin/archtimize/archtimize.sh"
    exit 1
}

# MKINITCPIO FOR CACHYOS KERNEL ONLY!
mkinitcpio_cachyos_only() {
    echo -e "${GREEN_BOLD} ==> Regenerating initramfs (linux-cachyos only)...${RESET}"
    if ! mkinitcpio -p linux-cachyos; then
        echo -e "\e[1;33m[WARNING]\e[0m mkinitcpio preset rebuild failed, retrying safe mode..."
        mkinitcpio -k /boot/vmlinuz-linux-cachyos -g /boot/initramfs-linux-cachyos.img --nohooks modconf || true
    fi
}

# Fix the applications on kde task manager (get rid of discover app)
fix_kde_task_manager() {
(
    set +e

    CONFIG_FILE="$REALUSER_HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

    mkdir -p "$(dirname "$CONFIG_FILE")" || true
    touch "$CONFIG_FILE" || true

    printf "\n[Containments][3][Applets][6][Configuration][General]\n" >> "$CONFIG_FILE" || true
    printf "launchers=applications:systemsettings.desktop,preferred://filemanager,preferred://browser,applications:org.kde.konsole.desktop\n" >> "$CONFIG_FILE" || true

) || true
}

# CLEANUP
create_cleanup_service() {
    cat <<EOF >/etc/systemd/system/archtimize-cleanup.service
[Unit]
Description=Archtimize Final Cleanup After Installer Completes
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c '
    echo -e "==> Cleaning installer files...";
    rm -rf /usr/local/bin/archtimize;
    rm -rf /var/lib/archtimize;
    rm -rf /home/*/.config/archtimize 2>/dev/null || true;
    rm -rf /CachyOS-Settings 2>/dev/null || true;
    rm -rf /cachyos-repo* 2>/dev/null || true;
    echo -e "==> Cleaning archtimize on reboot service...";
    systemctl disable archtimize-login.service;
    rm /etc/systemd/system/archtimize-login.service;
'
ExecStartPost=/usr/bin/bash -c '
    echo -e "==> Removing cleanup service...";
    rm -f /etc/systemd/system/archtimize-cleanup.service;
    systemctl daemon-reload;
'

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable archtimize-cleanup.service
}

# STAGE 1
stage_1() {
    echo -e "${GREEN_BOLD} ==> Stage 1: Snapper, Kernel, Repos, Password-Requiring Packages...${RESET}"
    echo -e "${GREEN_BOLD} ==> Starting in 3 seconds...${RESET}"
    sleep 3

    setup_snapper

    echo -e "${GREEN_BOLD} ==> Installing CachyOS repositories...${RESET}"
    sudo -u "$REALUSER" curl -L https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz
    sudo -u "$REALUSER" tar xvf cachyos-repo.tar.xz
    cd cachyos-repo
    ./cachyos-repo.sh
    cd ..

    echo -e "${GREEN_BOLD} ==> Installing cachyos-rate-mirrors...${RESET}"
    pacman -S cachyos-rate-mirrors

    echo -e "${GREEN_BOLD} ==> Ranking mirrors and updating system...${RESET}"
    cachyos-rate-mirrors
    pacman -Syu --noconfirm

    echo -e "${GREEN_BOLD} ==> Installing CachyOS kernel...${RESET}"
    pacman -Syu --noconfirm linux-cachyos linux-cachyos-headers

    echo -e "${GREEN_BOLD} ==> Installing yay...${RESET}"
    pacman -S --needed --noconfirm git base-devel
    sudo -u "$REALUSER" git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    sudo -u "$REALUSER" makepkg -si --noconfirm
    cd ..
    rm -rf yay-bin

    echo -e "${GREEN_BOLD} ==> Installing Lune...${RESET}"
    sudo -u "$REALUSER" yay -S --noconfirm lune-bin

    if ! pacman -Q "networkmanager" &> /dev/null; then
        echo -e "${GREEN_BOLD} ==> Installing NetworkManager...${RESET}"
        pacman -S --noconfirm networkmanager
        systemctl enable NetworkManager.service
    fi

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

stage_2() {
    cd /usr/local/bin/archtimize

    wait_for_internet

    echo -e "${GREEN_BOLD} ==> Stage 2: Headers and Drivers Setup${RESET}"
    echo -e "${GREEN_BOLD} ==> Starting in 3 seconds...${RESET}"
    sleep 1
    echo -e "${GREEN_BOLD} ==> 2 seconds...${RESET}"
    sleep 1
    echo -e "${GREEN_BOLD} ==> 1 second...${RESET}"
    sleep 1

    safe_chwd_driver_setup

    echo -e "${GREEN_BOLD} ==> Updating grub...${RESET}"
    grub-mkconfig -o /boot/grub/grub.cfg

    echo -e "${GREEN_BOLD} ==> Stage 2 complete — rebooting in 3 seconds...${RESET}"
    set_stage 3
    sleep 3
    reboot
}

# STAGE 3
stage_3() {
    cd /usr/local/bin/archtimize

    wait_for_internet

    echo -e "${GREEN_BOLD} ==> Stage 3: GUI + Packages + CachyOS Settings${RESET}"
    echo -e "${GREEN_BOLD} ==> Starting in 3 seconds...${RESET}"
    sleep 1
    echo -e "${GREEN_BOLD} ==> 2 seconds...${RESET}"
    sleep 1
    echo -e "${GREEN_BOLD} ==> 1 second...${RESET}"
    sleep 1

    echo -e "${GREEN_BOLD} ==> Installing plasma, wayland and sddm...${RESET}"
    pacman -S --noconfirm plasma-desktop sddm
    systemctl enable sddm

    echo -e "${GREEN_BOLD} ==> Making some choices for you...${RESET}"
    pacman -S --noconfirm konsole kate spectacle ark gwenview kde-system plasma-nm plasma-systemmonitor firefox nano

    # incase your installer broke and cachyos-settings was already installed
    if [ ! -d CachyOS-Settings ]; then
        echo -e "${GREEN_BOLD} ==> Cloning CachyOS settings...${RESET}"
        sudo -u "$REALUSER" git clone https://github.com/CachyOS/CachyOS-Settings
    fi

    # remove cachy's dns settings
    rm -rf CachyOS-Settings/usr/lib/NetworkManager

    echo -e "${GREEN_BOLD} ==> Running CachyOS settings installer...${RESET}"
    cd install-cachyos-settings
    lune run main.luau
    cd ..

    echo -e "${GREEN_BOLD} ==> Installing custom .bashrc...${RESET}"
    if [ -f ~/.bashrc ]; then
        mv ~/.bashrc ~/.bashrc_backup
    fi
    mv ./.bashrc ~/.bashrc

    echo -e "${GREEN_BOLD} ==> Making some changes to kde task manager...${RESET}"
    fix_kde_task_manager

    echo -e "${GREEN_BOLD} ==> Installing self-deleting cleanup service...${RESET}"
    create_cleanup_service

    echo -e "${GREEN_BOLD} ==> Regenerating initramfs...${RESET}"
    mkinitcpio_cachyos_only -P

    echo -e "${GREEN_BOLD} ==> Updating grub...${RESET}"
    grub-mkconfig -o /boot/grub/grub.cfg

    echo -e "${GREEN_BOLD} ==> Installation complete, cleanup will finish after next reboot. Rebooting into KDE in 3 seconds!...${RESET}"
    set_stage done
    sleep 3
    reboot
}

# MAIN

archtimize_states_exists="0"

if [[ -d "/var/lib/archtimize" ]]; then
    if [[ -f "$STATE_FILE" ]]; then
        archtimize_states_exists="1"
    fi
fi

if [[ "$archtimize_states_exists" == "0" || $(get_stage) == "1" ]]; then
    copy_installer_dir
    create_systemd_service
    create_state_file
fi

case "$(get_stage)" in
    1) stage_1 ;;
    2) stage_2 ;;
    3) stage_3 ;;
    done)
        echo -e "${GREEN_BOLD}Archtimize installation is complete.${RESET}"
        ;;
    *)
        echo "Unknown installer state."
        exit 1
        ;;
esac