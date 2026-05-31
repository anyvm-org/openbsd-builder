#!/bin/sh
# =================================================================
# OpenBSD LXQt Auto-Start Desktop Setup Script
#
# Background:
#   LXQt is a Qt-based lightweight desktop. It does not bundle a
#   window manager -- on first run it shows a "Welcome to LXQt"
#   dialog asking the user to pick one. To skip that dialog on an
#   autostart VM, we install openbox up front and pre-write
#   ~/.config/lxqt/session.conf pointing at it.
#
# Requirements that bite if you change them:
#   * QEMU -vga cirrus (anyvm.py: --vga cirrus, auto for -lxqt).
#   * machdep.allowaperture=2 (sysctl.conf, next boot only).
#   * /root mode 711 (rc.local) so _x11 can read .serverauth.*.
#   * umask 022 in rc.local before startx so the auth file is 644
#     and not 600 -- LXQt's Qt6 platform plugin is stricter about
#     auth handshake timing than XFCE / GNOME / KDE and intermittently
#     fails with "Could not load the Qt platform plugin xcb" if the
#     auth file is not consistently readable.
#
# Usage: doas sh lxqt.sh   (run as root, then reboot)
# =================================================================
set -e

ARCH=$(uname -m)
if [ "$ARCH" != "amd64" ]; then
    echo "ERROR: hooks/lxqt.sh currently only supports amd64 (got $ARCH)."
    exit 1
fi

echo "--- 1. Installing LXQt + openbox (the chosen WM) ---"
# LXQt has no WM of its own; openbox is the conventional pick. Without
# pre-installing one, LXQt blocks on a "select a window manager" dialog.
pkg_add -I lxqt openbox

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
exec /usr/local/bin/startlxqt
EOF
chmod 755 /root/.xinitrc

echo "--- 5. Pre-configuring LXQt to use openbox (skip Welcome dialog) ---"
# The Welcome dialog only appears when window_manager is not set in
# session.conf. Pre-seed it so first boot goes straight to the
# desktop with no user input.
mkdir -p /root/.config/lxqt
cat > /root/.config/lxqt/session.conf <<'EOF'
[General]
window_manager=openbox
EOF

echo "--- 6. Configuring auto-start via /etc/rc.local ---"
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

echo "--- 7. Enabling dbus (messagebus) ---"
rcctl enable messagebus

echo "--- 8. Disabling LXQt screen lock / power (system-wide) ---"
# LXQt reads ~/.config/lxqt/*.conf; system defaults go to
# /etc/xdg/lxqt/. lxqt-powermanagement and lxqt-screensaver are the
# components that would otherwise idle-lock / dim the display.
mkdir -p /etc/xdg/lxqt
cat > /etc/xdg/lxqt/power.conf <<'EOF'
[General]
disableIdlenessWatcher=true
idlenessAction=0
idlenessActionTime=0

[IdlenessWatcher]
enabled=false
EOF

echo "--- Setup Complete! ---"
echo "Reboot now to apply: aperture sysctl + rc.local autostart."
echo "VM consumer must launch QEMU with -vga cirrus (anyvm.py: --vga"
echo "cirrus, auto-selected for any --release ending in -lxqt)."
