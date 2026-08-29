#!/bin/sh
# Install dlna-audio-sink for the current user.
set -eu

BIN_DIR="${HOME}/.local/bin"
UNIT_DIR="${HOME}/.config/systemd/user"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

for tool in ffmpeg pactl python3; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "missing dependency: $tool" >&2
        exit 1
    }
done

mkdir -p "$BIN_DIR" "$UNIT_DIR"
install -m 755 "$SRC_DIR/dlna-audio-sink" "$BIN_DIR/dlna-audio-sink"
install -m 644 "$SRC_DIR/systemd/dlna-audio-sink@.service" \
    "$UNIT_DIR/dlna-audio-sink@.service"
systemctl --user daemon-reload 2>/dev/null || true

echo "installed: $BIN_DIR/dlna-audio-sink"
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) echo "note: $BIN_DIR is not on your PATH" ;;
esac
cat <<'MSG'

Next:
  dlna-audio-sink --list
  systemctl --user enable --now dlna-audio-sink@<name>
MSG
