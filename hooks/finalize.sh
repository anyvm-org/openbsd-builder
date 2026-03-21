


#remove root password
sed -i 's|$2b$10$qS3/zFLn/6wTQrjNhAddEepvKw.XculyRsXH60FLXjcj5fQeZzIQu||' /etc/master.passwd
pwd_mkdb -p /etc/master.passwd

# Zero unused disk space on filesystems that have had activity.
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
  swapctl -d $swap
  dd if=/dev/zero of=$swap bs=1024k >/dev/null 2>&1
fi

#enable autologin with root in the console
#echo "su - root" >>/etc/rc.local


exit 0
