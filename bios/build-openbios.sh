#!/bin/bash
# Build the patched OpenBIOS blob OpenBSD/sparc64 needs under QEMU sun4u
# and place it at bios/openbios-sparc64.elf.
#
# The ~700KB binary is NOT committed to git -- this directory only carries
# the patch (the actual fix, see bios/README.md for the full story) and
# this script. hooks/host_beforeBuild.sh runs it when a conf sets VM_BIOS
# and the blob is missing, and the release-files job in
# .github/data/uploadfiles.yml runs it before publishing the blob as a
# release asset (anyvm's runtime downloads it from there).
#
# Source: upstream OpenBIOS at the exact revision QEMU 8.2.2 bundles
# (so the produced device tree matches the stock blob apart from the
# fixes) plus bios/openbios-sparc64.patch.
#
# Intended host: ubuntu-24.04 (noble), the GitHub Actions runner image;
# needs the sparc64-linux-gnu cross toolchain from apt.

set -e

OPENBIOS_REV=af97fd7af5e7c18f591a7b987291d3db4ffb28b5

BIOS_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$BIOS_DIR/openbios-sparc64.elf"
PATCH="$BIOS_DIR/openbios-sparc64.patch"

SUDO=sudo
[ "$(id -u)" = 0 ] && SUDO=
export DEBIAN_FRONTEND=noninteractive
$SUDO apt-get update -qq
$SUDO apt-get install -y -qq build-essential git gcc-sparc64-linux-gnu \
  fcode-utils xsltproc >/dev/null

WORK=$(mktemp -d /tmp/openbios-build.XXXXXX)
echo "build dir: $WORK (left in place; /tmp is ephemeral)"
cd "$WORK"
git init -q openbios
cd openbios
git remote add origin https://github.com/openbios/openbios.git
# GitHub serves arbitrary commits by sha to shallow fetches; fall back to
# a full fetch if that is ever disabled.
if ! git fetch -q --depth 1 origin "$OPENBIOS_REV"; then
  git fetch -q origin
fi
git checkout -q "$OPENBIOS_REV"
git apply "$PATCH"

./config/scripts/switch-arch cross-sparc64 > "$WORK/configure.log" 2>&1 \
  || { tail -20 "$WORK/configure.log"; exit 1; }
make > "$WORK/make.log" 2>&1 || { tail -30 "$WORK/make.log"; exit 1; }

cp obj-sparc64/openbios-builtin.elf "$OUT"
ls -la "$OUT"
md5sum "$OUT"
sha256sum "$OUT"
echo "build-openbios: done"
