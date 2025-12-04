#!/bin/bash
set -euo pipefail

GREEN_BOLD="\e[1;32m"
RESET="\e[0m"

add_modules_to_mkinitcpio() {
    echo -e "${GREEN_BOLD} ==> Adding Nvidia + CRC32C modules to mkinitcpio.conf...${RESET}"

    MODULES_TO_ADD=("nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" "crc32c")

    # Ensure MODULES= exists
    if ! grep -q "^MODULES=" /etc/mkinitcpio.conf; then
        echo "MODULES=()" | sudo tee -a /etc/mkinitcpio.conf
    fi

    # Append modules safely
    for mod in "${MODULES_TO_ADD[@]}"; do
        if ! grep -q "$mod" /etc/mkinitcpio.conf; then
            sudo sed -i "s/^MODULES=(/MODULES=($mod /" /etc/mkinitcpio.conf
        fi
    done
}

echo -e "${GREEN_BOLD} ==> Installing CachyOS repositories...${RESET}"
curl -L https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz
tar xvf cachyos-repo.tar.xz
cd cachyos-repo
sudo ./cachyos-repo.sh
cd ..

echo -e "${GREEN_BOLD} ==> Syncing pacman...${RESET}"
sudo pacman -Syyu --noconfirm

echo -e "${GREEN_BOLD} ==> Installing CachyOS Bore kernel...${RESET}"
sudo pacman -S --noconfirm linux-cachyos-bore linux-cachyos-bore-headers

echo -e "${GREEN_BOLD} ==> Installing git...${RESET}"
sudo pacman -S --noconfirm git

echo -e "${GREEN_BOLD} ==> Cloning CachyOS settings...${RESET}"
git clone https://github.com/CachyOS/CachyOS-Settings

echo -e "${GREEN_BOLD} ==> Installing yay...${RESET}"
sudo pacman -S --needed --noconfirm git base-devel
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si --noconfirm
cd ..
rm -rf yay-bin

echo -e "${GREEN_BOLD} ==> Installing Lune from AUR...${RESET}"
yay -S --noconfirm lune-bin

echo -e "${GREEN_BOLD} ==> Running CachyOS settings installer with Lune...${RESET}"
cd install-cachyos-settings
lune run main.luau
cd ..

echo -e "${GREEN_BOLD} ==> Detecting hardware & installing Nvidia drivers...${RESET}"
sudo chwd -a pci nonfree 0300

echo -e "${GREEN_BOLD} ==> Updating mkinitcpio.conf...${RESET}"
add_modules_to_mkinitcpio

echo -e "${GREEN_BOLD} ==> Regenerating initramfs...${RESET}"
sudo mkinitcpio -P

echo -e "${GREEN_BOLD} ==> Installing Plasma, Wayland, and SDDM...${RESET}"
sudo pacman -S --noconfirm plasma-wayland-session plasma sddm
sudo systemctl enable sddm

echo -e "${GREEN_BOLD} ==> Making some choices for you...${RESET}"
sudo pacman -S --noconfirm konsole kate spectacle ark gwenview

echo -e "${GREEN_BOLD} ==> Some more choices...${RESET}"
sudo pacman -S --noconfirm kde-system

echo -e "${GREEN_BOLD} ==> Installing Basic Packages...${RESET}"
sudo pacman -S firefox

echo -e "${GREEN_BOLD} ==> Installation finished. Rebooting...${RESET}"
reboot