#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
# VibeWM v3.0 — Privacy-First i3 Desktop for Debian 13 (Trixie)
# Target: HP 14-dk0095nr (AMD A4-9125, 4GB RAM, 128GB SSD)
# Goal:   <250MB idle | Zero-Trust | SSH remote-ready
# Usage:  sudo bash INSTALL.sh
# ═══════════════════════════════════════════════════════════════════
set -euo pipefail
IFS=$'\n\t'

# ── Colors ──────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
info() { echo -e "${CYAN}[i]${NC} $1"; }

# ── Root & User Detection ──────────────────────────────────────
[[ $EUID -ne 0 ]] && err "Run as root: sudo bash INSTALL.sh"
USER_NAME="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
[[ -z "$USER_NAME" ]] && err "Cannot determine non-root user."
USER_HOME=$(eval echo "~$USER_NAME")
HOSTNAME_SHORT="hp14-vibewm"

# ── APT with 3x Retry ──────────────────────────────────────────
apt_retry() {
    local attempt=0
    while [[ $attempt -lt 3 ]]; do
        if apt-get "$@" -y; then return 0; fi
        attempt=$((attempt + 1))
        warn "APT failed (attempt $attempt/3), retrying in 5s..."
        sleep 5
    done
    err "APT failed after 3 attempts: $*"
}

# ── Banner ──────────────────────────────────────────────────────
banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << 'EOF'
 __      _____ ____  ________        ____  __   _____  ___
 \ \    / /_ _| __ )| ____\ \      / /  \/  | |___ / / _ \
  \ \  / / | ||  _ \|  _|  \ \ /\ / /| |\/| |   |_ \| | | |
   \ \/ /  | || |_) | |___  \ V  V / | |  | |  ___) | |_| |
    \__/  |___|____/|_____|  \_/\_/  |_|  |_| |____(_)___/
EOF
    echo -e "${NC}"
    echo -e "${BOLD}Privacy-First i3 Desktop • Debian 13 Trixie${NC}"
    echo -e "${CYAN}Target: HP 14-dk0095nr • <250MB idle RAM${NC}"
    echo ""
}

# ── Interactive Menu ────────────────────────────────────────────
menu() {
    banner
    echo -e "${BOLD}Select Installation Mode:${NC}"
    echo ""
    echo -e "  ${GREEN}1${NC}) ${BOLD}Express Install${NC} (Recommended — full VibeWM)"
    echo -e "  ${BLUE}2${NC}) ${BOLD}Minimal Install${NC} (i3 + security, no extras)"
    echo -e "  ${YELLOW}3${NC}) ${BOLD}Dry Run${NC} (preview packages, no changes)"
    echo -e "  ${RED}0${NC}) Exit"
    echo ""
    read -rp "Choice [1]: " CHOICE
    CHOICE="${CHOICE:-1}"
}

# ── Dry Run Mode ────────────────────────────────────────────────
dry_run() {
    banner
    info "DRY RUN — No changes will be made."
    echo ""
    echo "Packages to install:"
    echo "  Core: xserver-xorg-core xinit i3-wm i3status i3lock dmenu"
    echo "  DM:   lightdm lightdm-gtk-greeter"
    echo "  Apps: falkon thunar xfce4-terminal mousepad pavucontrol vlc zathura"
    echo "  Sec:  ufw apparmor apparmor-utils openssh-server fail2ban"
    echo "  Perf: zram-tools earlyoom preload picom"
    echo "  Rec:  flameshot byzanz-recorder ffmpeg"
    echo "  Net:  network-manager avahi-daemon"
    echo "  Bar:  polybar fonts-font-awesome"
    echo ""
    echo "Config changes:"
    echo "  SSH:      Port 2222, no root, no password, Ed25519 only"
    echo "  UFW:      deny incoming, allow 2222/tcp + 5901/tcp"
    echo "  AppArmor: enforce all profiles"
    echo "  sysctl:   hidepid=2, kernel hardening"
    echo "  LightDM:  autologin → i3"
    echo "  ZRAM:     50% RAM, zstd"
    echo "  mDNS:     ${HOSTNAME_SHORT}.local"
    echo ""
    info "Run with option 1 or 2 to install."
    exit 0
}

