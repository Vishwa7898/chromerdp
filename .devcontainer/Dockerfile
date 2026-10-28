FROM mcr.microsoft.com/devcontainers/base:bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      chromium \
      curl \
      novnc \
      openbox \
      python3 \
      websockify \
      x11vnc \
      x11-utils \
      xvfb \
    && rm -rf /var/lib/apt/lists/*

COPY .devcontainer/chromium-policy.json /etc/chromium/policies/managed/chromerdp.json
