#!/usr/bin/env bash
set -o allexport
source /home/gordonpn/workspace/server-services-configs/scripts/.env
set +o allexport

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
source "$script_dir"/trim_logs.sh

curl -vs --retry 3 https://hc-ping.com/"$HC_UUID"/start
echo

backup_folders=(
  "/boot"
  "/etc"
  "/home"
  "/var/spool/cron/crontabs"
  "/var/spool/mail"
  "/root"
)

dest="$BACKUP_DIR"

day=$(date +%A)
hostname=$(hostname -s)
archive_file="$hostname-$day.tar"

for folder in "${backup_folders[@]}"; do
  if [ ! -f "$dest"/"$archive_file" ]; then
    tar cf "$dest"/"$archive_file" "$folder"
    status=$?
  fi

  echo "Backing up $folder to $dest/$archive_file"
  date
  echo

  tar rf "$dest"/"$archive_file" "$folder"
  status=$?
done

echo
echo "Backup finished"
date

ls -lh "$dest"

echo

trim_logs "/media/drive/logs/backup.log"

if [ $status -eq 0 ]; then
  curl -vs --retry 3 https://hc-ping.com/"$HC_UUID"
else
  curl -vs --retry 3 https://hc-ping.com/"$HC_UUID"/fail
fi
