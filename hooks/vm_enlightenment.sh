#!/bin/sh
# =================================================================
# OpenBSD Enlightenment (E16) Auto-Start Desktop Setup Script
#
# Background:
#   The `enlightenment` package on OpenBSD ports is the *classic*
#   Enlightenment 16, not the EFL-based E22+. Its session binary is
#   /usr/local/bin/e16, not enlightenment_start. E16 is extremely
#   lightweight and a good fit for the cirrus VM with no GL accel.
#
# Requirements that bite if you change them:
#   * QEMU -vga cirrus (anyvm.py: --vga cirrus, auto for -enlightenment).
#   * machdep.allowaperture=2 (sysctl.conf, next boot only).
#   * /root mode 711 + umask 022 in rc.local (same Xauth reasoning).
#   * First boot shows an "Menu generation complete" dialog -- click
#     OK once and it does not return on subsequent boots.
#
# Usage: doas sh enlightenment.sh   (run as root, then reboot)
# =================================================================
set -e

ARCH=$(uname -m)
if [ "$ARCH" != "amd64" ]; then
    echo "ERROR: hooks/enlightenment.sh currently only supports amd64 (got $ARCH)."
    exit 1
fi

echo "--- 1. Installing Enlightenment (E16) ---"
pkg_add -I enlightenment

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
# Note: the binary is e16, not enlightenment_start (that is the
# E22+ entry which OpenBSD ports does not ship).
cat > /root/.xinitrc <<'EOF'
#!/bin/sh
exec /usr/local/bin/e16
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
# E16 does not strictly need dbus, but keep it on for consistency
# with the other desktop hooks and so apps launched from E16 work.
rcctl enable messagebus

echo "--- Setup Complete! ---"
echo "Reboot now to apply: aperture sysctl + rc.local autostart."
echo "First boot shows a 'Menu generation complete' E16 dialog --"
echo "click OK once; it does not return on subsequent boots."
echo "VM consumer must launch QEMU with -vga cirrus (anyvm.py: --vga"
echo "cirrus, auto-selected for any --release ending in -enlightenment)."
