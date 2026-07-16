#!/bin/bash
# Snapshot the live system files into the repo and push.
# Run any time you change something outside this directory
# (boot config, services, ALSA setup, camilladsp binary upgrade).
#
# Usage: ./backup.sh ["commit message"]

set -euo pipefail
cd "$(dirname "$0")"

cp /boot/firmware/config.txt system/config.txt
cp /boot/firmware/overlays/nospi10.dtbo system/nospi10.dtbo
cp /etc/asound.conf system/asound.conf
cp /etc/modules-load.d/snd-aloop.conf system/snd-aloop.conf
sudo cp /etc/raspotify/conf system/raspotify.conf && sudo chown "$USER" system/raspotify.conf && chmod 644 system/raspotify.conf
cp /etc/shairport-sync.conf system/shairport-sync.conf
sudo cp /etc/NetworkManager/system-connections/eth-p2p.nmconnection system/eth-p2p.nmconnection && sudo chown "$USER" system/eth-p2p.nmconnection && chmod 644 system/eth-p2p.nmconnection
cp /etc/systemd/system/camilladsp.service system/camilladsp.service
cp /etc/systemd/system/camillagui.service system/camillagui.service
cp /usr/local/bin/camilladsp bin/camilladsp
cp /etc/systemd/system/oled-display.service system/oled-display.service
cp /usr/local/bin/oled-spotify-event bin/oled-spotify-event
cp ~/oled/display.py bin/oled-display.py

git add -A
if git diff --cached --quiet; then
    echo "Nothing changed since last backup."
    exit 0
fi
git commit -m "${1:-snapshot $(date '+%Y-%m-%d %H:%M')}"
git push
echo "Backed up and pushed."
