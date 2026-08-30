# dlna-audio-sink

Turn any DLNA/UPnP MediaRenderer — a TV, an AV receiver, a networked speaker —
into a regular audio output on your Linux desktop.

Select it in your volume mixer like any sound card. Everything you play goes to
the device: your music player, a browser tab, a video call, anything.

```
  ┌──────────────┐   PipeWire    ┌───────────────┐   HTTP    ┌─────────────┐
  │ any app      │──── sink ────▶│ dlna-audio-   │── audio ─▶│ TV / AVR /  │
  │ (player,     │               │ sink          │           │ speaker     │
  │  browser...) │               │               │◀── UPnP ──│             │
  └──────────────┘               └───────────────┘  control  └─────────────┘
```

The motivating case: a laptop whose only decent speakers are the ones attached
to a TV, with the TV feeding an amplifier over HDMI ARC. Bluetooth on many TVs
only reaches the internal speakers, and AirPlay is often locked behind pairing.
DLNA is the one path that stays open — and because playback happens in the TV's
own media player, the audio follows the TV's sound-output setting and reaches
the amplifier.

No cable, no extra hardware.

## Requirements

- Linux with PipeWire or PulseAudio
- `ffmpeg`
- Python 3.9 or later — standard library only, no packages to install
- A renderer on the same network (SSDP needs UDP 1900)

If your `ffmpeg` was built without PulseAudio input, `parec`
(`pulseaudio-utils`) or `pw-record` (`pipewire-bin`) is used instead. One of
the three always works.

## Install

```sh
git clone https://github.com/Asch3nte/dlna-audio-sink
cd dlna-audio-sink
./install.sh          # ~/.local/bin + a systemd user unit
```

Or copy the single script anywhere on your `PATH`. It has no dependencies.

## Use

Find what is on your network:

```
$ dlna-audio-sink --list

1 renderer(s):

  [1] Living Room TV
      host   : 192.168.4.27
      device : ExampleCorp SmartTV
      audio  : audio/flac, audio/l16;rate=44100;channels=2, audio/mpeg
      udn    : uuid:00000000-0000-0000-0000-000000000000
```

Start it:

```
$ dlna-audio-sink --renderer "Living Room"

renderer: Living Room TV (192.168.4.27)
sink 'Living-Room-TV' created (module 12345678)
serving http://192.168.4.10:45871/stream/…
trying flac...
  flac: refused (state=TRANSITIONING)
trying lpcm...
  lpcm: accepted
ready - select 'Living Room TV' as your audio output
```

Then pick that device in your mixer (`pavucontrol`, GNOME Settings, the KDE
audio applet). To run it at login:

```sh
systemctl --user enable --now "dlna-audio-sink@Living Room"
```

The instance name is passed straight to `--renderer`, so any unambiguous part
of the device name works. systemd escapes spaces for you when you quote the
unit name; for anything more exotic use `systemd-escape 'My TV (kitchen)'`.

### Streaming something other than your desktop audio

By default a new sink is created and you choose it in your mixer. To send an
existing source instead — a microphone, or a copy of what another output is
already playing:

```sh
dlna-audio-sink --list-sources
dlna-audio-sink -r "Living Room" --source alsa_input.pci-0000_00_1f.3.analog-stereo
```

## How it works

1. **Discovery** — an SSDP `M-SEARCH` for `MediaRenderer:1`, sent from every
   local IPv4 address, so a multi-homed machine finds devices on each subnet.
2. **A null sink** is created; its monitor becomes the capture source.
3. **`ffmpeg`** reads that source and encodes on the fly.
4. **An HTTP server** serves the endless stream on an ephemeral port.
5. **UPnP `AVTransport`** tells the renderer to play that URL.
6. **A watchdog** restarts playback when the device stops, sleeps, changes
   input, silently stops reading, sticks in a vendor-specific transitional
   state, or is about to reach the end of the length we declared. It backs off
   if restarting keeps failing, and once the renderer has stopped answering
   altogether it **removes the sink** rather than leave a dead one behind
   (see below). Anything playing into it is handed to the default sink first
   and put back when the sink returns, so losing the renderer costs you the
   renderer, not your choice of output.

## Two things that make this harder than it looks

**Renderers stall without a `Content-Length`.** Given an endless stream of
undeclared size, many devices sit in a transitioning state forever and never
start — the `Play` call simply never returns. The fix is to advertise a large
bogus length. For the rare device that wants the opposite, use
`--no-content-length`.

**Renderers lie about what they support.** `GetProtocolInfo` is a wish list,
not a contract: devices advertise formats they will not play. So the tool
*probes* — it tries each candidate, best quality first, and keeps the first one
that genuinely reports `PLAYING`. The winner is cached per device, so later
starts skip straight to it.

Order of preference: FLAC → LPCM → WAV → MP3. The first three are lossless;
MP3 is reached only when a device refuses everything else, and it says so.

## Options

