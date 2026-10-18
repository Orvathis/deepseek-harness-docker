# DeepSeek Harness (@deepseek-ai/dsh); runs `dsh web` only.
FROM node:24-slim

ARG DSH_VERSION

LABEL org.opencontainers.image.title="deepseek-harness-docker" \
      org.opencontainers.image.source="https://github.com/Orvathis/deepseek-harness-docker" \
      org.opencontainers.image.description="DeepSeek Harness (dsh web) container image; LAN-reachable DSH Web UI out of the box" \
      org.opencontainers.image.licenses="MIT" \
      org.dsh.version="${DSH_VERSION}"

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      git curl wget unzip procps less ripgrep jq openssh-client tmux \
      python3 python3-pip python3-venv build-essential; \
    rm -rf /var/lib/apt/lists/*

# npm >=11.16 skips install scripts by default; native deps (node-pty) need an explicit allow-list.
# --strict-allow-scripts turns a package missing from that list into a build-time failure.
RUN set -eux; \
    test -n "${DSH_VERSION}"; \
    npm install -g \
      --allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs \
      --strict-allow-scripts=true \
      "@deepseek-ai/dsh@${DSH_VERSION}"; \
    npm cache clean --force

# Ship upstream license files (MIT).
RUN set -eux; \
    pkg="$(npm root -g)/@deepseek-ai/dsh"; \
    mkdir -p /app/licenses; \
    for f in LICENSE THIRD_PARTY_NOTICES.md; do \
      if [ -f "$pkg/$f" ]; then cp "$pkg/$f" /app/licenses/; else echo "note: $pkg/$f not found, skipping"; fi; \
    done

# DSH_* belongs to upstream; no custom DSH_* vars here.
ENV DSH_HOME=/data

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 3080
VOLUME ["/data"]

# dsh listens on the container IP only, so probe that IP; 401 on / means ready.
HEALTHCHECK --interval=30s --timeout=5s --start-period=25s --retries=3 \
  CMD curl -s -o /dev/null -w '%{http_code}' "http://$(hostname -i | awk '{print $1}'):3080/" | grep -q 401

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
