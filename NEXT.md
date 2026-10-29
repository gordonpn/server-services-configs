# Project Execution Queue

**Last Refined:** 2026-10-29  
**Repository:** [gordonpn/server-services-configs](https://github.com/gordonpn/server-services-configs)  
**GitHub Backlog:** [Open Issues](https://github.com/gordonpn/server-services-configs/issues)  

---

## NOW: Recommended Next Task

### [#39: Decommission legacy autossh VPS tunnel service on master](https://github.com/gordonpn/server-services-configs/issues/39)
* **Priority:** P2
* **Effort:** XS
* **Readiness:** IN PROGRESS
* **Why now:** Decommissions the obsolete `vps-tunnel.service` (`autossh` on port 443 to `23.95.192.74`) on `master` because cross-node and administrative communications route securely through the private Tailscale WireGuard mesh. Caddy and Cloudflare Tunnel on the VPS remain active.
* **First action:** Stop and disable `vps-tunnel.service` on `master`, remove `/etc/systemd/system/vps-tunnel.service`, and verify no orphaned `autossh` processes remain.
* **Definition of Done:** `vps-tunnel.service` is inactive, disabled, and removed; `pgrep autossh` returns nothing; Tailscale mesh routing between `master` and `racknerd-edc1bc8` continues uninterrupted.
* **Unblocks:** Removes an unnecessary background service and failure loop from `master`.

---

## NEXT: Upcoming Work

1. **[#32: Harden edge VPS host firewall (racknerd-edc1bc8)](https://github.com/gordonpn/server-services-configs/issues/32)**
   * **Priority:** P1 | **Effort:** S | **Readiness:** READY; independent of other open issues.
   * **Dependencies:** None.
   * **Rationale:** Reduces the RackNerd VPS attack surface by enforcing default-deny inbound host access (allowing `tailscale0` only) and closing public SSH ports 22 and 443, while preserving Cloudflare ingress via Caddy over Tailscale.

2. **[#33: Establish automated offsite replication for MinIO Terraform state](https://github.com/gordonpn/server-services-configs/issues/33)**
   * **Priority:** P1 | **Effort:** M | **Readiness:** READY
   * **Dependencies:** None.
   * **Rationale:** Resolves the critical single-disk failure risk on `master`. Replicates OpenTofu state snapshots to an offsite S3-compatible cloud bucket (e.g. Cloudflare R2) so infrastructure state survives local hardware failure.

3. **[#34: Symlink Jellyfin host compose configuration to repository](https://github.com/gordonpn/server-services-configs/issues/34)**
   * **Priority:** P2 | **Effort:** XS | **Readiness:** READY
   * **Dependencies:** None (Trivial operational fix).
   * **Rationale:** Replaces runtime compose file `/home/gordonpn/jellyfin/docker-compose.yml` on `master` with a symlink to version-controlled `docker-compose/jellyfin/docker-compose.yml`, preventing host configuration drift.

4. **[#36: Purge obsolete deployment scripts, legacy CI pipelines, and dead documentation](https://github.com/gordonpn/server-services-configs/issues/36)**
   * **Priority:** P2 | **Effort:** S | **Readiness:** READY
   * **Dependencies:** None.
   * **Rationale:** Eliminates technical debt by removing dead shell scripts (`scripts/ping.sh`, `scripts/ddns-start`, `scripts/force_rebalance.sh`, `scripts/deploy.sh`), dead CI configs (`Jenkinsfile`, `.drone.yml`), and outdated references to decommissioned Raspberry Pi nodes.

5. **[#14: Provision a reproducible Always-Free OCI A1 foundation](https://github.com/gordonpn/server-services-configs/issues/14)**
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
