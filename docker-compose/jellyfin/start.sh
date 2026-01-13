#!/bin/bash
export UID
export GID="$(id -g)"
docker compose pull
docker compose config
docker compose up -d

