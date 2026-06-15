
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
if [ "$(uname -m)" = "sparc64" ]; then
  config -e -f /bsd <<'UKC'
change 91
y

0xffc
quit
UKC
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
