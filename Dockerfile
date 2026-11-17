# ARMv5-only image: Dockerfile does not compile or download binaries.
# Run scripts/build.sh first; binaries are built with CGO_ENABLED=0 GOARM=5.
FROM --platform=linux/arm/v5 busybox:stable
COPY --chmod=0755 dist/tailscale /usr/local/bin/tailscale
COPY --chmod=0755 dist/tailscaled /usr/local/bin/tailscaled
COPY --chmod=0755 container/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY dist/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
