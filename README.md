# dsppi — CamillaDSP car audio setup

Full snapshot of the Raspberry Pi 5 + HiFiBerry DAC8x DSP rig for the
Chevy Cruze (4-way front + rear fill + dual subs).

## Restore after a brick

1. Flash Raspberry Pi OS (64-bit) with user `dsppi`, boot, connect network.
2. ```
   sudo apt update && sudo apt install -y git
   git clone <this-repo-url> ~/camilladsp
   cd ~/camilladsp && sudo ./restore.sh
   sudo reboot
   ```

That's it — services, boot config, ALSA loopback, binary and configs all
come from this repo.

## Layout

| Path | What |
|---|---|
| `config.yml` | Live CamillaDSP config (loaded by the service) |
| `configs/` | Saved configs, incl. `car_8ch.yml` (8-ch car crossover) |
| `coeffs/` | FIR coefficients |
| `camillagui_backend/` | CamillaGUI web UI (compiled bundle) |
| `bin/camilladsp` | CamillaDSP 4.1.3 aarch64 binary |
| `system/` | Copies of `/boot/firmware/config.txt`, `nospi10.dtbo`, `asound.conf`, `snd-aloop.conf`, systemd units |
| `backup.sh` | Re-copy live system files, commit, push |
| `restore.sh` | Put everything back on a fresh OS |

## Signal flow

Sources play to `plughw:Loopback,0,0` → CamillaDSP captures `hw:Loopback,1,0`
→ processes → plays to `hw:sndrpihifiberry` (DAC8x, 8 ch).

The DAC8x overlay loads automatically from the HAT EEPROM (no line in
config.txt); onboard/HDMI audio are disabled so card names stay stable.

## Notes

- `statefile.yml` is runtime state (volume etc.) and is not tracked.
- Wi-Fi credentials and other secrets are **not** in this repo; reconfigure
  those in the Raspberry Pi Imager when flashing.
- After changing anything outside `~/camilladsp`, run `./backup.sh`.
