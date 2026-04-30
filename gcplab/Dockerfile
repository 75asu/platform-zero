FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ARG MINISKY_VERSION=1.2.0
RUN curl -fsSL \
    https://github.com/qamarudeenm/minisky/releases/download/v${MINISKY_VERSION}/minisky_linux_amd64.tar.gz \
    | tar -xz -C /usr/local/bin minisky \
    && chmod +x /usr/local/bin/minisky

RUN mkdir -p /root/.minisky/logs

EXPOSE 8082 8083

# minisky start daemonises — tail -f /dev/null keeps the container alive.
# If minisky crashes after starting, the healthcheck catches it.
CMD ["/bin/sh", "-c", "minisky start && tail -f /dev/null"]
