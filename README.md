

[![Build](https://github.com/anyvm-org/openbsd-builder/actions/workflows/build.yml/badge.svg)](https://github.com/anyvm-org/openbsd-builder/actions/workflows/build.yml)

Latest: v2.0.9


The image builder for `openbsd`


All the supported releases are here:



| Release | x86_64 | aarch64(arm64) | riscv64 | sparc64 |
|---------|---------|---------|---------|---------|
| 7.9 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) |
| 7.8 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | — |
| 7.7 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | — |
| 7.6 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | — | — |
| 7.5 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | — | — |
| 7.4 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | — | — |
| 7.3 | ✅ (rsync,scp,sshfs,nfs,tar) | ✅ (rsync,scp,sshfs,nfs,tar) | — | — |

<!-- arch-label: aarch64 = aarch64(arm64) -->
<!-- desktop-header: OpenBSD desktop images (x86_64): -->

> **Note:** OpenBSD 7.2 and 7.9-xfce-aarch64 confs are kept on disk but
> deliberately shelved (undocumented -- no table row, no releases.json
> entry). Verified against `git show HEAD:.github/data/table.md`: no 7.2
> row has ever been published (7.2 has no aarch64 variant to begin with).
> 7.9-xfce-aarch64 is shelved for the same reason -- `git show
> HEAD:.github/data/desktop.md` shows the aarch64 column as absent (dash)
> for every 7.9 desktop variant row, i.e. no verified aarch64 XFCE image.
<!-- shelved: 7.2 -->
<!-- shelved: 7.9-xfce-aarch64 -->

> **Note:** OpenBSD 7.3-7.6 (x86_64 and aarch64) are documented and
> already tested elsewhere -- their images are served by the vmactions
> fallback repo, and anyvm's own openbsd.yml test matrix already covers
> them -- but this builder's own CI matrix does not build them: their tags
> are deliberately left OUT of conf/all.release.conf (the hand-owned build
> membership; the table row and releases.json entry stay, with
> releases.json marking them "build": false).

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



OpenBSD desktop images (x86_64):

| Release | x86_64 | aarch64(arm64) | riscv64 | sparc64 |
|---------|---------|---------|---------|---------|
| 7.9-xfce | ✅ | — | — | — |
| 7.9-mate | ✅ | — | — | — |
| 7.9-lxqt | ✅ | — | — | — |
| 7.9-lumina | ✅ | — | — | — |
| 7.9-kde6 | ✅ | — | — | — |
| 7.9-gnome | ✅ | — | — | — |
| 7.9-enlightenment | ✅ | — | — | — |



How to build:

1. Use the [manual.yml](.github/workflows/manual.yml) to build manually.
   
    Run the workflow manually, you will get a view-only webconsole from the output of the workflow, just open the link in your web browser.
   
    You will also get an interactive VNC connection port from the output, you can connect to the vm by any vnc client.

2. Run the builder locally on your Ubuntu machine.

    Just clone the repo. and run:
    ```bash
    python3 build.py conf/openbsd-7.9.conf
    ```
   
