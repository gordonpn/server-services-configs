# Project Execution Queue

**Last Refined:** 2026-10-29  
**Repository:** [gordonpn/server-services-configs](https://github.com/gordonpn/server-services-configs)  
**GitHub Backlog:** [Open Issues](https://github.com/gordonpn/server-services-configs/issues)  

---

## NOW: Recommended Next Task

### [#33: Establish automated offsite replication for MinIO Terraform state](https://github.com/gordonpn/server-services-configs/issues/33)
* **Priority:** P1
* **Effort:** M
* **Readiness:** READY
* **Why now:** Resolves the critical single-disk failure risk on `master`. Replicates OpenTofu state snapshots to an offsite S3-compatible cloud bucket (e.g. Cloudflare R2) so infrastructure state survives local hardware failure.
* **First action:** Evaluate offsite storage target bucket options, credentials, and automated replication tooling.
* **Definition of Done:** Terraform state bucket on MinIO replicates automatically to offsite bucket with verified recovery procedures.
* **Unblocks:** Critical disaster recovery foundation for home infrastructure state.

---

## NEXT: Upcoming Work

1. **[#36: Purge obsolete deployment scripts, legacy CI pipelines, and dead documentation](https://github.com/gordonpn/server-services-configs/issues/36)**
   * **Priority:** P2 | **Effort:** S | **Readiness:** READY
   * **Dependencies:** None.
   * **Rationale:** Eliminates technical debt by removing dead shell scripts (`scripts/ping.sh`, `scripts/ddns-start`, `scripts/force_rebalance.sh`, `scripts/deploy.sh`), dead CI configs (`Jenkinsfile`, `.drone.yml`), and outdated references to decommissioned Raspberry Pi nodes.

2. **[#22: Export Uptime Kuma metrics to Prometheus](https://github.com/gordonpn/server-services-configs/issues/22)**
   * **Priority:** P1 | **Effort:** S | **Readiness:** READY
   * **Dependencies:** None.
   * **Rationale:** Correlates external Northflank Uptime Kuma monitor observations with internal Prometheus metrics by configuring an authenticated HTTPS scrape target.

3. **[#14: Provision a reproducible Always-Free OCI A1 foundation](https://github.com/gordonpn/server-services-configs/issues/14)**
   * **Priority:** P1 | **Effort:** M | **Readiness:** READY
   * **Dependencies:** Tenancy home region eligibility and A1 capacity verification.
   * **Rationale:** Initiates the strategic offsite disaster recovery track (Epic #12) by creating a reproducible ARM64 compute instance and private Tailscale network path outside the home failure domain.

---

## BLOCKERS & ACTIVE DECISIONS

* **Decision 1 (Offsite Backup Target):** Standardize on Cloudflare R2 (recommended: 10GB free tier, zero egress fees, existing Terraform provider) or OCI Object Storage for MinIO state replication (#33) and Longhorn snapshot sync (#35).
* **Decision 2 (OCI GitOps Controller):** Select Flux CD (recommended: minimal memory footprint on ARM64) or Argo CD for autonomous reconciliation on OCI (#15).

---

## LATER: Remaining Strategic Backlog

* **[#12: Build an OCI A1 offsite k3s disaster recovery environment](https://github.com/gordonpn/server-services-configs/issues/12)** (Epic | P1 | XL)
  * [#15: Bootstrap independent OCI k3s reconciliation from Git](https://github.com/gordonpn/server-services-configs/issues/15) (Story | P1 | M | Blocked by #14)
  * [#35: Configure encrypted offsite backup sync and Sealed Secrets key escrow](https://github.com/gordonpn/server-services-configs/issues/35) (Story | P1 | M | Blocked by #14, #33)
  * [#16: Make the critical recovery subset restorable from offsite backups](https://github.com/gordonpn/server-services-configs/issues/16) (Story | P1 | M | Blocked by #15, #35)
  * [#17: Prove ARM64 disaster recovery of the selected home services on OCI](https://github.com/gordonpn/server-services-configs/issues/17) (Story | P1 | L | Blocked by #15, #35, #16)
* **[#13: Evaluate optional GCP e2-micro utility and ingress redundancy](https://github.com/gordonpn/server-services-configs/issues/13)** (Epic | P3 | L | On Hold)
  * [#18: Validate sustainable GCP e2-micro utility node eligibility](https://github.com/gordonpn/server-services-configs/issues/18) (Story | P3 | S | On Hold)
  * [#19: Prove RackNerd ingress host redundancy through GCP](https://github.com/gordonpn/server-services-configs/issues/19) (Story | P3 | M | On Hold, Blocked by #18)
