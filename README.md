Optimize your arch install with a script.

**<ins>Run this on a fresh, vanilla arch install.</ins>**
*This script will install custom drivers, therefore you cannot have previously installed graphics drivers*
*This is meant to be used after a minimal "archinstall" installation"

Prerequisites
- Git must be installed
- No previously installed graphics drivers
- No previously installed graphical environment or window manager
- Btrfs preferred (if using archinstall, make sure use subvolumes default layout and compression is ON)
- Swap on zram preferred
- Grub bootloader

What does this install?
- CachyOS optimized repositories - [wiki](https://wiki.cachyos.org/features/optimized_repos/)
- CachyOS linux kernel - [repo](https://github.com/CachyOS/linux-cachyos) [wiki](https://wiki.cachyos.org/features/kernel/)
- CachyOS settings - [repo](https://github.com/CachyOS/CachyOS-Settings) [wiki](https://wiki.cachyos.org/features/optimized_repos/)
- CachyOS NVIDIA Drivers
- Wayland and KDE Plasma (plasma-desktop)
- Minimal desktop KDE packages (dolphin, konsole, kate, spectacle, ark, gwenview)
- KDE-System packages+ plasma-nm, plasma-systemmonitor
- Some basic packages: firefox, nano
- If you have Btrfs, snapper is installed and backups are automatically created before running archtimize.
- NetworkManager if you do not already have it
- A custom bashrc with nice colors and functions.

Installation
- Clone this repository. git clone https://github.com/beters02/archtimize
- cd archtimize
- sudo ./archtimize.sh

Post Installation
- Add game-performance to your launch options for all of your games
- Take a look at recommended packages

Recommended Packages
- Vesktop (A standalone Electron-based Discord app with Vencord & improved Linux support)
- cachyos-gaming-meta [repo](https://github.com/CachyOS/CachyOS-PKGBUILDS/blob/master/cachyos-gaming-meta/PKGBUILD)
- cachyos-gaming-applications [repo](https://github.com/CachyOS/CachyOS-PKGBUILDS/blob/master/cachyos-gaming-applications/PKGBUILD)

Coming Soon:
- Tutorial on how to enable secure boot support
- Support for systemd-boot
- "How does this optimize my arch install" information
- "Restore from backup with btrfs" information
- Potentially an ISO / seperate distro
