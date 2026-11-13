#!/usr/bin/env bash
# Glyph: installs everything on a clean Arch and links configs from this repo.
#   ./install.sh                   packages + services + symlinks; asks what to add from EXTRA
#   ./install.sh --with telegram   same without prompting (--with "" — only the rice itself)
#   ./install.sh --links           symlinks only (on an already set up system)
#   ./install.sh --sddm            only the login theme (sudo); after edits in config/sddm — again
set -euo pipefail

DOTS="$(cd "$(dirname "$0")" && pwd)"
BACKUP="$HOME/.dots-backup-$(date +%F_%H-%M-%S)"

PACMAN=(
    # base
    base-devel git curl jq python
    # session
    hyprland hypridle hyprsunset hyprpicker xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    sddm quickshell polkit-gnome gnome-keyring geoclue upower xdg-user-dirs
    # sound, network, bluetooth
    pipewire pipewire-pulse pipewire-alsa wireplumber networkmanager bluez bluez-utils power-profiles-daemon
    # utilities invoked by binds and shell
    brightnessctl playerctl wl-clipboard cliphist grim slurp swappy imagemagick libvips libqalculate
    gpu-screen-recorder ydotool libnotify trash-cli
    # terminal and console
    kitty fish starship fastfetch btop cava eza zoxide direnv
    # apps from variables.lua
    thunar pavucontrol
    # fonts (cjk — kaomoji in Charms), icons (Papirus-Dark — base of Rice folder theme), dark base for gtk.css
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji papirus-icon-theme adw-gtk-theme
)

AUR=(
    qtengine darkly-bin bibata-cursor-theme-bin
    brave-origin-bin
)

# choose, like optional components in caelestia. What special-workspace binds open — apps in hypr/variables.lua
declare -A EXTRA=(
    [telegram]="telegram-desktop"                                        # Super+D
    [spotify]="spotify-launcher spicetify-cli spicetify-marketplace-bin" # Super+M
    [clash]="clash-verge-rev-bin"                                        # VPN panel, Super+P
)

G=config/quickshell/glyph
# repo path → path in $HOME
LINKS=(
    "config/hypr                                .config/hypr"
    "$G                                         .config/quickshell/glyph"
    "config/quickshell/rice                     .config/quickshell/rice"
    "config/quickshell/rice/rice                .local/bin/rice"
    "config/kitty                               .config/kitty"
    "config/qtengine                            .config/qtengine"
    "$G/term/qtengine.colors                    .config/qtengine.colors"
    "$G/term/starship.toml                      .config/starship.toml"
    "$G/term/fastfetch                          .config/fastfetch"
    "$G/term/btop                               .config/btop"
    "$G/term/cava                               .config/cava"
    "$G/term/gtk-3.0/gtk.css                    .config/gtk-3.0/gtk.css"
    "$G/term/gtk-4.0/gtk.css                    .config/gtk-4.0/gtk.css"
    "config/fish/config.fish                    .config/fish/config.fish"
    "config/fish/functions/fish_greeting.fish   .config/fish/functions/fish_greeting.fish"
    "config/fonts                               .local/share/fonts/glyph"
)

say() { printf '\e[38;2;215;25;33m●\e[0m %s\n' "$*"; }

