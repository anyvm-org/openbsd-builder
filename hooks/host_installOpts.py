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

waitForText("nstall, (")
string("a")
enter()

waitForText("Response file location")
string("http://192.168.122.1:8000/%s" % env("VM_OPTS"))
enter()

time.sleep(2)
waitForText("nstall or")
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
