#!/usr/bin/env bash
set -o allexport; source .env; set +o allexport

curl --retry 3 https://hc-ping.com/"$HC_UUID"/start

backup_files="/home /var/spool/mail /etc /root /boot /opt"

dest="$BACKUP_DIR"

day=$(date +%A)
hostname=$(hostname -s)
archive_file="$hostname-$day.tgz"

echo "Backing up $backup_files to $dest/$archive_file"
date
echo

tar czf "$dest"/"$archive_file" "$backup_files" || curl --retry 3 https://hc-ping.com/"$HC_UUID"/fail

echo
echo "Backup finished"
date

ls -lh "$dest"

curl --retry 3 https://hc-ping.com/"$HC_UUID"
