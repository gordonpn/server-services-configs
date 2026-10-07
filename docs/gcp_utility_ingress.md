# GCP Utility Node and Ingress Redundancy

Status: optional follow-up after OCI recovery work. This is a design plan, not deployed infrastructure. See [Cloud Decision Context](cloud_decision_context.md) for responsibility boundaries.

## Objective

Give an eligible Google Cloud `e2-micro` one lightweight responsibility. Candidates are a secondary Cloudflare Tunnel connector, backup Caddy endpoint, Tailscale/WireGuard gateway, small automation/webhook receiver, or control-plane utility. Avoid general application hosting and do not deploy Uptime Kuma; Northflank already owns independent external monitoring.

The preferred candidate is redundancy for the existing RackNerd ingress path. It should reach the home backend independently, without sending traffic through RackNerd or depending on the home Swarm scheduler for startup.

## Eligibility and cost gate

Provider documentation checked on 2026-10-07. Google's recurring Compute Engine allowance covers one non-preemptible `e2-micro` worth of monthly hours across `us-west1`, `us-central1`, and `us-east1`, 30 GB-months of standard persistent disk, and limited outbound transfer. Use standard persistent disk rather than assuming the console's disk default is eligible. [Google Cloud Free Tier](https://cloud.google.com/free/docs/free-cloud-features#compute).

External IPv4 on a standard VM is separately priced at USD 0.005/hour, with only one free hour monthly per account. Cloud NAT is also billable. A tunnel initiates outbound connections, but that alone does not make its IP or egress path free. Validate an IPv6-only path for package downloads, Cloudflare, and the VPN, or explicitly record a paid exception before provisioning. [Google VPC network pricing](https://cloud.google.com/vpc/network-pricing#ipaddress).

If a viable configuration cannot meet the permanent free-tier preference, leave the node unprovisioned and record the constraint. Trial credits must not disguise recurring networking costs.

## Candidate topology

```text
                        Cloudflare
                            |
                +-----------+-----------+
                |                       |
             RackNerd              GCP e2-micro
             cloudflared            cloudflared
                Caddy             optional Caddy
                |                       |
                +-----------+-----------+
                            |
                    Tailscale / WireGuard
                            |
                       Home backend

          Northflank Uptime Kuma observes externally
```

## Connector and routing constraints

Use replicas of the same Cloudflare Tunnel as the simplest candidate for connector redundancy. Replicas provide additional connections; they do not establish a guaranteed RackNerd-primary/GCP-standby traffic policy. Explicit traffic steering requires a separate design and cost check. [Cloudflare tunnel availability and failover](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/tunnel-availability/).

The current tunnel origin is `http://caddy:80` inside the RackNerd Swarm network. A GCP connector cannot resolve that private service automatically. Either supply an equivalent local Caddy route on both hosts, preserving visitor IP behavior, or deliberately change and verify the shared origin configuration. A GCP Caddy must forward to home directly, not to the RackNerd Caddy.

Declare the VM, firewall, VPN, connector startup, and any Caddy configuration in version control. Keep tunnel/VPN credentials outside Git and avoid publishing host web ports for origin access. Reuse Northflank for external observation.

## Acceptance checks

- Given both connectors are healthy, when the chosen hostname is requested repeatedly, then both paths can reach the same backend with equivalent routing and visitor IP behavior.
- Given home is healthy, when the RackNerd connector is stopped, then new external requests succeed through GCP within a recovery threshold defined before the test.
- Given GCP is unavailable, when new requests are made, then RackNerd continues serving the selected hostname.
- Given home or the VPN backend path is unavailable, when requests are made, then the failure is observable; ingress redundancy must not be reported as application recovery.
- Given the VM reboots, when networking is ready, then the connector and optional proxy start without home orchestration.
- Given the planned resources and measured transfer, when eligibility is reviewed, then recurring charges are identified and the free-tier preference is met or an exception is explicitly recorded.

Document convergence times, backend-unreachable behavior, restart results, and rollback under `docs/`. A passing connector test proves RackNerd host redundancy for the chosen path, not independence from Cloudflare or the home backend.
