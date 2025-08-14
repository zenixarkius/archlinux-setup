#!/bin/bash
set -euo pipefail


#################################################################################
# PREPARATION FOR INSTALL
#################################################################################

### Convert arguments to variables
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -b) BOOT_PART="$2"; shift ;;
        -r) ROOT_PART="$2"; shift ;;
        -p) USER_PASS="$2"; shift ;;
        -n) NEXTDNS="$2"; shift ;;
        -m) MULLVAD="$2"; shift ;;
        -wi) WIFI_INT="$2"; shift ;;
        -wn) WIFI_NAME="$2"; shift ;;
        -wp) WIFI_PASS="$2"; shift ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
    shift
done

### Prompt the user for basic safety
read -rp $'\e[31mThis script will wipe everything and reformat. Type "IK" to continue: \e[0m' confirm
if [[ "$confirm" != "IK" ]]; then
  echo -e "\e[31mAborting.\e[0m"
  exit 1
fi

### Check if this is a repeat attempt and unmount affected partitions
if mountpoint -q /mnt; then
    umount -R /mnt
    cryptsetup close cryptroot
fi

### Setup Wi-Fi and timezone
if ! ping -c 1 archlinux.org &>/dev/null; then
    iwctl --passphrase $WIFI_PASS station $WIFI_INT connect $WIFI_NAME
fi
timedatectl set-timezone America/New_York


#################################################################################
# DISK CONFIGURATION
#################################################################################

### Format the esp partition with FAT32
mkfs.fat -F 32 "/dev/${BOOT_PART}"

### Create a hardened LUKS-encrypted container on the root partition
echo $USER_PASS | cryptsetup -q luksFormat -h sha512 -i 10000 -s 512 "/dev/${ROOT_PART}"
echo $USER_PASS | cryptsetup open "/dev/${ROOT_PART}" cryptroot

### Format the container with Btrfs
###     - No subvolumes because I just don't like them and I don't use snapshots
mkfs.btrfs -f /dev/mapper/cryptroot

### Mount the formatted partitions with optimized settings
###     - Defaults are already optimized and noatime is free performance
###     - `compress-force=zstd:3` shrinks my base install from 18GB to 4.5GB!!
mount -o defaults,noatime,compress-force=zstd:3 /dev/mapper/cryptroot /mnt
mkdir -p /mnt/boot
mount -o defaults,noatime "/dev/${BOOT_PART}" /mnt/boot


#################################################################################
# BOOTSTRAPPING THE NEW SYSTEM
#################################################################################

### Optimize pacman DL speed with an updated mirrorlist parallel downloads
reflector -c US -p https -a 12 -l 20 -f 5 --sort rate --save /etc/pacman.d/mirrorlist
sed -i 's/^#\(ParallelDownloads = 5\)/\1/' /etc/pacman.conf

### Sync the package database and keyring as it can be dated in the live ISO
pacman -Sy
pacman -S --noconfirm archlinux-keyring

### Install the base system and low level components into the new install
pacstrap -K /mnt base base-devel intel-ucode linux linux-firmware nvidia sbctl

### Generate the filesystem table
genfstab -U /mnt >> /mnt/etc/fstab

### Stage my dotfiles into the new install to be moved later
mkdir -p /mnt/dottmp
cp -r $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd) /mnt/dottmp

### Change root to the new install
arch-chroot /mnt /bin/bash <<CHROOT


#################################################################################
# SETTING UP THE NEW SYSTEM
#################################################################################

### Synchronize the system and hardware clocks with my timezone
ln -sf "/usr/share/zoneinfo/America/New_York" /etc/localtime
hwclock --systohc
timedatectl set-ntp true

### Make resolv.conf managed by systemd-resolved
rm /etc/resolv.conf
ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

### Generate the locale
sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

### Set the hostname to something generic
echo archlinux > /etc/hostname

### Set the root password then disable root for extra security
echo "root:$USER_PASS" | chpasswd
passwd --lock root

### Create the new user with a generic name
useradd -m user
echo "user:$USER_PASS" | chpasswd

### Symlink .cache to tmp to wipe it on shutdown
ln -s /tmp /home/user/.cache

#################################################################################
# SETTING UP THE BOOT PROCESS
#################################################################################

### Setup kernel options, including NVIDIA ones for gaming performance
mkdir -p /etc/kernel
echo "cryptdevice=UUID=$(blkid -s UUID -o value /dev/"${ROOT_PART}"):cryptroot root=/dev/mapper/cryptroot rw nvidia.NVreg_EnableGpuFirmware=0 nvidia.NVreg_UsePageAttributeTable=1" > /etc/kernel/cmdline

### Create a UKI preset so that I don't need bootloader overhead
###     - UKI's securitywise synergize well with Secure Boot and disk encryption,
###       this is currently the only way to prevent initramfs tampering
cat <<UKI > /etc/mkinitcpio.d/linux.preset
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"
PRESETS=('default')

default_uki="/boot/EFI/BOOT/BOOTX64.EFI"
default_options="--cmdline /etc/kernel/cmdline"
UKI

## Add encrypt to mkinitcpio hooks and regenerate the initramfs
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/' /etc/mkinitcpio.conf
mkdir -p /boot/EFI/BOOT
mkinitcpio -p linux

### Setup secure boot keys and sign the UKI
if sbctl status | grep -q "Setup Mode:     ✘ Enabled"; then
    sbctl create-keys
    sbctl enroll-keys --microsoft
    sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI
