# Home Lab Configuration Project

## Project Overview
This repository manages the configuration, deployment, and maintenance of a multi-node home lab. The infrastructure is built on Raspberry Pi and x86 nodes, utilizing a hybrid orchestration approach with **K3s (Kubernetes)**, **Docker Swarm**, and **Docker Compose**.

### Main Technologies
- **Orchestration:** K3s, Docker Swarm, Docker Compose.
- **Networking:** Tailscale (internal mesh network), Cloudflare (tunnels and domain management).
- **Storage:** Longhorn (replicated block storage for Kubernetes).
- **Monitoring:** Prometheus & Grafana (via `kube-prometheus-stack`), Node Exporter.
- **CI/CD:** Jenkins, Drone CI, GitHub Actions.
- **Infrastructure as Code:** Terraform (for domain management), Helm/Helmfile (for Kubernetes charts).
- **Security:** Sealed Secrets (encrypting Kubernetes secrets).

## Directory Structure
- `docker-compose/`: Individual service configurations for standard Docker.
- `docker-swarm/`: Service stack definitions for Docker Swarm (e.g., Traefik, AdGuard, Jenkins).
- `k8s/`: Kubernetes manifests and local Helm charts.
    - `charts/`: Contains `helmfile.yaml` and the custom `k3s-maintenance` chart.
- `scripts/`: Utility scripts for deployment, backups, DDNS, and log trimming.
- `terraform/`: Terraform configuration for domain management.
- `docs/`: Architectural diagrams and documentation assets.

## Building and Running

### Command Runner (`task`)
The project uses `go-task` (Taskfile.yaml) as the primary interface for common operations.

- **List all tasks:** `task help` or `task --list-all`
- **Kubernetes Operations:**
    - `task charts:apply`: Deploy all Helm charts via Helmfile.
    - `task charts:diff`: See pending changes in the Kubernetes cluster.
    - `task k8s:apply:all`: Apply all charts and raw manifests (CoreDNS, Redis, etc.).
- **Docker Swarm Operations:**
    - `task swarm:deploy STACK=<name>`: Deploy a specific stack.
    - `task swarm:ls`: List active stacks.
- **Docker Compose Operations:**
    - `task compose:up SERVICE=<name>`: Start a service in the `docker-compose/` directory.
- **Terraform:**
    - `task tf:plan` / `task tf:apply`: Manage external infrastructure.

### Maintenance Scripts
Key scripts in the `scripts/` directory:
- `deploy.sh`: Orchestrates the deployment of Swarm stacks.
- `backup.sh`: Handles periodic backups.
- `ping.sh`: Health check script reported to external monitoring.

## Development Conventions

### Kubernetes Node Strategy
- **Master Node:** Used for heavy control-plane operations and high-resource pods (e.g., Gemini CLI, Prometheus, heavy databases, and self-hosted GitHub Actions runners) due to higher RAM (16GB). Critical or resource-intensive pods should be pinned here using `nodeSelector`.
- **Worker Nodes (Raspberry Pi):** Best for lightweight or distributed services.
- **Storage Strategy:** Longhorn volumes should be tuned for Tailscale. High-churn volumes (like Prometheus DB) should ideally be restricted to 2 replicas within the same site (e.g., Montreal) to avoid saturating CPU with Tailscale encryption overhead.

### Monitoring & Alerts
- **Persistence:** Failed Kubernetes Jobs must be manually cleaned up if they are older than the `successfulJobsHistoryLimit` to prevent Alertmanager from re-triggering noisy `KubeJobFailed` alerts.
- **Node Saturation:** Raspberry Pi nodes frequently hit `NodeSystemSaturation` during Longhorn rebuilds or Tailscale encryption spikes. Moving high-IO pods to the master node is the preferred mitigation.
- **Timestamp Jitter:** Raspberry Pi nodes may experience clock jitter in cAdvisor metrics. Prometheus should be configured with `outOfOrderTimeWindow: 30m` (or similar) to prevent sample drops and `PrometheusOutOfOrderTimestamps` alerts.

### Audio Bridge (AirConnect & Music Assistant)
- **Purpose:** Bridges Apple AirPlay to Google Cast devices and provides a unified music management interface.
- **Location:** `docker-compose/airconnect-music-assistant/`
- **Network Mode:** Uses `network_mode: host` for cross-brand device discovery (AirPlay/Cast).
- **Storage Strategy:** Music Assistant persistence is mapped to `/media/storage/audio/data` to leverage the high-capacity disk.