| Option | Default | Meaning |
|---|---|---|
| `--list` | | scan for renderers, then exit |
| `--list-sources` | | list local audio sources, then exit |
| `-r`, `--renderer` | | name fragment, UDN, or description URL |
| `--source` | | capture this source instead of creating a sink |
| `-f`, `--format` | `auto` | force `flac`, `lpcm`, `wav` or `mp3` |
| `-b`, `--bitrate` | `320k` | MP3 bitrate, if it falls back that far |
| `--rate`, `--channels` | auto | negotiated from the device; override if needed |
| `--sink-name`, `--description` | from device name | how it appears in the mixer |
| `--force-sink` | off | recreate the sink instead of reusing one |
| `--port`, `--bind`, `--local-ip` | auto | HTTP server placement |
| `--allow-any-client` | off | serve any host holding the URL, not just the renderer |
| `--timeout` | `4` | SSDP discovery window |
| `--probe-timeout` | `25` | seconds allowed for a format to start |
| `--watchdog` | `20` | seconds between playback checks |
| `--no-content-length` | off | for devices that dislike the length trick |
| `-v`, `--verbose` | | SSDP, HTTP and encoder detail |

## Troubleshooting

**"No MediaRenderer found."** The device must be powered on, on the same
network, and reachable by multicast. Many Wi-Fi networks isolate clients or
drop multicast — check for an "AP isolation" or "multicast filtering" setting.
Try `--timeout 10`. If you know the device's description URL, pass it directly
to `--renderer` and skip discovery entirely.

**"The renderer never connected to our stream."** The device found the URL but
could not reach it: a firewall is blocking the inbound HTTP port. Pin it with
`--port 8210` and open that port, or allow the program through.

**"The renderer refused every format."** Try `--no-content-length`, then
`--format mp3`. Run with `--verbose` and open an issue with the log.

**"No usable sound server."** Under systemd this almost always means the unit
is running system-wide instead of in your user session. It must be a *user*
unit (`systemctl --user`), because that is where PipeWire lives.

**A device on my network was refused.** The log names the address it came
from and the renderer's address it expected. Some devices fetch the stream
from a different interface than the one they answered SSDP on; `--allow-any-client`
covers that case.

**The sink vanished from my audio settings.** The renderer stopped
answering, so the sink was removed on purpose: one that leads nowhere is worse
than none, and `module-stream-restore` will route a client onto it by itself,
remembering a session from when the device was still up. Switch the device on
and the sink reappears within half a minute.

Whatever was playing into it is moved to your default sink *before* the module
goes, never orphaned by it — a client is not obliged to survive its sink
disappearing mid-stream, and when it does not, the failure is silent: the
process stays up, the stream stays listed at full volume, and only the far end
notices that nothing is being consumed. Those streams are moved back when the
sink returns. It is best effort: a stream that ended, or whose application
restarted meanwhile, is left where it is.

**The sound is delayed.** That is expected; see below.

## Limitations

**Latency is 2–5 seconds**, inherent to renderer buffering. Fine for music,
useless for video — the picture would drift out of sync.

**The rate is the device's, not the source's.** L16 carries its sample rate in
the MIME type, so a device that only advertises 44.1 kHz caps you there: a
96 kHz album is resampled. The tool picks the highest rate the device
advertises and pins the sink to it, so that conversion happens exactly once,
in PipeWire, rather than twice.

**Volume is separate.** The renderer keeps its own volume; the local slider
does not drive it.

**One renderer per instance.** Run several instances for several devices; they
will not be synchronised with each other.

## Tested devices

| Device | Result |
|---|---|
| LG C9 series OLED (webOS 4.5) | LPCM, lossless. Advertises FLAC but refuses it. Needs the `Content-Length` workaround. |

Reports are very welcome, especially failures. Please include the output of
`dlna-audio-sink --list` and a `--verbose` run — and redact your UDN and local
addresses if you would rather not publish them.

## Security

The stream carries whatever this computer is playing, so the URL is treated as
a capability. Two things guard it, and neither is optional:

* the path holds a random token minted at startup, compared in constant time,
  so the endpoint cannot be found by scanning the port;
* requests are served only to the renderer's own address. `--allow-any-client`
  lifts that, for the rare device that fetches from a different address than
  it answers on — it does not lift the token.

**What this does not protect against.** DLNA has no transport security: the
URL is handed to the renderer in a plain SOAP call, so anyone in a position
to watch that traffic sees the token. The address check still stands in their
way, and an attacker who can also spoof the renderer's address is already
inside your network. Think twice all the same on a network you do not trust.

Discovery is treated as hostile input too. Anything can answer an SSDP search,
so a description is only fetched from the address that answered, over http(s)
only, with no redirects, capped in size and in time, and rejected outright if
it carries a DTD. `--source` will stream a capture device — a microphone —
if you point it at one, and says so when you do.

See [SECURITY.md](SECURITY.md) for how to report a vulnerability.

## Contributing

Pull requests are welcome and every one is reviewed before merging; `main` is
protected. Device reports — especially failures — are the most valuable
contribution. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
