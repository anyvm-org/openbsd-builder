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
> them -- but this builder's own CI matrix does not build them, so they are
> no-build rather than shelved: the table row and releases.json entry stay
> (releases.json marks them "build": false). Verified against `git show
> HEAD:.github/data/table.md`: every 7.3-7.6 row already showed a green
> check for BOTH x86_64 and aarch64 with sync methods
> "rsync,scp,sshfs,nfs", which matches each conf's own VM_SYNC_METHODS
> exactly -- no discrepancy found between the hand-written HEAD cells and
> the confs' actual sync methods.
<!-- no-build: 7.3 -->
<!-- no-build: 7.3-aarch64 -->
<!-- no-build: 7.4 -->
<!-- no-build: 7.4-aarch64 -->
<!-- no-build: 7.5 -->
<!-- no-build: 7.5-aarch64 -->
<!-- no-build: 7.6 -->
<!-- no-build: 7.6-aarch64 -->
