#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
: "${TAILSCALE_VERSION:=v1.104.7}"
: "${GO_IMAGE:=golang:1.27.4}"
mkdir -p dist
docker run --rm -v "$PWD/dist:/out" "$GO_IMAGE" sh -ec '
  export CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=5 GOBIN=/out
  go install tailscale.com/cmd/tailscaled@'"$TAILSCALE_VERSION"' tailscale.com/cmd/tailscale@'"$TAILSCALE_VERSION"'
'
# Go places the binaries in /out when GOBIN is set, regardless of target GOARCH.
cp /etc/ssl/certs/ca-certificates.crt dist/
file dist/tailscale dist/tailscaled | grep -c 'ELF 32-bit.*ARM' | grep -qx 2
sha256sum dist/tailscale dist/tailscaled > dist/SHA256SUMS
sha256sum -c dist/SHA256SUMS
docker buildx build --platform linux/arm/v5 -t tailscale-mikrotik-armv5:${TAILSCALE_VERSION#v} --load .
docker image inspect tailscale-mikrotik-armv5:${TAILSCALE_VERSION#v} --format '{{.Os}}/{{.Architecture}}/{{.Variant}}'
docker save tailscale-mikrotik-armv5:${TAILSCALE_VERSION#v} > "dist/tailscale-mikrotik-armv5-${TAILSCALE_VERSION#v}.tar"
sha256sum "dist/tailscale-mikrotik-armv5-${TAILSCALE_VERSION#v}.tar" > "dist/image-SHA256SUMS"
