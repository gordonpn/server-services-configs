#!/usr/bin/env bash
set -o allexport
source /home/gordonpn/workspace/server-services-configs/scripts/.env
set +o allexport

curl -vs --retry 3 https://hc-ping.com/"$HC_UUID"/start
echo

logfile="/home/gordonpn/logs/backup.log"

clean_log() {
  local lines
  lines=$(wc -l <${logfile})
  if ((lines >= 80)); then
    lines_to_remove=$((lines - 80 + 1))
    tail -n +"${lines_to_remove}" "$logfile" >"$logfile.tmp" && mv "$logfile.tmp" "$logfile"
  else
    echo "Log file not long enough yet, not trimming."
  fi
}

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

clean_log

if [ $status -eq 0 ]; then
  curl -vs --retry 3 https://hc-ping.com/"$HC_UUID"
else
  curl -vs --retry 3 https://hc-ping.com/"$HC_UUID"/fail
fi
