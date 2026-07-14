# dsppi — CamillaDSP car audio setup

Full snapshot of the Raspberry Pi 5 + HiFiBerry DAC8x DSP rig for a
2011 Chevy Cruze 2.0 diesel: 4-way active front (woofers + tweeters),
rear fill, low subwoofer (20–50 Hz) and shallow sub/midbass (50–150 Hz).

**Repo:** https://github.com/shreyasuchil1-rgb/dsppi-car-dsp (public — contains no secrets)

## Hardware this assumes

- Raspberry Pi 5 (the DAC8x is Pi 5-only — it uses all four RP1 I2S data lines)
- HiFiBerry DAC8x HAT (8-channel, its overlay auto-loads from the HAT EEPROM —
  that's why there is no `dtoverlay` line for it in config.txt)
- Raspberry Pi OS 64-bit (Bookworm or later), user `dsppi`

## Restore after a brick

1. **Flash** Raspberry Pi OS 64-bit with Raspberry Pi Imager.
   In the Imager settings set username `dsppi`, your Wi-Fi, and enable SSH
   (Wi-Fi/SSH credentials are deliberately NOT in this repo).
2. **Boot, SSH in, paste this ONE command — no logins, no prompts:**

   ```bash
   curl -fsSL https://raw.githubusercontent.com/shreyasuchil1-rgb/dsppi-car-dsp/main/bootstrap.sh | sudo bash
   ```

   It installs git, clones this repo to `~/camilladsp`, runs `restore.sh`
   (raspotify install, boot config, ALSA loopback, CamillaDSP binary +
   services, GUI), and reboots. When the Pi comes back up it IS the snapshot.

3. **Verify after reboot:**

   ```bash
   systemctl status camilladsp camillagui raspotify   # all active (running)
   aplay -l                                 # should list Loopback + sndrpihifiberry
   ```

`restore.sh` puts back: raspotify (installed from its official apt repo, with
our `/etc/raspotify/conf`), `/boot/firmware/config.txt`, the custom
`nospi10.dtbo` overlay, `/etc/asound.conf`, the `snd-aloop` module autoload,
the CamillaDSP binary, both systemd services (enabled), and adds `dsppi` to
the `audio` group.

## Saving changes (do this after every tweak)

```bash
~/camilladsp/backup.sh "what you changed"
```

Edits inside `~/camilladsp` (configs, coeffs) are picked up by git directly;
`backup.sh` additionally re-copies the system files from `/boot` and `/etc`,
commits everything, and pushes. Run it after changing boot config, services,
ALSA setup, or upgrading the camilladsp binary.

Pushing needs GitHub credentials. This Pi is already set up; on a
freshly restored Pi run once: `sudo apt install -y gh && gh auth login &&
gh auth setup-git` (restore itself never needs this — only saving NEW
snapshots does).

## Web interfaces

| Port | What |
|---|---|
| `http://<pi-ip>:5005` | CamillaGUI (edit configs, live volume/levels) |
| `<pi-ip>:1234` | CamillaDSP websocket (used by the GUI; also scriptable) |

### Direct-cable access (no router / in the car)

Plug an Ethernet cable straight from a laptop to the Pi. The `eth-p2p`
NetworkManager profile gives the Pi a fixed `10.55.0.1` and runs DHCP for
the laptop (set the laptop's Ethernet to DHCP — the macOS default). Then:

- CamillaGUI: `http://10.55.0.1:5005`
- SSH: `ssh dsppi@10.55.0.1`

Wi-Fi keeps working independently. Restored automatically by `restore.sh`.

## Signal flow

```
raspotify (Spotify Connect) and other players → plughw:Loopback,0,0
            │  (snd-aloop kernel loopback)
CamillaDSP captures hw:Loopback,1,0
            │  mixer + crossovers + delays + EQ
        hw:sndrpihifiberry → DAC8x → 8 × RCA line out → amps
```

Onboard/HDMI audio are disabled in config.txt so card names never shift.
All configs reference cards by NAME (`Loopback`, `sndrpihifiberry`), never by
index, so module load order doesn't matter.

## Layout

| Path | What |
|---|---|
| `config.yml` | Live CamillaDSP config (loaded by the service) |
| `configs/car_8ch.yml` | 8-channel car crossover (see below) |
| `configs/` | Other saved configs |
| `coeffs/` | FIR coefficients (room/car correction filters go here) |
| `camillagui_backend/` | CamillaGUI web UI, compiled bundle; its own config is `camillagui_backend/_internal/config/camillagui.yml` |
| `bin/camilladsp` | CamillaDSP 4.1.3 aarch64 binary |
| `system/` | Copies of boot config, `nospi10.dtbo`, `asound.conf`, `snd-aloop.conf`, `raspotify.conf`, `eth-p2p.nmconnection`, systemd units |
| `backup.sh` / `restore.sh` | Snapshot to git / rebuild a fresh flash |

## Car config: channel map (`configs/car_8ch.yml`)

| DAC8x out | Driver | Band |
|---|---|---|
| 0 / 1 | Front woofer L / R | 150 Hz – 2.5 kHz |
| 2 / 3 | Front tweeter L / R | 2.5 kHz + |
| 4 / 5 | Rear fill L / R | 150 Hz +, −6 dB |
| 6 | Low subwoofer | 20 – 50 Hz (L+R summed) |
| 7 | Shallow sub / midbass | 50 – 150 Hz (L+R summed) |

Crossovers are Linkwitz-Riley 24 dB/oct. Still TODO before it sounds right:

- [ ] Set crossover points to the actual drivers' specs
- [ ] Time alignment: measure each speaker's distance to the driver's head;
      farthest speaker = 0 ms, others = `(farthest − distance in m) / 343 × 1000` ms
- [ ] Level-match sections, then EQ from REW measurements (UMIK mic at head position)

## Notes

- `statefile.yml` is runtime state (volume etc.) — gitignored on purpose.
- DAC8x is line-level out (~2 V RCA): all 8 channels need external amplification.
- In-car power: Pi 5 wants a solid 5 V / 5 A buck converter from 12 V, ideally
  with delayed-off from ACC so it can shut down cleanly at key-off.
