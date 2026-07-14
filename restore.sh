#!/bin/bash
# Restore the dsppi audio setup onto a fresh Raspberry Pi OS flash.
#
# Usage (on a fresh Pi, as user dsppi):
#   git clone <your-repo-url> ~/camilladsp
#   cd ~/camilladsp && sudo ./restore.sh
#   sudo reboot
#
# Assumes: Raspberry Pi 5, HiFiBerry DAC8x HAT attached (overlay auto-loads
# from the HAT EEPROM, so no dtoverlay line is needed for it).

set -euo pipefail
cd "$(dirname "$0")"

if [ "$EUID" -ne 0 ]; then
    echo "Run with sudo: sudo ./restore.sh"
    exit 1
fi

echo "==> Raspotify (Spotify Connect)"
if ! dpkg -s raspotify >/dev/null 2>&1; then
    apt-get update
    apt-get install -y curl
    curl -sL https://dtcooper.github.io/raspotify/install.sh | sh
fi
install -m 600 -o root -g root system/raspotify.conf /etc/raspotify/conf
systemctl enable raspotify

echo "==> Boot config (disables onboard/HDMI audio, loads nospi10 overlay)"
cp system/config.txt /boot/firmware/config.txt
cp system/nospi10.dtbo /boot/firmware/overlays/nospi10.dtbo

echo "==> Ethernet P2P profile (direct cable to laptop -> http://10.55.0.1:5005)"
install -m 600 -o root -g root system/eth-p2p.nmconnection \
    /etc/NetworkManager/system-connections/eth-p2p.nmconnection
nmcli connection reload || true

echo "==> ALSA loopback module + default device"
cp system/snd-aloop.conf /etc/modules-load.d/snd-aloop.conf
cp system/asound.conf /etc/asound.conf
modprobe snd-aloop || true

echo "==> CamillaDSP binary"
install -m 755 bin/camilladsp /usr/local/bin/camilladsp

echo "==> GUI backend executable bit"
chmod +x camillagui_backend/camillagui_backend

echo "==> systemd services"
cp system/camilladsp.service /etc/systemd/system/
cp system/camillagui.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable camilladsp camillagui

echo "==> Groups"
usermod -aG audio dsppi

echo
echo "Done. Reboot to bring everything up:  sudo reboot"
echo "After reboot: CamillaDSP on port 1234, GUI via camillagui service."
