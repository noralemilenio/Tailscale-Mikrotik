#!/bin/sh
# RouterOS container: Tailscale subnet router. No credentials embedded in image.
set -eu
STATE_DIR="${TS_STATE_DIR:-/var/lib/tailscale}"
SOCKET_DIR=/var/run/tailscale
SOCKET="$SOCKET_DIR/tailscaled.sock"
ROUTES="${TS_ROUTES:-}"
[ -n "$ROUTES" ] || { echo "ERROR: TS_ROUTES must be set (e.g. 192.168.88.0/24)" >&2; exit 2; }
mkdir -p "$STATE_DIR" "$SOCKET_DIR"
chmod 700 "$STATE_DIR"
if [ "${TS_TEST_USERSPACE:-0}" = "1" ]; then
  TUN=userspace-networking
else
  [ -c /dev/net/tun ] || { echo "ERROR: /dev/net/tun absent" >&2; exit 3; }
  [ -w /proc/sys/net/ipv4/ip_forward ] || { echo "ERROR: cannot configure IPv4 forwarding" >&2; exit 4; }
  echo 1 >/proc/sys/net/ipv4/ip_forward
  TUN=tailscale0
fi
/usr/local/bin/tailscaled --tun="$TUN" --socket="$SOCKET" --state="$STATE_DIR/tailscaled.state" &
PID=$!
stop() { kill "$PID" 2>/dev/null || :; wait "$PID" 2>/dev/null || :; }
trap stop INT TERM EXIT
n=0
while [ ! -S "$SOCKET" ]; do
  kill -0 "$PID" 2>/dev/null || { echo "ERROR: tailscaled exited" >&2; exit 5; }
  n=$((n+1))
  [ "$n" -le 30 ] || { echo "ERROR: tailscaled socket timeout" >&2; exit 6; }
  sleep 1
done
if [ "${TS_TEST_USERSPACE:-0}" = "1" ]; then
  echo "LAB: userspace mode; no login, no subnet advertisements"
else
  # Avoid stale fail-open routing: subnet is advertised only after tailscale up succeeds.
  if [ -n "${TS_AUTHKEY:-}" ]; then
    /usr/local/bin/tailscale --socket="$SOCKET" up --authkey="$TS_AUTHKEY" --advertise-routes="$ROUTES" --netfilter-mode=off --accept-dns=false --accept-routes=false
  else
    /usr/local/bin/tailscale --socket="$SOCKET" up --advertise-routes="$ROUTES" --netfilter-mode=off --accept-dns=false --accept-routes=false
  fi
fi
wait "$PID"
