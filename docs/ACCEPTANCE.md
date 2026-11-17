# Acceptance and rollback checklist (RouterOS ARMv5 subnet router)

**Current certification state: tested on an ARMv5 hEX S with a remote LAN client and reboot persistence; still not long-term/security certified.**

## Minimum acceptance gate

- [x] Tailscale v1.104.7 compiled with Go 1.27.4, CGO disabled, GOARCH arm, GOARM=5
- [x] Static ELF ARM32 and SHA256 metadata checked
- [x] Minimal ARMv5 image packaged and TAR hash checked in Docker VM101
- [x] No-auth isolated **AMD64** launcher test succeeded (daemon, socket, CLI; no network)
- [x] ARMv5 runtime or QEMU ARMv5 smoke test including entrypoint executable
- [x] Linux TUN creation in ARMv5 image
- [x] Verify kernel IP forwarding, IPv4 routing, netfilter=off behavior under RouterOS
- [ ] Validate production firewall forward permissions and precise source NAT, with original routes preserved
- [x] Insert matching RouterOS `container` package; device mode enabled via authorized physical button
- [x] Confirm external USB EXT4, persistent state and free capacity after restart (sustained-load test still open)
- [x] Enroll container through human-approved login URL; no enrollment secret committed to image or repository
- [x] Advertise a test route and obtain approval in Tailscale console without displacing the NAS
- [x] External client receives ICMP responses from LAN host using the approved route; RouterOS's own input ICMP remains firewall-restricted
- [ ] Split DNS `home.arpa` resolves through chosen internal DNS, without breaking public DNS
- [x] Reboot RouterOS; reconnect and verify persistence of identity, routing, DHCP and DNS
- [ ] Deliberate failure of Tailscale daemon under watchdog policy: not tested (RouterOS reboot recovery passed)
- [x] Control-plane old NAS route disabled; **local NAS still advertises it** and must be cleared on device
- [x] Verify NAS remains connected with its individual Tailscale IP while route is disabled; local announcement withdrawal still open

## Known blockers

- The hEX S E60iUGS now has `container=yes`, matching RouterOS `container` package installed, and EXT4 USB storage. Physical validation was performed by cold power cycle.
- VM101 AMD64 smoke tests alone cannot certify ARMv5; **the binaries were subsequently started and authenticated on the actual E60iUGS**.
- The image uses BusyBox and Tailscale with `--netfilter-mode=off`. RouterOS NAT and return routing reached a LAN host from a remote client, but **firewall and ACL hardening remain to be audited**.
- RouterOS device mode required physical confirmation via a cold power cycle; do not automate or bypass the check.

## Safe rollback

1. Preserve old subnet router (NAS) advertisement and node until a replacement is certified. Do not revoke or delete it.
2. If newly deployed container or route fails, withdraw the NEW advertised route from Tailscale control plane; keep the old route enabled.
3. Stop only the new RouterOS container; remove its scoped veth route/firewall NAT entries using their unique comments; do not reset the router or touch unrelated DHCP, DNS, default gateway or LAN bridge.
4. Restore router configuration from preflight export if necessary and verify local gateway/DNS/Internet access first.
5. Observe remote-client connectivity and confirm the old NAS route still works.

## Public release policy

Publishing source in a public repository does **not** mean the image or router is certified. Do not tag a stable release or distribute a production container until remaining security, resilience, DNS and upgrade gates have passed. Include tested RouterOS version, actual host model, image digest and reproducible build hash in any release.
