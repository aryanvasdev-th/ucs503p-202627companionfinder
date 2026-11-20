#!/usr/bin/env bash
# start-demo.sh — runs the Campus Companion backend on this laptop and puts
# it on a permanent public address with ngrok, so the app works from any
# network (campus wifi, hostel wifi, mobile data) as long as this is running.
#
#   ./scripts/start-demo.sh
#
# Needs, once:
#   - ngrok installed (brew install ngrok) and logged in with
#     `ngrok config add-authtoken <your token>`
#   - NGROK_DOMAIN=<your-name>.ngrok-free.dev in backend/.env
#
# Keeps the Mac awake while it runs, restarts the backend or the tunnel if
# either stops (e.g. the wifi changes), and stops both on Ctrl+C.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/backend/.env"
PORT=5001

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing $ENV_FILE (copy backend/.env.example and fill it in)." >&2
  exit 1
fi

NGROK_DOMAIN="${NGROK_DOMAIN:-$(grep -E '^NGROK_DOMAIN=' "$ENV_FILE" | cut -d= -f2- | tr -d '"' | tr -d "'")}"
if [ -z "$NGROK_DOMAIN" ]; then
  echo "Set NGROK_DOMAIN=<your-name>.ngrok-free.dev in backend/.env first." >&2
  exit 1
fi
if ! command -v ngrok >/dev/null 2>&1; then
  echo "ngrok isn't installed. Run: brew install ngrok" >&2
  exit 1
fi

cleanup() {
  echo
  echo "Stopping backend and tunnel..."
  kill 0 2>/dev/null
}
trap cleanup EXIT INT TERM

# Keep the Mac (and its network) awake while the demo is up.
caffeinate -dims -w $$ &

(
  cd "$ROOT/backend"
  while true; do
    node --env-file=.env server.js
    echo "backend stopped — restarting in 2s" >&2
    sleep 2
  done
) &

(
  # Give the backend a moment to start listening.
  sleep 3
  while true; do
    ngrok http "$PORT" --url="$NGROK_DOMAIN" --log=stdout --log-level=warn
    echo "tunnel stopped — restarting in 3s" >&2
    sleep 3
  done
) &

sleep 6
echo
echo "Campus Companion is live at: https://$NGROK_DOMAIN"
echo "Check it from any phone browser — it should say the API is running."
echo "Press Ctrl+C to stop."
wait
