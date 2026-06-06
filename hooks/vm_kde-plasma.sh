#!/bin/sh
# =================================================================
# OpenBSD KDE Plasma 6 Auto-Start Desktop Setup Script
#
# Background:
#   OpenBSD ports has no SDDM, so we use the same rc.local + startx
#   pattern as hooks/xfce.sh. /root/.xinitrc follows the recipe in
#   /usr/local/share/doc/pkg-readmes/kde-plasma (XDG_RUNTIME_DIR +
#   dbus-launch + ck-launch-session + startplasma-x11).
#
# Requirements that bite if you change them:
#   * QEMU must be -vga cirrus (anyvm.py: --vga cirrus, auto-selected
#     for any release ending in -kde6). Default virtio-gpu has no DRM
#     driver in OpenBSD base; Xorg cannot get a framebuffer.
#   * machdep.allowaperture must be 2 (sysctl.conf, takes effect on
#     next boot). cirrus_drv needs the VGA aperture which OpenBSD
#     locks at securelevel 1.
#   * kern.maxfiles raised to 65535: Plasma + KWin + KDED + many KIO
#     workers open lots of files. The KDE README warns about this.
#   * root login class = kde: raises openfiles soft limit so Qt does
#     not hit "Too many open files" during session startup. Set via
#     usermod -L kde. We also ulimit -n 8192 in rc.local since the
#     startx path skips login(1) and thus skips login.conf entirely.
#   * /root must be mode 711 (not the default 700) so the _x11 user
#     that Xorg drops privs to can read $HOME/.serverauth.*.
#   * Cirrus on QEMU is 4 MB VRAM / 1024x768 max with software
#     rendering. Plasma 6 boots but the first ~ 3 minutes will sit
#     at load > 5 while kwin+plasmashell warm up; settles to ~ 1.
#
# Usage: doas sh kde-plasma.sh   (run as root, then reboot)
# =================================================================
set -e

# --- Arch guard: amd64 only for now ---
ARCH=$(uname -m)
if [ "$ARCH" != "amd64" ]; then
    echo "ERROR: hooks/kde-plasma.sh currently only supports amd64 (got $ARCH)."
    exit 1
fi

echo "--- 1. Installing KDE Plasma 6 meta-package ---"
# Includes dolphin, konsole, kmix. pkg_add -I = no interactive prompts.
# Tip: on slow networks pkg_add sometimes stalls; if it does, retry the
# specific missing packages (e.g. pkg_add plasma-workspace plasma-desktop
# kde-plasma) once the stalled connection is freed.
pkg_add -I kde-plasma

echo "--- 2. Allowing VGA aperture + raising maxfiles (sysctl.conf) ---"
if ! grep -q "^machdep.allowaperture=" /etc/sysctl.conf 2>/dev/null; then
    echo "machdep.allowaperture=2" >> /etc/sysctl.conf
fi
if ! grep -q "^kern.maxfiles=" /etc/sysctl.conf 2>/dev/null; then
    echo "kern.maxfiles=65535" >> /etc/sysctl.conf
fi

echo "--- 3. Forcing Xorg to use cirrus driver ---"
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/10-cirrus.conf <<'EOF'
Section "Device"
    Identifier "Card0"
    Driver     "cirrus"
EndSection
EOF

echo "--- 4. Creating /root/.xinitrc per OpenBSD kde-plasma README ---"
# XDG_RUNTIME_DIR must be 700 and exist before startplasma-x11.
# dbus-launch sets up the session bus. ck-launch-session wraps the
# session with a ConsoleKit2 session so logout / lock dialogs work.
cat > /root/.xinitrc <<'EOF'
#!/bin/sh
export XDG_RUNTIME_DIR=/tmp/run/$(id -u)
mkdir -m 700 -p $XDG_RUNTIME_DIR
if [ -x /usr/local/bin/dbus-launch -a -z "${DBUS_SESSION_BUS_ADDRESS}" ]; then
    eval $(dbus-launch --sh-syntax --exit-with-x11)
fi
exec /usr/local/bin/ck-launch-session /usr/local/bin/startplasma-x11
EOF
chmod 755 /root/.xinitrc

echo "--- 5. Configuring auto-start via /etc/rc.local ---"
# Same pattern as XFCE: rc.local spawns startx in a backgrounded subshell.
# chmod 711 /root: _x11 (Xorg privsep user) must traverse /root for
# the serverauth file. ulimit -n 8192: raise nofile soft limit since
# rc.local does not go through login(1) and so does not pick up the
# 'kde' login class limits.
cat > /etc/rc.local <<'EOF'
#!/bin/sh
# anyvm: auto-start KDE Plasma desktop session on console vt05.
chmod 711 /root
if [ -x /usr/X11R6/bin/startx ] && ! pgrep -q Xorg; then
    (
        sleep 3
        ulimit -n 8192
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

echo "--- 7. Setting root login class to kde ---"
# /etc/login.conf.d/kde is shipped by the kde-plasma package; it
# raises datasize / openfiles limits. Only useful for paths that go
# through login(1) (e.g. console getty, ssh), not for the rc.local
# startx path -- but harmless to set, and helpful if the user ssh-es
# into the VM with X forwarding.
usermod -L kde root 2>&1 || true

echo "--- 8. Disabling Plasma screen lock + auto-suspend (system-wide) ---"
# Plasma reads kscreenlockerrc / powermanagementprofilesrc from
# /etc/xdg/ as system defaults; the user can override later via
# System Settings (writes to ~/.config/*). For a no-password VM, we
# disable lock entirely and turn off PowerDevil's suspend / dim.
mkdir -p /etc/xdg
cat > /etc/xdg/kscreenlockerrc <<'EOF'
[Daemon]
Autolock=false
LockOnResume=false
Timeout=0
EOF
cat > /etc/xdg/powermanagementprofilesrc <<'EOF'
[AC]
icon=battery-charging

[AC][SuspendSession]
suspendType=0

[AC][DimDisplay]
idleTime=0

[AC][DPMSControl]
idleTime=0
lockBeforeTurnOff=0

[Battery]
icon=battery-060

[Battery][SuspendSession]
suspendType=0

[Battery][DimDisplay]
idleTime=0

[Battery][DPMSControl]
idleTime=0
lockBeforeTurnOff=0

[LowBattery]
icon=battery-low

[LowBattery][SuspendSession]
suspendType=0

[LowBattery][DimDisplay]
idleTime=0

[LowBattery][DPMSControl]
idleTime=0
lockBeforeTurnOff=0
EOF

echo "--- Setup Complete! ---"
echo "Reboot now to apply: aperture / maxfiles sysctl + rc.local autostart."
echo "First boot warm-up takes ~ 3 minutes (load 5+) before plasmashell"
echo "finishes rendering the desktop. Subsequent boots are similar."
echo "VM consumer must launch QEMU with -vga cirrus (anyvm.py: --vga cirrus,"
echo "auto-selected for any --release ending in -kde6)."
