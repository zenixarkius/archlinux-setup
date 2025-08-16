#
# ~/.bashrc
#

[[ $- != *i* ]] && return
[[ "$(whoami)" = "root" ]] && return
[[ -z "$FUNCNEST" ]] && export FUNCNEST=100

bind '"\e[A":history-search-backward'
bind '"\e[B":history-search-forward'

export HISTCONTROL=ignoredups:erasedups
export HISTSIZE=10000
export HISTFILESIZE=20000

alias mv='mv -i'
alias cp='cp -i'
alias rm='rm -i'
alias ls='ls -lha --color=auto --group-directories-first'
alias grep='grep --color=auto'
alias pacman='yay --color=auto'
alias yay='yay --color=auto'
alias mssd='sudo cryptsetup open /dev/sda3 cryptext && sudo mount /dev/mapper/cryptext /mnt'
alias ussd='sudo umount -R /mnt && sudo cryptsetup close cryptext'

cd() {
    builtin cd "$@" && ls
}

mullvad() {
    command mullvad "$@" &&
    while ! resolvectl status wg0-mullvad | grep -q "DNS Domain:"; do
    sleep 0.2
    done && sudo resolvectl domain wg0-mullvad ""
}

extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.gz)    tar xvzf "$1"    ;;
            *.tgz)       tar xvzf "$1"    ;;
            *.tar.xz)    tar xvJf "$1"    ;;
            *.tar)       tar xvf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *)           echo "'$1' cannot be extracted" ;;
        esac
    fi
}