# ── APT Sources (Debian 13 Trixie) ─────────────────────────────
setup_sources() {
    log "Configuring APT sources (Trixie + non-free-firmware)..."
    cat > /etc/apt/sources.list << 'EOF'
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF
    apt_retry update
    apt_retry dist-upgrade
}

# ── Core X + i3 Stack ──────────────────────────────────────────
install_core() {
    log "Installing Xorg + i3 + LightDM (no GNOME/KDE)..."
    apt_retry install \
        xserver-xorg-core xinit x11-xserver-utils xdg-utils \
        i3-wm i3status i3lock dmenu \
        lightdm lightdm-gtk-greeter \
        network-manager network-manager-gnome \
        mate-polkit \
        fonts-dejavu fonts-noto-core fonts-font-awesome \
        dbus-x11 libnotify-bin notify-osd dunst \
        sudo curl wget git

    log "Installing Polybar..."
    apt_retry install polybar || {
        warn "Polybar not in repos, falling back to i3status."
        POLYBAR_AVAILABLE=false
    }
    POLYBAR_AVAILABLE="${POLYBAR_AVAILABLE:-true}"

    systemctl enable NetworkManager
    systemctl enable lightdm
}

# ── Applications ───────────────────────────────────────────────
install_apps() {
    log "Installing lightweight app suite..."
    apt_retry install \
        falkon links2 \
        xfce4-terminal thunar thunar-archive-plugin \
        mousepad ristretto viewnior \
        vlc zathura zathura-pdf-poppler \
        galculator xarchiver \
        pavucontrol pipewire pipewire-pulse wireplumber \
        htop btop psmisc tree jq \
        unclutter xdg-utils xdg-user-dirs
}

# ── Screen Capture Tools ───────────────────────────────────────
install_capture() {
    log "Installing screen capture (flameshot + byzanz + ffmpeg)..."
    apt_retry install \
        flameshot ffmpeg \
        byzanz || warn "byzanz not available, GIF recording disabled."
}

