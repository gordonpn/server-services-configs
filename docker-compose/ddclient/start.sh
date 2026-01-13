#!/bin/bash
export UID
export GID=$(id -g)
docker compose config
docker compose up -d
