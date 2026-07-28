# Wait for the guest to reach the login prompt after a fresh boot.
#
# Host-side hook: run by base-builder/build.py via exec() in this module's
# globals. start_and_wait() invokes us right after openConsole().
#
# Two-stage wait: first match VM_LOGIN_TAG (e.g. "OpenBSD/amd64"), then
# look for the literal "logi" so we catch the actual login: prompt and not
# a banner that happens to embed the tag.

# Stage 1 is BEST EFFORT -- do not make it fatal. It legitimately times out in
# successful builds: 30 s is short, and CI tesseract regularly drops the leading
# capital (run 30265864696 green jobs logged "Timeout for text: penBSD/amd64"
# and "OpenBSD/sparc64" and still built fine).
waitForText(env("VM_LOGIN_TAG"), "30")

time.sleep(10)

# Stage 2 is the real gate, and it MUST be bounded and fatal.
#
# It used to be an unbounded waitForText("logi"): with no second argument
# waitForText polls forever, so a guest that panicked or installed nothing
# pinned the job until the 6 h CI ceiling or a human killed it. The identical
# line in midnightbsd-builder did exactly that on 2026-07-27 -- its 3.2.4 ISO
# panicked, nothing was installed, the disk had no bootloader, and the job hung
# 5 h 40 m here.
#
# Fatal is safe (unlike stage 1): across all 17 green jobs of run 30265864696
# "logi" was always found -- it never timed out in a build that worked.
#
# Why exit rather than return quietly: start_and_wait() treats the mere presence
# of a waitForLoginTag hook as success (`if run_hook(...): return 0`), so it
# applies neither VM_LOGIN_MAX_SECONDS nor its force-kill-and-reboot reroll
# here. Returning after a failed wait would march the pipeline on against a VM
# that never booted.
#
# The ceiling MUST be per-arch. Measured wall-clock from "Waiting for text:
# logi" to the prompt, across green runs 30265864696 and 30224606954:
#
#   amd64 (incl. every desktop conf) :   31 -  141 s
#   riscv64                          :   99 -  109 s
#   aarch64                          :  622 - 1070 s   <-- 10x the rest
#
# OpenBSD's arm64 first boot does fsck + the whole rc + sshd keygen under
# plain TCG (no KVM on the runners), and it is simply that slow. A flat 300 s
# looked generous against "always found" but was never checked against how
# LONG it took, and it killed all three aarch64 builds of run 30321977470
# while every other arch stayed green. These numbers are crash backstops, not
# performance budgets: size them well above the worst observed run.
obsd_login_max = "2400" if (env("VM_ARCH") or "") == "aarch64" else "600"
if waitForText("logi", obsd_login_max) != 0:
    log("FATAL: guest never reached a login prompt in %s s "
        "(no 'logi' on the console, arch=%s)."
        % (obsd_login_max, env("VM_ARCH") or "x86_64"))
    log("       The install most likely failed or the guest panicked -- check "
        "the screen dump above for 'panic:' or 'not a bootable disk'.")
    sys.exit(1)
