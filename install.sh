#!/bin/bash
set -euo pipefail


###############################################################################
# PREPARATION FOR INSTALL
# 1. Convert arguments to variables
# 2. Prompt the user for basic safety
# 3. Setup Wi-Fi and timezone
# 4. Check if this is a repeat attempt and unmount affected partitions
###############################################################################

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

read -rp $'\e[31mThis script will wipe everything and reformat. Type "IK" to continue: \e[0m' confirm
if [[ "$confirm" != "IK" ]]; then
  echo -e "\e[31mAborting.\e[0m"
  exit 1
fi

if ! ping -c 1 archlinux.org &>/dev/null; then
    iwctl --passphrase $WIFI_PASS station $WIFI_INT connect $WIFI_NAME
fi

timedatectl set-timezone America/New_York

if mountpoint -q /mnt; then
    umount -R /mnt
    cryptsetup close cryptroot
fi


###############################################################################
# DISK CONFIGURATION
# 1. Format the esp partition with FAT32
# 2. Create a hardened LUKS-encrypted container on the root partition
# 3. Format the container with Btrfs
#    - No subvolumes because I just don't like them and I don't use snapshots
# 4. Mount the formatted partitions with optimized settings
#    - Defaults are already optimized and noatime is free performance
#    - `compress-force=zstd:3` shrinks my base install from 18GB to 4.5GB!!
###############################################################################

mkfs.fat -F 32 "/dev/${BOOT_PART}"

echo $USER_PASS | cryptsetup -q luksFormat -h sha512 -i 10000 -s 512 "/dev/${ROOT_PART}"
echo $USER_PASS | cryptsetup open "/dev/${ROOT_PART}" cryptroot

mkfs.btrfs -f /dev/mapper/cryptroot

mount -o defaults,noatime,compress-force=zstd:3 /dev/mapper/cryptroot /mnt
mkdir -p /mnt/boot
mount -o defaults,noatime "/dev/${BOOT_PART}" /mnt/boot


###############################################################################
# BOOTSTRAPPING THE NEW SYSTEM
# 1. Optimize pacman DL speed with an updated mirrorlist parallel downloads
# 2. Sync the package database and keyring as it can be dated in the live ISO
# 3. Install the base system and low level components into the new install
# 4. Generate the filesystem table
# 5. Stage my dotfiles into the new install before chrooting into it
###############################################################################

reflector -c US -p https -a 12 -l 20 -f 5 --sort rate --save /etc/pacman.d/mirrorlist
sed -i 's/^#\(ParallelDownloads = 5\)/\1/' /etc/pacman.conf

pacman -Sy
pacman -S --noconfirm archlinux-keyring

pacstrap -K /mnt base base-devel intel-ucode linux linux-firmware nvidia sbctl

genfstab -U /mnt >> /mnt/etc/fstab

mkdir -p /mnt/dottmp
cp $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bash/.bashrc /mnt/dottmp
cp $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/services/custom.service /mnt/dottmp
cp -r $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hypr /mnt/dottmp/hypr
arch-chroot /mnt /bin/bash <<CHROOT


###############################################################################
# SETTING UP THE NEW SYSTEM
# 1. Synchronize the system and hardware clocks with my timezone
# 2. Make resolv.conf a stub so that its managed by systemd-resolved
# 3. Generate the locale
# 4. Set the hostname to something generic
# 5. Set the root password then disable root for extra security
# 6. Create the new user with a generic name
# 7. Symlink .cache to tmp to wipe it on shutdown
# 8. Move staged dotfiles from earlier into their proper locations
###############################################################################

ln -sf "/usr/share/zoneinfo/America/New_York" /etc/localtime
hwclock --systohc
timedatectl set-ntp true

rm /etc/resolv.conf
ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo archlinux > /etc/hostname

echo "root:$USER_PASS" | chpasswd
passwd --lock root

useradd -m user
echo "user:$USER_PASS" | chpasswd

ln -s /tmp /home/user/.cache

mv /dottmp/.bashrc /home/user
mv /dottmp/custom.service /etc/systemd/system/
mv /dottmp/hypr /home/user/.config
rmdir /dottmp


###############################################################################
# SETTING UP THE BOOT PROCESS
# 1. Setup kernel options, including NVIDIA ones for gaming performance
# 2. Create a UKI preset so that I don't need bootloader overhead
#    - UKI's securitywise synergize well with Secure Boot and disk encryption,
#      this is currently the only way to prevent initramfs tampering
# 3. Add encrypt to mkinitcpio hooks and regenerate the initramfs
# 4. Setup secure boot keys and sign the UKI
###############################################################################

mkdir -p /etc/kernel
echo "cryptdevice=UUID=$(blkid -s UUID -o value /dev/"${ROOT_PART}"):cryptroot root=/dev/mapper/cryptroot rw nvidia.NVreg_EnableGpuFirmware=0 nvidia.NVreg_UsePageAttributeTable=1" > /etc/kernel/cmdline

