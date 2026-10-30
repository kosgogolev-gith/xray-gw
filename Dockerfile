# Xray-шлюз (TUN) для контейнеров MikroTik RouterOS
FROM alpine:3.22

ARG XRAY_VERSION=26.10.21
ARG TARGETARCH
ARG SHA256_amd64=0eec3ed4163c273d8c8bf821f7d219e257921cf584aa3fb970715e458e631978
ARG SHA256_arm64=d1304946c486d98e6b886e9b931eaaaebb23835b30e217638037b7f2721d4e9c

RUN apk add --no-cache iproute2 iptables ca-certificates curl tzdata \
 && case "$TARGETARCH" in \
      amd64) ZIP=Xray-linux-64.zip; SUM=$SHA256_amd64 ;; \
      arm64) ZIP=Xray-linux-arm64-v8a.zip; SUM=$SHA256_arm64 ;; \
      *) echo "unsupported arch $TARGETARCH"; exit 1 ;; \
    esac \
 && wget -qO /tmp/xray.zip "https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/${ZIP}" \
 && echo "${SUM}  /tmp/xray.zip" | sha256sum -c - \
 && mkdir -p /usr/local/share/xray /tmp/x && unzip -q /tmp/xray.zip -d /tmp/x \
 && install -m 0755 /tmp/x/xray /usr/local/bin/xray \
 && cp /tmp/x/geoip.dat /tmp/x/geosite.dat /usr/local/share/xray/ \
 && rm -rf /tmp/x /tmp/xray.zip \
 && /usr/local/bin/xray version | head -1

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

ENV XRAY_LOCATION_ASSET=/usr/local/share/xray \
    XRAY_CONFIG=/etc/xray/config.json \
    TUN_NAME=xray0 \
    TUN_TABLE=100

LABEL org.opencontainers.image.source="https://github.com/kosgogolev-gith/xray-gw" \
      org.opencontainers.image.description="Xray TUN gateway for MikroTik RouterOS containers" \
      org.opencontainers.image.licenses="MPL-2.0"

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
