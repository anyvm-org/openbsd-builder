#!/bin/sh
# =================================================================
# OpenBSD XFCE Auto-Start Desktop Setup Script
#
# Background:
#   Unlike FreeBSD, OpenBSD ships X (Xenocara) and a display manager
#   (xenodm) in base. But xenodm has no native autologin, and OpenBSD
#   ports does not currently package SLiM / SDDM / LightDM / lxdm.
#   So this hook skips a display manager entirely: rc.local launches
#   startx -> startxfce4 directly, as root, no login prompt.
#
# Requirements that bite if you change them:
#   * QEMU must be started with -vga cirrus (or equivalent). With the
#     default virtio-gpu, OpenBSD's base has no DRM driver for it and
#     wsfb/scfb cannot get a framebuffer ioctl -> Xorg "no screens
#     found". With cirrus, the xenocara cirrus_drv works.
#   * machdep.allowaperture must be raised from 0 -> 2. cirrus_drv
#     and vesa_drv both need the legacy VGA aperture which OpenBSD
#     blocks by default at securelevel 1. The sysctl is read-only at
#     runtime once securelevel > 0; it must be set via /etc/sysctl.conf
#     and picked up on the next boot.
#   * /root must be mode 711 (not the default 700). Xorg drops privs
#     to user _x11 and needs to traverse /root to read the auth file
#     startx generated as $HOME/.serverauth.<RANDOM>. Without this you
#     get "Failed to open authorization file ... Permission denied".
#
# Usage: doas sh xfce.sh   (run as root, then reboot)
# =================================================================
set -e

# --- Arch guard: amd64 only for now ---
# aarch64/riscv64 may work via efifb but is untested by anyvm-org.
ARCH=$(uname -m)
if [ "$ARCH" != "amd64" ]; then
    echo "ERROR: hooks/xfce.sh currently only supports amd64 (got $ARCH)."
    echo "OpenBSD non-amd64 desktops may work via efifb + wsfb but have"
    echo "not been verified. Remove this guard to try at your own risk."
    exit 1
fi

echo "--- 1. Installing XFCE meta-package ---"
# X server is already in OpenBSD base, so we only need the desktop itself.
# pkg_add -I = no interactive prompts (for unattended builds).
pkg_add -I xfce

echo "--- 2. Allowing VGA aperture for cirrus / vesa driver (sysctl.conf) ---"
# Required so xf86-video-cirrus can access the VGA aperture memory.
# Default OpenBSD locks this at securelevel 1; we raise to 2 (allow X).
# Takes effect on next reboot only -- /etc/rc reads sysctl.conf early
# but the kernel will not allow runtime changes once securelevel rises.
if ! grep -q "^machdep.allowaperture=" /etc/sysctl.conf 2>/dev/null; then
    echo "machdep.allowaperture=2" >> /etc/sysctl.conf
fi

echo "--- 3. Forcing Xorg to use cirrus driver ---"
# Without this, Xorg auto-probes and picks vesa (which fails on UEFI
# and seg-faults on legacy paths) or modesetting (needs /dev/drm0,
# which the OpenBSD vga(4) driver does not expose for QEMU's emulated
# Cirrus). We pin cirrus_drv explicitly.
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/10-cirrus.conf <<'EOF'
Section "Device"
    Identifier "Card0"
    Driver     "cirrus"
EndSection
EOF

echo "--- 4. Creating /root/.xinitrc ---"
# Absolute path is important -- rc.local runs with a minimal PATH that
# does not include /usr/local/bin, where startxfce4 lives.
cat > /root/.xinitrc <<'EOF'
exec /usr/local/bin/startxfce4
EOF
chmod 755 /root/.xinitrc

echo "--- 5. Configuring auto-start via /etc/rc.local ---"
# rc.local runs at the end of /etc/rc (multi-user). We spawn startx in
# a backgrounded subshell so rc.local returns immediately. The sleep 3
# gives messagebus / udev-equivalent time to settle.
#
# chmod 711 /root: Xorg's privilege-separation drops to user _x11.
# _x11 must be able to traverse /root to open the .serverauth file
# that startx generated under $HOME. Default mode 700 blocks it and
# X server bails with "Permission denied".
cat > /etc/rc.local <<'EOF'
#!/bin/sh
# anyvm: auto-start XFCE desktop session as root on console vt05.
# /root must be mode 711 so _x11 (Xorg privsep user) can read
# $HOME/.serverauth.* that startx generates.
chmod 711 /root
if [ -x /usr/X11R6/bin/startx ] && ! pgrep -q Xorg; then
    (
        sleep 3
        cd /root
        HOME=/root USER=root LOGNAME=root \
        PATH=/usr/local/bin:/usr/X11R6/bin:/bin:/usr/bin:/usr/sbin:/sbin \
            /usr/X11R6/bin/startx -- vt05
    ) >/var/log/startx.log 2>&1 &
fi
EOF
chmod 755 /etc/rc.local

echo "--- 6. Enabling dbus (messagebus) ---"
# XFCE session and its panel plugins need a system bus. OpenBSD's
# dbus rc script is named 'messagebus' (BSD convention).
rcctl enable messagebus
rcctl start messagebus || true

echo "--- 7. Disabling xfce4-screensaver / xfce4-power-manager (system xfconf) ---"
# This image is a no-login autostart VM, so no user can unlock the
# screen lock (there is no password prompt path at all). Also we do
# not want PowerDevil-equivalent to suspend the VM after idle. On
# OpenBSD, packages drop XDG defaults under /etc/xdg/ (not the
# /usr/local/etc/xdg/ location FreeBSD uses), so the override goes
# there. xfconf-daemon will use these on a first session when the
# user has no ~/.config/xfce4/... yet.
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml
cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-screensaver.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-screensaver" version="1.0">
  <property name="saver" type="empty">
    <property name="enabled" type="bool" value="false"/>
  </property>
  <property name="lock" type="empty">
    <property name="enabled" type="bool" value="false"/>
  </property>
</channel>
EOF
cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-power-manager" version="1.0">
  <property name="xfce4-power-manager" type="empty">
    <property name="blank-on-ac" type="uint" value="0"/>
    <property name="blank-on-battery" type="uint" value="0"/>
    <property name="dpms-enabled" type="bool" value="false"/>
    <property name="inactivity-on-ac" type="uint" value="0"/>
    <property name="inactivity-on-battery" type="uint" value="0"/>
    <property name="inactivity-sleep-mode-on-ac" type="uint" value="0"/>
    <property name="inactivity-sleep-mode-on-battery" type="uint" value="0"/>
    <property name="lock-screen-suspend-hibernate" type="bool" value="false"/>
    <property name="logind-handle-lid-switch" type="bool" value="false"/>
  </property>
</channel>
EOF

echo "--- Setup Complete! ---"
echo "Reboot now to apply: aperture sysctl + rc.local autostart."
echo "VM consumer must launch QEMU with -vga cirrus (or equivalent --vga"
echo "cirrus via anyvm.py). Default virtio-gpu will NOT work."