cat <<EOF > /etc/mkinitcpio.d/linux.preset
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"
PRESETS=('default')

default_uki="/boot/EFI/BOOT/BOOTX64.EFI"
default_options="--cmdline /etc/kernel/cmdline"
EOF

sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/' /etc/mkinitcpio.conf
mkdir -p /boot/EFI/BOOT
mkinitcpio -p linux

if sbctl status | grep -q "Setup Mode:     ✘ Enabled"; then
    sbctl create-keys
    sbctl enroll-keys --microsoft
    sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI
fi


###############################################################################
# SETTING UP THE USER PACKAGES
# 1. Temporarily allow the user to use passwordless sudo for yay
# 2. Install yay and then my preferred packages
# 3. Annihilate the orphans and build files
# 4. Set depended-upon packages to dependency status
# 5. Revoke passwordless sudo form the user for security
###############################################################################

echo "user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/00_user
chmod 440 /etc/sudoers.d/00_user

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

pacman -Rcns --noconfirm $(pacman -Qttdq)
pacman -Yc --noconfirm
rm -rf /home/user/.cargo
rm -rf /home/user/.config/go

pacman -D --asdeps git noto-fonts pipewire-jack

echo "user ALL=(ALL) ALL" > /etc/sudoers.d/00_user
chmod 440 /etc/sudoers.d/00_user


###############################################################################
# SETTING CONFIGURATIONS
# 1. Set a .bash_profile to automatically start hyprland on tty1 sign in
# 2. Set getty to autologin the user for convenience
# 3. Configure PAM no-password login because there's little security loss
# 4. Fix ~/.pulse-cookie bug with Steam
# 5. Disable coredumps as they're HUGE and I don't care about them
# 6. Configure my hardened NextDNS profile via resolved
# 7. Configure Mullvad VPN with hardened settings
###############################################################################

echo "if [[ -z \$DISPLAY ]] && [[ \$(tty) = /dev/tty1 ]]; then" >> /home/user/.bash_profile
echo "    exec hyprland" >> /home/user/.bash_profile
echo "fi" >> /home/user/.bash_profile

mkdir -p /etc/systemd/system/getty@tty1.service.d
echo "[Service]" > /etc/systemd/system/getty@tty1.service.d/override.conf
echo "ExecStart=" >> /etc/systemd/system/getty@tty1.service.d/override.conf
echo "ExecStart=-/sbin/agetty -o '-- \\\\u' --autologin user --noreset --noclear - \${TERM}" >> /etc/systemd/system/getty@tty1.service.d/override.conf

sed -i '/pam_nologin.so/i auth       sufficient   pam_succeed_if.so user = user' /etc/pam.d/login

sed -i 's|^; cookie-file =.*|cookie-file = ~/.config/pulse/cookie|' /etc/pulse/client.conf

sed -i 's/^#Storage=.*/Storage=none/' /etc/systemd/coredump.conf
sed -i 's/^#ProcessSizeMax=.*/ProcessSizeMax=0/' /etc/systemd/coredump.conf

sed -i "s|^#DNS=.*|DNS=45.90.28.0#${NEXTDNS}.dns.nextdns.io|" /etc/systemd/resolved.conf
sed -i "/^DNS=45.90.28.0#/a DNS=2a07:a8c0::#${NEXTDNS}.dns.nextdns.io\nDNS=45.90.30.0#${NEXTDNS}.dns.nextdns.io\nDNS=2a07:a8c1::#${NEXTDNS}.dns.nextdns.io" /etc/systemd/resolved.conf
sed -i 's/^#FallbackDNS=.*/FallbackDNS=/' /etc/systemd/resolved.conf
sed -i 's/^#Domains=.*/Domains=~/' /etc/systemd/resolved.conf
sed -i 's/^#DNSOverTLS=.*/DNSOverTLS=yes/' /etc/systemd/resolved.conf

mullvad account login $MULLVAD
mullvad relay set location any
mullvad auto-connect set on
mullvad lockdown-mode set on


###############################################################################
# WRAPPING UP THE INSTALL
# 1. Ensure the user owns their own home
# 2. Disable NVIDA services irrelevant to my desktop
# 3. Enable filesystem maintainence timers
# 4. Enable essential networking services
# 5. Exit chroot, unmount partitions, and reboot into the new install
###############################################################################

chown -R user:user /home/user

systemctl disable nvidia-hibernate
systemctl disable nvidia-resume
systemctl disable nvidia-suspend

systemctl enable fstrim.timer
systemctl enable btrfs-scrub@-.timer

systemctl enable custom
systemctl enable iwd
systemctl enable iptables
systemctl enable mullvad-daemon
systemctl enable systemd-resolved
systemctl enable systemd-timesyncd

CHROOT
umount -R /mnt
cryptsetup close cryptroot
reboot