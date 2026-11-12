#!/usr/bin/env bash
# Usage: ./checkpoint.sh <name>   e.g. ./checkpoint.sh 01-v2.0.0
# Needs the stack running; leaves it stopped.
set -euo pipefail
cd "$(dirname "$0")"
NAME="${1:?usage: $0 <checkpoint-name>}"
B="$HOME/plausible-backup/$NAME"
[ -e "$B" ] && { echo "$B already exists" >&2; exit 1; }
mkdir -p "$B"; chmod 700 "$HOME/plausible-backup"

# Postgres volume currently mounted by plausible_db (db-data or db-data-16)
VOL=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/var/lib/postgresql/data"}}{{.Name}}{{end}}{{end}}' "$(docker compose ps -q plausible_db)")
echo "$VOL" > "$B/db-volume.txt"

# 1) logical Postgres dump (while it's running)
docker compose exec -T plausible_db pg_dumpall -U postgres > "$B/pg_dumpall.sql"

# 2) stop everything so ClickHouse files are consistent
docker compose stop

# 3) raw copies of both databases + config
docker run --rm -v "$VOL":/v:ro alpine:3 tar czf - -C /v . > "$B/db-data.tgz"
sudo tar czpf - event-data > "$B/event-data.tgz"
sudo ls -lnR event-data | head -20 > "$B/event-data-owners.txt"
cp docker-compose.yml plausible-conf.env "$B/"

# 4) check the archives are readable
gzip -t "$B"/*.tgz
ls -lh "$B"
echo "Checkpoint $NAME done. Stack is stopped."
