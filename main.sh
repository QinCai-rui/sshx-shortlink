#!/usr/bin/env bash
set -euo pipefail

# Config — valid for 24 hrs
SSHX_INSTALL_URL="https://sshx.io/get"
YOURLS_API_FULL="https://go.qincai.xyz/yourls-api.php?timestamp=1753763443&signature=d7774b9715da19f8380cd9cf93c26639&action=shorturl&format=simple"
MAX_RETRIES=3
RETRY_DELAY=2

log() { echo "[sshx-shortlink] $*" >&2; }

# Ensure sshx exists
if ! command -v sshx &>/dev/null; then
  log "sshx not found; attempting install..."
  curl -sSf "$SSHX_INSTALL_URL" | sh || {
    log "Failed to install sshx"
    exit 1
  }
  log "sshx installed successfully"
fi

# Start sshx in background, capture output
log "Launching sshx in background..."
pipe="$(mktemp -u)"
mkfifo "$pipe"
sshx >"$pipe" &
sshx_pid=$!

# Try to extract link
attempt=1
link=""
while [[ "$attempt" -le "$MAX_RETRIES" ]]; do
  log "Attempt $attempt: waiting for sshx to emit link..."
  raw_link="$(timeout 5 head -n 10 "$pipe" | grep -o 'https://sshx.io[^ ]*' | head -n1 || true)"
  link="${raw_link:0:-4}"  # trim last 4 chars
  if [[ -n "$link" ]]; then
    log "Captured link: $link"
    break
  fi
  log "No link yet, retrying in $RETRY_DELAY s..."
  sleep "$RETRY_DELAY"
  attempt=$((attempt + 1))
done

rm "$pipe"

if [[ -z "$link" ]]; then
  log "Failed to capture sshx link after $MAX_RETRIES attempts"
  kill "$sshx_pid" 2>/dev/null || true
  exit 1
fi

# Shorten the link
shortlink="$(curl -sG "$YOURLS_API_FULL" --data-urlencode "url=$link" | awk NF)"

if [[ -n "$shortlink" ]]; then
  echo "$shortlink"
else
  log "URL shortening failed"
  kill "$sshx_pid" 2>/dev/null || true
  exit 1
fi

# Leave sshx running in foreground
wait "$sshx_pid"
