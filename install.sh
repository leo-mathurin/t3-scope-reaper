#!/usr/bin/env bash
# Installs or removes t3-scope-reaper for the current user.
#
# Usage: ./install.sh [--uninstall]
set -euo pipefail

cd "$(dirname "$0")"
bin=$HOME/.local/bin
units=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user

if [ "$(uname -s)" != Linux ]; then
  echo "t3-scope-reaper needs Linux with a systemd user manager" >&2
  exit 1
fi

if [ "${1:-}" = --uninstall ]; then
  systemctl --user disable --now t3-scope-reaper.timer 2>/dev/null || true
  rm -f "$bin/t3-scope-reaper" "$units/t3-scope-reaper.service" "$units/t3-scope-reaper.timer"
  rm -rf "${XDG_STATE_HOME:-$HOME/.local/state}/t3-scope-reaper"
  systemctl --user daemon-reload
  echo "t3-scope-reaper removed"
  exit 0
fi

install -Dm755 t3-scope-reaper "$bin/t3-scope-reaper"
install -Dm644 systemd/t3-scope-reaper.service "$units/t3-scope-reaper.service"
install -Dm644 systemd/t3-scope-reaper.timer "$units/t3-scope-reaper.timer"
systemctl --user daemon-reload
systemctl --user enable --now t3-scope-reaper.timer
echo "t3-scope-reaper $("$bin/t3-scope-reaper" --version | cut -d' ' -f2) installed"
echo "orphaned scopes now:"
"$bin/t3-scope-reaper" --dry-run
