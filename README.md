# ⚙️ Zenixark's Arch Linux Setup
**My dotfiles + automated installation and utility scripts, all focused on hardening, minimalism, and performance.**

<pre>
[user@zenixark ~]$ fastfetch
                  -`                     user@zenixark
                 .o+`                    -------------
                `ooo/                    OS: Arch Linux x86_64
               `+oooo:                   Host: Z790 AORUS ELITE AX DDR4
              `+oooooo:                  Kernel: Linux 6.16.3-arch1-1
              -+oooooo+:                 Uptime: 24 seconds
            `/:-:++oooo+:                Packages: 464 (pacman)
           `/++++/+++++++:               Shell: bash 5.3.3
          `/++++++++++++++:              Display (M34WQ): 3440x1440 @ 144 Hz in 34"
         `/+++ooooooooooooo/`            Display (LG ULTRAGEAR): 1920x1080 @ 144 Hz in 24"
        ./ooosssso++osssssso+`           WM: Hyprland 0.50.1 (Wayland)
       .oossssso-````/ossssss+`          Cursor: Adwaita
      -osssssso.      :ssssssso.         Terminal: foot 1.23.1
     :osssssss/        osssso+++.        Terminal Font: monospace (8pt)
    /ossssssss/        +ssssooo/-        CPU: 13th Gen Intel(R) Core(TM) i7-13700K (24) @ 5.80 GHz
  `/ossssso+/:-        -:/+osssso+-      GPU 1: NVIDIA GeForce RTX 4070
 `+sso+:-`                 `.-/+oso:     GPU 2: Intel UHD Graphics 770 @ 1.60 GHz
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
    ├── bash
    │   ├── <a href="./bash/bash_profile">bash_profile</a>
    │   └── <a href="./bash/bashrc">bashrc</a>            # Various QOL aliases & functions esp. for file management
    ├── git
    │   └── <a href="./git/gitconfig">gitconfig</a>
    ├── hypr
    │   ├── <a href="./hypr/hyprland.conf">hyprland.conf</a>
    │   ├── <a href="./hypr/hyprpaper.conf">hyprpaper.conf</a>
    │   ├── <a href="./hypr/sigiluw.png">sigiluw.png</a>
    │   └── <a href="./hypr/sigilw.png">sigilw.png</a>
    ├── librewolf
    │   ├── <a href="./librewolf/chrome">chrome</a>            # <a href="https://github.com/rafaelmardojai/firefox-gnome-theme">firefox-gnome-theme</a>
    │   └── <a href="./librewolf/user.js">user.js</a>           # Extra hardening & aesthetics over LibreWolf's great defaults
    ├── nvim
    │   └── <a href="./nvim/init.lua">init.lua</a>
    ├── scripts
    │   ├── <a href="./scripts/leftovers">leftovers</a>         # Scans common junk dirs and outputs files not in custom filters
    │   └── <a href="./scripts/zarchinstall">zarchinstall</a>      # Sets up disks, packages, hardening, dots, and more
    └── systemd
        └── <a href="./systemd/custom.service">custom.service</a>    # Sets GPU overclocks and static RGB colors on startup
[user@zenixark ~]$ yay -Rcns tree
</pre>

## 🧰 Software Preferences
I generally prefer to avoid proprietary and GUI nonsense whenever possible in favor of FOSS and CLI stuff respectively, as well as avoiding having anything I don't actively need installed.
> *Anything important that's not visible is a dep of one of these, like `noto-fonts` is a dep of `librewolf-bin`.*
<pre>
[user@zenixark ~]$ yay -Qqe
base
base-devel
btrfs-progs
foot                          # Terminal
hyprland                      # Window Manager
hyprpaper                     # Wallpaper
hyprshot                      # Screenshots
intel-ucode
iwd                           # Wi-Fi
keepassxc                     # Password Manager
librewolf-bin                 # Browser
linux                         # Kernel
linux-firmware
mullvad-vpn-cli               # VPN
neovim                        # Text Editor
nvidia                        # GPU
openrgb
pipewire-pulse                # Audio
python-nvidia-ml-py
sbctl
ttf-hack-nerd
yay
[user@zenixark ~]$ yay -Rcns ya^C
</pre>
