# REFERENCE ONLY — NOT AN AUTOMATED INSTALLER.
# Before use: review LAN range, veth addresses, RouterOS 7.25+ syntax,
# firewall chain ordering, existing routes/NAT, backups and device mode.
# Container feature requires a physical confirmation and matching package.
#
# IMPORTANT: Do not apply these commands while the old Tailscale subnet router
# is still the only verified remote management path.
#
# Step 1: isolate the container from production LAN bridge:
# /interface/veth add name=ao-ts-veth address=172.30.254.2/30 gateway=172.30.254.1
# /interface/bridge add name=ao-ts-bridge
# /ip/address add address=172.30.254.1/30 interface=ao-ts-bridge
# /interface/bridge/port add bridge=ao-ts-bridge interface=ao-ts-veth
#
# Step 2: allow NAT for container's own internet egress, only if needed:
# /ip/firewall/nat add chain=srcnat src-address=172.30.254.2/32 action=masquerade comment="ts container outbound - REVIEW"
#
# Step 3: tailnet source routes for replies to the container:
# /ip/route add dst-address=100.64.0.0/10 gateway=172.30.254.2 comment="ts overlay -> veth - REVIEW"
# Network policy: RouterOS firewall forward must allow only approved remote
# clients to the intended LAN subnet and allow ESTABLISHED/RELATED replies.
# For LAN clients whose default gateway is NOT MikroTik, an appropriately
# scoped srcnat from 100.64.0.0/10 to the LAN may be required.
# Do not blanket allow-forward or blanket NAT.
#
# Step 4: prepare external disk and persistent state mount. No secrets here.
# See https://help.mikrotik.com/docs/spaces/ROS/pages/84901929/Container
# /container/mounts add list=ao-ts-state src=disk1/ao-ts-state dst=/var/lib/tailscale
# /container/envs add list=ao-ts key=TS_ROUTES value="192.168.88.0/24"
# Do NOT store long-lived TS_AUTHKEY in a source file or Git.
#
# Step 5: after validation and installing the correct container package,
# import the verified image TAR, configure veth/mount/env/start-on-boot.
# DO NOT copy production CIDRs or secrets into public documentation.
#
# Step 6: remote client verifies LAN/DNS and reboot recovery before
# withdrawing the old NAS route advertisement.
