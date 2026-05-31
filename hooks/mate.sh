#!/bin/sh
# =================================================================
# OpenBSD MATE Auto-Start Desktop Setup Script
#
# Background:
#   MATE is the GNOME 2 fork; GTK 3, traditional taskbar layout, much
#   lighter than GNOME / Plasma. OpenBSD ports has a `mate` meta-port.
#   No DM is involved -- rc.local + startx + .xinitrc, same pattern
#   as hooks/xfce.sh.
#
# Requirements that bite if you change them:
#   * QEMU must be -vga cirrus (anyvm.py: --vga cirrus, auto-selected
#     for any release ending in -mate). Default virtio-gpu has no DRM
#     driver in OpenBSD base; Xorg cannot get a framebuffer.
#   * machdep.allowaperture must be 2 (sysctl.conf, takes effect on
#     next boot). cirrus_drv needs the VGA aperture which OpenBSD
#     locks at securelevel 1.
#   * /root must be mode 711 (set in rc.local) so _x11 can traverse
#     to read $HOME/.serverauth.*.
#
# Usage: doas sh mate.sh   (run as root, then reboot)
# =================================================================
set -e

ARCH=$(uname -m)
if [ "$ARCH" != "amd64" ]; then
    echo "ERROR: hooks/mate.sh currently only supports amd64 (got $ARCH)."
    exit 1
fi

echo "--- 1. Installing MATE meta-package ---"
pkg_add -I mate

echo "--- 2. Allowing VGA aperture (sysctl.conf) ---"
if ! grep -q "^machdep.allowaperture=" /etc/sysctl.conf 2>/dev/null; then
    echo "machdep.allowaperture=2" >> /etc/sysctl.conf
fi

echo "--- 3. Forcing Xorg to use cirrus driver ---"
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/10-cirrus.conf <<'EOF'
Section "Device"
    Identifier "Card0"
    Driver     "cirrus"
EndSection
EOF

echo "--- 4. Creating /root/.xinitrc ---"
cat > /root/.xinitrc <<'EOF'
#!/bin/sh
exec /usr/local/bin/mate-session
EOF
chmod 755 /root/.xinitrc

echo "--- 5. Configuring auto-start via /etc/rc.local ---"
# Same pattern as hooks/xfce.sh: chmod 711 /root + ulimit raise +
# umask 022 (so .serverauth is 644 instead of 600; required for
# stability across reboots -- some sessions race the X auth read).
cat > /etc/rc.local <<'EOF'
#!/bin/sh
chmod 711 /root
if [ -x /usr/X11R6/bin/startx ] && ! pgrep -q Xorg; then
    (
        sleep 3
        ulimit -n 8192
        umask 022
        cd /root
        HOME=/root USER=root LOGNAME=root \
        PATH=/usr/local/bin:/usr/X11R6/bin:/bin:/usr/bin:/usr/sbin:/sbin \
            /usr/X11R6/bin/startx -- vt05
    ) >/var/log/startx.log 2>&1 &
fi
EOF
chmod 755 /etc/rc.local

echo "--- 6. Enabling dbus (messagebus) ---"
rcctl enable messagebus

echo "--- 7. Disabling MATE screen lock / power suspend (system dconf) ---"
# MATE uses GSettings/dconf for desktop preferences. We provide a
# system-wide override so a fresh root session inherits no-lock /
# no-suspend defaults; user can still toggle via Control Center.
mkdir -p /etc/dconf/profile /etc/dconf/db/local.d
if [ ! -f /etc/dconf/profile/user ]; then
    cat > /etc/dconf/profile/user <<'EOF'
user-db:user
system-db:local
EOF
fi
cat > /etc/dconf/db/local.d/00-no-screen-lock <<'EOF'
[org/mate/screensaver]
lock-enabled=false
idle-activation-enabled=false

[org/mate/session]
idle-delay=uint32 0

[org/mate/power-manager]
sleep-display-ac=0
sleep-display-battery=0
sleep-computer-ac=0
sleep-computer-battery=0
EOF
dconf update

echo "--- Setup Complete! ---"
echo "Reboot now to apply: aperture sysctl + rc.local autostart."
echo "VM consumer must launch QEMU with -vga cirrus (anyvm.py: --vga"
echo "cirrus, auto-selected for any --release ending in -mate)."
