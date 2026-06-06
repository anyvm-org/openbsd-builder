

[![Build](https://github.com/anyvm-org/openbsd-builder/actions/workflows/build.yml/badge.svg)](https://github.com/anyvm-org/openbsd-builder/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/anyvm-org/openbsd-builder?include_prereleases&sort=semver)](https://github.com/anyvm-org/openbsd-builder/releases)

Latest: v2.0.3


The image builder for `openbsd`


All the supported releases are here:



| Release | x86_64  | aarch64(arm64) | riscv64 |
|---------|---------|---------|----------------|
| 7.9     |  ✅     |   ✅   |           ✅  |
| 7.9-xfce  |  ✅     |   ❌   |           ❌  |
| 7.9-gnome |  ✅     |   ❌   |           ❌  |
| 7.9-kde6  |  ✅     |   ❌   |           ❌  |
| 7.9-mate  |  ✅     |   ❌   |           ❌  |
| 7.9-lxqt  |  ✅     |   ❌   |           ❌  |
| 7.9-lumina  |  ✅     |   ❌   |           ❌  |
| 7.9-enlightenment  |  ✅     |   ❌   |           ❌  |
| 7.8     |  ✅     |   ✅   |           ✅  |
| 7.7     |  ✅     |   ✅   |           ✅  |
| 7.6     |  ✅     |   ✅   |           ❌  |
| 7.5     |  ✅     |   ✅   |           ❌  |
| 7.4     |  ✅     |   ✅   |           ❌  |
| 7.3     |  ✅     |   ✅   |           ❌  |







How to build:

1. Use the [manual.yml](.github/workflows/manual.yml) to build manually.
   
    Run the workflow manually, you will get a view-only webconsole from the output of the workflow, just open the link in your web browser.
   
    You will also get an interactive VNC connection port from the output, you can connect to the vm by any vnc client.

2. Run the builder locally on your Ubuntu machine.

    Just clone the repo. and run:
    ```bash
    python3 build.py conf/openbsd-7.9.conf
    ```
   
