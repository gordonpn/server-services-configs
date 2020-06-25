# Server service configs and tools

![Healthchecks](https://healthchecks.io/badge/d5b6a7bd-1598-4684-8b91-1128b377a198/Er4g1DRe.svg)
![License](https://badgen.net/github/license/gordonpn/server-services-configs)

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/gordonpn)

## Description

This repository contains configuration (docker-compose.yml files) to set up the services I run on my home server. As well as, some useful scripts in the `./scripts` directory.

## Service configs

I currently use the following services on my home server.

| Service              | Purpose                                                   |
|----------------------|-----------------------------------------------------------|
| Drone CI and runners | CI/CD                                                     |
| Droppy               | File storage                                              |
| Resilio Sync         | Real-time peer to peer syncing                            |
| Swarmpit             | Monitor resources                                         |
| Traefik              | Reverse proxy                                             |

## Current nodes in the Swarm cluster

![Docker Swarm Nodes](./docs/nodes.png)

## Scripts

### `backup.sh`

Make backups of important directories into tarballs.

### `update_container.sh`

Update redeploy (update) containers.
