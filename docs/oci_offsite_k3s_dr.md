# OCI Offsite k3s and Disaster Recovery

Status: planned. This is a delivery plan, not an executed deployment runbook. The decision and responsibility boundaries are recorded in [Cloud Decision Context](cloud_decision_context.md).

## Objective and scope

Build a tiny independent ARM64 k3s environment on Oracle Cloud Always-Free Ampere A1. Use it for GitOps reconstruction, offsite backup restore tests, staging, multi-architecture validation, and emergency hosting of a selected critical subset.

Start with one k3s server and choose one controller, Argo CD or Flux. Keep the home Docker Swarm and heavier workloads at home. Do not extend the home control plane into OCI, synchronously replicate every volume across the WAN, or continuously mirror every application.

## Free-tier eligibility

Verify provider limits against current official documentation prior to provisioning. Published baseline terms list 1,500 A1 OCPU-hours and 9,000 GB-hours per month, equivalent to 2 OCPUs and 12 GB for Always-Free tenancies. They also list 200 GB combined boot/block storage and five volume backups. Compute must be in the tenancy home region; capacity shortages and idle-instance reclamation are possible. Recheck account entitlements before sizing or applying infrastructure. [Oracle Always Free Resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm).

The documented object-storage allowance is small and account-dependent. Measure the selected backup set against current storage, request, and transfer allowances before choosing its offsite destination. A VM's local disk must not be the only backup copy. [Oracle storage allowances](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm).

## Delivery gates

| Gate | Deliverable | Check |
| :--- | :--- | :--- |
| Foundation | Eligible A1 instance, networking, firewall, VPN enrollment, and recoverable infrastructure state | Recreate the node from tracked configuration; confirm sizing and cost eligibility |
| GitOps bootstrap | Independent k3s and one controller with OCI-specific configuration | Reconcile a test workload with access to the home API blocked |
| Recovery scope | Explicit service inventory, image support, dependencies, data sizes, RPO, and RTO | Every selected service has measurable recovery criteria and every excluded service has a reason |
| Offsite backup | Encrypted data, configuration, and required recovery keys stored outside home | Retrieve and verify backups without the home storage or control plane |
| Recovery exercise | Reconstruct the selected subset on a clean OCI environment | Check each service's data and health against its recorded criteria |
| ARM64 readiness | Compatible images and runtime dependencies | Verify image manifests and functional behavior on ARM64 and AMD64 |

RPO is the maximum accepted age of recovered data; RTO is the maximum accepted time to restore service. Select concrete values per service before the drill rather than declaring success after observing the results.

## Bootstrap and secret recovery

The existing home GitOps workflow uses self-hosted runners on `master`. OCI recovery must not require those runners to be alive. Provide an independent bootstrap path and let the offsite controller pull its own desired state from Git.

Use an explicit OCI deployment target so reconciliation cannot apply home node selectors, host paths, or storage classes unchanged. Recover Git credentials, VPN enrollment, application secrets, and any Sealed Secrets decryption keys through an encrypted mechanism available without home. Never commit plaintext secrets or infrastructure state.

Keep staging credentials, data, and hostnames separate from production. Disable production-writing integrations until emergency activation is explicitly performed.

## Backup boundary

The current Longhorn backup target is MinIO on storage attached to `master`. It provides local backup durability, but it disappears from reach with the home server. An offsite copy is necessary for this recovery exercise.

For each selected service, record:

- The authoritative data source and a consistent backup/export procedure.
- Offsite location, encryption-key recovery, retention, integrity check, and measured size.
- Configuration and external dependencies required beyond Kubernetes manifests.
- Storage restore method compatible with OCI, without assuming home Longhorn settings apply.
- Recovery order, RPO, RTO, and functional checks, including data correctness.

## Recovery exercise

1. Select the critical subset and record resource budgets, recovery objectives, and excluded workloads.
2. Create a fresh OCI node and bootstrap its independent control plane and GitOps controller.
3. Simulate home loss by blocking the recovery environment's access to home APIs, runners, storage, and service endpoints. Keep production home services running.
4. Recover secrets and fetch verified offsite backups, then restore data and reconcile the selected workloads.
5. Exercise emergency service access through a path that does not require a healthy home host. Check it externally using the existing Northflank monitoring environment.
6. Record elapsed recovery time, backup age, per-service data checks, unsupported dependencies, and resource usage under `docs/`.
7. Document activation and failback, including which data copy becomes authoritative and how to prevent concurrent writers.

Given home is unreachable, when GitOps and offsite backups reconstruct the selected subset on a clean OCI environment, then every selected service must satisfy its recorded health, data, RPO, and RTO checks. Missing/corrupt backups, unavailable recovery keys, and unsupported ARM64 images must produce explicit failed checks rather than partial success.

## Choices to resolve before implementation

- Eligible tenancy home region, current capacity, and actual A1 allocation.
- Argo CD or Flux, chosen for resource fit and operational learning value.
- Critical service inventory and recovery objectives.
- Offsite backup location, consistency method, retention, and key recovery.
- Tailscale or WireGuard, with independently recoverable enrollment.
- Emergency hostname/routing and controlled failback procedure.
