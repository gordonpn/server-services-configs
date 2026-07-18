# Design Proposal: Three-Tier Homelab Monitoring with Uptime Kuma

This document outlines the architecture, configuration templates, and diagnostic logic for a three-tier, decentralized push monitoring system for our 4-node homelab cluster using Uptime Kuma (hosted on Northflank).

---

## 1. Architectural Overview

To achieve high-fidelity diagnostic data that isolates host, VPN (Tailscale), and orchestrator (K3s / Swarm) failures, we monitor each of the 4 nodes at three distinct layers.

```
                  +----------------------------------------------+
                  |           Uptime Kuma (Northflank)           |
                  +----------------------------------------------+
                                ^       ^       ^
        +-----------------------+       |       +-----------------------+
        | (Public Ingress)              | (K3s Internal Overlay)        | (Swarm Overlay)
  +-----------+                   +-----------+                   +-----------+
  | Tier 1:   |                   | Tier 2:   |                   | Tier 3:   |
  | Host OS   |                   | K3s Agent |                   | Swarm     |
  | (Systemd) |                   | DaemonSet |                   | Global Svc|
  +-----------+                   +-----------+                   +-----------+
        |                               |                               |
        +-------------------------------+-------------------------------+
                                        |
                             [ Physical Bare Metal Node ]
```

### The Diagnostic Matrix
For any node (e.g. `pi-bos-0`), Uptime Kuma will maintain three push monitors. If failures occur, the dashboard tells us exactly where the problem is:

| Host OS (Tier 1) | K3s Agent (Tier 2) | Swarm Svc (Tier 3) | Root Cause Diagnosis |
| :--- | :--- | :--- | :--- |
| 🟢 **UP** | 🟢 **UP** | 🟢 **UP** | **Healthy node and software stack.** |
| 🟢 **UP** | 🔴 **DOWN** | 🔴 **DOWN** | **Mesh VPN or Routing Collapse:** Host has internet, but Tailscale overlay keys have expired or routing failed. |
| 🟢 **UP** | 🔴 **DOWN** | 🟢 **UP** | **K3s Agent Failure:** Host and Swarm are fine, but the local K3s agent process has stopped. |
| 🟢 **UP** | 🟢 **UP** | 🔴 **DOWN** | **Swarm Node Failure:** Host and K3s are fine, but the Swarm daemon is stopped or disconnected. |
| 🔴 **DOWN** | 🔴 **DOWN** | 🔴 **DOWN** | **Physical Outage:** Power failure, hardware crash, or local ISP outage at the node's site. |

---

## 2. Implementation Specifications

### Tier 1: Host OS Monitoring (Systemd Timer)
This script runs directly on the host operating system and sends pings to Uptime Kuma over the **public internet**. It does not depend on K3s, Swarm, or Tailscale.

#### 1. Configuration Script: `/usr/local/bin/kuma-host-ping.sh`
```bash
#!/bin/bash
set -e

# Target Kuma Push URL (defined uniquely per node via host environment)
KUMA_URL="${KUMA_HOST_PUSH_URL}"

if [ -z "$KUMA_URL" ]; then
    echo "Error: KUMA_HOST_PUSH_URL environment variable is not set."
    exit 1
fi

# Basic local health check: Validate outgoing internet gateway is reachable
ping -c 3 -W 5 1.1.1.1 > /dev/null || { echo "Outgoing gateway unreachable"; exit 1; }

# Send success ping to Uptime Kuma
curl -fsS --retry 3 "${KUMA_URL}?status=up&msg=Host+OK"
```

#### 2. Systemd Service: `/etc/systemd/system/kuma-host-ping.service`
```ini
[Unit]
Description=Uptime Kuma Host OS Ping Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
EnvironmentFile=/etc/default/kuma-host-ping
ExecStart=/usr/local/bin/kuma-host-ping.sh
```

#### 3. Systemd Timer: `/etc/systemd/system/kuma-host-ping.timer`
```ini
[Unit]
Description=Run Uptime Kuma Host OS Ping every 30 seconds

[Timer]
OnBootSec=1min
OnUnitActiveSec=30s
AccuracySec=1s

[Install]
WantedBy=timers.target
```

---

### Tier 2: K3s Agent Monitoring (DaemonSet)
This runs inside K3s and pings Uptime Kuma. If the K3s agent or the Flannel overlay interface fails, this ping will stop.

