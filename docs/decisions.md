# Implementation Decisions Log

This document records non-obvious engineering and implementation decisions made in Server Services Configs, ordered newest first.

## 2026-11-08: SHA256-verified helm-diff installation in GitOps workflow

- Decision: Install `helm-diff` v3.15.12 in `.github/workflows/gitops.yml` using exact version matching against `helm plugin list`, downloading the architecture-specific tarball, checking its SHA256 digest against pinned checksums, and extracting into `HELM_PLUGINS` without `|| true`.
- Rationale: Make `helm-diff` installation compatible with Helm 4 and fail closed if checksum verification or installation fails.
- Rejected alternatives: Unverified plugin installation or masking installation failures with `|| true`.
- Source: [#61 fix(gitops): install helm-diff with sha256 verification in helm 4](https://github.com/gordonpn/server-services-configs/pull/61), [#60 Install helm-diff plugin with SHA256 verification in GitOps workflow](https://github.com/gordonpn/server-services-configs/issues/60)

## 2026-11-07: Upgrade Helmfile to 1.8.2 for serverSide apply compatibility

- Decision: Pin `HELMFILE_VERSION` in `.github/workflows/gitops.yml` to `1.8.2`.
- Rationale: Resolve schema unmarshaling errors (`field serverSide not found in type state.ReleaseSpec`) encountered with version `1.2.3` during GitOps synchronization.
- Rejected alternatives: Not recorded in the source.
- Source: [#59 fix(gitops): bump helmfile to 1.8.2 to support serverSide apply](https://github.com/gordonpn/server-services-configs/pull/59), [#58 Bump Helmfile version in GitOps workflow to support serverSide apply](https://github.com/gordonpn/server-services-configs/issues/58)

## 2026-11-05: Force HTTP/2 over TCP and IPv4 edge routing for cloudflared

- Decision: Configure `cloudflared` in the workloads Helm chart with `--protocol http2` and `--edge-ip-version 4`.
- Rationale: Mitigate recurring replica mismatch alerts caused by connection drops across scheduled router reboots and WAN interruptions.
- Rejected alternatives: Default QUIC/UDP and dual-stack edge selection.
- Source: [#57 fix(k8s): configure cloudflared to use http2 over tcp in workloads chart](https://github.com/gordonpn/server-services-configs/pull/57), [#56 Configure cloudflared to use HTTP/2 over TCP in workloads chart](https://github.com/gordonpn/server-services-configs/issues/56)

## 2026-10-30: Edge VPS nftables firewall and symlinked media compose config

- Decision: Enforce a default-deny inbound firewall with `nftables` on the edge VPS (closing public SSH and preserving private Tailscale mesh administration and Cloudflare ingress) and replace drifted host Compose files for the standalone media stack with symlinks to the version-controlled `docker-compose/` definition.
- Rationale: Remove public SSH exposure on the edge node and eliminate configuration drift between running Docker Compose stacks and Git.
- Rejected alternatives: Not recorded in the source.
- Source: [#41 feat(vps): harden host firewall with nftables and close public ssh](https://github.com/gordonpn/server-services-configs/pull/41), [#32 Harden edge VPS host firewall](https://github.com/gordonpn/server-services-configs/issues/32), [#42 chore(compose): symlink jellyfin host compose configuration to repository](https://github.com/gordonpn/server-services-configs/pull/42), [#34 Symlink Jellyfin host compose configuration to repository](https://github.com/gordonpn/server-services-configs/issues/34)

## 2026-10-29: Replace reverse autossh VPS tunnel with Tailscale WireGuard mesh

- Decision: Decommission the legacy `autossh` systemd tunnel service on the home node and route cross-node and administrative traffic exclusively over the Tailscale WireGuard mesh.
- Rationale: Eliminate duplicate tunneling infrastructure now that Tailscale provides private node-to-node connectivity.
- Rejected alternatives: Maintaining the legacy reverse SSH tunnel service alongside Tailscale.
- Source: [#40 chore(vps): decommission legacy autossh tunnel service on master](https://github.com/gordonpn/server-services-configs/pull/40), [#39 Decommission legacy autossh VPS tunnel service](https://github.com/gordonpn/server-services-configs/issues/39)

## 2026-10-27: Pin cloudflared 2026.10.4 with readiness probes and client-side Helm apply

- Decision: Pin `cloudflared` container images to `2026.10.4`, add Kubernetes readiness probes and start-first Swarm rollouts, and keep the workloads Helm release on client-side apply rather than server-side apply.
- Rationale: Preserve zero-downtime tunnel rollouts and match existing field managers without breaking Helm upgrades.
- Rejected alternatives: Not recorded in the source.
- Source: [#38 [Security] Upgrade cloudflared to 2026.10.4](https://github.com/gordonpn/server-services-configs/pull/38), [#37 Upgrade active cloudflared connectors to the fixed release](https://github.com/gordonpn/server-services-configs/issues/37)

## 2026-10-18: Shared MinIO S3 OpenTofu backend and declarative Helmfile workloads

- Decision: Migrate unmanaged Kubernetes manifests into a declarative `k8s/charts/workloads` Helm chart managed by Helmfile, move Terraform/OpenTofu state to a MinIO S3 backend with native locking and fail-closed credential guards, and manage Cloudflare zone DNS records and Healthchecks.io checks as code (with `ignore_changes` on tunnel secrets and explicit `name = var.domain` apex handling).
- Rationale: Share state consistently between local workstations and CI, prevent missing-credential state operations, and eliminate manual DNS/monitoring drift.
- Rejected alternatives: Unmanaged raw Kubernetes YAML manifests and local-only Terraform state files.
- Source: [#31 feat(k8s): migrate standalone manifests to declarative workloads helm chart](https://github.com/gordonpn/server-services-configs/pull/31), [#29 feat(terraform): automate deployment with shared MinIO state](https://github.com/gordonpn/server-services-configs/pull/29), [#27 feat(terraform): manage healthchecks.io checks as code](https://github.com/gordonpn/server-services-configs/pull/27), [#24 feat(terraform): manage all cloudflare zone dns records as code](https://github.com/gordonpn/server-services-configs/pull/24)

## 2026-10-08: Prioritize OCI Always-Free k3s for disaster recovery over duplicate hosting

- Decision: Prioritize OCI Always-Free Ampere A1 for an independent offsite k3s control plane (GitOps reconstruction, backup restore tests, staging, and ARM64 validation) while keeping GCP `e2-micro` optional for secondary ingress redundancy and leaving external monitoring solely on Northflank.
- Rationale: Address distinct failure domains (disaster recoverability and edge ingress redundancy) rather than duplicating home compute or external monitoring.
- Rejected alternatives: Deploying another monitoring instance on GCP or collecting free VMs without a defined failure domain.
- Source: [#20 docs(cloud): record homelab failure domain decisions](https://github.com/gordonpn/server-services-configs/pull/20), [cloud_decision_context.md](cloud_decision_context.md)
