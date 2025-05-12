![Screenshot from 2025-05-11 07-08-38](https://github.com/user-attachments/assets/a2609ec0-e390-4090-98ec-73cac5060836)
# Universal-NialWRT Build Script

Universal-NialWRT is an automated firmware build script supporting OpenWrt, OpenWrt-IPQ, and ImmortalWrt. Designed for ease of use, recovery, and flexibility, it allows users to select a distribution, clone its source, manage feeds, and compile — all while handling errors gracefully.

## Features

- Choose between OpenWrt, OpenWrt-IPQ, and ImmortalWrt.
- Automatically installs required build dependencies.
- Smart feed handling with retry mechanism.
- Supports custom feeds before installation.
- Lists and checks out any available tag or branch with fallback.
- Preset `.config` support for OpenWrt-IPQ.
- Error recovery: script waits for manual fixes and resumes automatically.
- Loop retry until build is successful.
- Cleanup mode to remove build directory and the script itself.

## Requirements

- Ubuntu 22.04 or newer
- Minimum: 2 CPU cores, 4GB RAM, 50GB storage
- Internet access for downloading sources and feeds

## Credits

Special thanks to the following open-source projects and communities:

- [OpenWrt](https://openwrt.org/) — The original embedded Linux firmware project.
- [OpenWrt-IPQ by Qosmio](https://github.com/qosmio/openwrt-ipq) — A performance-tuned OpenWrt fork for IPQ-based SoCs.
- [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) — A community-maintained fork of OpenWrt with enhanced package and device support.

**All credit goes to the respective developers and contributors of these projects. Universal-NialWRT is only a build automation layer.**

## Setup

```bash
wget https://raw.githubusercontent.com/nialwrt/UNIVERSAL-NIALWRT/main/universal-nialwrt.sh && chmod +x universal-nialwrt.sh && ./universal-nialwrt.sh