extras() { # --with or prompt → into EXT, installs yay (and from repo) separately from AUR
    local w; EXT=()
    if [ -z "${WITH+x}" ]; then
        say "anything else to install? space-separated, Enter for none"
        for w in "${!EXTRA[@]}"; do printf '  %-9s %s\n' "$w" "${EXTRA[$w]}"; done
        read -rp "  > " WITH || true
    fi
    for w in ${WITH//,/ }; do
        [ -n "${EXTRA[$w]-}" ] || { echo "no such extra: $w (available: ${!EXTRA[*]})"; exit 1; }
        EXT+=(${EXTRA[$w]})
    done
}

packages() {
    say "pacman"
    # pulseaudio modules require pulseaudio itself — pacman wouldn't let replace it with pipewire-pulse.
    # As a list, not grep '^pulseaudio-': pulseaudio-alsa and pulseaudio-qt live with pipewire
    local pa; pa=$(pacman -Qq pulseaudio-{bluetooth,jack,lirc,rtp,zeroconf,equalizer,equalizer-ladspa} 2>/dev/null || true)
    [ -z "$pa" ] || sudo pacman -R $pa
    pacman -Q pulseaudio &>/dev/null && say "pacman will ask \"Remove pulseaudio?\": answer y, pipewire-pulse replaces it"
    # without --noconfirm: on conflict (pulseaudio → pipewire-pulse) it would answer "no" and break the install
    sudo pacman -Syu --needed "${PACMAN[@]}"

    if ! command -v yay >/dev/null; then
        say "yay"
        local tmp; tmp="$(mktemp -d)"
        git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
        (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
        rm -rf "$tmp"
    fi

    say "aur"
    # AUR is optional: a package failed — services and links still get installed
    yay -S --needed --noconfirm "${AUR[@]}" || say "aur: some packages failed, see above"
    # separately: spicetify failed to build — AUR core doesn't suffer
    [ ${#EXT[@]} -eq 0 ] || yay -S --needed --noconfirm "${EXT[@]}" || say "extras: some packages failed, see above"
}

services() {
    say "services"
    sudo systemctl enable NetworkManager bluetooth power-profiles-daemon
    systemctl is-enabled -q display-manager.service 2>/dev/null || sudo systemctl enable sddm
    systemctl --user enable pipewire-pulse.socket wireplumber ydotool
    sudo usermod -aG input,video "$USER" # ydotool (uinput), brightnessctl
    xdg-user-dirs-update
}

links() {
    say "symlinks (old files → $BACKUP)"
    local src dst
    for l in "${LINKS[@]}"; do
        read -r src dst <<<"$l"
        src="$DOTS/$src" dst="$HOME/$dst"
        [ "$(readlink "$dst")" = "$src" ] && continue
        if [ -e "$dst" ] || [ -L "$dst" ]; then
            mkdir -p "$BACKUP/$(dirname "${dst#"$HOME"/}")"
            mv "$dst" "$BACKUP/${dst#"$HOME"/}"
        fi
        mkdir -p "$(dirname "$dst")"
        ln -s "$src" "$dst"
        echo "  $dst"
    done
    # rules.json and kitty.conf the shell creates itself; rice brings up glyph and builds the folder theme
    mkdir -p "$HOME/.config/demonshot" "${XDG_STATE_HOME:-$HOME/.local/state}/rice"
    echo glyph > "${XDG_STATE_HOME:-$HOME/.local/state}/rice/shell"
    mkdir -p "$HOME/Pictures/Wallpapers" # wallpaper picker (Super+Shift+W) looks here
    fc-cache -f >/dev/null
    command -v gsettings >/dev/null || return 0 # --links on a system without GNOME schemas
    # dark mode for Zen, Electron and libadwaita (via portal) and dark gtk3 base under our gtk.css
    gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark
}

greeter() { # login theme. Copy, not link: sddm user can't read locked $HOME. fonts in theme — link to config/fonts, -L copies the files themselves
    say "sddm: glyph theme"
    [ -d /usr/share/sddm/themes ] || { say "sddm isn't installed, skipping the theme"; return 0; }
    # rm: files removed from repo don't linger in the theme; chmod: with umask 077 the copy would be 600 and sddm can't read it
    sudo rm -rf /usr/share/sddm/themes/glyph
    sudo cp -rLT "$DOTS/config/sddm/glyph" /usr/share/sddm/themes/glyph
    sudo chmod -R a+rX /usr/share/sddm/themes/glyph
    # InputMethod empty: sddm default is qtvirtualkeyboard, and with this theme an on-screen keyboard covers the whole screen
    sudo mkdir -p /etc/sddm.conf.d
    # zz-: conf.d files read alphabetically, the next overrides — ours last, on top of others (virtualkbd.conf from astronaut)
    printf '[Theme]\nCurrent=glyph\n\n[General]\nInputMethod=\n' | sudo tee /etc/sddm.conf.d/zz-glyph.conf >/dev/null
    # /etc/sddm.conf takes precedence over conf.d
    if grep -qsE '^\s*Current=' /etc/sddm.conf && ! grep -qsE '^\s*Current=glyph\s*$' /etc/sddm.conf; then
        say "/etc/sddm.conf sets its own theme and wins over conf.d: set Current=glyph there"
    fi
}

[ "$EUID" -eq 0 ] && { echo "run as your user, not root: sudo asks when it needs to"; exit 1; }

case "${1:-}" in
    --links) links ;; # on any distro (NixOS, Fedora…): packages then yours, list — in README
    --sddm) greeter ;;
    ""|--with) command -v pacman >/dev/null || { echo "packages install on Arch only; on another distro: $0 --links"; exit 1; }
        [ "${1:-}" = --with ] && WITH="${*:2}" # both comma and space separated
        extras; packages; services; links; greeter
        # spicetify needs Spotify already downloaded and logged in, so there's nothing to apply before first launch
        [[ " ${WITH//,/ } " == *" spotify "* ]] && say "spotify: launch it, log in, then run spicetify config custom_apps marketplace && spicetify backup apply"
        say "done. reboot and pick Hyprland in sddm" ;;
    *) echo "usage: $0 [--with telegram,spotify,clash | --links | --sddm]"; exit 1 ;;
esac