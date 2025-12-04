Optimize your arch install with a script.

**<ins>Run this on a fresh, vanilla arch install.</ins>**
*This script will install custom drivers, therefore you cannot have previously installed graphics drivers*

Prerequisites
- Git must be installed
- No previously installed graphics drivers
- No previously installed graphical environment or window manager
- Btrfs preferred
- Swap on zram
- Grub bootloader (support for systemd-boot coming soon)

What does this install?
- CachyOS optimized repositories - [wiki](https://wiki.cachyos.org/features/optimized_repos/)
- CachyOS linux kernel - [repo](https://github.com/CachyOS/linux-cachyos) [wiki](https://wiki.cachyos.org/features/kernel/)
- CachyOS settings - [repo](https://github.com/CachyOS/CachyOS-Settings) [wiki](https://wiki.cachyos.org/features/optimized_repos/)
- CachyOS NVIDIA Drivers
- Wayland and KDE Plasma (plasma-desktop)
- Minimal desktop KDE packages (dolphin, konsole, kate, spectacle, ark, gwenview)
- KDE-System packages
- Btrfs snapshot management packages: snapper
- Some basic packages: firefox, nano

How does this optimize my arch install?
- wip

Installation
- Clone this repository. git clone https://github.com/beters02/archtimize
- cd archtimize
- sudo ./archtimize.sh

Be sure you add game-performance to your launch options for all of your games to reap the benefits of the power profile optimizations!

Tutorial on how to enable secure boot support coming soon
