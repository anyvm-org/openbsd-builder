#!/bin/sh
# =================================================================
# OpenBSD/arm64 (aarch64) XFCE Auto-Start Desktop Setup Script
#
# Background:
#   This is the arm64 sibling of hooks/xfce.sh. It is kept separate
#   because the kernel framebuffer story, the Xorg driver, and the
#   xfce / X server flags all differ enough that splitting is cleaner
#   than another big per-arch if/else inside xfce.sh.
#
#   OpenBSD ships X (Xenocara) and a display manager (xenodm) in base.
#   xenodm has no native autologin path and the OpenBSD/arm64 wsdisplay
#   stack does not implement the VT_PROCESS ioctl that xenodm's Xorg
#   invocation needs, so we skip xenodm entirely and let rc.local do
#   startx -> startxfce4 directly, as root, no login prompt.
#
# Requirements that bite if you change them:
#   * QEMU must expose a virtio-gpu (anyvm.py default for aarch64).
#     There is no cirrus_drv for OpenBSD/arm64 xenocara. The kernel
#     attaches the virtio-gpu PCI device as viogpu0 and gives it a
#     wsdisplay framebuffer; the Xorg wsfb driver writes through that.
#   * The wsfb driver must run with Option "ShadowFB" "off". With
#     ShadowFB on, X paints into a RAM shadow and only the periodic
#     shadow->wsdisplay flush updates the actual framebuffer that
#     viogpu exposes. Render / Composite operations (xfce-panel,
#     xfdesktop) end up in the shadow but the damage events do not
#     reach the flush path on arm64+viogpu, so the QEMU display stays
#     black even though `xwd -root` inside X shows the right desktop.
#     With ShadowFB off, X writes directly into the wsdisplay
#     framebuffer and every change reaches viogpu immediately.
#   * xfwm4's compositor must be off (use_compositing=false). Even
#     with ShadowFB off, the compositor pulls each window into an
#     offscreen pixmap and composites them onto the root via the
#     Composite / Render extensions; wsfb's CPU fallback for those
#     operations does not push the resulting damage out to wsdisplay
#     on arm64+viogpu. Without the compositor xfwm4 damages the root
#     region directly and updates reach the framebuffer fine.
#   * The X server needs -keeptty, started on vt04 (not vt05).
#     xf86OpenConsole calls VT_SETMODE VT_PROCESS on the wsdisplay
#     control device; that ioctl returns ENOTSUP when X is launched
#     from a process whose controlling tty is not a wscons device
#     (rc.local, an SSH login, an rcctl-spawned xenodm all hit this).
#     -keeptty skips the controlling-tty switch and X starts fine.
#     ttyC4 is the wsdisplay screen reserved for X in OpenBSD's
#     /etc/ttys (it is off-by-default for getty while ttyC5 has one),
#     so the startx invocation passes vt04.
#   * /root must be mode 711 (not the default 700). Xorg drops privs
#     to user _x11 and needs to traverse /root to read the auth file
#     startx generated as $HOME/.serverauth.<RANDOM>. Without this you
#     get "Failed to open authorization file ... Permission denied".
#   * machdep.allowaperture is NOT touched. That sysctl is amd64 /
#     i386 only (it controls access to the legacy VGA aperture which
#     does not exist on arm64); writing it on arm64 fails on the next
#     boot when rc parses sysctl.conf.
#
# Usage: doas sh xfce-aarch64.sh   (run as root, then reboot)
# =================================================================
set -e

# --- Arch guard: arm64 only ---
# Note: OpenBSD's uname -m on aarch64 returns "arm64", not "aarch64".
ARCH=$(uname -m)
if [ "$ARCH" != "arm64" ]; then
    echo "ERROR: hooks/xfce-aarch64.sh is for arm64 (got $ARCH)."
    echo "Use hooks/xfce.sh for amd64."
    exit 1
fi

