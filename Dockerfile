FROM node:20-bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium \
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
    CHROMIUM_FLAGS="--no-sandbox --disable-dev-shm-usage --disable-gpu"

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget git gnupg sudo gosu \
      python3 python3-pip python3-venv pipx \
      iptables ipset dnsutils iproute2 \
      ripgrep jq less vim-tiny nano \
      libcap2-bin procps tini \
      build-essential pkg-config \
      chromium fonts-liberation \
 && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

RUN useradd -m -s /bin/bash -u 1001 dev \
 && mkdir -p /workspace /home/dev/.claude /etc/claude-docker \
 && chown -R dev:dev /workspace /home/dev

RUN echo 'dev ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh' > /etc/sudoers.d/dev-firewall \
 && chmod 0440 /etc/sudoers.d/dev-firewall

COPY init-firewall.sh /usr/local/bin/init-firewall.sh
COPY entrypoint.sh    /usr/local/bin/entrypoint.sh
COPY allowlist.txt    /etc/claude-docker/allowlist.txt
    RUN chmod 0755 /usr/local/bin/init-firewall.sh /usr/local/bin/entrypoint.sh

WORKDIR /workspace
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD []
