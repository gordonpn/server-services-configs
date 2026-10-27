# Cloudflared Security Upgrade

Cloudflare's eMudhra certificate advisory requires `cloudflared` 2026.10.2 or later. This repository pins container deployments to 2026.10.4. Keep the connector version explicit so `IfNotPresent` cannot leave an older cached image in place.

## Deployments

- `default/cloudflared`: four replicas of the `home` tunnel in the workloads Helm chart on `master`.
- `caddy_cloudflared`: one replica of `vps-shield-tunnel` in the RackNerd Docker Swarm `caddy` stack.
- `cloudflared.service`: one Debian package installation on `master`, used by the `master-rescue` tunnel.
- `docker-compose/caddy` and `docker-compose/tunnel`: inactive standalone examples, also pinned to 2026.10.4.

The four Kubernetes replicas and the RackNerd connector use container images and must be redeployed. Restarting their existing containers does not update the image.

## Kubernetes

The Deployment starts one surge pod at a time and keeps all existing pods until the new pod's `/ready` probe confirms a connection to Cloudflare.

```sh
task k8s:diff:workloads
task k8s:sync:workloads
kubectl --context k3s-master rollout status deployment/cloudflared -n default --timeout=5m
kubectl --context k3s-master get pods -n default -l app=cloudflared -o 'custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,READY:.status.containerStatuses[0].ready'
```

Confirm all four pods use `cloudflare/cloudflared:2026.10.4` and are Ready. The chart exposes the metrics listener on port 2000 inside each pod for the readiness endpoint.

## RackNerd Docker Swarm

The stack uses a start-first update with one task at a time and rollback on a failed task. In the Cloudflare dashboard, open `vps-shield-tunnel`, select **Add a replica**, and start a temporary `cloudflare/cloudflared:2026.10.4` connector with the tunnel's token. Wait until Cloudflare reports it connected and the tunnel healthy, then keep it running while the service updates.

```sh
task swarm:deploy STACK=caddy
```

Confirm the service task runs `cloudflare/cloudflared:2026.10.4`, Cloudflare reports the updated connector connected, and the route through Caddy works. Then remove the temporary connector. Do not remove or replace the original until the temporary connector is healthy.

## Master systemd service

The `master-rescue` tunnel currently has one connector. In the Cloudflare dashboard, open `master-rescue`, select **Add a replica**, and start a temporary connector on another host. Confirm it is connected before restarting the systemd service. Then update the Debian package and verify it:

```sh
sudo apt update
sudo apt install --only-upgrade cloudflared
sudo systemctl restart cloudflared
cloudflared --version
systemctl is-active cloudflared
```

Confirm the upgraded connector is connected and the SSH route works before removing the temporary connector. The package repository should provide 2026.10.2 or later.

## Origin certificates

Before an upgrade, check whether a tunnel route uses an HTTPS origin whose certificate chain depends on an affected eMudhra intermediate. Replace an affected origin certificate before upgrading. Keep origin certificate verification enabled; do not set `noTLSVerify` to bypass a failure.

On 2026-10-27, the checked Cloudflare tunnel routes used HTTP or SSH origins, so no HTTPS origin certificate replacement was needed for this upgrade.
