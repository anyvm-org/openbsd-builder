# Wait for the guest to reach the login prompt after a fresh boot.
#
# Host-side hook: run by base-builder/build.py via exec() in this module's
# globals. start_and_wait() invokes us right after openConsole().
#
# Two-stage wait: first match VM_LOGIN_TAG (e.g. "OpenBSD/amd64"), then
# look for the literal "logi" so we catch the actual login: prompt and not
# a banner that happens to embed the tag.

waitForText(env("VM_LOGIN_TAG"), "30")

time.sleep(10)

waitForText("logi")