echo "--- 1. Installing XFCE meta-package ---"
# X server is already in OpenBSD base, so we only need the desktop itself.
# pkg_add -I = no interactive prompts (for unattended builds).
pkg_add -I xfce

echo "--- 2. Pinning Xorg to wsfb without shadow framebuffer ---"
# viogpu0 attaches wsdisplay; wsfb writes through that. ShadowFB off
# is mandatory on arm64+viogpu (see file header for the long story).
# No /dev/drm* node exists, so modesetting is not an option either.
# No machdep.allowaperture: aperture sysctl does not exist on arm64.
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/10-wsfb.conf <<'EOF'
Section "Device"
    Identifier "Card0"
    Driver     "wsfb"
    Option     "ShadowFB" "off"
EndSection
EOF

echo "--- 3. Creating /root/.xinitrc ---"
# Absolute path is important -- rc.local runs with a minimal PATH that
# does not include /usr/local/bin, where startxfce4 lives.
cat > /root/.xinitrc <<'EOF'
exec /usr/local/bin/startxfce4
EOF
chmod 755 /root/.xinitrc

echo "--- 4. Configuring auto-start via /etc/rc.local ---"
# rc.local runs at the end of /etc/rc (multi-user). We spawn startx in
# a backgrounded subshell so rc.local returns immediately. The sleep 3
# gives messagebus time to settle.
#
# chmod 711 /root: Xorg's privilege-separation drops to user _x11.
# _x11 must be able to traverse /root to open the .serverauth file
# that startx generated under $HOME. Default mode 700 blocks it and
# X server bails with "Permission denied".
#
# -keeptty: required on arm64 (see file header). vt04 is the wsdisplay
# screen reserved for X (ttyC4 is off-by-default for getty in /etc/ttys
# while ttyC5 has one, unlike the amd64 hook which uses vt05).
cat > /etc/rc.local <<'EOF'
#!/bin/sh
# anyvm: auto-start XFCE desktop session as root on console vt04.
chmod 711 /root
if [ -x /usr/X11R6/bin/startx ] && ! pgrep -q Xorg; then
    (
        sleep 3
        cd /root
        HOME=/root USER=root LOGNAME=root \
        PATH=/usr/local/bin:/usr/X11R6/bin:/bin:/usr/bin:/usr/sbin:/sbin \
            /usr/X11R6/bin/startx -- -keeptty vt04
    ) >/var/log/startx.log 2>&1 &
fi
EOF
chmod 755 /etc/rc.local

echo "--- 5. Enabling dbus (messagebus) ---"
# XFCE session and its panel plugins need a system bus. OpenBSD's
# dbus rc script is named 'messagebus' (BSD convention).
rcctl enable messagebus
rcctl start messagebus || true

echo "--- 6. Disabling xfwm4 compositor (REQUIRED on arm64) ---"
# See the file header for the long story. Without this xfwm4 paints
# into offscreen pixmaps and composites via Render, which on
# arm64+viogpu does not push damage to wsdisplay -- so the QEMU
# display stays black even though X has the right pixmaps.
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml
cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="use_compositing" type="bool" value="false"/>
  </property>
</channel>
EOF

echo "--- 7. Disabling xfce4-screensaver / xfce4-power-manager (system xfconf) ---"
# This image is a no-login autostart VM, so no user can unlock the
# screen lock (there is no password prompt path at all). Also we do
# not want PowerDevil-equivalent to suspend the VM after idle. On
# OpenBSD, packages drop XDG defaults under /etc/xdg/, so the
# override goes there. xfconf-daemon will use these on a first
# session when the user has no ~/.config/xfce4/... yet.
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
echo "Reboot now to apply: xorg.conf.d wsfb + rc.local autostart."
echo "VM consumer should launch QEMU with -device virtio-gpu-pci"
echo "(anyvm.py default for aarch64). Do NOT pass --vga cirrus on"
echo "arm64 -- cirrus_drv is amd64-only in OpenBSD's Xenocara."
