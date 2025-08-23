# ⚙️ Zenixark's Arch Linux Setup
**My dotfiles + automated installation and utility scripts, all focused on hardening, minimalism, and performance.**

<pre>
[user@zenixark ~]$ fastfetch
                  -`                     user@zenixark
                 .o+`                    -------------
                `ooo/                    OS: Arch Linux x86_64
               `+oooo:                   Host: Z790 AORUS ELITE AX DDR4
              `+oooooo:                  Kernel: Linux 6.16.1-arch1-1
              -+oooooo+:                 Uptime: 24 seconds
            `/:-:++oooo+:                Packages: 464 (pacman)
           `/++++/+++++++:               Shell: bash 5.3.3
          `/++++++++++++++:              Display (M34WQ): 3440x1440 @ 144 Hz in 34" [External]
         `/+++ooooooooooooo/`            Display (LG ULTRAGEAR): 1920x1080 @ 144 Hz in 24" [External]
        ./ooosssso++osssssso+`           WM: Hyprland 0.50.1 (Wayland)
       .oossssso-````/ossssss+`          Cursor: Adwaita
      -osssssso.      :ssssssso.         Terminal: alacritty 0.15.1
     :osssssss/        osssso+++.        Terminal Font: alacritty (11pt)
    /ossssssss/        +ssssooo/-        CPU: 13th Gen Intel(R) Core(TM) i7-13700K (24) @ 5.80 GHz
  `/ossssso+/:-        -:/+osssso+-      GPU 1: NVIDIA GeForce RTX 4070 [Discrete]
 `+sso+:-`                 `.-/+oso:     GPU 2: Intel UHD Graphics 770 @ 1.60 GHz [Integrated]
`++:.                           `-/+/    Memory: 1.45 GiB / 31.11 GiB (5%)
.`                                 `/    Disk (/): 3.03 GiB / 930.50 GiB (0%) - btrfs
[user@zenixark ~]$ yay -Rcns fastfetch
</pre>

## 📁 Repo Contents
> [!CAUTION]
> Files here are ***NOT*** intended to be used by others (especially `zarchinstall`) as everything here is very *very* personalized.
<pre>
[user@zenixark ~]$ tree
~
└── .zenixark
    ├── configs
    │   ├── bash
    │   │   ├── <a href="./configs/bash/bash_profile">bash_profile</a>
    │   │   └── <a href="./configs/bash/bashrc">bashrc</a>            # Various QOL aliases and functions esp. for file management
    │   ├── git
    │   │   └── <a href="./configs/git/gitconfig">gitconfig</a>
    │   ├── hypr
    │   │   ├── <a href="./configs/hypr/hyprland.conf">hyprland.conf</a>
    │   │   ├── <a href="./configs/hypr/hyprpaper.conf">hyprpaper.conf</a>
    │   │   ├── <a href="./configs/hypr/sigiluw.png">sigiluw.png</a>
    │   │   └── <a href="./configs/hypr/sigilw.png">sigilw.png</a>
    │   ├── librewolf
    │   │   ├── <a href="https://github.com/rafaelmardojai/firefox-gnome-theme">chrome</a>            # firefox-gnome-theme
    │   │   └── <a href="./configs/librewolf/user.js">user.js</a>           # Extra hardening over LibreWolf's already great defaults
    │   └── systemd
    │       └── <a href="./configs/systemd/custom.service">custom.service</a>    # Sets GPU overclocks and static RGB colors on startup
    └── scripts
        ├── <a href="./scripts/leftovers">leftovers</a>             # Scans common junk dirs and outputs files not in custom filters
        └── <a href="./scripts/zarchinstall">zarchinstall</a>          # Sets up disks, packages, hardening, dots, and more
[user@zenixark ~]$ yay -Rcns tree
</pre>

## 🧰 Software Preferences
I generally prefer to avoid proprietary and GUI nonsense whenever possible in favor of FOSS and CLI stuff respectively, as well as avoiding having anything I don't actively need installed.
> *Anything important that's not visible is a dep of one of these, like `noto-fonts` is a dep of `librewolf-bin`.*
<pre>
[user@zenixark ~]$ yay -Qqe
alacritty                         # Terminal
base
base-devel
btrfs-progs
hyprland                          # Window Manager
hyprpaper                         # Wallpaper
hyprshot                          # Screenshots
intel-ucode
iwd                               # Wi-Fi (+ systemd-resolved)
keepassxc                         # Password Manager
librewolf-bin                     # Browser
linux                             # Kernel
linux-firmware
mullvad-vpn-cli                   # VPN
neovim                            # Text Editor
nvidia                            # GPU
openrgb
pipewire-pulse                    # Audio
python-nvidia-ml-py
sbctl
signal-desktop
yay                               # AUR
[user@zenixark ~]$ yay -Rcns ya^C
</pre>
