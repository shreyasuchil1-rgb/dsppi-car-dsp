#!/bin/bash
# Zero-interaction first-boot restore for the dsppi car DSP.
#
# On a freshly flashed Raspberry Pi OS (user dsppi, network up), run:
#
#   curl -fsSL https://raw.githubusercontent.com/shreyasuchil1-rgb/dsppi-car-dsp/main/bootstrap.sh | sudo bash
#
# Installs git, clones this repo to /home/dsppi/camilladsp, runs restore.sh
# (raspotify, boot config, ALSA loopback, CamillaDSP + GUI services), reboots.

set -euo pipefail

REPO_URL="https://github.com/shreyasuchil1-rgb/dsppi-car-dsp.git"
TARGET="/home/dsppi/camilladsp"

if [ "$EUID" -ne 0 ]; then
    echo "Run me with sudo (curl ... | sudo bash)"
    exit 1
fi

echo "==> Installing git"
apt-get update
apt-get install -y git curl

if [ -d "$TARGET/.git" ]; then
    echo "==> $TARGET already cloned, pulling latest"
    sudo -u dsppi git -C "$TARGET" pull --ff-only
else
    echo "==> Cloning snapshot to $TARGET"
    sudo -u dsppi git clone "$REPO_URL" "$TARGET"
fi

echo "==> Running restore"
"$TARGET/restore.sh"

echo "==> Rebooting in 5 seconds (Ctrl-C to cancel)"
sleep 5
reboot
