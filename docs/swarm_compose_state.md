# Docker Swarm & Standalone Compose Deployment State

This document captures the architecture, configurations, and running container state of the Docker Swarm and standalone Docker Compose layers across the home lab nodes.

---

## 1. Docker Swarm Infrastructure

The Docker Swarm cluster is managed from the control plane node (`master`) and uses Tailscale IP overlay endpoints for secure, cross-site communication (port `2377/tcp`).

### Node Registry State
*Query Time: 2026-07-18*

| Node Hostname | IP Address (Tailscale) | Swarm Status | Availability | Manager Status | Engine Version |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **master** | `100.72.77.63` | **Ready** | Active | Leader | `29.1.4` |
| **pi-bos-0** | `100.70.156.88` | **Ready** | Active | (Worker) | `29.1.4` |
| **pi-mtl-0** | (Tailscale offline) | *Down* | Active | (Worker) | `29.1.4` |
| **pi-mtl-1** | (Tailscale offline) | *Down* | Active | (Worker) | `29.1.4` |

> [!NOTE]
> The Montreal nodes (`pi-mtl-0` and `pi-mtl-1`) are currently showing as *Down* because their Tailscale machine keys expired and they cannot connect to the overlay network. They will automatically rejoin gossip status once re-authenticated.

---

## 2. Docker Swarm Stacks & Services

Swarm services are deployed globally or replicated across the Swarm cluster using the Kubernetes-to-Swarm GitOps bridge CronJob running on K3s.

### Active Stacks
*   **kuma-ping** (Global Service)
    *   **Compose Location:** [docker-swarm/kuma-ping/docker-compose.yml](file:///home/gordonpn/workspace/server-services-configs/docker-swarm/kuma-ping/docker-compose.yml)
    *   **Description:** Global agent task that runs on every online Swarm node, reads the host hostname, and pushes health status alerts to Northflank Uptime Kuma every 30 seconds.
    *   **Scheduling Mode:** `global` (1 replica per active node)
    *   **Task State:**
        *   `kuma-ping_kuma-swarm-pusher` running on node **master** (Healthy/Active)
        *   `kuma-ping_kuma-swarm-pusher` running on node **pi-bos-0** (Healthy/Active)

---

## 3. Standalone Docker Compose Stacks (Host-Level)

These services run as standalone Docker Compose stacks on specific hosts outside of the Swarm or K3s schedulers.

### A. Master Node (`master`)

#### 1. Media & Automation Stack (Jellyfin Stack)
*   **Compose Configuration:** [docker-compose/jellyfin/docker-compose.yml](file:///home/gordonpn/workspace/server-services-configs/docker-compose/jellyfin/docker-compose.yml)
*   **Active Services:**
    *   `jellyfin` (Port `8096`, `1900/udp`, `7359/udp`, `8920`) - Primary media client
    *   `jellyseerr` (Port `5055`) - Media discovery/requests
    *   `sonarr` (Port `8989`) - TV show automation
    *   `radarr` (Port `7878`) - Movie automation
    *   `prowlarr` (Port `9696`) - Indexer management
    *   `rdtclient` (Port `6500`) - RealDebrid client
    *   `autoscan` (Port `3030`) - Plex/Jellyfin library auto-scanner
    *   `flaresolverr` (Port `8191`) - Captcha bypass proxy for indexers

#### 2. Audio Bridge Stack (AirConnect & Music Assistant)
*   **Compose Configuration:** [docker-compose/airconnect-music-assistant/docker-compose.yml](file:///home/gordonpn/workspace/server-services-configs/docker-compose/airconnect-music-assistant/docker-compose.yml)
*   **Description:** Bridges Apple AirPlay protocols to Google Cast devices and provides unified music management. Uses `network_mode: host` to facilitate mDNS discovery.
*   **Active Services:**
    *   `music-assistant-server` - Unified audio server engine
    *   `airconnect` - Airplay UPnP/Sonos/Chromecast bridge daemon

---

### B. Boston Node (`pi-bos-0`)

*   **Active Services:**
    *   *No standalone Docker Compose stacks are currently running on this host.* The only active container is the `kuma-ping` Swarm worker task.
