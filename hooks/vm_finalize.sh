
set -e 
#make sure the packages are installed
pkg_info -e rsync-*
pkg_info -e  sshfs-fuse-*

#remove root password
sed -i 's|$2b$10$qS3/zFLn/6wTQrjNhAddEepvKw.XculyRsXH60FLXjcj5fQeZzIQu||' /etc/master.passwd
pwd_mkdb -p /etc/master.passwd

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
