#!/usr/bin/env python3
"""OLED status display for dsppi.

Default page: clock + CPU temperature.
When Spotify (raspotify/librespot) is playing: track name, artist,
progress bar and elapsed/total time, fed by the librespot onevent
hook via /run/raspotify/oled-event.json.
"""
import json
import time
from datetime import datetime

from luma.core.interface.serial import i2c
from luma.core.render import canvas
from luma.oled.device import ssd1306
from PIL import ImageFont

STATE_FILE = "/run/raspotify/oled-event.json"
FONT_DIR = "/usr/share/fonts/truetype/dejavu"

font_clock = ImageFont.truetype(f"{FONT_DIR}/DejaVuSans-Bold.ttf", 30)
font_med = ImageFont.truetype(f"{FONT_DIR}/DejaVuSans-Bold.ttf", 14)
font_small = ImageFont.truetype(f"{FONT_DIR}/DejaVuSans.ttf", 11)
font_tiny = ImageFont.truetype(f"{FONT_DIR}/DejaVuSans.ttf", 10)

SCROLL_PX_PER_FRAME = 2
SCROLL_PAUSE_FRAMES = 15  # pause at the start of each scroll cycle


def cpu_temp():
    try:
        with open("/sys/class/thermal/thermal_zone0/temp") as f:
            return f"{int(f.read()) / 1000:.0f}\N{DEGREE SIGN}C"
    except Exception:
        return "--"


def read_spotify():
    """Return (track dict, position_ms, playing) or None when idle."""
    try:
        with open(STATE_FILE) as f:
            s = json.load(f)
    except Exception:
        return None
    track = s.get("track") or {}
    if s.get("state") != "playing" or not track.get("name"):
        return None
    pos = s.get("position_ms", 0)
    pos += (time.time() - s.get("position_time", time.time())) * 1000
    dur = track.get("duration_ms", 0)
    if dur and pos > dur + 5000:
        # track should have ended and no new event arrived -> treat as idle
        return None
    return track, min(pos, dur) if dur else pos


def fmt_ms(ms):
    s = int(ms / 1000)
    return f"{s // 60}:{s % 60:02d}"


class Marquee:
    """Horizontal scroll state for one line of text."""

    def __init__(self):
        self.text = None
        self.offset = 0
        self.pause = 0

    def draw(self, draw, y, text, font, width=128):
        if text != self.text:
            self.text = text
            self.offset = 0
            self.pause = SCROLL_PAUSE_FRAMES
        w = draw.textlength(text, font=font)
        if w <= width:
            draw.text(((width - w) // 2, y), text, font=font, fill="white")
            return
        gap = 30
        if self.pause > 0:
            self.pause -= 1
        else:
            self.offset += SCROLL_PX_PER_FRAME
            if self.offset >= w + gap:
                self.offset = 0
                self.pause = SCROLL_PAUSE_FRAMES
        x = -self.offset
        draw.text((x, y), text, font=font, fill="white")
        draw.text((x + w + gap, y), text, font=font, fill="white")


def draw_clock(draw, minute):
    # shift everything a few pixels each minute to avoid OLED burn-in
    dx = minute % 3
    dy = minute % 2
    now = datetime.now()
    t = now.strftime("%H:%M")
    w = draw.textlength(t, font=font_clock)
    draw.text(((128 - w) // 2 + dx, 6 + dy), t, font=font_clock, fill="white")
    line = now.strftime("%a %d %b") + "   " + cpu_temp()
    w = draw.textlength(line, font=font_small)
    draw.text(((128 - w) // 2 + dx, 46 + dy), line, font=font_small, fill="white")


def draw_spotify(draw, track, pos_ms, title_marquee, artist_marquee):
    header = datetime.now().strftime("%H:%M") + "  " + cpu_temp()
    w = draw.textlength(header, font=font_tiny)
    draw.text(((128 - w) // 2, 0), header, font=font_tiny, fill="white")

    title_marquee.draw(draw, 14, track["name"], font_med)
    artist_marquee.draw(draw, 31, track.get("artists", ""), font_tiny)

    dur = track.get("duration_ms", 0)
    bar_y = 46
    draw.rectangle((0, bar_y, 127, bar_y + 5), outline="white")
    if dur:
        fill_w = int(125 * min(pos_ms / dur, 1.0))
        if fill_w > 0:
            draw.rectangle((1, bar_y + 1, 1 + fill_w, bar_y + 4), fill="white")
    draw.text((0, 54), fmt_ms(pos_ms), font=font_tiny, fill="white")
    total = fmt_ms(dur) if dur else "-:--"
    w = draw.textlength(total, font=font_tiny)
    draw.text((128 - w, 54), total, font=font_tiny, fill="white")


def main():
    serial = i2c(port=1, address=0x3C)
    device = ssd1306(serial, width=128, height=64)
    title_marquee = Marquee()
    artist_marquee = Marquee()

    while True:
        spotify = read_spotify()
        with canvas(device) as draw:
            if spotify:
                draw_spotify(draw, spotify[0], spotify[1], title_marquee, artist_marquee)
            else:
                draw_clock(draw, datetime.now().minute)
        time.sleep(0.15 if spotify else 1.0)


if __name__ == "__main__":
    main()
