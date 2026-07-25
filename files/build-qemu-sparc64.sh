#!/bin/bash
# Build the PATCHED qemu-system-sparc64 this builder's sparc64 images need
# at run time, from the upstream source tarball, and package it as
#   <outdir>/qemu-10.2.3-sparc64-noble.tar.zst
# with a pruned, self-contained layout:
#   qemu10-sparc64/bin/qemu-system-sparc64
#   qemu10-sparc64/share/qemu/{openbios-sparc64,efi-e1000.rom,keymaps/}
# (QEMU locates its datadir relative to the binary, so the tree works from
# any extraction directory.)
#
# Why pinned at all: EVERY upstream QEMU release carries a sun4u IRQ-dispatch
# bug in hw/pci-host/sabre.c -- the IVEC dispatch has a single-slot
# irq_request that the PCI-INO branch overwrites even while an OBIO request
# (the onboard cmd646 IDE) is still unacknowledged; the guest's
# interrupt-clear write then mismatches irq_request and is silently dropped,
# permanently wedging both devices' interrupts. OpenBSD sparc64 hits it from
# both sides once disk and NIC DMA overlap:
#   - disk half: "wd0(pciide0:0:0): timeout" during boot, so the guest never
#     reaches sshd and the run times out;
#   - NIC half: "em0: watchdog: head N tail M TDH N TDT N" (the e1000 TX
#     completion interrupt was lost), which breaks a long rsync mid-transfer
#     with "write error: Broken pipe".
# files/qemu-sabre-irq-clobber.patch fixes it with one condition, mirroring
# what the OBIO branch already does.
#
# Firmware notes:
#  - efi-e1000.rom: option ROM for the e1000 NIC the sparc64 confs use
#    (VM_NIC=e1000 -> em0); QEMU 10.x ABORTS at launch without it ("failed to
#    find romfile efi-e1000.rom"), so it must ride along in the pruned tree.
#  - openbios-sparc64: the stock sun4u firmware, kept so the tree can boot
#    stand-alone. OpenBSD guests do NOT use it: QEMU's bundled OpenBIOS
#    crashes every OpenBSD >= 7.3 sparc64 kernel on cold boot, so anyvm
#    passes this builder's own patched blob (bios/build-openbios.sh, uploaded
#    as openbios-sparc64.elf) via -bios instead.
#
# Usage: bash files/build-qemu-sparc64.sh <outdir>
#
# Intended host: ubuntu-24.04 (noble) -- the GitHub Actions runner image
# (the "noble" in the tarball name). The tarball is NOT committed to git:
# the release-files job (.github/data/uploadfiles.yml) builds and uploads it
# beside the image assets, and anyvm.py downloads it at run time on Linux
# x86_64 hosts, pinned to THIS builder's release. Self-contained by design:
# every builder builds and publishes the artifacts its own guests need, and
# never reads another builder's files or release assets -- deleting any one
# builder must not affect any other builder or VM action.
set -e

QEMU_VER=10.2.3

OUTDIR="$1"
if [ -z "$OUTDIR" ]; then
  echo "usage: $0 <outdir>" >&2
  exit 1
fi
ROOT="$(pwd)"
mkdir -p "$OUTDIR"
OUT="$ROOT/$OUTDIR"
PATCH="$ROOT/files/qemu-sabre-irq-clobber.patch"
[ -s "$PATCH" ] || { echo "missing $PATCH" >&2; exit 1; }

SUDO=sudo
[ "$(id -u)" = 0 ] && SUDO=

export DEBIAN_FRONTEND=noninteractive
$SUDO apt-get update -qq
$SUDO apt-get install -y -qq build-essential ninja-build pkg-config \
  python3-venv libglib2.0-dev libpixman-1-dev libslirp-dev libfdt-dev \
  zlib1g-dev wget xz-utils zstd >/dev/null

WORK=$(mktemp -d /tmp/qemu-sparc64-build.XXXXXX)
echo "build dir: $WORK (left in place; /tmp is ephemeral)"
cd "$WORK"
wget -q "https://download.qemu.org/qemu-${QEMU_VER}.tar.xz"
tar xf "qemu-${QEMU_VER}.tar.xz"
cd "qemu-${QEMU_VER}"

patch -p1 < "$PATCH"

# Same feature trim as the other anyvm pinned-QEMU builds: no GUI, no docs,
# no storage/remote backends the runtime never uses; slirp + VNC + system
# fdt kept (anyvm drives guests over user networking and VNC).
./configure --target-list=sparc64-softmmu --prefix="$WORK/install" \
  --disable-docs --disable-gtk --disable-sdl --disable-opengl \
  --disable-virglrenderer --disable-spice --disable-smartcard \
  --disable-usb-redir --disable-libiscsi --disable-rbd --disable-glusterfs \
  --disable-libnfs --disable-seccomp --disable-linux-aio --disable-libusb \
  --disable-tpm --enable-slirp --enable-vnc --enable-fdt=system \
  > "$WORK/configure.log" 2>&1 || { tail -30 "$WORK/configure.log"; exit 1; }
make -j"$(nproc)" > "$WORK/make.log" 2>&1 || { tail -30 "$WORK/make.log"; exit 1; }
make install > /dev/null

pkg="$WORK/pkg"
mkdir -p "$pkg/qemu10-sparc64/bin" "$pkg/qemu10-sparc64/share/qemu"
cp "$WORK/install/bin/qemu-system-sparc64" "$pkg/qemu10-sparc64/bin/"
for f in openbios-sparc64 efi-e1000.rom; do
  cp "$WORK/install/share/qemu/$f" "$pkg/qemu10-sparc64/share/qemu/"
done
cp -r "$WORK/install/share/qemu/keymaps" "$pkg/qemu10-sparc64/share/qemu/keymaps"

"$pkg/qemu10-sparc64/bin/qemu-system-sparc64" --version | head -1
out="$OUT/qemu-${QEMU_VER}-sparc64-noble.tar.zst"
tar --zstd -cf "$out" -C "$pkg" qemu10-sparc64
ls -la "$out"
sha256sum "$out"
echo "build-qemu-sparc64: done"
