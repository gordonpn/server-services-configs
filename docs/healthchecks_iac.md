# Healthchecks.io Infrastructure as Code (IaC)

This document details the configuration, state adoption, credential handling, and operational runbook for Healthchecks.io dead man's snitch monitoring managed via Terraform.

---

## 1. Architecture and Separation of Responsibilities

The homelab infrastructure separates external telemetry into distinct failure domains:
* **Uptime Kuma (Northflank):** Responsible for real-time heartbeat push monitoring of nodes and orchestrator layers (Host OS, K3s Agent, and Docker Swarm), as well as internal HTTP services.
* **Healthchecks.io (SaaS):** Responsible for dead man's snitches and cron execution monitoring. Jobs send pings on scheduled intervals; if a job fails or misses its deadline plus grace window, Healthchecks triggers notifications via configured integrations (Slack).

---

## 2. Inventory and Scope

### Managed Checks

| Check Name | Slug | Schedule / Interval | Timezone | Grace | Integrations | Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `scraper` | `scraper` | `*/5 10-18 * * *` | `America/New_York` | 900s (15m) | Slack (`#healthchecks`) | Monitors scheduled scrape runner jobs on K3s |

* **Concrete Caller:** The `scraper` check is pinged by the scheduled web scraper workflow executing inside K3s on the self-hosted ARC runner set `arc-runner-set-scraper` (`home-lab-runners-scraper`). It issues a `start` ping upon runner job startup and a `success` ping upon clean job completion.

### Integrations and Channels
* **Slack Integration:** ID `fd532f77-c68c-42fc-b70b-26ea154b6c16` posting alerts to channel `#healthchecks`. The Slack webhook integration itself is configured externally in Healthchecks.io project settings. OpenTofu discovers the channel via data source `healthchecksio_channel.slack` and manages the check's channel assignment, while the external Slack app and webhook lifecycle remain managed outside Terraform.

### Historical Script Callers (Out of Scope / Legacy)
The following scripts in `scripts/` previously referenced Healthchecks UUIDs:
* `scripts/backup.sh` (`HC_UUID`): Historical host backup script. Replaced by Longhorn MinIO recurring backups.
* `scripts/deploy.sh` (`UPDATE_HC_UUID`): Historical manual Swarm deployment script. Replaced by automated GitOps workflows.
* `scripts/force_rebalance.sh` (`REBALANCE_HC_UUID`): Historical Swarm worker rebalance script.
* `scripts/ping.sh` (`PING_HC_UUID`): Historical host ping script. Replaced by Uptime Kuma push monitors.

These legacy scripts do not have active checks in the current Healthchecks project and their credentials are not present in host environment files.

---

## 3. Terraform Provider Configuration

The configuration uses the `kristofferahl/healthchecksio` provider pinned to `~> 2.3.0` in [terraform/domains.tf](../terraform/domains.tf) and declared in [terraform/healthchecks.tf](../terraform/healthchecks.tf).

### Provider Declaration
```hcl
variable "healthchecksio_api_key" {
  description = "Healthchecks.io API Key (read-write)"
  type        = string
  sensitive   = true
}

provider "healthchecksio" {
  api_key = var.healthchecksio_api_key
}

data "healthchecksio_channel" "slack" {
  kind = "slack"
  name = "#healthchecks"
}

resource "healthchecksio_check" "scraper" {
  name     = "scraper"
  schedule = "*/5 10-18 * * *"
  timezone = "America/New_York"
  grace    = 900
  channels = [
    data.healthchecksio_channel.slack.id
  ]
}
```

---

## 4. Operational Runbook

### Credential Storage and Retrieval
The read-write API key is stored securely in the macOS Keychain under service name `healthchecks_api_key`.
* **Retrieve key from Keychain:**
  ```bash
  security find-generic-password -s "healthchecks_api_key" -w
  ```
* **Local variable file:**
  Set `healthchecksio_api_key` in `terraform/terraform.tfvars` (gitignored). An example template is maintained at [terraform/terraform.tfvars.example](../terraform/terraform.tfvars.example).

### State Adoption Procedure (Import)
To adopt an existing Healthchecks.io check into Terraform:
1. Capture a private backup of the configured backend using the [shared state recovery procedure](terraform_iac.md#pull-state-via-cli). Export backend and provider credentials before proceeding.
2. Import the check using its UUID:
   ```bash
   tofu -chdir=terraform import healthchecksio_check.scraper <check-uuid>
   ```
3. Verify zero drift:
   ```bash
   tofu -chdir=terraform plan -detailed-exitcode
   ```
   An exit code of `0` confirms the local configuration matches live Healthchecks state.

### Drift Detection Verification
To verify that drift detection is functional:
1. Introduce a deliberate temporary difference in `terraform/healthchecks.tf` (e.g. modify `grace` from 900 to 901).
2. Run `tofu -chdir=terraform plan -detailed-exitcode`.
3. Confirm the command exits with code `2` and displays the exact attribute diff.
4. Revert the modification and confirm the plan returns to exit code `0`.

### Missed-Deadline and Lifecycle Verification
Observed state transitions and deadline behaviors were verified using an isolated test check (`iac-deadline-test`) without notifying channels:
1. **Creation:** Newly declared check initializes in status `new` with 0 pings.
2. **Start Ping:** Sending `GET /start` updates `started = true` and records the start timestamp.
3. **Success Ping:** Sending `GET /` transitions status to `up` and records execution duration.
4. **Grace Window:** When the expected deadline passes without a ping, the check enters `grace`.
5. **Missed Deadline:** When the grace period expires without a ping, the check transitions from `grace` to `down` and triggers alert channels.
6. **Recovery:** Sending a subsequent ping transitions status from `down` back to `up`.
7. **Pause & Destruction:** Pausing the check halts alerting until resumed; removing the resource cleanly destroys it from Healthchecks.io.

### Rollback Procedure
If state corruption occurs during an import attempt, stop other writers and use the [shared state recovery procedure](terraform_iac.md#restore-state). Copying a local state file does not restore the MinIO backend. Preserve locking, lineage, and serial safeguards; review any rejected restore instead of forcing it.

`tofu import` updates the configured backend state and reads Healthchecks.io without changing the live check configuration.