check() {
    declare -A package_map
    while read -r pkg; do
        package_map["$pkg"]=$(sed -E 's/-(bin|git|dev|dbg|cli|utils|common|extra|minimal|pro|plus)$//' <<< "$pkg")
    done < <(pacman -Qq)
    local search_dirs=("$HOME" "$HOME/.config" "$HOME/.local/share" "$HOME/.local/state" "/etc" "/var/lib" "/var/cache" "/var/log")
    local found_items=()
    for dir in "${search_dirs[@]}"; do
        [ -d "$dir" ] && while IFS= read -r -d '' item; do
            [[ -e "$item" ]] && [[ ! " ${filters[*]} " =~ " $item " ]] && found_items+=("$item")
        done < <(find "$dir" -mindepth 1 -maxdepth 1 -print0)
    done
    [ ${#found_items[@]} -eq 0 ] && echo "All clean!" && return
    printf "%-50s %-10s %-5s\n%-50s %-10s %-5s\n" "PATH" "SIZE" "PACKAGE" "----" "----" "-------"
    for item in "${found_items[@]}"; do
        local size base_name matched_pkg
        size=$(du -sh -- "$item" 2>/dev/null | awk '{print $1}')
        base_name=$(basename "$item")
        matched_pkg=""
        for pkg in "${!package_map[@]}"; do
            [[ "$base_name" == *"${package_map[$pkg]}"* ]] && { matched_pkg="$pkg"; break; }
        done
        if [[ -n "$matched_pkg" ]]; then
            printf "\e[1;32m%-50s %-10s YES (%s)\e[0m\n" "$item" "$size" "$matched_pkg"
        else
            printf "\e[1;31m%-50s %-10s NO\e[0m\n" "$item" "$size"
        fi
    done
}

prune() {
    echo "Checking filter paths..."
    local missing=0
    for path in "${filters[@]}"; do
        if [[ ! -e "$path" ]]; then
            echo -e "\e[1;31mMISSING:\e[0m $path"
            ((missing++))
        fi
    done
    echo -e "\nTotal missing: $missing"
}

filters=(
    "/home/user/.bash_logout"
    "/home/user/.bash_history"
    "/home/user/.bash_profile"
    "/home/user/.bashrc"
    "/home/user/.cache"
    "/home/user/.config"
    "/home/user/.git"
    "/home/user/.gitconfig"
    "/home/user/.gitignore"
    "/home/user/.gnupg"
    "/home/user/.librewolf"
    "/home/user/.local"
    "/home/user/.pki"
    "/home/user/.vscode-oss"
    "/home/user/.config/dconf"
    "/home/user/.config/hypr"
    "/home/user/.config/keepassxc"
    "/home/user/.config/pulse"
    "/home/user/.config/VSCodium"
    "/home/user/.config/yay"
    "/home/user/.local/share/hyprland"
    "/home/user/.local/share/recently-used.xbel"
    "/etc/adjtime"
    "/etc/alsa"
    "/etc/arch-release"
    "/etc/audisp"
    "/etc/audit"
    "/etc/avahi"
    "/etc/bash.bash_logout"
    "/etc/bash.bashrc"
    "/etc/bindresvport.blacklist"
    "/etc/ca-certificates"
    "/etc/conf.d"
    "/etc/credstore"
    "/etc/credstore.encrypted"
    "/etc/crypttab"
    "/etc/dconf"
    "/etc/debuginfod"
    "/etc/default"
    "/etc/e2scrub.conf"
    "/etc/environment"
    "/etc/ethertypes"
    "/etc/fonts"
    "/etc/fstab"
    "/etc/gai.conf"
    "/etc/gnutls"
    "/etc/gprofng.rc"
    "/etc/group"
    "/etc/group-"
    "/etc/gshadow"
    "/etc/gshadow-"
    "/etc/gtk-3.0"
    "/etc/healthd.conf"
    "/etc/host.conf"
    "/etc/hostname"
    "/etc/hosts"
    "/etc/initcpio"
    "/etc/inputrc"
    "/etc/iptables"
    "/etc/issue"
    "/etc/iwd"
    "/etc/kernel"
    "/etc/krb5.conf"
    "/etc/ld.so.cache"
    "/etc/ld.so.conf"
    "/etc/libaudit.conf"
    "/etc/libnl"
    "/etc/libva.conf"
    "/etc/locale.conf"
    "/etc/locale.gen"
    "/etc/localtime"
    "/etc/login.defs"
    "/etc/machine-id"
    "/etc/mailcap"
    "/etc/makepkg.conf"
    "/etc/makepkg.conf.d"
    "/etc/mime.types"
    "/etc/mke2fs.conf"
    "/etc/mkinitcpio.conf"
    "/etc/mkinitcpio.d"
    "/etc/modules-load.d"
    "/etc/mtab"
    "/etc/mullvad-vpn"
    "/etc/netconfig"
    "/etc/nginx"
    "/etc/nsswitch.conf"
    "/etc/openldap"
    "/etc/openrgb"
    "/etc/os-release"
    "/etc/pacman.conf"
    "/etc/pacman.d"
    "/etc/pam.d"
    "/etc/passwd"
    "/etc/passwd-"
    "/etc/pipewire"
    "/etc/pkcs11"
    "/etc/polkit-1"
    "/etc/profile"
    "/etc/profile.d"
    "/etc/protocols"
    "/etc/pulse"
    "/etc/.pwd.lock"
    "/etc/rc_keymaps"
    "/etc/rc_maps.cfg"
    "/etc/request-key.conf"
    "/etc/resolv.conf"
    "/etc/rpc"
    "/etc/securetty"
    "/etc/security"
    "/etc/sensors3.conf"
    "/etc/services"
    "/etc/shadow"
    "/etc/shadow-"
    "/etc/shells"
    "/etc/skel"
    "/etc/ssh"
    "/etc/ssl"
    "/etc/subgid"
    "/etc/subgid-"
    "/etc/subuid"
    "/etc/subuid-"
    "/etc/sudo.conf"
    "/etc/sudoers"
    "/etc/sudoers.d"
    "/etc/sudo_logsrvd.conf"
    "/etc/systemd"
    "/etc/tpm2-tss"
    "/etc/ts.conf"
    "/etc/udev"
    "/etc/.updated"
    "/etc/vconsole.conf"
    "/etc/vdpau_wrapper.cfg"
    "/etc/X11"
    "/etc/xattr.conf"
    "/etc/xdg"
    "/var/cache/fontconfig"
    "/var/cache/ldconfig"
    "/var/cache/mullvad-vpn"
    "/var/cache/private"
    "/var/lib/dbus"
    "/var/lib/iwd"
    "/var/lib/krb5kdc"
    "/var/lib/lastlog"
    "/var/lib/libuuid"
    "/var/lib/machines"
    "/var/lib/misc"
    "/var/lib/pacman"
    "/var/lib/portables"
    "/var/lib/private"
    "/var/lib/sbctl"
    "/var/lib/systemd"
    "/var/lib/tpm2-tss"
    "/var/lib/xkb"
    "/var/log/audit"
    "/var/log/btmp"
    "/var/log/journal"
    "/var/log/lastlog"
    "/var/log/mullvad-vpn"
    "/var/log/old"
    "/var/log/pacman.log"
    "/var/log/private"
    "/var/log/README"
    "/var/log/wtmp"
)
