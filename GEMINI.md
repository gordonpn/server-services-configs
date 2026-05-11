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
- **Master Node:** Used for heavy control-plane operations and high-resource pods (e.g., Gemini CLI, heavy databases) due to higher RAM (16GB).
- **Worker Nodes (Raspberry Pi):** Best for lightweight or distributed services.
- **Storage Strategy:** Longhorn volumes should be tuned for Tailscale. High-churn volumes (like Prometheus DB) should ideally be restricted to 2 replicas within the same site (e.g., Montreal) to avoid saturating CPU with Tailscale encryption overhead.

### Monitoring & Alerts
- **Persistence:** Failed Kubernetes Jobs must be manually cleaned up if they are older than the `successfulJobsHistoryLimit` to prevent Alertmanager from re-triggering noisy `KubeJobFailed` alerts.
- **Node Saturation:** Raspberry Pi nodes frequently hit `NodeSystemSaturation` during Longhorn rebuilds or Tailscale encryption spikes. Moving high-IO pods to the master node is the preferred mitigation.

### Formatting
- **Terraform:** Run `task tf:fmt` before committing changes.
- **K3s Maintenance:** The `k3s-maintenance` chart should be linted with `task charts:lint:maintenance`.

## AI Agent Guidelines
- **Context Discovery:** Always reference other Markdown files (e.g., `README.md`) and configuration files (e.g., `Taskfile.yaml`, `helmfile.yaml`) within the repository to get a complete picture of the project's architecture and requirements.
- **Incremental Commits:** Commit changes incrementally as sub-tasks are completed to maintain a clean and traceable history.
- **Commit Style:** Always use [Conventional Commits](https://www.conventionalcommits.org/) for all commit messages (e.g., `fix(k8s): ...`, `feat(scripts): ...`).
