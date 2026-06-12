#!/bin/bash
# host-side beforeBuild hook -- the earliest hook point in build.py's
# pipeline, before setup() runs.
#
# Generates the patched OpenBIOS blob on the fly when the conf asks for
# one (VM_BIOS): the binary is NOT committed to git -- bios/ only carries
# the patch and build-openbios.sh. CI compiles the blob per build here,
# and the release-files job in .github/data/uploadfiles.yml compiles the
# same blob when publishing it as a release asset.

set -e

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
