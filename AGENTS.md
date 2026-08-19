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
- **Stuck Active Jobs (Orphaned Pods):** If a node goes offline/unreachable while a CronJob is running on it, the pod remains in `Unknown`/`Terminating` status and the Job remains `Active` forever. If the CronJob has `Concurrency Policy: Forbid`, it will block future runs and eventually trigger `TooManyMissedTimes` warnings, halting all scheduling. Stale active jobs must be deleted manually (`kubectl delete job <name>`) to resume scheduling.
- **Uptime Kuma Monitoring Architecture:** A decentralized three-tier push monitoring configuration (Host OS, K3s Agent DaemonSet, and Docker Swarm Global Service) is designed to isolate bare-metal, network/Tailscale, and orchestration failures. Refer to [monitoring_design.md](file:///home/gordonpn/workspace/server-services-configs/docs/monitoring_design.md) for configurations and templates.
- **Monitoring Host Networking (`hostNetwork: true`):** Telemetry DaemonSets pushing health metrics to external endpoints (such as `kuma-k3s-pusher`) should always set `hostNetwork: true` and `dnsPolicy: ClusterFirstWithHostNet`. This bypasses CoreDNS `ndots:5` search path lookup delays and pod-network overlay latency.
- **Zero-Dependency Health Check Tools:** Prefer built-in utilities (such as BusyBox `wget`) over runtime package installations (`apk add --no-cache curl`). Container boot-time network mirror latency can fail `apk` calls silently, leaving long-running container loops missing required binaries.
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
- **Runner Dependencies:** Since the default runner pod image (`ghcr.io/actions/actions-runner:latest`) is extremely minimal and lacks runtime tools, the workflow [gitops.yml](file:///.github/workflows/gitops.yml) bootstraps `go-task`, `kubectl`, `helm`, and `helmfile` using architecture-aware `curl` scripts with automatic retries (`--retry 5`) to support both AMD64 and ARM64 Raspberry Pi nodes and prevent transient download timeouts.

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
- **IPv4 Precedence & IPv6 Egress:** Self-hosted runner pods in K3s lack IPv6 egress routing. When external services (such as GitHub OCI registries like `pkg-containers.githubusercontent.com`) publish AAAA records, Go tools (`helm`, `helmfile`, `go-task`, `kubectl`) attempting IPv6 connections fail with `connect: network is unreachable`. The GitOps workflow configures `/etc/gai.conf` precedence (`precedence ::ffff:0:0/96 100`) and exports `GODEBUG="netdns=cgo"` to force Go binaries to use GLIBC `getaddrinfo` IPv4 address resolution.



### Infrastructure & Swarm Operational Notes
- **Docker Swarm Network Hot-Swapping:** When attempting to migrate a Swarm service from a standard overlay/bridge network to the `host` network, Docker Swarm does not gracefully hot-swap the network namespace during a standard `docker stack deploy` or `docker service update`. The service will remain bound to the old bridge network, and changes to the compose file (`networks: [host]`) will be silently ignored. You must fully tear down the stack (`docker stack rm`), allow the network to be removed, and redeploy it.
- **Tailscale/K3s IPTables Drops:** If an Alpine container (`wget`) on a Docker bridge network inexplicably times out hitting external endpoints (while host `curl` works), it is likely caused by K3s/Flannel mutating the iptables `FORWARD` chain to `DROP` unassociated packets. Using `hostNetwork: true` (or `networks: [host]`) bypasses the `DOCKER-USER` drop chain.
- **Alpine wget Quiet Flag:** In BusyBox/Alpine, using `wget -q` (quiet mode) suppresses *all* error messages, including timeout traces. When writing telemetry scripts, always omit `-q` or pipe stderr appropriately if visibility into failures is needed.
- **Local Swarm Deployment:** The Uptime Kuma monitoring tokens are securely housed within Kubernetes Secrets (`kuma-swarm-tokens` in the `kube-system` namespace). When manually deploying the swarm stack locally (`task swarm:deploy STACK=kuma-ping`), these environment variables will evaluate to empty strings if not explicitly fetched from Kubernetes or injected by the CI environment (e.g. `scripts/deploy.sh` sourcing `scripts/.env`). Empty tokens silently fail the telemetry loop without pushing.
- **BusyBox TLS SNI Trailing Dot Pitfall:** In BusyBox/Alpine `wget`, appending a trailing dot to a hostname (e.g., `https://domain.code.run./...`) sends TLS SNI with the literal trailing dot. Reverse proxies (Cloudflare, Northflank) reject this SNI with a TCP RST (`Connection reset by peer`). Standard hostnames without trailing dots must be used for HTTPS push URLs in BusyBox/Alpine containers.
- **K3s Auto-Scaled CoreDNS & Tainted Remote Nodes:** K3s automatically scales CoreDNS replicas based on total cluster nodes (e.g., 5 nodes = 5 replicas) with a strict `topologySpreadConstraints` (`maxSkew: 1`, `DoNotSchedule` per hostname). If a remote node (like `racknerd-edc1bc8`) has a `NoSchedule` taint (`node-role.kubernetes.io/remote`), CoreDNS will fail to schedule its 5th replica, causing `KubePodNotReady`, `KubeDeploymentReplicasMismatch`, and `KubeDeploymentRolloutStuck` alerts. CoreDNS must have a toleration for `node-role.kubernetes.io/remote:NoSchedule` so 1 replica can run on the remote node, and this toleration should be enforced by `coredns-config-enforcer`.
- **Maintenance CronJob Overlay Routing & History Limits:** Maintenance CronJobs (like `network-crossnode-check`) that test local Flannel VXLAN overlay networks must specify `nodeAffinity` excluding remote nodes (`node-role.kubernetes.io/remote` `DoesNotExist`), as local pod IPs (`10.42.x.x`) do not route across WAN to remote nodes. Additionally, set `failedJobsHistoryLimit: 1` and `successfulJobsHistoryLimit: 1` on maintenance CronJobs to prevent transient failures during reboots from lingering and triggering `KubeJobFailed` alerts in Alertmanager.
- **Push Telemetry Flapping & Interval Safety Margin:** In Uptime Kuma push monitors with a 60s timeout window, a 15s push loop with slow retries (e.g. 5s timeout + 2s sleep + 5s timeout) can easily take 40-55s total if transient DNS lag occurs. Pushing every 10s with a fast 3-attempt inline retry loop (`-T 3` and `sleep 1`) guarantees heartbeats arrive within 10-15s, completely avoiding false-positive "No heartbeat in time window" flapping alerts.


## Troubleshooting Checklists
- **Swarm Nodes Showing Down:**
  1. Check if the node's Swarm TLS certificate expired (90 days). The daemon might be running, but the node state will be `Down`. Force it to leave and rejoin the Swarm.
  2. Verify that network telemetry containers are actually operating on the `host` network and not accidentally caught in the Swarm `default` bridge.
  3. Verify that environment tokens were properly injected into the container (check `docker service inspect`).

## Known Issues & Future Improvements
- **Control Plane Single Point of Failure:** The current K3s cluster uses a single master node. During site-specific outages (e.g., Boston internet outage), worker nodes lose connection to the master, and the CronJob controller fails to schedule jobs on isolated nodes. If the master node's site goes down, all cluster-wide scheduling halts.
- **HA Control Plane Recommendation:** To improve resilience, transition to a High Availability (HA) control plane with at least 3 master nodes distributed across multiple sites (Montreal and Boston). This ensures that if one site goes offline, the surviving masters can maintain quorum and continue scheduling jobs.

## AI Agent Guidelines
- **Context Discovery:** Always reference other Markdown files (e.g., `README.md`) and configuration files (e.g., `Taskfile.yaml`, `helmfile.yaml`) within the repository to get a complete picture of the project's architecture and requirements.
- **Incremental Commits:** Commit changes incrementally as sub-tasks are completed to maintain a clean and traceable history.
- **Commit Style:** Always use [Conventional Commits](https://www.conventionalcommits.org/) for all commit messages (e.g., `fix(k8s): ...`, `feat(scripts): ...`).
- **Living Documentation:** Continuously update `AGENTS.md` to reflect new architectural decisions, learned conventions, or significant infrastructure changes as we work on the project together.
