
set -e 
#make sure the packages are installed
pkg_info -e rsync-*
pkg_info -e  sshfs-fuse-*

#remove root password
sed -i 's|$2b$10$qS3/zFLn/6wTQrjNhAddEepvKw.XculyRsXH60FLXjcj5fQeZzIQu||' /etc/master.passwd
pwd_mkdb -p /etc/master.passwd

# OpenBSD/sparc64 only: disable disk DMA and force PIO on the root disk.
# Under QEMU's sun4u cmd646 PCI-IDE, concurrent DMA on the two channels
# (disk write + network during boot, or CD read + disk write during install)
# wedges the controller into a sustained "lost interrupt" write-timeout storm
# that stalls boot and shutdown -- fatal for the anyvm runtime boot probe.
# GENERIC sets `wd* at pciide*` (UKC config entry 91 in 7.9/sparc64 GENERIC)
# flags 0xa00 = force UltraDMA mode 2; rewrite to 0x0ffc = PIO mode 4, no DMA,
# no UltraDMA. config(8) -e reads its UKC commands from stdin, so a here-doc
# drives it non-interactively; the blank line takes the "channel" locator
# default. The entry number is GENERIC-layout-specific: if the OpenBSD release
# changes, re-derive it with `config -e -f /bsd` then `find wd*`. Verified
# afterwards as "wd0(pciide0:0:0): using PIO mode 4" (no Ultra-DMA).
#
# CRITICAL ordering vs KARL: OpenBSD relinks /bsd at boot (reorder_kernel) to
# randomize the kernel layout. That relink rebuilds /bsd from the original
# object files -- WITHOUT our flag -- and installs it over /bsd. On sparc64
# under TCG the relink is slow (~7 min) and can finish AFTER this config -e,
# silently reverting /bsd to DMA, so the exported image storms on its first
# (verify / runtime) boot. Wait for any in-flight relink to finish FIRST, so
# our config -e is the last write to /bsd. (Cap the wait so a stuck relink
# cannot hang the build forever.)
if [ "$(uname -m)" = "sparc64" ]; then
  _i=0
  while ps axww 2>/dev/null | grep -qE '[r]eorder_kernel|[m]ake new'; do
    echo "finalize: waiting for KARL kernel relink to finish ($_i)"
    sleep 10
    _i=$((_i + 1))
    [ "$_i" -ge 120 ] && { echo "finalize: relink wait cap hit, proceeding"; break; }
  done
  config -e -f /bsd <<'UKC'
change 91
y

0xffc
quit
UKC
  # Disable OpenBSD's first-boot reordering. Even with the disk on PIO, the
  # heavy concurrent disk I/O of the boot-time ld.so/libc library reorder
  # ("reordering: ..." in /etc/rc, gated by library_aslr) by itself wedges
  # QEMU's sun4u cmd646 into wd0 command timeouts, so the freshly-shipped
  # image never becomes ssh-reachable on its first (verify / runtime) boot.
  # The kernel relink (KARL, /usr/libexec/reorder_kernel, run unconditionally
  # at the end of /etc/rc) does the same heavy I/O AND rebuilds /bsd from the
  # original objects, reverting the PIO flag set just above. Turn both off:
  #   * library_aslr=NO  -> reorder_libs() returns early.
  #   * move the kernel relink kit aside -> reorder_kernel finds nothing.
  # The first boot then does minimal disk I/O and comes up clean, and /bsd
  # stays permanently PIO. ASLR is a security feature; disabling it is an
  # accepted tradeoff for a throwaway QEMU sun4u test image that otherwise
  # cannot boot. (sparc64 only.)
  grep -q '^library_aslr=NO' /etc/rc.conf.local 2>/dev/null || \
      echo 'library_aslr=NO' >> /etc/rc.conf.local
  if [ -d /usr/share/relink/kernel ]; then
    mv /usr/share/relink/kernel /usr/share/relink/kernel.disabled
  fi
fi

# Zero unused disk space on filesystems that have had activity, so the
# exported qcow2 compresses well. amd64 only: the TCG arches (arm64,
# riscv64, sparc64) write at emulated-disk speed and this step would
# dominate the whole build, so they skip it and accept a slightly larger
# image.
if [ "$(uname -m)" = "amd64" ]; then
  for fs in / /usr /var /tmp; do
    echo zeroing unused space on $fs
    dd if=/dev/zero of=$fs/zero bs=1024k >/dev/null 2>&1 || true
    sync; sync; sync
    rm -f $fs/zero
  done

  # Clear swap space
  swap=$(swapctl -l | awk '/^\/dev/ {print $1}')
  if [ ! -z "$swap" ]; then
    echo zeroing swap $swap
    swapctl -d $swap || true
    dd if=/dev/zero of=$swap bs=1024k >/dev/null 2>&1 || true
  fi
fi

#enable autologin with root in the console
#echo "su - root" >>/etc/rc.local

# Wipe the shell history accumulated during the build (console login,
# enablessh, package steps) so the shipped image starts clean. Cover root
# and any pre-created users; ksh/sh and bash spellings.
unset HISTFILE
for h in /root/.sh_history /root/.ksh_history /root/.bash_history \
         /home/*/.sh_history /home/*/.ksh_history /home/*/.bash_history; do
  rm -f "$h"
done

exit 0
