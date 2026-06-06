#!/bin/sh
# =================================================================
# OpenBSD GNOME Auto-Login Desktop Setup Script
#
# Background:
#   OpenBSD ships X (Xenocara) in base; GNOME and GDM come from ports.
#   The OpenBSD GNOME team (Antoine Jacoutot) documents the standard
#   incantation in /usr/local/share/doc/pkg-readmes/gnome -- we follow
#   it, plus add GDM autologin and disable screen lock / auto-suspend
#   so the VM never prompts for a password the user has not set.
#
# Requirements that bite if you change them:
#   * QEMU must be started with -vga cirrus (anyvm.py: --vga cirrus,
#     auto-selected for any release ending in -gnome / -xfce / -kde6).
#     With virtio-gpu there is no DRM driver and Xorg cannot get a
#     framebuffer.
#   * machdep.allowaperture must be 2. cirrus_drv needs the VGA
#     aperture which OpenBSD locks at securelevel 1. Set in
#     /etc/sysctl.conf and only picked up on the next boot.
#   * WaylandEnable=false in custom.conf -- mutter Wayland backend
#     needs GBM/DRM, which cirrus does not provide. X11 session only.
#
# Usage: doas sh gnome.sh   (run as root, then reboot)
# =================================================================
set -e

# --- Arch guard: amd64 only for now ---
ARCH=$(uname -m)
if [ "$ARCH" != "amd64" ]; then
    echo "ERROR: hooks/gnome.sh currently only supports amd64 (got $ARCH)."
    echo "OpenBSD non-amd64 desktops may work via efifb but have not been"
    echo "verified by anyvm-org. Remove this guard to try at your own risk."
    exit 1
fi

echo "--- 1. Installing GNOME meta-package ---"
# Core GNOME (no Evolution/PIM/office). pkg_add -I = no interactive prompts.
pkg_add -I gnome

echo "--- 2. Allowing VGA aperture for cirrus driver (sysctl.conf) ---"
# Required so xf86-video-cirrus can access the VGA aperture memory.
# Default OpenBSD locks this at securelevel 1; we raise to 2 (allow X).
# Takes effect on the next reboot only.
if ! grep -q "^machdep.allowaperture=" /etc/sysctl.conf 2>/dev/null; then
    echo "machdep.allowaperture=2" >> /etc/sysctl.conf
fi

echo "--- 3. Forcing Xorg to use cirrus driver ---"
# Without this, Xorg auto-probes vesa (fails on UEFI / aperture EINVAL)
# or modesetting (needs /dev/drm0, absent on OpenBSD vga(4) for QEMU
# Cirrus). Pin cirrus_drv explicitly.
mkdir -p /etc/X11/xorg.conf.d
cat > /etc/X11/xorg.conf.d/10-cirrus.conf <<'EOF'
Section "Device"
    Identifier "Card0"
    Driver     "cirrus"
EndSection
EOF

echo "--- 4. Configuring GDM autologin (custom.conf) ---"
# AutomaticLogin=root bypasses the GDM greeter entirely. WaylandEnable=false
# is critical: mutter's Wayland session uses GBM/DRM which fails on cirrus
# (no /dev/drm0). Forcing X11 makes mutter use the working X11 backend.
mkdir -p /etc/gdm
cat > /etc/gdm/custom.conf <<'EOF'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=root
WaylandEnable=false

[security]
EOF

echo "--- 5. Service set per /usr/local/share/doc/pkg-readmes/gnome ---"
# OpenBSD's GNOME maintainer documents this exact sequence. xenodm is
# the OpenBSD default DM (off by default; we disable it so it cannot
# fight GDM). multicast + avahi_daemon are nominally optional but the
# README ships them in the cheat sheet, so we follow.
rcctl disable xenodm
rcctl enable multicast messagebus avahi_daemon gdm
rcctl order messagebus

echo "--- 6. Disabling screen lock + auto-suspend (system-wide dconf) ---"
# This is a no-password autologin VM: root has no password, so any
# lock-screen path would strand the user. Also kill the idle-suspend
# policy since QEMU virtio resume from suspend is unreliable.
mkdir -p /etc/dconf/profile /etc/dconf/db/local.d
# Ensure the 'user' profile exists and reads the local system db. Do
# not stomp on an existing profile (ibus etc.) -- only create if absent.
if [ ! -f /etc/dconf/profile/user ]; then
    cat > /etc/dconf/profile/user <<'EOF'
user-db:user
system-db:local
EOF
fi
cat > /etc/dconf/db/local.d/00-no-screen-lock <<'EOF'
[org/gnome/desktop/screensaver]
lock-enabled=false
idle-activation-enabled=false

[org/gnome/desktop/session]
idle-delay=uint32 0

[org/gnome/desktop/lockdown]
disable-lock-screen=true

[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-type='nothing'
sleep-inactive-ac-timeout=0
sleep-inactive-battery-type='nothing'
sleep-inactive-battery-timeout=0
idle-dim=false
EOF
dconf update

echo "--- Setup Complete! ---"
echo "Reboot now to apply: aperture sysctl + rc service set + GDM autologin."
echo "VM consumer must launch QEMU with -vga cirrus (anyvm.py: --vga cirrus,"
echo "auto-selected for any --release ending in -gnome)."
