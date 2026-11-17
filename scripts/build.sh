#!/usr/bin/env bash
# Build and package an ARMv5 image with ordinary Docker (no Buildx required).
set -Eeuo pipefail
cd "$(dirname "$0")/.."
: "${TAILSCALE_VERSION:=v1.104.7}"
: "${GO_IMAGE:=golang:1.27.4}"
IMAGE_TAG="tailscale-mikrotik-armv5:${TAILSCALE_VERSION#v}"
CONTAINER_NAME=ao-tailscale-armv5-pack
mkdir -p dist
docker run --rm -v "$PWD/dist:/out" "$GO_IMAGE" sh -ec '
  export CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=5 GOBIN=/out
  go install tailscale.com/cmd/tailscaled@'"$TAILSCALE_VERSION"' tailscale.com/cmd/tailscale@'"$TAILSCALE_VERSION"'
'
# Cross-compiled binaries are expected to have static ARM EABI metadata.
file dist/tailscale dist/tailscaled | grep -c 'ELF 32-bit.*ARM' | grep -qx 2
docker run --rm -v "$PWD/dist:/out:ro" "$GO_IMAGE" go version -m /out/tailscaled | grep -q 'GOARM=5'
cp /etc/ssl/certs/ca-certificates.crt dist/ca-certificates.crt
sha256sum dist/tailscale dist/tailscaled > dist/SHA256SUMS
sha256sum -c dist/SHA256SUMS

# Docker classic build cannot copy some cross-architecture layers.
# Use create/cp/commit/save. Never execute the ARM image on the build host.
chmod 755 container/entrypoint.sh
docker pull --platform linux/arm/v5 busybox:stable
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || :
trap 'docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || :' EXIT
docker create --platform linux/arm/v5 --name "$CONTAINER_NAME" busybox:stable >/dev/null
docker cp dist/tailscale "$CONTAINER_NAME":/bin/tailscale
docker cp dist/tailscaled "$CONTAINER_NAME":/bin/tailscaled
docker cp container/entrypoint.sh "$CONTAINER_NAME":/bin/entrypoint.sh
docker cp dist/ca-certificates.crt "$CONTAINER_NAME":/etc/ca-certificates.crt
docker commit --change 'ENTRYPOINT ["/bin/entrypoint.sh"]' --change 'ENV SSL_CERT_FILE=/etc/ca-certificates.crt' "$CONTAINER_NAME" "$IMAGE_TAG" >/dev/null
docker rm "$CONTAINER_NAME" >/dev/null
trap - EXIT
docker image inspect "$IMAGE_TAG" --format 'BUILT_PLATFORM={{.Os}}/{{.Architecture}}/{{.Variant}}'
docker save "$IMAGE_TAG" -o "dist/tailscale-mikrotik-armv5-${TAILSCALE_VERSION#v}.tar"
sha256sum "dist/tailscale-mikrotik-armv5-${TAILSCALE_VERSION#v}.tar" > dist/image-SHA256SUMS
sha256sum -c dist/image-SHA256SUMS
echo "ARMV5_IMAGE_PACKAGED=PASS"
