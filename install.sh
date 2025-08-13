#!/bin/bash
set -euo pipefail

########################################################
# 1. PREPARATION FOR INSTALL
########################################################

# --- Setup customized variables ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -b) BOOT_PART="$2"; shift ;;
        -r) ROOT_PART="$2"; shift ;;
        -u) USER_PASS="$2"; shift ;;
        -nd) NEXTDNS="$2"; shift ;;
        -mv) MULLVAD="$2"; shift ;;
        -gu) GIT_USER="$2"; shift ;;
        -gm) GIT_MAIL="$2"; shift ;;
        -gk) GIT_KEY="$2"; shift ;;
        -wi) WIFI_INT="$2"; shift ;;
        -wn) WIFI_NAME="$2"; shift ;;
        -wp) WIFI_PASS="$2"; shift ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
    shift
done

# --- Basic safety prompt ---
read -rp $'\e[31mThis script will wipe everything and reformat. Type "IK" to continue: \e[0m' confirm
if [[ "$confirm" != "IK" ]]; then
  echo -e "\e[31mAborting.\e[0m"
  exit 1
fi

# --- Check for mounted partitions to make repeated attempts less obnoxious ---
if mountpoint -q /mnt; then
    umount -R /mnt
    cryptsetup close cryptroot
fi

# --- Connect to the internet ---
if ! ping -c 1 archlinux.org &>/dev/null; then
    iwctl --passphrase $WIFI_PASS station $WIFI_INT connect $WIFI_NAME
fi

# --- Set the Live ISO timezone ---
timedatectl set-timezone America/New_York


########################################################
# 2. DISK CONFIGURATION
########################################################

# --- Format the boot partition with FAT32 ---
mkfs.fat -F 32 "/dev/${BOOT_PART}"

# --- Create a LUKS-encrypted container on the root partition and format it with Btrfs ---
echo $USER_PASS | cryptsetup -q luksFormat -h sha512 -i 5000 -s 512 "/dev/${ROOT_PART}"
echo $USER_PASS | cryptsetup open "/dev/${ROOT_PART}" cryptroot -
mkfs.btrfs -f /dev/mapper/cryptroot

# --- Mount the partitions with optimized filesystem settings
mount -o defaults,noatime,compress-force=zstd:3 /dev/mapper/cryptroot /mnt
mkdir -p /mnt/boot
mount -o defaults,noatime "/dev/${BOOT_PART}" /mnt/boot


########################################################
# 3. BOOTSTRAPPING THE NEW SYSTEM
########################################################

# --- Optimizing pacman download speed ---
reflector -c US -p https -a 12 -l 20 -f 5 --sort rate --save /etc/pacman.d/mirrorlist
sed -i 's/^#\(ParallelDownloads = 5\)/\1/' /etc/pacman.conf

# --- Sync the package database and keyring then pacstrap the system ---
pacman -Sy
pacman -S --noconfirm archlinux-keyring
pacstrap -K /mnt base base-devel btrfs-progs intel-ucode iwd linux linux-firmware nvidia pipewire-pulse sbctl

# --- Generate the fstab ---
genfstab -U /mnt >> /mnt/etc/fstab

# --- Prepare for chroot by staging dotfiles ---
mkdir -p /mnt/dottmp
cp $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dotfiles/.bashrc /mnt/dottmp
cp -r $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dotfiles/.config/hypr /mnt/dottmp/hypr
arch-chroot /mnt /bin/bash <<CHROOT


########################################################
# 4. SETTING UP THE NEW SYSTEM
########################################################

# --- Set up system clock ---
ln -sf "/usr/share/zoneinfo/America/New_York" /etc/localtime
hwclock --systohc
timedatectl set-ntp true

# --- Make resolv.conf managed by systemd-resolved ---
rm /etc/resolv.conf
ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# --- Generate locale ---
sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# --- Set the hostname ---
echo archlinux > /etc/hostname

# --- Set the root password and disable root for security ---
echo "root:$USER_PASS" | chpasswd
passwd --lock root

# --- Create the new user ---
useradd -m user
echo "user:$USER_PASS" | chpasswd

# --- Symlink .cache to tmp for cleanliness ---
ln -s /tmp /home/user/.cache

# --- Setup kernel options including NVIDIA ones for performance ---
mkdir -p /etc/kernel
echo "cryptdevice=UUID=$(blkid -s UUID -o value /dev/"${ROOT_PART}"):cryptroot root=/dev/mapper/cryptroot rw nvidia.NVreg_EnableGpuFirmware=0 nvidia.NVreg_UsePageAttributeTable=1" > /etc/kernel/cmdline

# --- Create a UKI preset so that 1. I dont need a bootloader and 2. because it synergizes securitywise with Secure Boot ---
cat <<EOF > /etc/mkinitcpio.d/linux.preset
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"
PRESETS=('default')

default_uki="/boot/EFI/BOOT/BOOTX64.EFI"
default_options="--cmdline /etc/kernel/cmdline"
EOF

# --- Add encrypt to mkinitcpio hooks and regenerate the initramfs ---
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)/' /etc/mkinitcpio.conf
mkdir -p /boot/EFI/BOOT
mkinitcpio -p linux

# --- Configure Secure Boot ---
if sbctl status | grep -q "Setup Mode:     ✘ Enabled"; then
    sbctl create-keys
    sbctl enroll-keys --microsoft
    sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI
fi

# --- Temporarily allow the user to use passwordless sudo for package installation ---
echo "user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/00_user
chmod 440 /etc/sudoers.d/00_user

