#!/usr/bin/env bash
set -euo pipefail

# Config - valid for 24 hrs
SSHX_INSTALL_URL="https://sshx.io/get"
YOURLS_API_FULL="https://go.qincai.xyz/yourls-api.php?timestamp=1753763443&signature=d7774b9715da19f8380cd9cf93c26639&action=shorturl&format=simple"
TIMEOUT=10
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

# Try to extract link and sanitizse
attempt=1
link=""
while [[ "$attempt" -le "$MAX_RETRIES" ]]; do
  log "Attempt $attempt: capturing sshx link..."
  link="$(timeout "$TIMEOUT" sshx \
    | grep -o 'https://sshx.io[^ ]*' \
    | head -n1 || true)"
  # Strip trailing _[0m if present (literal ESC + [0m)
  link="${link//_

\[0m/}"
  if [[ -n "$link" ]]; then
    log "Captured link: $link"
    break
  fi
  log "No link captured, retrying after $RETRY_DELAY s..."
  sleep "$RETRY_DELAY"
  attempt=$((attempt + 1))
done

if [[ -z "$link" ]]; then
  log "Failed to capture sshx link after $MAX_RETRIES attempts"
  exit 1
fi

# Shorten the link
shortlink="$(curl -sG "$YOURLS_API_FULL" \
  --data-urlencode "url=$link" | awk NF)"

if [[ -n "$shortlink" ]]; then
  echo "$shortlink"
else
  log "URL shortening failed"
  exit 1
fi
