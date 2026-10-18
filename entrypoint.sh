#!/bin/sh
# Bind dsh web to the container IP and exec it in the foreground; no port forwarding.
set -eu

# Allow a command override (e.g. `docker run <image> dsh --version`) for debugging.
if [ "$#" -gt 0 ]; then
  exec "$@"
fi

# --host accepts one concrete address, not a wildcard.
IP="$(hostname -i 2>/dev/null | awk '{print $1}')"
if [ -z "$IP" ]; then
  echo "entrypoint: failed to detect the container IP (hostname -i returned nothing)." >&2
  echo "entrypoint: dsh --host needs a concrete address; use a runtime that gives the container its own eth0 (host network won't work)." >&2
  exit 1
fi

# TRUSTED_HOST: the browser-visible authority; required.
if [ -z "${TRUSTED_HOST:-}" ]; then
  echo "entrypoint: TRUSTED_HOST is required; without it every browser /api request is rejected with 403." >&2
  echo "entrypoint: e.g. TRUSTED_HOST=192.168.1.10; comma-separated for several hosts; omit the port to match any port." >&2
  echo "entrypoint: for host loopback only (e.g. -p 127.0.0.1:3080:3080 with an SSH tunnel), set it to localhost." >&2
  exit 1
fi

# Advertise the host-side URL instead of the container IP; the first authority wins.
# HOST_PORT is the host-side port (compose publishes with it); a port already
# present in the authority is kept as-is.
HEAD="$(printf '%s' "$TRUSTED_HOST" | cut -d, -f1 | tr -d ' ')"
case "$HEAD" in
  *:*) PUBLIC="http://${HEAD}" ;;
  *)   PUBLIC="http://${HEAD}:${HOST_PORT:-3080}" ;;
esac

# Map to official flags: --trusted-host admits the browser authority, --public-url
# only advertises it; both derive from TRUSTED_HOST, so they cannot disagree.
set -- --host "$IP" --no-open --public-url "$PUBLIC"
for host in $(printf '%s' "$TRUSTED_HOST" | tr ',' ' '); do
  set -- "$@" --trusted-host "$host"
done

# Foreground exec so DSH stdout (launch token) lands in docker logs; default port 3080.
echo "entrypoint: starting dsh web on ${IP}:3080 (trusted-host: ${TRUSTED_HOST}; public-url: ${PUBLIC})"
exec dsh web "$@"
