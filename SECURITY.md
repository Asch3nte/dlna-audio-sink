# Security policy

## Reporting a vulnerability

Please report security issues through GitHub's **private vulnerability
reporting** (the "Report a vulnerability" button under the Security tab)
rather than opening a public issue.

Include what you were running, the device involved, and how to reproduce.
Expect a first reply within a few days. This is a small hobby project, not a
funded one — there is no bounty, only credit in the fix.

## By design: the stream is unauthenticated

This is the most important thing to understand before running it.

To play audio, the tool starts an HTTP server on your machine and hands the
URL to the renderer. DLNA renderers cannot authenticate, so **that stream has
no password**. While it runs, anyone who can reach the port can listen to
whatever your computer is playing — including a call, or a microphone if you
used `--source`.

This is inherent to DLNA, not a flaw in the implementation, but you should
choose deliberately:

- It listens on all interfaces (`0.0.0.0`) by default. Restrict it with
  `--bind 192.168.1.10` on a multi-homed machine.
- The port is ephemeral and changes on every start, which is obscurity, not
  security. Do not rely on it.
- On an untrusted network — a hotel, a shared flat, a co-working space —
  assume the stream is readable by others.
- The server only ever serves the live stream. It reads no files and exposes
  no paths.

## What the tool does to your system

- creates and removes a PulseAudio/PipeWire null sink
- runs `ffmpeg` (and `parec`/`pw-record` on some setups)
- listens on one TCP port
- sends UPnP control requests to the renderer you chose
- writes one small cache file per device under
  `${XDG_CACHE_HOME:-~/.cache}/dlna-audio-sink/`

It needs no root, installs no service beyond an optional systemd *user* unit,
and makes no outbound connection to anything but your renderer.

## Supported versions

The latest release on `main`. There are no maintained older branches.
