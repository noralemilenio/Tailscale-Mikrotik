# Acceptance and rollback checklist (RouterOS ARMv5 subnet router)

**Current certification state: lab-only, NOT production-ready.**

## Minimum acceptance gate

- [x] Tailscale v1.104.7 compiled with Go 1.27.4, CGO disabled, GOARCH arm, GOARM=5
- [x] Static ELF ARM32 and SHA256 metadata checked
- [x] Minimal ARMv5 image packaged and TAR hash checked in Docker VM101
- [x] No-auth isolated **AMD64** launcher test succeeded (daemon, socket, CLI; no network)
- [ ] ARMv5 runtime or QEMU ARMv5 smoke test including entrypoint executable
- [ ] Linux TUN creation in ARMv5 image
- [ ] Verify kernel IP forwarding, IPv4 routing, netfilter=off behavior under RouterOS
- [ ] Validate production firewall forward permissions and precise source NAT, with original routes preserved
- [ ] Insert matching RouterOS `container` package; device mode enabled via authorized physical button
- [ ] Confirm adequate external storage, persistent state, and safe capacity under sustained load
- [ ] Enroll container in tailnet using protected, short-lived auth key (Vault / host secret, never repository)
- [ ] Advertise a test route and obtain approval in Tailscale console without displacing the NAS
- [ ] Remote client connects to router and an actual LAN service with correct return routing
- [ ] Split DNS `home.arpa` resolves through chosen internal DNS, without breaking public DNS
- [ ] Reboot RouterOS; reconnect and verify persistence of identity, routing, DHCP and DNS
- [ ] Temporary failure of Tailscale container does not affect LAN DHCP, DNS or Internet
- [ ] Handover: retire old NAS subnet route advertisement only after remote path is confirmed
- [ ] Verify NAS retains individual Tailscale node address after route retirement

## Known blockers

- The hEX S E60iUGS currently has `container=no`, lacks RouterOS `container` package, and had no detected external storage. **This is intentionally not changed as part of the lab build.**
- The VM101 host lacks an ARMv5 runtime/emulator. Its AMD64 launcher smoke test validates shell logic only; it **cannot certify ARMv5 execution**.
- The image uses BusyBox and Tailscale with `--netfilter-mode=off`; RouterOS must provide routing/firewall/NAT. The commented router template is **not** a tested production firewall policy.
- RouterOS device mode needs physical confirmation; do not automate or bypass the check.

## Safe rollback

1. Preserve old subnet router (NAS) advertisement and node until a replacement is certified. Do not revoke or delete it.
2. If newly deployed container or route fails, withdraw the NEW advertised route from Tailscale control plane; keep the old route enabled.
3. Stop only the new RouterOS container; remove its scoped veth route/firewall NAT entries using their unique comments; do not reset the router or touch unrelated DHCP, DNS, default gateway or LAN bridge.
4. Restore router configuration from preflight export if necessary and verify local gateway/DNS/Internet access first.
5. Observe remote-client connectivity and confirm the old NAS route still works.

## Public release policy

Publishing source in a public repository does **not** mean the image or router is certified. Do not tag a stable release or distribute a production container until every required end-to-end gate has passed on the E60iUGS. Include tested RouterOS version, actual host model, image digest and reproducible build hash in any release.
