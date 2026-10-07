# Homelab and Free Cloud Decision Context

Status: architecture direction accepted; OCI and GCP infrastructure is planned, not deployed.

## Current responsibilities

RackNerd (`racknerd-edc1bc8`) already provides an external entry point through Cloudflare Tunnel and Caddy. Northflank already hosts Uptime Kuma independently of both Docker Swarm and k3s, providing external monitoring for the homelab.

Additional cloud resources should add a distinct responsibility or learning environment. Prefer major cloud providers' permanent free-tier allowances over expiring trial credits. Do not collect free VMs merely because they are free, or recreate ingress and monitoring without a specific redundancy goal.

| Environment | Responsibility | State |
| :--- | :--- | :--- |
| Home servers | Primary compute, storage, Docker Swarm, k3s, and heavier workloads | Existing |
| RackNerd | Primary ingress for the VPS proxy path, using cloudflared and Caddy | Existing |
| Northflank | Independent external monitoring through Uptime Kuma | Existing |
| OCI Ampere A1 | Offsite k3s, disaster recovery, staging, restore testing, and ARM64 testing | Next priority |
| GCP e2-micro | Lightweight utility node or ingress redundancy | Optional follow-up |

The existing direct-to-home Cloudflare tunnel also remains part of the current architecture. See [Ingress and External Routing Architecture](ingress_routing_architecture.md) for the deployed routes; the diagram below describes the intended additional capabilities.

## Intended topology

```text
                         Internet
                             |
                         Cloudflare
                             |
                 +-----------+-----------+
                 |                       |
             RackNerd               GCP e2-micro
          Existing ingress        Optional redundancy
             cloudflared             cloudflared
                Caddy              optional Caddy
                 |                       |
                 +-----------+-----------+
                             |
                     Tailscale / WireGuard
                             |
                      Home infrastructure
                  Docker Swarm / k3s / storage
                             |
                      GitOps + offsite backups
                             |
                    OCI Always-Free Ampere A1
                     Independent k3s environment
                  DR / staging / restore testing
                       ARM64 compatibility

             Northflank: independent Uptime Kuma
              observing the external environments
```

The diagram shows responsibilities, not an automatic failover mechanism. Each cloud environment introduces a separate host/provider failure domain while still sharing dependencies such as Cloudflare, GitHub, or the selected VPN.

## Decision: prioritize OCI offsite k3s

Use Always-Free Ampere A1 capacity for a tiny independent k3s environment, connected through Tailscale or WireGuard. Start with one node and one GitOps controller, choosing Argo CD or Flux after checking the resource budget.

Use it for backup restore testing, ARM64 container compatibility, staging isolated from home, and emergency hosting of a small selected set of critical services. The home servers continue to own primary storage and heavier workloads.

The central recovery question is:

> If the home k3s cluster disappeared, how much of the environment could GitOps and offsite backups reconstruct on OCI?

Do not continuously mirror the entire homelab. OCI must have its own control plane rather than depend on the home k3s API. Its bootstrap, secrets recovery, backups, and emergency service access must work when home is unavailable. Selected container images must support both `linux/amd64` and `linux/arm64`.

See [OCI Offsite k3s and Disaster Recovery](oci_offsite_k3s_dr.md) for delivery gates and recovery evidence.

## Decision: keep GCP lightweight and optional

Use an eligible `e2-micro` for a focused utility role: a secondary Cloudflare Tunnel connector, backup Caddy endpoint, Tailscale/WireGuard gateway, small automation or webhook receiver, or lightweight control-plane utility.

Ingress redundancy is the preferred candidate because it can remove RackNerd as the sole host supporting the VPS proxy path. Both connectors must reach home independently over the VPN. Northflank remains the external monitoring environment; do not deploy another Uptime Kuma on GCP.

This helps with a RackNerd outage while home is healthy. It does not make home-hosted services survive a home outage. See [GCP Utility Node and Ingress Redundancy](gcp_utility_ingress.md) for cost and routing constraints.

## Admission criteria for additional environments

- Define the distinct responsibility and the failure it addresses before provisioning.
- Verify current account, region, compute, storage, network, and IP eligibility. Trial credits do not prove sustainable free-tier operation.
- Declare infrastructure, bootstrap, and deployments in version control; keep credentials and state outside Git.
- Demonstrate the intended failure scenario and record the outcome under `docs/`.
- Treat free-tier capacity and availability as constraints to verify, not an availability guarantee.

OCI is the highest-value next project because recoverability and ARM64 validation add capabilities beyond the existing RackNerd, Northflank, and home environments.
