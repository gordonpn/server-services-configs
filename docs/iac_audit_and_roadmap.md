# Infrastructure as Code (IaC) Audit & Modernization Roadmap

This document captures the audit of unmanaged infrastructure components across the home lab and VPS nodes, along with the actionable roadmap to achieve 100% Infrastructure as Code coverage.

---

## 1. Executive Summary

| Domain | Current Coverage | Unmanaged Assets | Target IaC Tooling | Priority |
| :--- | :--- | :--- | :--- | :--- |
| **Cloudflare DNS & Edge** | 100% (Completed) | None (All 16 zone DNS records and VPS tunnel managed) | Terraform ([terraform/domains.tf](file:///terraform/domains.tf)) | Completed |
| **Kubernetes Workloads** | 100% (Completed) | None (All workloads managed via Helmfile workloads chart) | Helmfile ([k8s/charts/helmfile.yaml](file:///k8s/charts/helmfile.yaml)) | Completed |
| **Uptime Kuma Monitoring** | 100% (Completed) | None (7 push monitors and Slack notification imported) | Terraform ([terraform/uptime_kuma.tf](file:///terraform/uptime_kuma.tf)) | Completed |
| **Healthchecks.io Monitoring** | Checks Managed | Slack integration configured externally in Healthchecks.io (channel attached via data source) | Terraform ([terraform/healthchecks.tf](../terraform/healthchecks.tf)) | Completed |
| **Terraform Deploy on Push** | 100% (Completed) | Automated PR planning and master apply verified | GitHub Actions ([.github/workflows/terraform.yml](../.github/workflows/terraform.yml)) | Completed |
| **Host OS & Firewall (VPS)** | 100% (Completed) | Inbound host access restricted to Tailscale; public ports 22/443 closed | nftables ([scripts/vps-firewall/nftables.conf](../scripts/vps-firewall/nftables.conf)) | Completed |
| **Legacy Host Services** | Systemd | `autossh` (`vps-tunnel.service`) on `master` | Decommissioned ([#39](https://github.com/gordonpn/server-services-configs/issues/39)) | Completed |
| **Local Compose Stacks** | 100% (Completed) | None (Runtime compose file symlinked to repository) | Symlink ([#34](https://github.com/gordonpn/server-services-configs/issues/34)) | Completed |

---

## 2. Domain 1: Cloudflare DNS & Edge Infrastructure (Completed)

### State & Coverage
All 16 live DNS records for `gordon-pn.com` and the VPS shield tunnel are managed declaratively in Terraform with zero drift (`task tf:plan` detailed exit code 0):
* [terraform/domains.tf](file:///terraform/domains.tf) manages the 15 standard DNS records (Cloudflare Pages, SendGrid deliverability, ImprovMX MX/SPF, and internal tunnel ingress CNAMEs).
* [terraform/tunnels.tf](file:///terraform/tunnels.tf) manages the VPS shield tunnel (`vps-shield-tunnel`), ingress rules, and `test` CNAME record.

### In-Scope Records Managed
1. **Frontend / Cloudflare Pages:**
   * `@` (`gordon-pn.com`) -> `portfolio-4tf.pages.dev` (CNAME, proxied)
   * `www` -> `portfolio-4tf.pages.dev` (CNAME, proxied)
   * `gym` -> `gym-calculator.pages.dev` (CNAME, proxied)
   * `notes` -> `notes-1op.pages.dev` (CNAME, proxied)
2. **Internal Ingress & Services:**
   * `swarmpit` -> `gordon-pn.com` (CNAME, proxied)
   * `portainer` -> `gordon-pn.com` (CNAME, proxied)
   * `jenkins` -> `gordon-pn.com` (CNAME, proxied)
   * `ntfy` -> `35e86fee-93ab-4954-a01c-d40026bd42ca.cfargotunnel.com` (CNAME, proxied)
   * `ssh` -> `3f08a512-41c7-4448-831c-742e41a33afb.cfargotunnel.com` (CNAME, proxied)
   * `test` -> `512869b9-b95e-4c49-a6ba-3878e71ca4c5.cfargotunnel.com` (CNAME, proxied)
3. **Email Deliverability & Inbound Routing:**
   * SendGrid: `em7255`, `s1._domainkey`, `s2._domainkey` (CNAMEs, unproxied)
   * ImprovMX: `MX` records (`mx1.improvmx.com` priority 10, `mx2.improvmx.com` priority 20)
   * ImprovMX SPF: `TXT` record `v=spf1 include:spf.improvmx.com ~all`

### Invariants & Provider Nuances
* **Apex Record Names:** The Cloudflare Terraform provider requires `name = var.domain` for apex records (not `"@"`). Using `"@"` results in forced destroy and recreate in OpenTofu.
* **Content vs Value:** The provider v4 deprecates `value` in favor of `content`.
* **State Reconciliation:** During resource import, provider v4.52.9 leaves `content` and `allow_overwrite` as null in state. A safe attribute reconciliation setting `content` to the live API answer and `allow_overwrite = false` achieves a zero-drift plan without running destructive writes.

### Adoption, State Reconciliation & Rollback Runbook
1. **Live Zone Inventory:**
   * Query the Cloudflare DNS API (`GET /zones/<zone_id>/dns_records`) to obtain live record IDs, types, and target content.
2. **Resource Import:**
   * Run `tofu import cloudflare_record.<name> <zone_id>/<record_id>` for each DNS record.
   * Run `tofu import cloudflare_tunnel.<name> <account_id>/<tunnel_id>` for Cloudflare tunnels.
3. **State Reconciliation Safeguard:**
   * Because Cloudflare Provider v4.52.9 leaves `content` and `allow_overwrite` as `null` in state during import, a normal plan will report in-place modifications (`content = null -> <expected>`, `allow_overwrite = null -> false`).
   * Capture a private backend snapshot using the [state recovery procedure](terraform_iac.md#pull-state-via-cli) before editing.
   * Reconcile `instances[0].attributes.content` with the matching live API answer and set `allow_overwrite = false`.
   * Publish only reviewed state changes through the backend-aware [state restoration procedure](terraform_iac.md#restore-state), preserving locking, lineage, and serial safeguards.
   * Verify with `tofu plan -detailed-exitcode` (must exit 0 with zero proposed changes).
4. **Drift Detection Verification:**
   * Introduce a temporary change in configuration and verify `tofu plan -detailed-exitcode` exits with code 2, proving drift detection remains active and unsuppressed.
5. **Rollback Procedure:**
   * If state corruption occurs during import, stop other writers and follow the [backend-aware recovery procedure](terraform_iac.md#restore-state). Copying a local file does not restore MinIO state.
   * Because no `tofu apply` write calls are executed against Cloudflare during adoption, live DNS records remain completely intact and unaffected.
6. **Scope Boundary Clarification:**
   * The 100% coverage applies to all 16 active records present in the live Cloudflare DNS zone `gordon-pn.com`. Historical service references in Compose/Swarm configurations (e.g. `drone` or `traefik`) route via internal networks or local Traefik routing rules and do not correspond to public Cloudflare DNS records.

---

## 3. Domain 2: Kubernetes Workloads & GitOps (Completed)

### State & Coverage
All user-facing Kubernetes workloads and scaling policies are managed declaratively in Helmfile with zero drift (`task charts:diff` exits with 0):
* [k8s/charts/workloads](file:///k8s/charts/workloads) manages all standalone application workloads in the `default` namespace:
  * `cloudflared`: 4-replica Cloudflare Tunnel deployment pinned to `master`.
  * `redis`: Redis deployment, service, and persistent volume claim `redis-data` on `longhorn-master`.
  * `ntfy`: Ntfy push notification deployment, service, and persistent volume claim `ntfy-data` on `local-path`.
  * `lectures-notifier-et-10m`: Scheduled CronJob with `imagePullPolicy: IfNotPresent` and `restartPolicy: Never`.
* [k8s/charts/k3s-maintenance](file:///k8s/charts/k3s-maintenance/templates/coredns-config-enforcer.yaml) enforces CoreDNS replica scaling (5 replicas) and topology spread constraints (`ScheduleAnyway`) continuously without ad-hoc manual scaling manifests.
* Core infrastructure and workloads are deployed uniformly via `task charts:apply` and the automated GitOps workflow ([.github/workflows/gitops.yml](file:///.github/workflows/gitops.yml)).

### Deprecations & Cleanups
* Deleted loose, unmanaged manifests: `k8s/cloudflared-deployment.yaml`, `k8s/redis.yaml`, `k8s/ntfy/`, `k8s/lectures-notifier.yaml`, `k8s/coredns-scale.yaml`, and redundant `k8s/runner-rbac.yaml`.
* Deprecated manual `k8s:apply:*` tasks in `Taskfile.yaml`: `task k8s:apply:all` now directly invokes `task charts:apply`.
* Added `task charts:lint:workloads` and `task charts:lint:all`.

---

## 4. Domain 3: VPS Host OS & Firewall Hardening (Completed in [#32](https://github.com/gordonpn/server-services-configs/issues/32))

### Current State
* Node `racknerd-edc1bc8` host firewall is enforced via `nftables` (`table inet host_firewall`) with a default-deny inbound policy.
* Inbound host access on `racknerd-edc1bc8` is restricted exclusively to `tailscale0`, loopback, and internal container networks (`docker_gwbridge`, `docker0`, `flannel.1`, `cni0`).
* Public SSH on TCP ports 22 and 443 is closed and unreachable from WAN (`eth0`).
* Tailscale WireGuard encapsulation (`eth0:41641/udp`) and ICMP remain permitted.
* Node `master` legacy `vps-tunnel.service` (`autossh`) is stopped, disabled, and removed.

### Action Plan
1. **Decommission Autossh (Completed in [#39](https://github.com/gordonpn/server-services-configs/issues/39)):**
   * Stopped and disabled `vps-tunnel.service` on `master` (`sudo systemctl disable --now vps-tunnel.service`).
   * Removed `/etc/systemd/system/vps-tunnel.service` and reloaded systemd daemon.
   * Confirmed no orphaned `autossh` processes remain running.
   * All administrative access and service communications route securely over the private Tailscale WireGuard mesh (`100.88.170.93` <-> `100.72.77.63`).
2. **Automate Firewall Rules (Completed in [#32](https://github.com/gordonpn/server-services-configs/issues/32)):**
   * Applied default-deny inbound host policy via native `nftables` configuration ([scripts/vps-firewall/nftables.conf](../scripts/vps-firewall/nftables.conf)).
   * Enabled and started `nftables.service` to persist rules across host reboots without interfering with Docker Swarm overlay or K3s Flannel networking.
   * Removed legacy `Port 443` from `/etc/ssh/sshd_config` and drop-ins; verified SSH over Tailscale remains available and public WAN SSH is unreachable.

---

## 5. Domain 4: Standalone Docker Compose Workloads (Completed in [#34](https://github.com/gordonpn/server-services-configs/issues/34))

### Current State
* The Jellyfin media automation stack (`jellyfin`, `jellyseerr`, `sonarr`, `radarr`, `prowlarr`, `rdtclient`, `autoscan`, `flaresolverr`) runs as a standalone Docker Compose stack directly on `master`.
* The host compose file `/home/gordonpn/jellyfin/docker-compose.yml` is configured as a symbolic link pointing to the version-controlled file at `/home/gordonpn/workspace/server-services-configs/docker-compose/jellyfin/docker-compose.yml`.
* All 8 containers run stably without configuration drift between host runtime and git.

---

## 6. Domain 5: Terraform Automated GitOps Pipeline (Deploy on Push - Completed)

### Current State
* Terraform state migrated to MinIO S3 backend (`terraform-state` bucket on `master` backed by persistent hostPath storage on 1TB SSD).
* MinIO service exposed via NodePort `30900` over Tailscale for local workstation `task tf:plan` and `task tf:apply` execution.
* GitHub Actions repository secrets configured for automation:
  * `MINIO_ACCESS_KEY`
  * `MINIO_SECRET_KEY`
  * `CLOUDFLARE_API_TOKEN`
  * `CLOUDFLARE_EMAIL`
  * `TF_VAR_ACCOUNT_ID`
  * `TF_VAR_KUMA_PASSWORD`
  * `TF_VAR_KUMA_SLACK_WEBHOOK_URL`
  * `TF_VAR_HEALTHCHECKSIO_API_KEY`
* The GitHub Actions Terraform workflow ([.github/workflows/terraform.yml](../.github/workflows/terraform.yml)) runs on `home-lab-runners`:
  * Scoped triggers on `terraform/**`, `Taskfile.yaml`, `scripts/ci/**`, `tests/**`, and the Terraform workflow itself.
  * Runs offline backend credential regression checks before contacting infrastructure.
  * Runs formatting checks, initialization, validation, and speculative planning on pull requests.
  * Automatically reconciles infrastructure changes on pushes to `master` (verified in PR #40).
* Lock-contention and backup-restore exercises remain unverified. The Longhorn recurring backup does not back up the Terraform state bucket.
* Refer to [docs/terraform_iac.md](terraform_iac.md) for architecture, operational workflows, and disaster recovery procedures.