# --- Install yay and my preferred packages ---
pacman -S --noconfirm --needed git
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
runuser -l user -c 'makepkg -si --noconfirm'
runuser -l user -c 'yay -S --noconfirm --needed hyprland hyprpaper hyprshot keepassxc librewolf-bin mullvad-vpn-cli noto-fonts openrgb pipewire-jack python-nvidia-ml-py vscodium-bin'

# --- Clean up orphans and build files and set depended-on packages to dep status ---
pacman -Rcns --noconfirm $(pacman -Qttdq)
pacman -Yc --noconfirm
pacman -D --asdeps git noto-fonts pipewire-jack
rm -rf /home/user/.cargo
rm -rf /home/user/.config/go

# --- Revoke passwordless sudo from the user for security ---
echo "user ALL=(ALL) ALL" > /etc/sudoers.d/00_user
chmod 440 /etc/sudoers.d/00_user


########################################################
# 5. DOTFILES AND CONFIGS
########################################################

# --- Move staged dotfiles into their proper locations ---
mv /dottmp/.bashrc /home/user
mv /dottmp/hypr /home/user/.config
rmdir /dottmp

# --- Create a bash profile to automatically start hyprland on sign in ---
cat <<'HYPR' > /home/user/.bash_profile
#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

if [[ -z \$DISPLAY ]] && [[ \$(tty) = /dev/tty1 ]]; then
  exec hyprland
fi
HYPR

# --- Configure to autologin the user for convenience ---
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<'GETTY' > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-- \\u' --autologin user --noreset --noclear - \${TERM}
GETTY

# --- Create my custom systemd service file---
cat <<CUSTOM > /etc/systemd/system/custom.service
[Unit]
Description=Setup NVIDIA overclocks, OpenRGB lighting, and fix my DNS resolver tug-of-war between resolved and Mullvad thanks to my barebones network stack.

[Service]
WorkingDirectory=/tmp
ExecStart=/bin/bash -c '\
/usr/bin/env python -c "from pynvml import *; nvmlInit(); myGPU = nvmlDeviceGetHandleByIndex(0); nvmlDeviceSetGpcClkVfOffset(myGPU, 210); nvmlDeviceSetMemClkVfOffset(myGPU, 3000)" && \
/usr/bin/openrgb --mode static --color 1f13d4 --brightness 100 && \
while ! resolvectl status wg0-mullvad | grep -q "DNS Domain:"; do sleep 0.5; done && \
/usr/bin/resolvectl domain wg0-mullvad "" \
'

[Install]
WantedBy=multi-user.target
CUSTOM

# --- Configure my preferred VSCodium environment ---
mkdir -p /home/user/.config/VSCodium/User
cat <<VSCODIUM > /home/user/.config/VSCodium/User/settings.json
{
    "window.menuBarVisibility": "toggle",
    "window.customTitleBarVisibility": "never",
    "window.titleBarStyle": "native",
    "workbench.activityBar.location": "hidden",
    "workbench.startupEditor": "none",
    "explorer.confirmDragAndDrop": false,
    "workbench.statusBar.visible": false,
    "git.enableSmartCommit": true,
    "editor.wordWrap": "on"
}
VSCODIUM

# --- Fix .pulse-cookie bug with Steam ---
sed -i 's|^; cookie-file =.*|cookie-file = ~/.config/pulse/cookie|' /etc/pulse/client.conf

# --- Disable coredumps as theyre HUGE and I don't care about them ---
sed -i 's/^#Storage=.*/Storage=none/' /etc/systemd/coredump.conf
sed -i 's/^#ProcessSizeMax=.*/ProcessSizeMax=0/' /etc/systemd/coredump.conf

# --- Configure my NextDNS profile via resolved ---
sed -i "s|^#DNS=.*|DNS=45.90.28.0#${NEXTDNS}.dns.nextdns.io|" /etc/systemd/resolved.conf
sed -i "/^DNS=45.90.28.0#/a DNS=2a07:a8c0::#${NEXTDNS}.dns.nextdns.io\nDNS=45.90.30.0#${NEXTDNS}.dns.nextdns.io\nDNS=2a07:a8c1::#${NEXTDNS}.dns.nextdns.io" /etc/systemd/resolved.conf
sed -i 's/^#FallbackDNS=.*/FallbackDNS=/' /etc/systemd/resolved.conf
sed -i 's/^#Domains=.*/Domains=~/' /etc/systemd/resolved.conf
sed -i 's/^#DNSOverTLS=.*/DNSOverTLS=yes/' /etc/systemd/resolved.conf

# --- Configure Mullvad VPN ---
mullvad account login $MULLVAD
mullvad relay set location any
mullvad auto-connect set on
mullvad lockdown-mode set on

# --- Configure Git ---
runuser -l user -c 'git config --global user.name "$GIT_USER"'
runuser -l user -c 'git config --global user.email "$GIT_MAIL"'
runuser -l user -c 'git config --global user.signingkey $GIT_KEY'
runuser -l user -c 'git config --global commit.gpgSign true'


########################################################
# 6. WRAPPING UP THE INSTALL
########################################################

# --- Ensure the user owns the files in their own home ---
chown -R user:user /home/user

# --- Disable useless NVIDIA laptop nonsense ---
systemctl disable nvidia-hibernate
systemctl disable nvidia-resume
systemctl disable nvidia-suspend

# --- Enable filesystem timers ---
systemctl enable fstrim.timer
systemctl enable btrfs-scrub@-.timer

# --- Enable essential services ---
systemctl enable custom
systemctl enable iwd
systemctl enable iptables
systemctl enable mullvad-daemon
systemctl enable systemd-resolved
systemctl enable systemd-timesyncd

# --- Exit and reboot into the new install ---
CHROOT
umount -R /mnt
cryptsetup close cryptroot
reboot