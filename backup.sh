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
cp /etc/systemd/system/camilladsp.service system/camilladsp.service
cp /etc/systemd/system/camillagui.service system/camillagui.service
cp /usr/local/bin/camilladsp bin/camilladsp

git add -A
if git diff --cached --quiet; then
    echo "Nothing changed since last backup."
    exit 0
fi
git commit -m "${1:-snapshot $(date '+%Y-%m-%d %H:%M')}"
git push
echo "Backed up and pushed."
