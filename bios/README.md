# Patched OpenBIOS for OpenBSD/sparc64 under QEMU sun4u

`openbios-sparc64.elf` (md5 `a252db80f6b7ec9d2ebaab478191ab4e`) replaces the
OpenBIOS image bundled with QEMU. The sparc64 build pipeline passes it via
`-bios` (conf sets `VM_BIOS="bios/openbios-sparc64.elf"`), and any runtime
that boots the produced qcow2 must do the same.

## Why a patched firmware is required

OpenBSD 7.3 made the `call-method "map"` OpenFirmware invocation
spec-compliant (`nreturns = 0`) in both ofwboot and the kernel's
`prom_map_phys()`, and removed the two spare return cells from the argument
struct (openbsd/src commits `763065e94a` and `489b7dbe7d`, both referencing
NetBSD PR#56829). OpenBIOS's client interface (`handle_calls()` in
`libopenbios/client.c`) stores the catch result with
`pb->args[pb->nargs] = val;` UNCONDITIONALLY -- with the shrunk struct that
is an out-of-bounds write 8 bytes past the caller's stack struct on every
single map call. Result: every OpenBSD >= 7.3 GENERIC kernel crashes on
cold boot with `Unhandled Exception 0x30` right after the ELF symbol table
is loaded (reported on bugs@ for 7.3, 7.4 and 7.6; OpenBSD considers it a
QEMU bug; not fixed upstream as of 2026-06, QEMU master's blob crashes
identically). 7.2 survived only because its argument struct still had the
spare cells that absorbed the stray store.

A second, independent problem: OpenBIOS names IDE channel nodes `ide@x,0`
while real Sun OBP names them `ata@x`. OpenBSD's `device_register()`
(sys/arch/sparc64/sparc64/autoconf.c) only consumes the channel+disk
bootpath pair through its `"ata"` branch, so with the stock blob the kernel
cannot match the boot disk and stops at an interactive `root device:`
prompt on every boot.

## What the patch changes

Base revision: `af97fd7af5e7c18f591a7b987291d3db4ffb28b5` -- exactly the
OpenBIOS submodule revision QEMU 8.2.2 bundles (ubuntu-24.04 runners), so
the device tree matches what the bundled blob produces apart from the fixes.
See `openbios-sparc64.patch` for the full diff:

1. `libopenbios/client.c` `handle_calls()`: only store the catch result if
   the client asked for at least one return cell (`if (pb->nret > 0)`).
   This alone takes a stock 7.9 install from crash-on-every-boot to full
   multiuser.
2. `config/examples/sparc64_config.xml`: `CONFIG_IDE_DEV_NAME = "ata"`, so
   the bootpath becomes `/pci@1fe,0/pci@1,1/ide@3,0/ata@0,0/disk@0,0` and
   the kernel auto-roots on wd0a. (The ppc configs already use `ata` for
   Apple OF compatibility; the option existed, sparc64 just never set it.)
3. `config/scripts/switch-arch`: add `-fno-stack-protector -fno-pic` to the
   sparc64 CFLAGS. Build-environment fix only: upstream added the same
   flags on master in 2024 (commits `1de3e55fc9`, `564e579553`); without
   `-fno-pic`, modern Debian/Ubuntu cross compilers emit PIC code and the
   resulting firmware traps at PC=0 immediately.

## Rebuilding

On Ubuntu (24.04 verified):

    apt-get install gcc-sparc64-linux-gnu fcode-utils xsltproc
    git clone https://github.com/openbios/openbios.git
    cd openbios
    git checkout af97fd7af5e7c18f591a7b987291d3db4ffb28b5
    git apply ../openbios-sparc64.patch
    ./config/scripts/switch-arch cross-sparc64
    make
    # result: obj-sparc64/openbios-builtin.elf

OpenBIOS is GPLv2; the complete corresponding source is the upstream
repository at the revision above plus `openbios-sparc64.patch` in this
directory.

## Verified

2026-06-10, WSL Ubuntu 24.04, qemu-system-sparc64 8.2.2: stock OpenBSD 7.9
sparc64 autoinstall (cd0 sets) + this blob boots unattended to the login
prompt (`root on wd0a`, `uname -a` = `OpenBSD 7.9 GENERIC#160 sparc64`) and
`halt -p` shuts down cleanly. The fix candidate is upstreamable to OpenBIOS.
