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

# TRUSTED_HOST: the only custom var (browser-visible authority); required.
if [ -z "${TRUSTED_HOST:-}" ]; then
  echo "entrypoint: TRUSTED_HOST is required; without it every browser /api request is rejected with 403." >&2
  echo "entrypoint: e.g. TRUSTED_HOST=192.168.1.10; comma-separated for several hosts; omit the port to match any port." >&2
  echo "entrypoint: for host loopback only (e.g. -p 127.0.0.1:3080:3080 with an SSH tunnel), set it to localhost." >&2
  exit 1
fi

# Map to official flags; no --public-url (keep DSH's default announcement).
set -- --host "$IP" --no-open
for host in $(printf '%s' "$TRUSTED_HOST" | tr ',' ' '); do
  set -- "$@" --trusted-host "$host"
done

# Foreground exec so DSH stdout (launch token) lands in docker logs; default port 3080.
echo "entrypoint: starting dsh web on ${IP}:3080 (trusted-host: ${TRUSTED_HOST})"
exec dsh web "$@"
