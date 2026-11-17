# Tailscale subnet router for MikroTik hEX S ARMv5 (E60iUGS)

**Status: experimental — not production-certified.** This repository contains reproducible build files, a minimal Tailscale container, and a **manual** RouterOS configuration template. Source and binaries have had limited checks; **end-to-end ARMv5 runtime, TUN forwarding, remote access, reboot recovery and failover are not yet certified.** Do not replace an existing working subnet router until those tests succeed.

## Target

MikroTik **hEX S E60iUGS**, EN7562CT **ARM32v5**, RouterOS 7.x with the matching `container` package. This CPU **cannot** run the normal `linux/arm/v7` Tailscale containers.

The project compiles Tailscale **v1.104.7** with Go **1.27.4**, `CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=5`. The binaries are statically linked. The minimal image uses BusyBox ARMv5 and **does not install iptables**; Tailscale is intentionally configured with `--netfilter-mode=off`, with RouterOS handling firewall and NAT. This design still requires real-world verification.

## Status and evidence

| Test | Result |
|---|---|
| Compile Tailscale CLI and daemon (v1.104.7 / Go 1.27.4 / GOARM=5) | PASS |
| Inspect ELF and Go metadata (`GOARM=5`, static) | PASS |
| Compare image binaries byte-by-byte with compiled originals | PASS (lab prototype) |
| Check shell syntax | PASS\n| Isolated launcher smoke test, Linux/amd64 userspace mode (no authentication, no routes) | PASS; daemon answered `Logged out` |
| Build complete image with this launcher | Lab prototype packaged; final route/container execution NOT TESTED |
| Start ARMv5 binary on E60iUGS | NOT TESTED |
| Linux TUN + packet forwarding and RouterOS firewall/NAT | NOT TESTED |
| Tailscale remote LAN access + split DNS + persistence | NOT TESTED |
| Reboot, upgrade, rollback and failover from old router | NOT TESTED |

## Reproducible build

Requirements: standard Docker Engine (Buildx **not required**), support for pulling `linux/arm/v5`, internet access to the Go module proxy and image registry, and `file`, `sha256sum`, `ca-certificates` on the build host. Run:

```bash
bash scripts/build.sh
```

This creates `dist/tailscale`, `dist/tailscaled`, SHA-256 manifests and an image TAR for import to RouterOS. The builder uses `docker create`, `docker cp`, `docker commit` and `docker save` without running ARM binaries on the x86 build machine. GitHub source files are checked for shell syntax before packaging; the script marks the entrypoint executable. The build is **pinned to v1.104.7** rather than `latest` to avoid unexpected changes in Go requirements. Users should inspect the output image's `architecture` and inspect binaries (`go version -m`) before importing. A Docker manifest with generic `linux/arm` metadata is **not sufficient evidence of ARMv5 compatibility**; use `GOARM=5` metadata and an actual device test.

## Planned network topology

Example only — adjust to your own environment:

```text
Tailscale clients
      |
   Tailscale tunnel
      |
[RouterOS container 172.30.254.2/30]
      |
[veth on bridge 172.30.254.1/30] -- [MikroTik RouterOS] -- [LAN 192.168.88.0/24]
```

- Container has a dedicated veth and isolated bridge. Do **not** add this veth to an existing LAN bridge.
- RouterOS: route `100.64.0.0/10` via the veth peer if appropriate to your tailnet topology, allow forward traffic only for the intended LAN, and use carefully scoped source NAT for remote-to-LAN sessions where hosts do not return through MikroTik.
- In the container: enable IPv4 forwarding, require `/dev/net/tun`, persist Tailscale state, and advertise the LAN route only after authentication. No Exit Node is enabled by default.
- `--netfilter-mode=off` means that **RouterOS—not Tailscale—must implement and audit the packet filter and NAT**. Do not import a sample firewall blindly.
- Tailscale administration must approve the advertised route. Use **Split DNS** for the internal zone if required.
- External storage for container root/state is strongly recommended. Confirm `/system device-mode`, `/disk`, free space, and the correct RouterOS `container` package/version before installation.
- Authentication keys must never be committed to Git or included inside an image. Use a short-lived enrollment key via a protected provisioning workflow and persistent state.

See [docs/routeros-example.rsc](docs/routeros-example.rsc) for a commented preparation template. It is NOT an unattended installer.

## Testing and migration policy

1. Verify binary and image architecture, hashes and shell syntax.
2. In an isolated lab verify executable startup, TUN, Linux forwarding, Tailscale authentication, subnet advertisement and traffic in both directions.
3. Back up MikroTik RouterOS; check container feature and package, storage, firewall, DHCP, DNS and current gateway first.
4. Deploy the new container without disabling the old subnet router. Verify from a **remote** Tailscale client, including internal DNS and reboot persistence.
5. Approve the route and migrate one subnet router at a time; keep recovery access.
6. Only after the new path is proven, remove the **subnet route advertisement** from the old NAS. Keep the NAS in Tailscale with its own node IP.
7. If a test fails, revert only the new route/container changes; keep the NAS advertising as before.

## Attribution and license

MIT-licensed project-specific code; Tailscale's own code and binaries retain their upstream licenses. Based on technical ideas from [Fluent Networks / tailscale-mikrotik](https://github.com/Fluent-networks/tailscale-mikrotik) and [the ARMv5 hEX S community experiment](https://forum.mikrotik.com/t/working-tailscale-container-on-hex-s-en7562ct-arm32v5-54-mbit-s-exit-node/272193). This repository is independent and not affiliated with MikroTik or Tailscale.