fi


#################################################################################
# SETTING UP THE USER PACKAGES
#################################################################################

### Temporarily allow the user to use passwordless sudo for yay
echo "user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/00_user
chmod 440 /etc/sudoers.d/00_user

### Install yay and then my preferred packages
pacman -S --noconfirm --needed git
git clone https://aur.archlinux.org/yay.git /tmp/yay
runuser -l user -c 'cd /tmp/yay && makepkg -si --noconfirm'
runuser -l user -c 'yay -S --noconfirm --needed \
btrfs-progs \
hyprland \
hyprpaper \
hyprshot \
iwd \
keepassxc \
librewolf-bin \
mullvad-vpn-cli \
noto-fonts \
openrgb \
pipewire-jack \
pipewire-pulse \
python-nvidia-ml-py \
signal-desktop \
vscodium-bin'

### Annihilate the orphans and build files
pacman -Rcns --noconfirm $(pacman -Qttdq)
pacman -Yc --noconfirm
rm -rf /home/user/.cargo
rm -rf /home/user/.config/go

### Set depended-upon packages to dependency status
pacman -D --asdeps git noto-fonts pipewire-jack

### Revoke passwordless sudo form the user for security
echo "user ALL=(ALL) ALL" > /etc/sudoers.d/00_user
chmod 440 /etc/sudoers.d/00_user


#################################################################################
# SETTING CONFIGURATIONS
#################################################################################

### Setup dotfiles that were staged earlier
mkdir -p /home/user/.librewolf/user/chrome
git clone https://github.com/rafaelmardojai/firefox-gnome-theme.git /tmp/fgt
mv /tmp/fgt/theme /home/user/.librewolf/user/chrome
mv /tmp/fgt/userChrome.css /home/user/.librewolf/user/chrome
mv /dottmp/librewolf/user.js /home/user/.librewolf/user
mv /dottmp/bash/.bashrc /home/user
mv /dottmp/services/custom.service /etc/systemd/system/
mv /dottmp/hypr /home/user/.config
rm -rf /dottmp

### Set a .bash_profile to automatically start hyprland on tty1 sign in
echo "if [[ -z \$DISPLAY ]] && [[ \$(tty) = /dev/tty1 ]]; then" >> /home/user/.bash_profile
echo "    exec hyprland" >> /home/user/.bash_profile
echo "fi" >> /home/user/.bash_profile

### Set getty to autologin the user for convenience
mkdir -p /etc/systemd/system/getty@tty1.service.d
echo "[Service]" > /etc/systemd/system/getty@tty1.service.d/override.conf
echo "ExecStart=" >> /etc/systemd/system/getty@tty1.service.d/override.conf
echo "ExecStart=-/sbin/agetty -o '-- \\\\u' --autologin user --noreset --noclear - \${TERM}" >> /etc/systemd/system/getty@tty1.service.d/override.conf

### Configure PAM no-password login because there's little security loss for extra convenience
sed -i '/pam_nologin.so/i auth       sufficient   pam_succeed_if.so user = user' /etc/pam.d/login

### Fix ~/.pulse-cookie bug with Steam
sed -i 's|^; cookie-file =.*|cookie-file = /home/user/.config/pulse/cookie|' /etc/pulse/client.conf

### Disable coredumps as they're HUGE and I don't care about them
sed -i 's/^#Storage=.*/Storage=none/' /etc/systemd/coredump.conf
sed -i 's/^#ProcessSizeMax=.*/ProcessSizeMax=0/' /etc/systemd/coredump.conf

### Configure my hardened NextDNS profile via resolved
sed -i "s|^#DNS=.*|DNS=45.90.28.0#${NEXTDNS}.dns.nextdns.io|" /etc/systemd/resolved.conf
sed -i "/^DNS=45.90.28.0#/a DNS=2a07:a8c0::#${NEXTDNS}.dns.nextdns.io\nDNS=45.90.30.0#${NEXTDNS}.dns.nextdns.io\nDNS=2a07:a8c1::#${NEXTDNS}.dns.nextdns.io" /etc/systemd/resolved.conf
sed -i 's/^#FallbackDNS=.*/FallbackDNS=/' /etc/systemd/resolved.conf
sed -i 's/^#Domains=.*/Domains=~/' /etc/systemd/resolved.conf
sed -i 's/^#DNSOverTLS=.*/DNSOverTLS=yes/' /etc/systemd/resolved.conf

### Configure Mullvad VPN with hardened settings
mullvad account login $MULLVAD
mullvad relay set location any
mullvad auto-connect set on
mullvad lockdown-mode set on


#################################################################################
# WRAPPING UP THE INSTALL
#################################################################################

### Ensure the user owns their own home
chown -R user:user /home/user

### Disable NVIDIA services irrelevant to my desktop
systemctl disable nvidia-hibernate
systemctl disable nvidia-resume
systemctl disable nvidia-suspend

### Enable filesystem maintainence timers
systemctl enable fstrim.timer
systemctl enable btrfs-scrub@-.timer

### Enable essential networking services
systemctl enable custom
systemctl enable iwd
systemctl enable iptables
systemctl enable mullvad-daemon
systemctl enable systemd-resolved
systemctl enable systemd-timesyncd

### Exit chroot, unmount partitions, and reboot into the new install
CHROOT
umount -R /mnt
cryptsetup close cryptroot
reboot