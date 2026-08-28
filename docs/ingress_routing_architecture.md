# Ingress & External Routing Architecture

This document describes the external routing models used to expose services hosted across the home lab infrastructure.

---

## 1. Direct Cloudflare Tunnel (Home Control Plane)

In the default routing model, `cloudflared` runs directly on the home server (`master`) to establish outbound tunnels to Cloudflare Edge data centers.

### Topology

```text
[ Internet User ]
       │ (Public HTTPS)
       ▼
[ Cloudflare Edge ]
       │ (Encrypted Cloudflare Tunnel Protocol: QUIC / HTTP/2)
       ▼
[ Home Server (master) ]
       ├── Kubernetes Deployment (default/cloudflared, 4 replicas)
       └── Host OS systemd service (cloudflared.service)
       │
       ▼ (Local routing)
[ Internal Services: Jellyfin, Jellyseerr, Ntfy, Swarmpit, Portainer, Jenkins ]
```

### Key Characteristics
* **Outbound Only:** The home server initiates and maintains outbound TLS/QUIC connections to Cloudflare Edge nodes (such as Boston `bos` and Newark `ewr`). No inbound ports are opened on the local ISP router or firewall.
* **Redundancy:** Runs both as a 4-replica Kubernetes Deployment ([cloudflared-deployment.yaml](file:///k8s/cloudflared-deployment.yaml)) and a host-level systemd service ([cloudflared.service](file:///etc/systemd/system/cloudflared.service)) for high availability across reboots and container engine maintenance.
* **Scope:** Used for primary home lab application access, media services, administrative dashboards, and internal alert webhooks.

---

## 2. Shielded VPS Proxy Pipeline (Cloudflare to VPS to Tailscale to Master)

For services requiring public isolation, custom header manipulation, or protection from direct home server exposure, traffic routes through an external VPS bastion node (`racknerd-edc1bc8`) before entering the private Tailscale mesh.

### Topology

```text
[ Client Browser ]
       │ (Public HTTPS)
       ▼
[ Cloudflare Edge ]
       │ (Cloudflare Tunnel: Managed via Terraform)
       ▼
[ VPS (racknerd-edc1bc8): cloudflared container ]
       │ (Internal Swarm Overlay: http://caddy:80 - No Host Ports Exposed)
       ▼
[ VPS (racknerd-edc1bc8): Caddy Reverse Proxy ]
       │ (Tailscale WireGuard Mesh: http://100.72.77.63:8080)
       ▼
[ Home Server (master): Target Service (e.g. whoami) ]
```

### Key Components & Responsibilities
1. **Cloudflare Edge:** Terminates public TLS and injects visitor identity headers (such as `CF-Connecting-IP`).
2. **VPS Cloudflare Tunnel ([terraform/tunnels.tf](file:///terraform/tunnels.tf)):**
   * Managed via Terraform (`cloudflare_tunnel` and `cloudflare_tunnel_config`).
   * Routes `test.gordon-pn.com` directly to `http://caddy:80` inside the internal Swarm overlay network.
3. **VPS Caddy Proxy ([docker-swarm/caddy](file:///docker-swarm/caddy/)):**
   * Connected to `cloudflared` over the private Swarm overlay network (`vps_shield_net`).
   * **Zero Host Ports Published:** No ports (80 or 443) are published on the VPS host OS, preventing direct origin bypass and header forging.
   * Preserves real client IPs by mapping `CF-Connecting-IP` to `X-Real-IP`.
   * Acts as a Layer 7 buffer for rate limiting, WAF rules, and routing logic before traffic touches the home network.
4. **Tailscale Overlay Network:** Bridges the VPS to the home server over WireGuard encryption (`100.88.170.93` -> `100.72.77.63:8080`), bypassing WAN port forwarding entirely.
5. **Master Backend Service ([docker-swarm/whoami](file:///docker-swarm/whoami/)):**
   * Runs on `master` pinned via Swarm placement constraints (`node.hostname == master`).
   * Listens on port `8080` on `master` reachable over Tailscale.

---

## 3. Comparison Matrix

| Attribute | Direct Home Tunnel | Shielded VPS Proxy |
| :--- | :--- | :--- |
| **Tunnel Termination** | Home server (`master`) | External VPS (`racknerd-edc1bc8`) |
| **Home Firewall Exposure** | None (Outbound Tunnel) | None (Tailscale Mesh Only) |
| **Home IP Secrecy** | Fully Hidden by Cloudflare | Fully Hidden by Cloudflare + VPS |
| **L7 Inspection / WAF** | Cloudflare Edge rules only | Cloudflare Edge + VPS Caddy custom middleware |
| **Network Path** | Client -> Cloudflare -> Master | Client -> Cloudflare -> VPS -> Tailscale -> Master |
| **Primary Use Cases** | Internal home apps (Jellyfin, Ntfy, Jenkins) | Public-facing microservices, API gateways, webhooks |
