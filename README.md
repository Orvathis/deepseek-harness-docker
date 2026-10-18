# deepseek-harness-docker

[English](README.md) | [中文](README.zh-CN.md)

Docker image for the official [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) (npm package `@deepseek-ai/dsh`): one `docker compose up -d` and the DSH Web UI is reachable on your LAN.

- Upstream: https://github.com/deepseek-ai/deepseek-harness
- Image: `ghcr.io/orvathis/deepseek-harness-docker` (GitHub Actions builds it automatically, following upstream)
- License: MIT (see [LICENSE](LICENSE); the image also carries the upstream LICENSE at `/app/licenses/`)

> :warning: Upstream is a developer preview: all versions are pre-releases and breaking changes happen; this image follows upstream and does not guarantee cross-version compatibility.

## Quick start

Save the following as `docker-compose.yml`, create a `.env` in the same directory with `TRUSTED_HOST=<host IP>`, and create a `./dsh` directory (the container's HOME and working directory; point new workspaces in the Web UI at `/dsh`):

```yaml
services:
  dsh:
    image: ghcr.io/orvathis/deepseek-harness-docker:latest
    container_name: deepseek-harness
    restart: always
    ports:
      - "${HOST_PORT:-3080}:3080"
    volumes:
      - ./data:/data
      - ./dsh:/dsh
    environment:
      TRUSTED_HOST: ${TRUSTED_HOST:-192.168.1.10}
      TZ: ${TZ:-Asia/Shanghai}
      HOST_PORT: ${HOST_PORT:-3080}
```

```sh
docker compose up -d
```

Update: `docker compose pull && docker compose up -d`.

## Environment variables

| Variable | Value | Description |
| --- | --- | --- |
| `TRUSTED_HOST` | No image default (required); example value `192.168.1.10` | The authority used for browser access; comma-separated for multiple entries (IPs and domains); omitting the port matches any port; use `localhost` when only host loopback access is needed; if empty the container exits and all `/api` requests return 403 |
| `TZ` | Image default `Etc/UTC`; example value `Asia/Shanghai` | Container timezone; tzdata is bundled in the image |
| `HOST_PORT` | Default `3080`; also used for the compose port mapping | Host-side port, also used for the access URL printed in the logs; the container always listens on 3080 |
| `PUID` / `PGID` | Default `1000` | User the agent runs as; owns the files in `./data` and `./dsh` — set these to your host account's uid/gid |

## First-time authentication (do this once)

- Get the token: `docker compose logs dsh | grep -o 'token=[^& ]*'` (on PowerShell use `Select-String 'token='`)
- Open the URL printed in the logs (e.g. `http://192.168.1.10:3080/?token=xxxxxxxx`); afterwards visit the same address, the cookie stays valid for 30 days and does not renew
- When to re-fetch: after the cookie expires (changed IP / port / domain, cleared cookies, or a different browser). Restarting the container issues a new token and invalidates the old one, but already-issued cookies remain valid, so no re-login is needed

## Tags

| tag | Meaning |
| --- | --- |
| `:latest` | Newest version that passed smoke validation |
| `:<version>` | Produced on every build, e.g. `:0.2.1-rc.2`; use this for rollbacks or pinning |

## Security notes

- **The port has no protection, and the only auth is DSH's own launch token** (accessing `GET /` without a token returns 401; this image does not add Basic Auth).
  - Local only: `-p 127.0.0.1:3080:3080` plus an SSH tunnel
  - LAN access: `-p 3080:3080`, exposing the container port only to a trusted LAN
  - Public: go through a reverse proxy and add TLS / Basic Auth / IP allowlisting there
- **`network_mode: host` cannot be used**: `dsh web --host` needs a concrete container IP, which is unavailable under host networking; port mapping is required.
- The image bundles a full set of dev tools (git / python3 / gcc / ripgrep …) and is on the order of gigabytes in size.

## License

This repository's code is released under MIT, see [LICENSE](LICENSE); the other components in the image (DeepSeek Harness, npm dependencies, distro toolchain) each follow their own licenses.
