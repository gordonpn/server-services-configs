# K3s Cluster Network Maintenance Runbook

This document describes how to troubleshoot and maintain the network connectivity checks in the K3s cluster.

## Overview
The `k3s-maintenance` Helm chart installs several CronJobs in the `kube-system` namespace to monitor cluster health:
- `k3s-maintenance-network-health-check`: Basic DNS and API server reachability.
- `k3s-maintenance-network-crossnode-check`: Verifies pod-to-pod connectivity across different nodes using a DaemonSet of echo servers (`k3s-maintenance-network-echo`).

## Symptoms of Failure
- **Alert**: `KubeJobFailed` in Slack.
- **Log Observation**: `kubectl logs` for the failed job shows "Error: Failed to reach any remote echo pod".
- **False Resolves**: Alerts may resolve automatically when failed pods are rotated out of the CronJob history (limit is 5), even if the underlying issue persists.

## Architecture Context
- **Nodes**: `master`, `pi-bos-0`, `pi-mtl-0`, `pi-mtl-1`.
- **Network**: Nodes are connected via **Tailscale** (100.x.x.x IPs).
- **MTU**: 
    - Tailscale MTU is **1280**.
    - K3s Flannel MTU must be lower than Tailscale to account for encapsulation.
    - Current configuration uses MTU **1100** (verified on `flannel.1`).

## Troubleshooting Steps

### 1. Check Job Logs
Identify the failing pod and check its logs.
```bash
# Find the latest cross-node check pod
POD_NAME=$(kubectl get pods -n kube-system -l job-name --sort-by=.metadata.creationTimestamp -o name | grep crossnode | tail -n 1)
kubectl logs -n kube-system "$POD_NAME" --all-containers
```

### 2. Verify MTU Settings
Check the MTU of the flannel interface on the host:
```bash
ip addr show flannel.1 | grep mtu
```
And inside a pod:
```bash
kubectl run mtu-test --image=busybox --restart=Never -- ip addr show eth0
kubectl delete pod mtu-test
```
*Note: If MTU is > 1200, large packets will likely be dropped by Tailscale.*

### 3. Manual Connectivity Test
If the CronJob fails, verify manually by creating a test pod and curling the echo servers.

1. **Get Echo Pod IPs**:
   ```bash
   kubectl get pods -n kube-system -l app=k3s-maintenance-network-echo -o wide
   ```

2. **Run Test Pod**:
   ```bash
   kubectl run test-conn -n kube-system --image=busybox:1.36 --restart=Never -- sleep 3600
   ```

3. **Curl Remote Pod**:
   ```bash
   # Replace <TARGET_IP> with an IP from a DIFFERENT node
   kubectl exec -n kube-system test-conn -- wget -q -T 5 -O- http://<TARGET_IP>:8080
   ```

### 4. Known Issues

#### Parsing Bug (RESTARTS column)
The discovery script previously used `kubectl get pods -o wide | awk`. When a pod has restarts, `kubectl` adds a time-based string like `(2d22h ago)` to the RESTARTS column, shifting all subsequent columns (IP and Node).
- **Fix**: Use `-o jsonpath` for robust discovery.
- **Status**: Fixed in `k3s-maintenance` chart.

#### Missing Flannel Interface (external interface not found)
If Pod-to-Pod traffic between nodes fails even though DNS and local traffic work, the Flannel overlay might have failed to initialize.
- **Symptom**: `ip link show flannel.1` returns nothing on the host.
- **Log Observation**: `journalctl -u k3s-agent` shows `vxlan_network.go:167] external interface not found, retrying in 30s`.
- **Cause**: This happens if the specified `--flannel-iface` (e.g., `tailscale0`) is not ready or has an IP change that Flannel cannot bind to during K3s startup.
- **Fix**: Restart the `k3s-agent` (or `k3s`) service:
  ```bash
  sudo systemctl restart k3s-agent
  ```
- **Prevention**: To prevent this from occurring on system boot, configure systemd on the host to ensure `k3s-agent` only starts after Tailscale has fully initialized its network interface:
  1. Edit the service overrides:
     ```bash
     sudo systemctl edit k3s-agent.service
     ```
  2. Paste the following configuration:
     ```ini
     [Unit]
     After=tailscaled.service
     Requires=tailscaled.service
     ```
  3. Save and exit the editor.

#### Inotify Watches Exhaustion (Failed to allocate directory watch)
If you run `systemctl` commands and see `Failed to allocate directory watch: Too many open files`, your host has exhausted its kernel `inotify` watches or instances. This is common when running K3s (Kubernetes) and Docker side-by-side.

*   **Temporary Fix (Apply immediately):**
    ```bash
    sudo sysctl -w fs.inotify.max_user_watches=524288
    sudo sysctl -w fs.inotify.max_user_instances=512
    ```

*   **Permanent Fix (Survives reboots):**
    1. Append the limits to the sysctl configuration:
       ```bash
       echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.d/90-kubernetes.conf
       echo "fs.inotify.max_user_instances=512" | sudo tee -a /etc/sysctl.d/90-kubernetes.conf
       ```
    2. Apply the configuration:
       ```bash
       sudo sysctl --system
       ```


