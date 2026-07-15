#some tasks run in the VM as soon as the vm is up


echo 'pkg_scripts=""' >>/etc/rc.conf.local


# Point pkg_add(1) and syspatch(8) at the Cloudflare mirror instead of
# cdn.openbsd.org (Fastly). Both are official OpenBSD mirrors -- adjacent
# entries in ftplist.cgi -- but the Fastly path is several times slower and
# has a long tail where throughput collapses to ~0.1 MB/s on an already-cached
# object. For a user that is CI wall-clock swinging from 7 to 25+ min purely on
# package download. See vmactions/openbsd-vm#35.
#
# This is set here rather than through the "HTTP Server" answer in the .resp
# files because install.sub only derives /etc/installurl when the sets are
# fetched over HTTP: the sparc64 image installs from cd0, so it would silently
# keep install.sub's hardcoded cdn.openbsd.org default. Writing the file
# directly covers every arch and install method the same way.
#
# Runs before syspatch below and before VM_PRE_INSTALL_PKGS, so the build
# itself gets the faster mirror too.
echo "https://cloudflare.cdn.openbsd.org/pub/OpenBSD" >/etc/installurl


#openbsd doesn't support syspatch for riscv64
#https://cdn.openbsd.org/pub/OpenBSD/syspatch/7.8/
if [ "$(uname -m)" != "riscv64" ] || [ "$VM_RELEASE" = "7.7" ]; then
  sleep 20
  while ps aux | grep "[m]ake new"; do
    echo "reorder_kernel is running, just wait"
    sleep 5
  done
  
  echo "OK, start syspatch"
  
  syspatch
  syspatch
  
  ret="$?"
  #0 means ok
  #2 means no update
  if [ "$ret" != "2" ] && [ "$ret" != "0" ]; then
    echo "update error"
    ps aux
    exit $ret
  fi
fi








