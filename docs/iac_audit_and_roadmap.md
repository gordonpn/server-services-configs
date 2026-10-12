# Infrastructure as Code (IaC) Audit & Modernization Roadmap

This document captures the audit of unmanaged infrastructure components across the home lab and VPS nodes, along with the actionable roadmap to achieve 100% Infrastructure as Code coverage.

---

## 1. Executive Summary

| Domain | Current Coverage | Unmanaged Assets | Target IaC Tooling | Priority |
| :--- | :--- | :--- | :--- | :--- |
| **Cloudflare DNS & Edge** | 100% (Completed) | None (All 16 zone DNS records and VPS tunnel managed) | Terraform ([terraform/domains.tf](file:///terraform/domains.tf)) | Completed |
| **Kubernetes Workloads** | ~70% (Helmfile) | 5 standalone raw manifests (`cloudflared`, `redis`, `ntfy`, `coredns-scale`) | Helmfile ([k8s/charts/helmfile.yaml](file:///k8s/charts/helmfile.yaml)) | High |
| **Uptime Kuma Monitoring** | 100% (Completed) | None (7 push monitors and Slack notification imported) | Terraform ([terraform/uptime_kuma.tf](file:///terraform/uptime_kuma.tf)) | Completed |
| **Terraform Deploy on Push** | 0% (Manual tasks) | Automated CI/CD pipeline disabled; state stored locally | GitHub Actions ([.github/workflows/terraform.yml](file:///.github/workflows/terraform.yml)) | Medium |
| **Host OS & Firewall (VPS)** | Manual / Ad-hoc | UFW inactive on VPS, SSH exposed on public ports 22 and 443 | Ansible / K3s DaemonSet Hooks | Medium |
| **Legacy Host Services** | Manual | `autossh` (`vps-tunnel.service`) on `master` | Decommission (Replaced by Tailscale) | Medium |
| **Local Compose Stacks** | Tracked in Git | `/home/gordonpn/jellyfin/` directory drift risk | Symlink to repo compose files | Low |

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


---

## 3. Domain 2: Kubernetes Workloads & GitOps

### Current State
Core infrastructure (`kube-prometheus-stack`, `longhorn`, `actions-runner-controller`, `sealed-secrets`, `k3s-maintenance`) is declared in [k8s/charts/helmfile.yaml](file:///k8s/charts/helmfile.yaml) and deployed automatically on push via `.github/workflows/gitops.yml`.

### Unmanaged Raw Manifests
The following manifests are currently applied via ad-hoc `kubectl apply` tasks in [Taskfile.yaml](file:///Taskfile.yaml):
* `k8s/cloudflared-deployment.yaml` (Multi-replica Cloudflare Tunnel on `master`)
* `k8s/redis.yaml` (Redis deployment and service in `default` namespace)
* `k8s/ntfy/ntfy-deployment.yaml` and `k8s/ntfy/ntfy-pvc.yaml` (Push notification server)
* `k8s/coredns-scale.yaml` (CoreDNS horizontal replica override)

### Action Plan
* Migrate these manifests into Helmfile releases using either the `raw` chart or as sub-templates within `k3s-maintenance`.
* Deprecate the manual `k8s:apply:*` tasks in `Taskfile.yaml` in favor of the unified `task charts:apply`.

---

## 4. Domain 3: VPS Host OS & Firewall Hardening

### Current State
* Node `racknerd-edc1bc8` has `ufw` inactive.
* `sshd` listens on both public port 22 and 443.
* Node `master` runs `vps-tunnel.service` (`autossh` on port 443 to `23.95.192.74`).

### Action Plan
1. **Decommission Autossh:**
   * Stop and disable `vps-tunnel.service` on `master` since Tailscale WireGuard provides direct mesh connectivity (`100.88.170.93`).
2. **Automate Firewall Rules:**
   * Enable UFW on `racknerd-edc1bc8` with a default `deny` incoming policy.
   * Allow incoming traffic on `tailscale0` only.
   * Disable public port 443 SSH on the VPS.

---

## 5. Domain 4: Standalone Docker Compose Workloads

### Current State
* The Jellyfin media stack runs from `/home/gordonpn/jellyfin/docker-compose.yml`.
* A replica file exists in `docker-compose/jellyfin/docker-compose.yml`.

### Action Plan
* Replace `/home/gordonpn/jellyfin/docker-compose.yml` with a symlink to the version-controlled `docker-compose/jellyfin/docker-compose.yml` to prevent configuration drift.

---

## 6. Domain 5: Terraform Automated GitOps Pipeline (Deploy on Push)

### Current State
* The GitHub Actions Terraform workflow ([.github/workflows/terraform.yml](file:///.github/workflows/terraform.yml)) is disabled with `if: false`.
* Terraform state is stored locally in `terraform/terraform.tfstate` (gitignored).
* Changes are planned and applied manually via `task tf:plan` and `task tf:apply`.

### Action Plan (To-Do)
1. **Remote State Backend:**
   * Migrate Terraform state from local filesystem to a remote backend with state locking (such as MinIO S3 bucket on `master` or Cloudflare R2 / Terraform Cloud).
2. **GitHub Actions Secrets Provisioning:**
   * Configure repository secrets for automation:
     * `CLOUDFLARE_API_TOKEN`
     * `CLOUDFLARE_EMAIL`
     * `TF_VAR_kuma_password`
     * `TF_VAR_kuma_slack_webhook_url`
3. **Workflow Re-enablement & Path Scoping:**
   * Update [.github/workflows/terraform.yml](file:///.github/workflows/terraform.yml) to trigger only on pushes to `master` when files in `terraform/**` change:
     ```yaml
     on:
       push:
         branches:
           - master
         paths:
           - 'terraform/**'
       workflow_dispatch:
     ```
   * Remove `if: false` and ensure the workflow runs formatting checks, initialization, validation, and automated apply on merge.

