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

# Host-mounted dirs may be owned by root; align them with the runtime user, then drop
# to it. PUID/PGID default to 1000 so files stay manageable outside the container.
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"
[ "$(id -u node)" = "$PUID" ] || usermod -o -u "$PUID" node
[ "$(id -g node)" = "$PGID" ] || groupmod -o -g "$PGID" node
# Walk all of /data only when its owner is stale (first start, or PUID/PGID changed);
# afterwards every file is written by this user, so the walk would be pure overhead.
if [ "$(stat -c %u /data 2>/dev/null)" != "$PUID" ]; then
  chown -R node:node /data 2>/dev/null || true
else
  # Cheap net for the rare case where the tree is fine but a DSH entry was replaced
  # from outside (e.g. restored from a backup): no walk, just the known entries.
  chown node:node /data/.credentials.yaml /data/.anonymous-user-id /data/profiles /data/storages 2>/dev/null || true
fi
[ -d /workspace ] && chown node:node /workspace 2>/dev/null || true
# usermod -u already retargets files in the home dir; this just aligns the group.
[ -d /home/node ] && chown node:node /home/node 2>/dev/null || true

# DSH creates this file itself and validates its mode in the same step, so a host fs that
# forces a mode on newly created files fails the very first start: make sure the file
# exists and is owner-only before dsh starts. Creating it alone is not enough — `: >`
# honours the umask, so it lands at 644.
if [ ! -f /data/.credentials.yaml ]; then
  : > /data/.credentials.yaml
  chown "$PUID:$PGID" /data/.credentials.yaml 2>/dev/null || true
fi
chmod 600 /data/.credentials.yaml 2>/dev/null || true

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
export HOME=/home/node
echo "entrypoint: starting dsh web on ${IP}:3080 (trusted-host: ${TRUSTED_HOST}; public-url: ${PUBLIC}; user: ${PUID}:${PGID})"
exec setpriv --reuid="$PUID" --regid="$PGID" --init-groups dsh web "$@"