### Push-Based GitOps Loop & Runner RBAC
- **GitOps Workflow:** The GitOps loop is managed by the GitHub Actions workflow [gitops.yml](file:///.github/workflows/gitops.yml), which triggers on pushes to `master` when changes occur under `k8s/` or inside `Taskfile.yaml`.
- **Execution Target:** Runs on self-hosted runners labeled `home-lab-runners`.
- **Runner Pod ServiceAccount:** The runner pods are configured to use an explicit ServiceAccount named `home-lab-runner` in the `actions-runner-system` namespace. This is declared in [helmfile.yaml](file:///k8s/charts/helmfile.yaml) under the `arc-runner-set` release values, and pinned to the stable `master` node using `nodeSelector` to avoid worker node instability.
- **Privilege Assignment:** The `home-lab-runner` ServiceAccount is granted `cluster-admin` privileges via [runner-rbac.yaml](file:///k8s/runner-rbac.yaml). This RBAC manifest is integrated into the local `k3s-maintenance` chart templates ([runner-rbac.yaml](file:///k8s/charts/k3s-maintenance/templates/runner-rbac.yaml)) to ensure it is deployed automatically during the GitOps sync step (`task charts:apply`).
- **Runner Dependencies:** Since the default runner pod image (`ghcr.io/actions/actions-runner:latest`) is extremely minimal and lacks runtime tools, the workflow [gitops.yml](file:///.github/workflows/gitops.yml) must bootstrap `go-task`, `helm`, `kubectl`, and `helmfile` using setup actions (`arduino/setup-task` and `mamezou-tech/setup-helmfile` prior was replaced by `azure/setup-helm`, `azure/setup-kubectl`, and architecture-aware script for `helmfile` to support ARM64 Raspberry Pi nodes) prior to running any deployment tasks.

### Sealed Secrets Helm Repo Workaround
- **Bitnami Pages 404:** The official Helm repository endpoint for Sealed Secrets (`https://bitnami-labs.github.io/sealed-secrets`) returns a `404 Site not found` error on GitHub Pages.
- **Workaround:** Point the repository URL in [helmfile.yaml](file:///k8s/charts/helmfile.yaml) to `https://raw.githubusercontent.com/bitnami-labs/sealed-secrets/gh-pages`. Because the chart index contains absolute URLs pointing directly to GitHub releases for downloading the `.tgz` packages, this raw path functions as a transparent, reliable drop-in replacement.

### Formatting
- **Terraform:** Run `task tf:fmt` before committing changes.
- **K3s Maintenance:** The `k3s-maintenance` chart should be linted with `task charts:lint:maintenance`.

### DNS & Networking
- **CoreDNS Forwarders:** Do not use Tailscale's MagicDNS (`100.100.100.100`) as a primary forwarder in CoreDNS. It frequently returns `SERVFAIL` when queried from the K3s pod network (10.42.x.x), likely due to source IP validation in Tailscale's internal DNS server. Prioritize public DNS servers like `1.1.1.1` and `8.8.8.8`.
- **Search Paths & ndots:** K3s pods default to `ndots:5`. External resolution (e.g., `google.com`) will iterate through multiple internal search paths before trying the root domain. If upstream DNS is slow or unreliable, this can lead to connection timeouts in applications.
- **CoreDNS Maintenance**: The `coredns-config-enforcer` CronJob ensures that the `coredns` ConfigMap matches the `coredns-override` template in the `k3s-maintenance` chart. Any manual changes to CoreDNS should be reflected in the Helm chart.
- **Flannel Interface Dependency**: Flannel is configured to bind to `tailscale0` via `--flannel-iface`. If Tailscale restarts or has an IP change, the `flannel.1` interface may fail to initialize or bind, leading to cross-node timeouts (`external interface not found`). A restart of the `k3s-agent` is required in such cases. Refer to `RUNBOOK.md` for details.
- **Tailscale SSH Authentication:** When connecting to nodes via SSH over the Tailscale overlay network, connection requests may trigger interactive browser verification via a Tailscale authorization URL. The operator must complete this authentication in their browser before the terminal session begins.



## Known Issues & Future Improvements
- **Control Plane Single Point of Failure:** The current K3s cluster uses a single master node. During site-specific outages (e.g., Boston internet outage), worker nodes lose connection to the master, and the CronJob controller fails to schedule jobs on isolated nodes. If the master node's site goes down, all cluster-wide scheduling halts.
- **HA Control Plane Recommendation:** To improve resilience, transition to a High Availability (HA) control plane with at least 3 master nodes distributed across multiple sites (Montreal and Boston). This ensures that if one site goes offline, the surviving masters can maintain quorum and continue scheduling jobs.

## AI Agent Guidelines
- **Context Discovery:** Always reference other Markdown files (e.g., `README.md`) and configuration files (e.g., `Taskfile.yaml`, `helmfile.yaml`) within the repository to get a complete picture of the project's architecture and requirements.
- **Incremental Commits:** Commit changes incrementally as sub-tasks are completed to maintain a clean and traceable history.
- **Commit Style:** Always use [Conventional Commits](https://www.conventionalcommits.org/) for all commit messages (e.g., `fix(k8s): ...`, `feat(scripts): ...`).
- **Living Documentation:** Continuously update `GEMINI.md` to reflect new architectural decisions, learned conventions, or significant infrastructure changes as we work on the project together.