# ── Security Hardening ─────────────────────────────────────────
harden_system() {
    log "Hardening: UFW + SSH + AppArmor + sysctl..."

    # ── UFW Firewall ──
    apt_retry install ufw
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 2222/tcp comment 'SSH'
    ufw allow 5901/tcp comment 'VNC'
    ufw --force enable
    systemctl enable ufw

    # ── SSH (Port 2222, keys-only, no root) ──
    apt_retry install openssh-server fail2ban
    mkdir -p /etc/ssh/sshd_config.d
    cat > /etc/ssh/sshd_config.d/vibewm.conf << 'EOF'
Port 2222
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
HostKey /etc/ssh/ssh_host_ed25519_key
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding yes
X11DisplayOffset 10
AllowAgentForwarding yes
ClientAliveInterval 120
ClientAliveCountMax 3
EOF
    # Generate Ed25519 host key if missing
    [[ ! -f /etc/ssh/ssh_host_ed25519_key ]] && \
        ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ''
    # Create .ssh dir for user
    local SSH_DIR="$USER_HOME/.ssh"
    mkdir -p "$SSH_DIR"
    touch "$SSH_DIR/authorized_keys"
    chmod 700 "$SSH_DIR"
    chmod 600 "$SSH_DIR/authorized_keys"
    chown -R "$USER_NAME:$USER_NAME" "$SSH_DIR"
    systemctl enable ssh
    systemctl enable fail2ban

    # ── AppArmor ──
    apt_retry install apparmor apparmor-utils
    systemctl enable apparmor
    aa-enforce /etc/apparmor.d/* 2>/dev/null || warn "Some AppArmor profiles skipped."

    # ── sysctl hardening ──
    cat > /etc/sysctl.d/99-vibewm.conf << 'EOF'
# VibeWM Kernel Hardening
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
kernel.unprivileged_bpf_disabled=1
net.core.bpf_jit_harden=2
kernel.yama.ptrace_scope=2
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.default.send_redirects=0
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.default.accept_redirects=0
net.ipv6.conf.all.accept_redirects=0
net.ipv6.conf.default.accept_redirects=0
net.ipv4.icmp_echo_ignore_broadcasts=1
net.ipv4.tcp_syncookies=1
EOF
    sysctl --system > /dev/null 2>&1

    # ── hidepid (proc hardening) ──
    if ! grep -q 'hidepid=2' /etc/fstab; then
        echo 'proc /proc proc defaults,hidepid=2 0 0' >> /etc/fstab
    fi
}

# ── Performance Tuning ─────────────────────────────────────────
tune_performance() {
    log "Performance: ZRAM + EarlyOOM + picom..."

    # ── ZRAM (compressed swap) ──
    apt_retry install zram-tools
    cat > /etc/default/zramswap << 'EOF'
ALGO=zstd
PERCENT=50
PRIORITY=100
EOF
    systemctl enable zramswap

    # ── EarlyOOM ──
    apt_retry install earlyoom
    mkdir -p /etc/default
    cat > /etc/default/earlyoom << 'EOF'
EARLYOOM_ARGS="-r 10 -m 5 -s 5 --prefer '(Web|firefox|falkon)' --avoid '(i3|Xorg|polybar|ssh)'"
EOF
    systemctl enable earlyoom

    # ── Picom (lightweight compositor) ──
    apt_retry install picom
}

# ── mDNS (hostname.local) ─────────────────────────────────────
setup_mdns() {
    log "Setting up mDNS: ${HOSTNAME_SHORT}.local..."
    apt_retry install avahi-daemon
    hostnamectl set-hostname "$HOSTNAME_SHORT"
    systemctl enable avahi-daemon
}

# ── LightDM Autologin ─────────────────────────────────────────
setup_autologin() {
    log "Configuring LightDM autologin → i3..."
    mkdir -p /etc/lightdm/lightdm.conf.d
    cat > /etc/lightdm/lightdm.conf.d/50-vibewm.conf << EOF
[Seat:*]
autologin-user=$USER_NAME
autologin-user-timeout=0
user-session=i3
EOF
}

# ── i3 Config ──────────────────────────────────────────────────
install_i3_config() {
    log "Installing i3 config..."
    local I3_DIR="$USER_HOME/.config/i3"
    mkdir -p "$I3_DIR"
    cp /tmp/vibewm-i3-config "$I3_DIR/config" 2>/dev/null || \
        cat > "$I3_DIR/config" << 'EOFCONFIG'
# ═══════════════════════════════════════════════════════════
# VibeWM v3.0 — i3 Configuration
# ═══════════════════════════════════════════════════════════
set $mod Mod4
font pango:DejaVu Sans Mono 10

# ── App Launchers ──────────────────────────────────────────
bindsym $mod+Return exec xfce4-terminal
bindsym $mod+d exec --no-startup-id dmenu_run -fn 'DejaVu Sans Mono-11' -nb '#1a1a2e' -nf '#e0e0e0' -sb '#e94560' -sf '#ffffff'
bindsym $mod+w exec falkon
bindsym $mod+e exec thunar
bindsym $mod+Shift+q kill
bindsym $mod+Shift+e exec "i3-nagbar -t warning -m 'Exit i3?' -b 'Logout' 'i3-msg exit'"
bindsym $mod+Shift+r restart
bindsym $mod+Shift+c reload

# ── Focus & Move ───────────────────────────────────────────
bindsym $mod+Left focus left
bindsym $mod+Down focus down
bindsym $mod+Up focus up
bindsym $mod+Right focus right
bindsym $mod+h focus left
bindsym $mod+j focus down
bindsym $mod+k focus up
bindsym $mod+l focus right

bindsym $mod+Shift+Left move left
bindsym $mod+Shift+Down move down
bindsym $mod+Shift+Up move up
bindsym $mod+Shift+Right move right

# ── Layout ─────────────────────────────────────────────────
bindsym $mod+s layout stacking
bindsym $mod+t layout tabbed
bindsym $mod+g layout toggle split
bindsym $mod+v split v
bindsym $mod+b split h
bindsym $mod+f fullscreen toggle
bindsym $mod+Shift+space floating toggle
bindsym $mod+space focus mode_toggle

# ── Resize Mode ────────────────────────────────────────────
mode "resize" {
    bindsym Left  resize shrink width  5 px or 5 ppt
    bindsym Down  resize grow   height 5 px or 5 ppt
    bindsym Up    resize shrink height 5 px or 5 ppt
    bindsym Right resize grow   width  5 px or 5 ppt
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

# ── Workspaces ─────────────────────────────────────────────
set $ws1 "1:Web"
set $ws2 "2:Term"
set $ws3 "3:Files"
set $ws4 "4:Media"
set $ws5 "5:Dev"

bindsym $mod+1 workspace $ws1
bindsym $mod+2 workspace $ws2
bindsym $mod+3 workspace $ws3
bindsym $mod+4 workspace $ws4
bindsym $mod+5 workspace $ws5

bindsym $mod+Shift+1 move container to workspace $ws1
bindsym $mod+Shift+2 move container to workspace $ws2
bindsym $mod+Shift+3 move container to workspace $ws3
bindsym $mod+Shift+4 move container to workspace $ws4
bindsym $mod+Shift+5 move container to workspace $ws5

assign [class="Falkon"]   $ws1
assign [class="Firefox"]  $ws1
assign [class="Thunar"]   $ws3
assign [class="vlc"]      $ws4

# ── Screen Capture Hotkeys ─────────────────────────────────
# Print = Flameshot annotate + copy to clipboard
bindsym Print exec --no-startup-id flameshot gui
# Super+R = Toggle screen recording (MP4, ~5MB/min)
bindsym $mod+Shift+v exec --no-startup-id ~/bin/vibewm-toggle
# Super+Shift+R = GIF recording (10 seconds, byzanz)
bindsym $mod+Shift+g exec --no-startup-id byzanz-record -d 10 --delay=2 ~/Videos/vibewm-$(date +%s).gif && notify-send "GIF Saved" "10s recording to ~/Videos/"

# ── Volume ─────────────────────────────────────────────────
bindsym XF86AudioRaiseVolume exec --no-startup-id wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bindsym XF86AudioLowerVolume exec --no-startup-id wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindsym XF86AudioMute        exec --no-startup-id wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

# ── Brightness ─────────────────────────────────────────────
bindsym XF86MonBrightnessUp   exec --no-startup-id brightnessctl set +10%
bindsym XF86MonBrightnessDown exec --no-startup-id brightnessctl set 10%-

# ── Lock Screen ────────────────────────────────────────────
bindsym $mod+Escape exec --no-startup-id i3lock -c 1a1a2e

# ── Autostart ──────────────────────────────────────────────
exec --no-startup-id nm-applet &
exec --no-startup-id /usr/lib/mate-polkit/polkit-mate-authentication-agent-1 &
exec --no-startup-id unclutter --timeout 3 &
exec --no-startup-id picom --backend glx --vsync --fading --fade-in-step=0.07 --fade-out-step=0.07 --no-fading-openclose &
exec --no-startup-id dunst &
exec --no-startup-id xdg-user-dirs-update &
exec_always --no-startup-id ~/.config/polybar/launch.sh

# ── Window Colors ──────────────────────────────────────────
# class                 border  backgr  text    indicator child_border
client.focused          #e94560 #e94560 #ffffff #e94560   #e94560
client.focused_inactive #1a1a2e #1a1a2e #888888 #1a1a2e   #1a1a2e
client.unfocused        #0f3460 #0f3460 #888888 #0f3460   #0f3460
client.urgent           #ff0000 #ff0000 #ffffff #ff0000   #ff0000

# ── Gaps & Borders ─────────────────────────────────────────
default_border pixel 2
default_floating_border pixel 2
hide_edge_borders smart
EOFCONFIG
    chown -R "$USER_NAME:$USER_NAME" "$I3_DIR"
}

# ── Polybar Config ─────────────────────────────────────────────
install_polybar_config() {
    if [[ "${POLYBAR_AVAILABLE:-true}" != "true" ]]; then
        log "Polybar unavailable, i3status fallback active."
        return
    fi
    log "Installing Polybar config..."
    local PB_DIR="$USER_HOME/.config/polybar"
    mkdir -p "$PB_DIR"

    cat > "$PB_DIR/config.ini" << 'EOF'
; ═══════════════════════════════════════════════
; VibeWM v3.0 — Polybar Config
; CPU / RAM / SSH / WiFi / Date
; ═══════════════════════════════════════════════
[colors]
background = #1a1a2e
foreground = #e0e0e0
primary = #e94560
secondary = #0f3460
alert = #ff0000

[bar/vibewm]
width = 100%
height = 26
fixed-center = true
background = ${colors.background}
foreground = ${colors.foreground}
padding-left = 1
padding-right = 2
module-margin = 1
font-0 = DejaVu Sans Mono:size=10;2
font-1 = Font Awesome 6 Free Solid:size=10;2
modules-left = i3
modules-center = date
modules-right = cpu memory wlan ssh battery
tray-position = right
tray-maxsize = 16

[module/i3]
type = internal/i3
pin-workspaces = true
show-urgent = true
label-focused = %name%
label-focused-background = ${colors.primary}
label-focused-padding = 2
label-unfocused = %name%
label-unfocused-padding = 2
label-urgent = %name%
label-urgent-background = ${colors.alert}
label-urgent-padding = 2

[module/cpu]
type = internal/cpu
interval = 3
label =  %percentage:2%%

[module/memory]
type = internal/memory
interval = 3
label =  %percentage_used:2%%

[module/wlan]
type = internal/network
interface-type = wireless
interval = 5
label-connected =  %essid%
label-disconnected =  --

[module/date]
type = internal/date
interval = 30
date = %a %b %d
time = %H:%M
label = %date%  %time%

[module/battery]
type = internal/battery
battery = BAT0
adapter = ACAD
label-charging =  %percentage%%
label-discharging =  %percentage%%
label-full =  Full

[module/ssh]
type = custom/script
exec = ss -tlnp 2>/dev/null | grep -q ':2222' && echo ' ON' || echo ' OFF'
interval = 10
EOF

    cat > "$PB_DIR/launch.sh" << 'EOFLAUNCH'
#!/usr/bin/env bash
killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.5; done
polybar vibewm 2>&1 | tee -a /tmp/polybar.log & disown
EOFLAUNCH
    chmod +x "$PB_DIR/launch.sh"
    chown -R "$USER_NAME:$USER_NAME" "$PB_DIR"
}

# ── Screen Record Toggle Script ────────────────────────────────
install_scripts() {
    log "Installing VibeWM scripts..."
    local BIN_DIR="$USER_HOME/bin"
    local VIDEOS="$USER_HOME/Videos"
    mkdir -p "$BIN_DIR" "$VIDEOS"

    # ── vibewm-toggle (MP4 screen recorder) ──
    cat > "$BIN_DIR/vibewm-toggle" << 'EOF'
#!/usr/bin/env bash
# VibeWM v3.0 — Toggle Screen Recording (MP4, ~5MB/min, H.264)
PIDFILE="/tmp/vibewm-record.pid"
OUTDIR="$HOME/Videos"
mkdir -p "$OUTDIR"

if [[ -f "$PIDFILE" ]]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null
    rm -f "$PIDFILE"
    notify-send "Recording Stopped" "Saved to $OUTDIR/" -i media-record
else
    OUTFILE="$OUTDIR/vibewm-$(date +%Y%m%d-%H%M%S).mp4"
    RES=$(xdpyinfo | awk '/dimensions/{print $2}')
    ffmpeg -y -video_size "$RES" -framerate 15 -f x11grab -i :0.0 \
        -c:v libx264 -preset ultrafast -crf 28 -pix_fmt yuv420p \
        "$OUTFILE" > /dev/null 2>&1 &
    echo $! > "$PIDFILE"
    notify-send "Recording Started" "$OUTFILE" -i media-record
fi
EOF
    chmod +x "$BIN_DIR/vibewm-toggle"

    # ── cleanup-cache.sh ──
    cat > "$BIN_DIR/vibewm-cleanup" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
rm -rf "$HOME/.cache/thumbnails" "$HOME/.cache/falkon" 2>/dev/null || true
rm -rf "$HOME/.local/share/Trash"/* 2>/dev/null || true
pkill -9 falkon 2>/dev/null || true
PROFILE_ROOT="$HOME/.mozilla/firefox"
for p in "$PROFILE_ROOT"/*.default*; do
    [[ -d "$p" ]] && rm -rf "$p"/{cache2,thumbnails} 2>/dev/null || true
done
notify-send "VibeWM Cleanup" "Browser & system caches cleared."
EOF
    chmod +x "$BIN_DIR/vibewm-cleanup"

    # ── performance-boost.sh ──
    cat > "$BIN_DIR/vibewm-boost" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ $(id -u) -ne 0 ]]; then pkexec "$0"; exit 0; fi
sync && echo 3 > /proc/sys/vm/drop_caches
journalctl --vacuum-time=3d > /dev/null 2>&1 || true
apt-get clean -y > /dev/null 2>&1 || true
DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "${SUDO_USER:-$USER}")/bus" \
    sudo -u "${SUDO_USER:-$USER}" notify-send "VibeWM Boost" "Caches dropped, logs trimmed." 2>/dev/null || true
EOF
    chmod +x "$BIN_DIR/vibewm-boost"

    # ── vnc-remote.sh ──
    cat > "$BIN_DIR/vibewm-vnc" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
command -v x11vnc > /dev/null || { notify-send "VNC Error" "x11vnc not installed"; exit 1; }
PIDFILE="/tmp/vibewm-vnc.pid"
if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    kill "$(cat "$PIDFILE")"
    rm -f "$PIDFILE"
    notify-send "VNC Stopped" "Remote access disabled."
else
    x11vnc -display :0 -rfbport 5901 -nopw -forever -shared -bg \
        -o /tmp/vibewm-vnc.log
    pgrep -n x11vnc > "$PIDFILE"
    notify-send "VNC Started" "Port 5901 — connect from HP Envy."
fi
EOF
    chmod +x "$BIN_DIR/vibewm-vnc"

    chown -R "$USER_NAME:$USER_NAME" "$BIN_DIR" "$VIDEOS"

    # Add ~/bin to PATH
    local PROFILE="$USER_HOME/.profile"
    if ! grep -q 'HOME/bin' "$PROFILE" 2>/dev/null; then
        echo 'export PATH="$HOME/bin:$PATH"' >> "$PROFILE"
        chown "$USER_NAME:$USER_NAME" "$PROFILE"
    fi
}

# ── Desktop Launchers (.desktop files) ─────────────────────────
install_launchers() {
    log "Installing desktop launchers..."
    local APP_DIR="$USER_HOME/.local/share/applications"
    local DESK="$USER_HOME/Desktop/Utilities"
    mkdir -p "$APP_DIR" "$DESK"

    # 1. Cleanup-Cache
    cat > "$APP_DIR/vibewm-cleanup.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Cleanup Cache
Comment=Clear browser & system caches
Exec=$USER_HOME/bin/vibewm-cleanup
Icon=edit-clear
Terminal=false
Categories=Utility;
EOF

    # 2. Performance-Boost
    cat > "$APP_DIR/vibewm-boost.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Performance Boost
Comment=Drop caches, trim logs, free RAM
Exec=$USER_HOME/bin/vibewm-boost
Icon=system-run
Terminal=false
Categories=Utility;
EOF

    # 3. Screenshot
    cat > "$APP_DIR/vibewm-screenshot.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Screenshot
Comment=Annotate & copy screenshot
Exec=flameshot gui
Icon=accessories-screenshot
Terminal=false
Categories=Utility;
EOF

    # 4. Record-Video
    cat > "$APP_DIR/vibewm-record.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Record Video
Comment=Toggle MP4 screen recording
Exec=$USER_HOME/bin/vibewm-toggle
Icon=media-record
Terminal=false
Categories=Utility;
EOF

    # 5. VNC-Remote
    cat > "$APP_DIR/vibewm-vnc.desktop" << EOF
[Desktop Entry]
Type=Application
Name=VNC Remote
Comment=Start/stop VNC for remote access
Exec=$USER_HOME/bin/vibewm-vnc
Icon=preferences-desktop-remote-desktop
Terminal=false
Categories=Utility;
EOF

    # Symlinks to Desktop
    for f in vibewm-cleanup vibewm-boost vibewm-screenshot vibewm-record vibewm-vnc; do
        ln -sf "$APP_DIR/${f}.desktop" "$DESK/"
    done
    chown -R "$USER_NAME:$USER_NAME" "$APP_DIR" "$DESK" \
        "$USER_HOME/Desktop" 2>/dev/null || true
}

# ── VNC Optional Install ──────────────────────────────────────
install_vnc() {
    log "Installing x11vnc for remote access..."
    apt_retry install x11vnc || warn "x11vnc not available."
}

# ── Create Required Dirs ──────────────────────────────────────
setup_dirs() {
    mkdir -p "$USER_HOME"/{Desktop,Documents,Downloads,Music,Pictures,Videos,bin}
    mkdir -p "$USER_HOME/.config"/{i3,polybar,dunst,picom}
    chown -R "$USER_NAME:$USER_NAME" "$USER_HOME"
}

# ── AMD Firmware ──────────────────────────────────────────────
install_firmware() {
    log "Installing AMD firmware..."
    apt_retry install firmware-amd-graphics amd64-microcode \
        xserver-xorg-video-amdgpu mesa-vulkan-drivers 2>/dev/null \
        || warn "Some AMD firmware packages unavailable."
}

# ── Brightnessctl ─────────────────────────────────────────────
install_brightness() {
    apt_retry install brightnessctl || warn "brightnessctl not available."
}

# ═══════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════
main() {
    menu

    case "$CHOICE" in
        0) echo "Exiting."; exit 0 ;;
        3) dry_run ;;
        1|2) ;;
        *) err "Invalid choice." ;;
    esac

    local START_TIME=$SECONDS
    info "Installing VibeWM v3.0 for user: $USER_NAME"
    echo ""

    setup_sources
    setup_dirs
    install_firmware
    install_core
    install_brightness

    if [[ "$CHOICE" == "1" ]]; then
        install_apps
        install_capture
        install_vnc
    fi

    harden_system
    tune_performance
    setup_mdns
    setup_autologin
    install_i3_config
    install_polybar_config
    install_scripts
    install_launchers

    local ELAPSED=$(( SECONDS - START_TIME ))
    echo ""
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}  VibeWM v3.0 installed in ${ELAPSED}s${NC}"
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${CYAN}Reboot:${NC}  sudo reboot"
    echo -e "  ${CYAN}SSH in:${NC}  ssh -p 2222 ${USER_NAME}@${HOSTNAME_SHORT}.local"
    echo -e "  ${CYAN}X11 fwd:${NC} ssh -X -p 2222 ${USER_NAME}@${HOSTNAME_SHORT}.local"
    echo ""
    echo -e "  ${YELLOW}NOTE:${NC} Add your public key to ~/.ssh/authorized_keys"
    echo -e "  ${YELLOW}NOTE:${NC} Password auth is DISABLED (keys-only)"
    echo ""

    read -rp "Reboot now? [y/N]: " REBOOT
    [[ "${REBOOT,,}" == "y" ]] && reboot
}

main "$@"
