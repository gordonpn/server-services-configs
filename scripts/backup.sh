#!/usr/bin/env bash
set -o allexport; source .env; set +o allexport

curl --retry 3 https://hc-ping.com/"$HC_UUID"/start
echo

backup_folders=(
	"/home"
	"/var/spool/mail"
	"/etc"
	"/root"
	"/boot"
	"/opt"
)

dest="$BACKUP_DIR"

day=$(date +%A)
hostname=$(hostname -s)
archive_file="$hostname-$day.tar"

for folder in "${backup_folders[@]}"
do
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
if [ $status -eq 0 ]
then
	curl --retry 3 https://hc-ping.com/"$HC_UUID"
else
	curl --retry 3 https://hc-ping.com/"$HC_UUID"/fail
fi
