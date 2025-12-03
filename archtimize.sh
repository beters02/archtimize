#!/bin/bash
set -euo pipefail

add_modules_to_mkinitcpio() {
    echo "==> Adding Nvidia + CRC32C modules to mkinitcpio.conf..."

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

echo "==> Installing CachyOS repositories..."
curl -L https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz
tar xvf cachyos-repo.tar.xz
cd cachyos-repo
sudo ./cachyos-repo.sh
cd ..

echo "==> Syncing pacman..."
sudo pacman -Syyu --noconfirm

echo "==> Installing CachyOS Bore kernel..."
sudo pacman -S --noconfirm linux-cachyos-bore linux-cachyos-bore-headers

echo "==> Installing git..."
sudo pacman -S --noconfirm git

echo "==> Cloning CachyOS settings..."
git clone https://github.com/CachyOS/CachyOS-Settings

echo "==> Installing yay..."
sudo pacman -S --needed --noconfirm git base-devel
git clone https://aur.archlinux.org/yay-bin.git
cd yay-bin
makepkg -si --noconfirm
cd ..
rm -rf yay-bin

echo "==> Installing Lune from AUR..."
yay -S --noconfirm lune

echo "==> Running CachyOS settings installer with Lune..."
cd install-cachyos-settings
lune run main.luau
cd ..

echo "==> Detecting hardware & installing Nvidia drivers..."
sudo chwd -a pci nonfree 0300

echo "==> Updating mkinitcpio.conf..."
add_modules_to_mkinitcpio

echo "==> Regenerating initramfs..."
sudo mkinitcpio -P

echo "==> Installing Plasma, Wayland, and SDDM..."
sudo pacman -S --noconfirm plasma-wayland-session plasma sddm
sudo systemctl enable sddm

echo "==> Installation finished. Rebooting..."
reboot