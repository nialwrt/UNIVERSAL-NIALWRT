![Screenshot from 2025-05-11 07-08-38](https://github.com/user-attachments/assets/a2609ec0-e390-4090-98ec-73cac5060836)
# UNIVERSAL-NIALWRT

**Source:** ImmortalWrt  
**Target OS:** Ubuntu 22.04 LTS or newer

## Overview

UNIVERSAL-NIALWRT is a minimal and clean automation script that simplifies the process of building OpenWrt firmware based on ImmortalWrt. It is intended for advanced users who prefer full control over system customization and package selection.

## Features

- **Minimal Base Setup**  
  Provides a clean starting point with only the essentials, allowing full user control.

- **Flexible Configuration**  
  Customize everything through `make menuconfig`, including packages, kernel, and system options.

- **Standalone Script**  
  No dependencies on other scripts or projects — everything is handled within this script.

## Requirements

- Ubuntu 22.04 LTS or newer
- Internet connection
- Adequate disk space and RAM
- Basic terminal usage knowledge

## Quick Installation

Open your terminal and run:

```bash
wget https://raw.githubusercontent.com/nialwrt/UNIVERSAL-NIALWRT/main/universal-nialwrt.sh && chmod +x universal-nialwrt.sh && ./universal-nialwrt.sh
