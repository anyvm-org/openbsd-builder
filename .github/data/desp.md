How the images are built:

Each image is built automatically in the
[anyvm-org/openbsd-builder](https://github.com/anyvm-org/openbsd-builder)
repo's GitHub Actions: it downloads the official OpenBSD install media
(`installXX.iso` / `installXX.img`), boots it in QEMU, answers the
installer unattended over the serial console, enables ssh, pre-installs
the packages listed in the conf, and exports the installed disk as a
compressed qcow2 image.

Upstream install media: the official OpenBSD releases from
https://cdn.openbsd.org/pub/OpenBSD/ (mirror list:
https://www.openbsd.org/ftp.html).
