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
HELMFILE_KUBE_CONTEXT=k3s-master task k8s:diff:workloads
HELMFILE_KUBE_CONTEXT=k3s-master task k8s:sync:workloads
kubectl --context k3s-master rollout status deployment/cloudflared -n default --timeout=5m
kubectl --context k3s-master get pods -n default -l app=cloudflared -o 'custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,READY:.status.containerStatuses[0].ready'
```

Confirm all four pods use `cloudflare/cloudflared:2026.10.4` and are Ready. The chart exposes the metrics listener on port 2000 inside each pod for the readiness endpoint.

## RackNerd Docker Swarm

The stack uses a start-first update and also starts the previous task first during rollback. Swarm continues when the updated task reaches `RUNNING`; check tunnel connection status in Cloudflare separately. The active route resolves to `http://caddy:80`, and Caddy has no published host port, so the temporary connector must join the attachable `caddy_vps_shield_net` overlay.

Set `VPS_TUNNEL_TOKEN` in the invoking shell from the sensitive Terraform output `vps_tunnel_token`; `task swarm:deploy` does not load `scripts/.env`. For example, capture the output in the environment without printing it:

```sh
export VPS_TUNNEL_TOKEN="$(terraform -chdir=terraform output -raw vps_tunnel_token)"
```

On RackNerd, start the temporary connector and verify that the overlay can reach Caddy:

```sh
test -n "${VPS_TUNNEL_TOKEN:-}" || { echo "VPS_TUNNEL_TOKEN is unset" >&2; exit 1; }
TUNNEL_TOKEN="$VPS_TUNNEL_TOKEN" docker run --detach --name cloudflared-rollout --network caddy_vps_shield_net --env TUNNEL_TOKEN cloudflare/cloudflared:2026.10.4 tunnel run
docker run --rm --network caddy_vps_shield_net busybox:1.37.0 wget -S -O /dev/null http://caddy:80/
```

Wait until Cloudflare reports the temporary connector connected and the tunnel healthy. Keep it running while the service updates. The task requires `VPS_TUNNEL_TOKEN` to be non-empty and contain no whitespace before it deploys the stack.

```sh
task swarm:deploy STACK=caddy
```

Confirm the replacement task runs `cloudflare/cloudflared:2026.10.4`, remains attached to `caddy_vps_shield_net`, and Cloudflare reports it connected. Both connectors then use the same `caddy:80` origin path. A public route check alone is insufficient because Cloudflare may serve it through the temporary connector. Remove the temporary connector only after the replacement connector and route are verified:

```sh
docker rm -f cloudflared-rollout
```

If the updated connector does not connect, leave the temporary connector running and restore the previous service spec:

```sh
docker service update --rollback caddy_cloudflared
```

Confirm the previous connector is connected and the route works before removing the temporary connector.

## Master systemd service

The `master-rescue` tunnel currently has one connector. Before adding a temporary replica, check the route's configured SSH origin. A connector on another host cannot reach an origin such as `localhost:22` on `master`; for a connector-local origin, run the temporary connector on `master` with the host network, or configure an origin reachable by both connectors. Confirm the temporary connector can reach that origin and Cloudflare reports it connected before restarting the systemd service. Then update the Debian package and verify it:

```sh
sudo apt update
sudo apt install --only-upgrade cloudflared
sudo systemctl restart cloudflared
cloudflared --version
systemctl is-active cloudflared
```

Confirm the upgraded systemd connector itself is connected and can use the same configured SSH origin before removing the temporary connector; an SSH route check alone may still hit the temporary connector. The package repository should provide 2026.10.2 or later.

## Origin certificates

Before an upgrade, check whether a tunnel route uses an HTTPS origin whose certificate chain depends on an affected eMudhra intermediate. Replace an affected origin certificate before upgrading. Keep origin certificate verification enabled; do not set `noTLSVerify` to bypass a failure.

On 2026-10-27, the checked Cloudflare tunnel routes used HTTP or SSH origins, so no HTTPS origin certificate replacement was needed for this upgrade.
