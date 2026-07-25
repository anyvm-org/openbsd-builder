#!/bin/bash
# host-side beforeBuild hook -- the earliest hook point in build.py's
# pipeline, before setup() runs.
#
# Generates the two sparc64 binaries on the fly; neither is committed to
# git, bios/ and files/ carry only the patches and the build scripts. CI
# compiles them per build HERE, and the release-files job in
# .github/data/uploadfiles.yml compiles the same ones when publishing them
# as release assets -- so what ships is exactly what the images were built
# and verified on, and a broken artifact fails a build instead of reaching
# users at run time.
#
#  1. VM_QEMU_TAR -- the patched qemu-system-sparc64 the BUILD ITSELF runs
#     on. GitHub runners ship stock QEMU 8.2, whose sun4u sabre PCI-host
#     has the single-slot IRQ-clobber bug
#     (files/qemu-sabre-irq-clobber.patch): under concurrent cmd646 IDE +
#     e1000 DMA the guest's interrupt-clear is dropped and both devices'
#     interrupts wedge ("wd0(pciide0:0:0): timeout" / "em0: watchdog").
#     setup() extracts the tarball next and VM_QEMU_BIN (set in the conf)
#     points at the binary, so every VM in the pipeline runs on it.
#  2. VM_BIOS -- the patched OpenBIOS blob the guest needs to cold-boot.
#
# Everything is built from upstream sources by THIS builder's own scripts
# -- no reference to any sibling builder (user policy).

set -e

# VM_QEMU_TAR names the output tarball; its dirname is the outdir.
if [ -n "${VM_QEMU_TAR:-}" ] && [ ! -e "$VM_QEMU_TAR" ]; then
  echo "host_beforeBuild: building patched sparc64 QEMU -> $VM_QEMU_TAR"
  bash files/build-qemu-sparc64.sh "$(dirname "$VM_QEMU_TAR")"
  test -e "$VM_QEMU_TAR"
fi

if [ -z "${VM_BIOS:-}" ]; then
  exit 0
fi
if [ -e "$VM_BIOS" ]; then
  echo "host_beforeBuild: $VM_BIOS already present, skipping firmware build"
  exit 0
fi

case "$VM_BIOS" in
  bios/openbios-sparc64.elf)
    echo "host_beforeBuild: building $VM_BIOS"
    bash bios/build-openbios.sh
    ;;
  *)
    echo "host_beforeBuild: do not know how to build VM_BIOS=$VM_BIOS" >&2
    exit 1
    ;;
esac
test -e "$VM_BIOS"
