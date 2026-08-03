

| Release | x86_64 | aarch64(arm64) | riscv64 | sparc64 |
|---------|---------|---------|---------|---------|
| 7.9 | ✅ (rsync,scp,sshfs,nfs) | ✅ (rsync,scp,sshfs,nfs) | ✅ (rsync,scp,sshfs,nfs) | ✅ (rsync,scp,sshfs,nfs) |
| 7.8 | ✅ (rsync,scp,sshfs,nfs) | ✅ (rsync,scp,sshfs,nfs) | ✅ (rsync,scp,sshfs,nfs) | — |
| 7.7 | ✅ (rsync,scp,sshfs,nfs) | ✅ (rsync,scp,sshfs,nfs) | ✅ (rsync,scp,sshfs,nfs) | — |
| 7.6 | ✅ (rsync,scp,sshfs,nfs) | ✅ (rsync,scp,sshfs,nfs) | — | — |
| 7.5 | ✅ (rsync,scp,sshfs,nfs) | ✅ (rsync,scp,sshfs,nfs) | — | — |
| 7.4 | ✅ (rsync,scp,sshfs,nfs) | ✅ (rsync,scp,sshfs,nfs) | — | — |
| 7.3 | ✅ (rsync,scp,sshfs,nfs) | ✅ (rsync,scp,sshfs,nfs) | — | — |

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
