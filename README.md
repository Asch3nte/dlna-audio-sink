# dlna-audio-sink

Turn any DLNA/UPnP MediaRenderer — a TV, an AV receiver, a networked speaker —
into a regular audio output on your Linux desktop.

Select it in your volume mixer like any sound card. Everything you play goes to
the device: your music player, a browser tab, a video call's audio, anything.

```
  ┌──────────────┐   PipeWire    ┌───────────────┐   HTTP    ┌─────────────┐
  │ any app      │──── sink ────▶│ dlna-audio-   │── audio ─▶│ TV / AVR /  │
  │ (player,     │               │ sink          │           │ speaker     │
  │  browser...) │               │               │◀── UPnP ──│             │
  └──────────────┘               └───────────────┘  control  └─────────────┘
```

The motivating case: a laptop whose only decent speakers are on a TV, with the
TV feeding an amplifier over HDMI ARC. Bluetooth on many TVs only reaches the
internal speakers, and AirPlay is often locked behind pairing. DLNA is the one
path that stays open — and because playback happens in the TV's own media
player, the audio follows the TV's sound-output setting and reaches the
amplifier.

No cable, no extra hardware.

## Requirements

- Linux with PipeWire or PulseAudio (`pactl`)
- `ffmpeg`
- Python 3.9+
- A renderer reachable on the same network (UDP 1900 must not be blocked)

## Install

```sh
git clone https://github.com/<you>/dlna-audio-sink
cd dlna-audio-sink
./install.sh          # installs to ~/.local/bin + a systemd user unit
```

Or just copy the single script anywhere on your `PATH`; it has no dependencies
beyond the Python standard library.

## Use

Find what is on your network:

```sh
$ dlna-audio-sink --list

1 renderer(s):

  [1] [LG] webOS TV OLED55C9PLA
      host   : 192.168.1.22
      device : LG Electronics LG TV
      audio  : audio/flac, audio/l16;rate=44100;channels=2, audio/mpeg, ...
      udn    : uuid:f1dc6ac8-c384-801e-6b57-f276e65565e5
```

Start it:

```sh
$ dlna-audio-sink --renderer "OLED55C9"

renderer: [LG] webOS TV OLED55C9PLA (192.168.1.22)
sink 'LG-webOS-TV-OLED55C9PLA' created
serving http://192.168.1.62:42617/stream
trying flac...
  flac: refused (state=LG_TRANSITIONING)
trying lpcm...
  lpcm: accepted
ready - select '[LG] webOS TV OLED55C9PLA' as your audio output
```

Then pick that device in your mixer (`pavucontrol`, GNOME Settings, KDE audio
applet). Run it at login:

```sh
systemctl --user enable --now dlna-audio-sink@OLED55C9
```

The instance name is passed to `--renderer`, so any substring of the device
name works. For a name with spaces, escape it with
`systemd-escape 'Living room speaker'`.

## How it works

1. **Discovery** — an SSDP `M-SEARCH` for `MediaRenderer:1`, sent from every
   local IPv4 address so multi-homed machines find devices on each subnet.
2. **A null sink** is created with `pactl`; its monitor is the capture source.
3. **`ffmpeg`** reads that monitor and encodes on the fly.
4. **An HTTP server** serves the endless stream.
5. **UPnP `AVTransport`** tells the renderer to play that URL.
6. **A watchdog** restarts playback if the device stops, sleeps or changes
   input.

## Two things that make this harder than it looks

**Renderers stall without a `Content-Length`.** Given an endless stream with no
declared size, many devices sit in a transitioning state forever and never
start — the `Play` call simply never returns. The fix is to advertise a large
bogus length (2 GiB). If you meet a device that needs the opposite, use
`--no-content-length`.

**Renderers lie about what they support.** `GetProtocolInfo` is a wish list,
not a contract. The LG C9 above advertises FLAC and plays none of it. So the
tool *probes*: it tries each candidate, best quality first, and keeps the first
one that genuinely reports `PLAYING`. The working format is cached per device,
so later starts go straight to it.

Order of preference: FLAC → LPCM → WAV → MP3. The first three are lossless;
MP3 is only reached when a device refuses everything else, and it says so.

## Options

| Option | Default | Meaning |
|---|---|---|
| `--list` | | scan and list renderers, then exit |
| `-r`, `--renderer` | | name substring, UDN, or description URL |
| `-f`, `--format` | `auto` | force `flac`, `lpcm`, `wav` or `mp3` |
| `-b`, `--bitrate` | `320k` | MP3 bitrate, when it falls back that far |
| `--rate`, `--channels` | `44100`, `2` | sink audio parameters |
| `--sink-name`, `--description` | from device name | how it appears in the mixer |
| `--port`, `--bind`, `--local-ip` | auto | HTTP server placement |
| `--probe-timeout` | `25` | seconds to wait for a format to start |
| `--watchdog` | `20` | seconds between playback checks |
| `--no-content-length` | off | for devices that dislike the length trick |
| `-v`, `--verbose` | | show SSDP, HTTP and ffmpeg detail |

## Limitations

**Latency is 2–5 seconds**, inherent to renderer buffering. Fine for music,
useless for video — the picture would drift out of sync.

**Volume is separate.** The renderer keeps its own volume; the local sink
slider does not drive it.

**One renderer per instance.** Run several instances, on different ports, to
feed several devices — they will not be synchronised.

## Tested devices

| Device | Result |
|---|---|
| LG OLED55C9PLA (webOS 4.5, `p20.05.50.00`) | LPCM, lossless. FLAC advertised but refused. |

Reports welcome — please include `dlna-audio-sink --list` output and the
negotiation log from a `--verbose` run.

## License

MIT
