![Screenshot from 2025-05-11 07-08-38](https://github.com/user-attachments/assets/a2609ec0-e390-4090-98ec-73cac5060836)
[![Status](https://img.shields.io/badge/Status-Stable-green.svg)](https://github.com/nialwrt/UNIVERSAL-NIALWRT)
[![License](https://img.shields.io/badge/License-GPLv2-blue.svg)](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html)
[![Maintenance](https://img.shields.io/badge/Maintained-Yes-brightgreen.svg)](https://github.com/nialwrt/UNIVERSAL-NIALWRT)

## UNIVERSAL-NIALWRT Firmware Builder

**Universal-NialWRT** automates firmware builds for OpenWrt, OpenWrt-IPQ, and ImmortalWrt, focusing on ease of use and error recovery.

## Key Features

* Supports OpenWrt, OpenWrt-IPQ, and ImmortalWrt.
* Automated dependency installation.
* Smart feed handling with retry.
* Custom feed support.
* Git branch/tag selection with fallback.
* Preset `.config` for OpenWrt-IPQ.
* Pauses for manual error correction.
* Iterative build attempts.
* Optional cleanup mode.

## System Requirements

* Ubuntu 22.04+.
* Min: 2 CPU cores, 4GB RAM, 50GB storage.
* Internet access.

## Credits

Thanks to:

* [OpenWrt](https://openwrt.org/)
* [OpenWrt-IPQ](https://github.com/qosmio/openwrt-ipq)
* [ImmortalWrt](https://github.com/immortalwrt/immortalwrt)

All заслуга to their developers.

## Setup

```bash
wget https://raw.githubusercontent.com/nialwrt/UNIVERSAL-NIALWRT/main/universal-nialwrt.sh && chmod +x universal-nialwrt.sh && ./universal-nialwrt.sh
