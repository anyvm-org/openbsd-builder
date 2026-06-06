#!/bin/sh
# =================================================================
# OpenBSD Lumina Auto-Start Desktop Setup Script
#
# Background:
#   Lumina is a BSD-native Qt-based lightweight desktop (originally
#   PC-BSD's). It is designed to avoid systemd / heavy dbus reliance.
#   It uses Fluxbox internally as its WM and pulls it in as a dep, so
#   no extra WM install is needed (unlike LXQt). No DM is involved.
#
# Requirements that bite if you change them:
#   * QEMU -vga cirrus (anyvm.py: --vga cirrus, auto for -lumina).
#   * machdep.allowaperture=2 (sysctl.conf, next boot only).
#   * /root mode 711 + umask 022 in rc.local (same Xauth reasoning
#     as the other hooks).
#
# Usage: doas sh lumina.sh   (run as root, then reboot)
# =================================================================
set -e

ARCH=$(uname -m)
if [ "$ARCH" != "amd64" ]; then
    echo "ERROR: hooks/lumina.sh currently only supports amd64 (got $ARCH)."
    exit 1
fi

echo "--- 1. Installing Lumina ---"
pkg_add -I lumina

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
exec /usr/local/bin/start-lumina-desktop
EOF
chmod 755 /root/.xinitrc

echo "--- 5. Configuring auto-start via /etc/rc.local ---"
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
# Lumina is designed to work without dbus, but several apps (file
# manager actions, notifications) integrate better with it on. Cheap
# to leave running.
rcctl enable messagebus

echo "--- Setup Complete! ---"
echo "Reboot now to apply: aperture sysctl + rc.local autostart."
echo "First boot shows a splash with a Steve Jobs quote for ~ 30 seconds"
echo "while Lumina builds its menu / icons cache."
echo "VM consumer must launch QEMU with -vga cirrus (anyvm.py: --vga"
echo "cirrus, auto-selected for any --release ending in -lumina)."
