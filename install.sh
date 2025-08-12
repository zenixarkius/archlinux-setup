#!/bin/bash
set -euo pipefail

# ------ PREPARATION ------

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -b) part1="$2"; shift ;;
        -r) part2="$2"; shift ;;
        -p) upass="$2"; shift ;;
        -n) ndns="$2"; shift ;;
        -wi) wint="$2"; shift ;;
        -wn) wname="$2"; shift ;;
        -wp) wpass="$2"; shift ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
    shift
done

if mountpoint -q /mnt; then
    umount -R /mnt
    cryptsetup close cryptroot
fi

if ! ping -c 1 archlinux.org &>/dev/null; then
    iwctl --passphrase $wpass station $wint connect $wname
fi

timedatectl set-timezone America/New_York

read -rp $'\e[31mWipe everything and reformat? Type "YES" to continue: \e[0m' confirm
if [[ "$confirm" != "YES" ]]; then
  echo -e "\e[31mAborting.\e[0m"
  exit 1
fi


# ------ PARTITIONING ------

mkfs.fat -F 32 "/dev/${part1}"
echo $upass | cryptsetup -q luksFormat -h sha512 -i 5000 -s 512 "/dev/${part2}"
echo $upass | cryptsetup open "/dev/${part2}" cryptroot -
mkfs.btrfs -f /dev/mapper/cryptroot

mount -o defaults,noatime,compress-force=zstd:8 /dev/mapper/cryptroot /mnt
mkdir -p /mnt/boot
mount -o defaults,noatime "/dev/${part1}" /mnt/boot


# ------ INSTALLATION ------

reflector -c US -p https -a 12 -l 20 -f 5 --sort rate --save /etc/pacman.d/mirrorlist

sed -i 's/^#\(ParallelDownloads = 5\)/\1/' /etc/pacman.conf
pacman -Sy
pacman -S --noconfirm archlinux-keyring
pacstrap -K /mnt base base-devel btrfs-progs intel-ucode iwd linux linux-firmware nvidia pipewire-pulse sbctl

genfstab -U /mnt >> /mnt/etc/fstab

mkdir -p /mnt/dottmp
cp $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dotfiles/.bashrc /mnt/dottemp
cp -r $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dotfiles/.config/hypr /mnt/dottemp/hypr
arch-chroot /mnt /bin/bash <<CHROOT


# ------ SYSTEM ------

ln -sf "/usr/share/zoneinfo/America/New_York" /etc/localtime
hwclock --systohc

sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo archlinux > /etc/hostname

echo $upass | passwd --stdin
passwd --lock root


# ------ BOOT ------

mkdir -p /etc/kernel
echo "cryptdevice=UUID=$(blkid -s UUID -o value /dev/"${part2}"):cryptroot root=/dev/mapper/cryptroot rw nvidia.NVreg_EnableGpuFirmware=0 nvidia.NVreg_UsePageAttributeTable=1" > /etc/kernel/cmdline

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


# ------ USER ------

useradd -m user
echo $upass | passwd user --stdin

ln -s /tmp /home/user/.cache
mv /dottmp/.bashrc /home/user
mv /dottmp/hypr /home/user/.config

# ------ PACKAGES ------

pacman -Sy
pacman -S --noconfirm --needed git

echo "user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/00_user
chmod 440 /etc/sudoers.d/00_user

sudo -u user bash <<'EOF'
cd /tmp
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
yay -S --noconfirm --needed hyprland hyprpaper hyprshot keepassxc librewolf-bin noto-fonts openrgb pipewire-jack python-nvidia-ml-py vscodium-bin
yay -Rcns --noconfirm yay-debug
yay -Rcns --noconfirm $(yay -Qttdq)
yay -Yc --noconfirm
yay -D --asdeps git noto-fonts pipewire-jack
rm -rf /home/user/.cargo
rm -rf /home/user/.config/go
EOF

echo "user ALL=(ALL) ALL" > /etc/sudoers.d/00_user
chmod 440 /etc/sudoers.d/00_user
chown -R user:user /home/user


# ------ CONFIGS ------

cat <<'HYPR' > /home/user/.bash_profile
#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

if [[ -z \$DISPLAY ]] && [[ \$(tty) = /dev/tty1 ]]; then
  exec hyprland
fi
HYPR

mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<'GETTY' > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-- \\u' --autologin user --noreset --noclear - \${TERM}
GETTY

cat <<CUSTOM > /etc/systemd/system/custom.service
[Unit]
Description=Setup NVIDIA overclocks and OpenRGB.

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

sed -i 's|^; cookie-file =.*|cookie-file = ~/.config/pulse/cookie|' /etc/pulse/client.conf

sed -i 's/^#Storage=.*/Storage=none/' /etc/systemd/coredump.conf
sed -i 's/^#ProcessSizeMax=.*/ProcessSizeMax=0/' /etc/systemd/coredump.conf

sed -i "s|^#DNS=.*|DNS=45.90.28.0#${ndns}.dns.nextdns.io|" /etc/systemd/resolved.conf
sed -i "/^DNS=45.90.28.0#/a DNS=2a07:a8c0::#${ndns}.dns.nextdns.io\nDNS=45.90.30.0#${ndns}.dns.nextdns.io\nDNS=2a07:a8c1::#${ndns}.dns.nextdns.io" /etc/systemd/resolved.conf
sed -i 's/^#FallbackDNS=.*/FallbackDNS=/' /etc/systemd/resolved.conf
sed -i 's/^#Domains=.*/Domains=~/' /etc/systemd/resolved.conf
sed -i 's/^#DNSOverTLS=.*/DNSOverTLS=yes/' /etc/systemd/resolved.conf


# ------ SERVICES ------

systemctl disable nvidia-hibernate
systemctl disable nvidia-resume
systemctl disable nvidia-suspend

systemctl enable fstrim.timer
systemctl enable btrfs-scrub@-.timer

systemctl enable custom
systemctl enable iptables
systemctl enable iwd
systemctl enable mullvad-daemon

systemctl enable systemd-boot-update.service
systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable systemd-timesyncd
timedatectl set-ntp true

CHROOT
umount -R /mnt
cryptsetup close cryptroot
reboot