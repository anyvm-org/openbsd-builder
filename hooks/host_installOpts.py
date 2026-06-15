# Unattended install driver for OpenBSD's bsd.rd installer.
#
# OpenBSD's installer is the same TUI on every release / arch; we drive it by:
#   1. waitForText "nstall, (" -> press 'a' (auto) + enter
#   2. waitForText "Response file location" -> type our URL + enter
#   3. waitForText "nstall or"               -> press 'i' (install) + enter
# Then the installer runs unattended off the .resp file fetched from the
# host's HTTP server.
#
# Arch-specific shutdown handling:
#   * aarch64 + console build: 7.3/4 reboot after install but 7.5/6 just
#     halt. Force a clean shutdown for the reboot-after-install case so
#     build.py's "wait for VM down" loop proceeds.
#   * riscv64: installer leaves you at the "(R)eboot, (S)hell or (H)alt?"
#     prompt; press 'h' to halt, then force shutdown if QEMU is still up.
#
# Host-side hook: run by base-builder/build.py via exec() in this module's
# globals -- waitForText / string / enter / isRunning / shutdownVM /
# destroyVM / env / time / log are bare names.

if env("VM_ARCH") == "sparc64":
    # sparc64 install runs with the RAMDISK kernel in UKC: build.py passes
    # boot-file="bsd -c" to OpenBIOS for the openbsd/sparc64 install, so the
    # kernel stops in its User Kernel Config editor before autoconfiguration.
    # Force the root disk (wd* at pciide*, RAMDISK config entry 68) to PIO
    # mode 4 / no DMA / no UltraDMA (flags 0x0ffc), so the install's concurrent
    # CD-read + disk-write does NOT wedge QEMU's sun4u cmd646 PCI-IDE into a
    # sustained "lost interrupt" write-timeout storm (which otherwise stalls
    # the install for the better part of an hour). The same flag is baked into
    # the installed /bsd by hooks/vm_finalize.sh (GENERIC entry 91) for the
    # runtime boot.
    #
    # Prompt quirks: the UKC prompt is "UKC>" (uppercase); the "change (y/n) ?"
    # confirm reads a SINGLE CHARACTER, so send "y" with NO enter (an extra CR
    # desyncs the channel/flags prompts that follow). Anchors use the bracketed
    # prompt forms ("channel [-1]", "flags [0xa00]") so they do not match the
    # device-display line ("channel -1 flags 0xa00", no brackets).
    waitForText("UKC>")
    string("change 68")
    enter()
    waitForText("(y/n)")
    string("y")
    waitForText("channel [-1]")
    enter()
    waitForText("flags [0xa00]")
    string("0xffc")
    enter()
    waitForText("changed")
    string("quit")
    enter()

waitForText("nstall, (")
string("a")
enter()

waitForText("Response file location")
string("http://192.168.122.1:8000/%s" % env("VM_OPTS"))
enter()

time.sleep(2)
# Wait for the post-response-file "(I)nstall or (U)pgrade?" prompt, then
# pick install. Anchor on "pgrade?" WITH the trailing question mark, NOT
# "nstall or": the very first menu -- "(I)nstall, (U)pgrade, (A)utoinstall
# or (S)hell?" -- is still on screen at this point (the console only
# scrolls a few lines), and its "Autoinstall or" substring matches
# "nstall or". The old anchor therefore fired 'i' immediately, while the
# response file was still downloading, so the keystroke was dropped and the
# real prompt was never answered -> the install hung forever. Only the
# install/upgrade prompt ends in "Upgrade?"; in the first menu it is
# "Upgrade," (comma), so "pgrade?" matches the right screen unambiguously.
#
# Why this prompt always appears here: autoinstall infers the mode from the
# response file NAME (install.conf vs upgrade.conf). Our files are named
# openbsd-<release>.resp, so the installer prints "Could not determine auto
# mode." and asks -- on every arch, serial and VNC alike.
waitForText("pgrade?")
string("i")
enter()

if env("VM_ARCH") == "aarch64" and env("VM_USE_CONSOLE_BUILD"):
    # 7.3/4 reboot after install; 7.5/6 just shut down. Force shutdown for
    # the reboot case so the pipeline proceeds.
    waitForText("Your OpenBSD install has been successfully completed")
    if isRunning() == 0:
        if shutdownVM() != 0:
            log("shutdown error")
        if destroyVM() != 0:
            log("destroyVM error")

if env("VM_ARCH") == "riscv64":
    waitForText("Your OpenBSD install has been successfully completed")
    # halt at the post-install (R)eboot/(S)hell/(H)alt prompt
    string("h")
    enter()
    time.sleep(10)
    if isRunning() == 0:
        if shutdownVM() != 0:
            log("shutdown error")
        if destroyVM() != 0:
            log("destroyVM error")

if env("VM_ARCH") == "sparc64":
    # Console build: the serial log is cumulative, so the success banner is
    # a reliable signal (no VNC/OCR 3s-poll race here). autoinstall reboots
    # on its own after the banner and -boot order=d would land back in the
    # installer's first menu, so force the VM down as soon as it shows.
    waitForText("Your OpenBSD install has been successfully completed")
    if isRunning() == 0:
        if shutdownVM() != 0:
            log("shutdown error")
        if destroyVM() != 0:
            log("destroyVM error")

if env("VM_ARCH") not in ("aarch64", "riscv64", "sparc64"):
    # amd64 / default x86 (VNC build). OpenBSD autoinstall installs the sets
    # and then REBOOTS -- it never powers off -- and the install ISO is still
    # first in the boot order (-boot order=dc), so the reboot lands back in
    # the installer's first menu instead of the freshly installed disk. The
    # pipeline's "wait for the install VM to power off" loop would then never
    # return.
    #
    # We do NOT key off the "...successfully completed!" banner here: on the
    # VNC path the screen is sampled by a 3s OCR poll, and the banner flashes
    # by faster than that before the reboot (reproducibly missed on CI, only
    # caught locally by luck). Instead we wait for the installer's FIRST MENU
    # to reappear after the post-install reboot -- it sits there waiting for
    # input, so it is a stable, long-lived signal. (aarch64/riscv64 use a
    # console/serial build whose log is cumulative, so their banner wait
    # above is reliable; only this VNC path needs the reboot-based signal.)
    #
    # Sleep first so the "answer i" residual first menu has been replaced by
    # the disk-setup screens before we start matching "utoinstall or"
    # (otherwise it would match the lingering first menu immediately and we'd
    # shut the VM down mid-install). The sets install takes minutes, so 60s
    # cannot overshoot into a real reboot.
    time.sleep(60)
    waitForText("utoinstall or")
    if isRunning() == 0:
        if shutdownVM() != 0:
            log("shutdown error")
        if destroyVM() != 0:
            log("destroyVM error")