#### DaemonSet Manifest: `kuma-k3s-pusher.yaml`
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: kuma-k3s-pusher
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: kuma-k3s-pusher
  template:
    metadata:
      labels:
        app: kuma-k3s-pusher
    spec:
      tolerations:
        - operator: Exists
          effect: NoSchedule
      containers:
        - name: pusher
          image: busybox:1.36
          env:
            - name: MY_NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            # Tokens passed securely from a Sealed Secret
            - name: MASTER_TOKEN
              valueFrom:
                secretKeyRef:
                  name: kuma-k3s-tokens
                  key: master
            - name: PI_BOS_0_TOKEN
              valueFrom:
                secretKeyRef:
                  name: kuma-k3s-tokens
                  key: pi-bos-0
            - name: PI_MTL_0_TOKEN
              valueFrom:
                secretKeyRef:
                  name: kuma-k3s-tokens
                  key: pi-mtl-0
            - name: PI_MTL_1_TOKEN
              valueFrom:
                secretKeyRef:
                  name: kuma-k3s-tokens
                  key: pi-mtl-1
          command:
            - /bin/sh
            - -c
            - |
              while true; do
                case "$MY_NODE_NAME" in
                  "master")   TOKEN="$MASTER_TOKEN" ;;
                  "pi-bos-0") TOKEN="$PI_BOS_0_TOKEN" ;;
                  "pi-mtl-0") TOKEN="$PI_MTL_0_TOKEN" ;;
                  "pi-mtl-1") TOKEN="$PI_MTL_1_TOKEN" ;;
                  *)          TOKEN="" ;;
                esac

                if [ -n "$TOKEN" ]; then
                  # Resolve internal API server to verify DNS and Flannel VXLAN path
                  if nslookup kubernetes.default.svc.cluster.local > /dev/null && nc -z -w5 kubernetes.default.svc 443; then
                    wget -q -O- -T 5 -t 3 "https://p01--uptime-kuma--m5z2j5q8x7zn.code.run/api/push/${TOKEN}?status=up&msg=K3s+Ready" || true
                  fi
                fi
                sleep 30
              done
```

---

### Tier 3: Docker Swarm Monitoring (Global Service)
This runs as a Docker Swarm global service. It ensures that if a node disconnects from the Swarm Manager, its task will terminate or lose authentication, stopping the pings.

#### Swarm Compose file: `docker-compose.monitoring.yml`
```yaml
version: '3.8'

services:
  kuma-swarm-pusher:
    image: alpine:latest
    deploy:
      mode: global
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
    environment:
      - MASTER_TOKEN=${MASTER_TOKEN}
      - PI_BOS_0_TOKEN=${PI_BOS_0_TOKEN}
      - PI_MTL_0_TOKEN=${PI_MTL_0_TOKEN}
      - PI_MTL_1_TOKEN=${PI_MTL_1_TOKEN}
    volumes:
      - /etc/hostname:/etc/host_hostname:ro
    command:
      - sh
      - -c
      - |
        apk add --no-cache curl
        NODE_NAME=$$(cat /etc/host_hostname)
        while true; do
          case "$$NODE_NAME" in
            "master")   TOKEN="$$MASTER_TOKEN" ;;
            "pi-bos-0") TOKEN="$$PI_BOS_0_TOKEN" ;;
            "pi-mtl-0") TOKEN="$$PI_MTL_0_TOKEN" ;;
            "pi-mtl-1") TOKEN="$$PI_MTL_1_TOKEN" ;;
            *)          TOKEN="" ;;
          esac

          if [ -n "$$TOKEN" ]; then
            curl -fsS --retry 3 "https://p01--uptime-kuma--m5z2j5q8x7zn.code.run/api/push/$${TOKEN}?status=up&msg=Swarm+Active" || true
          fi
          sleep 30
        done
```

---

## 3. Preparation & Action Items

To prepare for implementation, we need the following:

1.  **Generate Push Tokens in Uptime Kuma:**
    *   Create **12 new Push monitors** in your Northflank Uptime Kuma dashboard (4 nodes $\times$ 3 layers).
    *   Example naming convention:
        *   `master (Host)` / `master (K3s)` / `master (Swarm)`
        *   `pi-bos-0 (Host)` / `pi-bos-0 (K3s)` / `pi-bos-0 (Swarm)`
        *   *(etc. for Montreal nodes)*
2.  **Collect the Tokens:**
    *   Note down the unique push tokens (the hash at the end of the push URLs).
3.  **Provide Tokens to the Cluster:**
    *   We will encrypt the K3s tokens into a **Sealed Secret** and add the Swarm tokens to our local Environment files.
4.  **Tailscale Key Expiry Maintenance:**
    *   Log in to the Tailscale Admin Console and **Disable Key Expiry** for the nodes to prevent overlay dropouts.

---

## 4. Step-by-Step Deployment Guide for Tier 1 (Host OS)

To deploy the Host OS push monitoring service and timer on any bare-metal node:

1.  **Copy the scripts and unit files** to the host OS directories:
    ```bash
    sudo cp scripts/kuma-host-ping/kuma-host-ping.sh /usr/local/bin/
    sudo chmod +x /usr/local/bin/kuma-host-ping.sh
    sudo cp scripts/kuma-host-ping/kuma-host-ping.service scripts/kuma-host-ping/kuma-host-ping.timer /etc/systemd/system/
    ```

2.  **Define the node-specific token** in `/etc/default/kuma-host-ping` (replace `<NODE_HOST_TOKEN>` with the unique token for that specific host):
    ```bash
    echo "KUMA_HOST_PUSH_URL=https://p01--uptime-kuma--m5z2j5q8x7zn.code.run/api/push/<NODE_HOST_TOKEN>" | sudo tee /etc/default/kuma-host-ping
    ```

3.  **Enable and start the systemd timer:**
    ```bash
    sudo systemctl daemon-reload
    sudo systemctl enable --now kuma-host-ping.timer
    ```

4.  **Verify the setup** (you can run the service manually once to trigger a test ping):
    ```bash
    sudo systemctl status kuma-host-ping.timer
    sudo systemctl start kuma-host-ping.service
    sudo journalctl -u kuma-host-ping.service
    ```

