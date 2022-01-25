# Server service configs and tools

![Healthchecks](https://healthchecks.io/badge/d5b6a7bd-1598-4684-8b91-1128b377a198/Er4g1DRe.svg)
![License](https://badgen.net/github/license/gordonpn/server-services-configs)

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/gordonpn)

## Description

This repository contains configuration (docker-compose.yml files) to set up the services I run on my home server. As well as, some useful scripts in the `./scripts` directory.

## Service configs

I currently use the following services on my home server.

| Service              | Purpose                        |
| -------------------- | ------------------------------ |
| Drone CI and runners | CI/CD                          |
| Filebrowser          | File storage                   |
| Resilio Sync         | Real-time peer to peer syncing |
| Swarmpit             | Monitor resources              |
| Traefik              | Reverse proxy                  |

## Scripts

### `backup.sh`

Make backups of important directories into tarballs.

### `update_container.sh`

Update redeploy (update) containers.

### `force_rebalance.sh`

Simply force a rebalance of the Swarm on all the services. Can be automated, will rebalance only if the numbers of tasks running on each server is skewed.

Should not be run too often and only when necessary.

### `ddns-start`

Modified version of @alphabt's project [asuswrt-merlin-ddns-cloudflare](https://github.com/alphabt/asuswrt-merlin-ddns-cloudflare) to suit my usage.

More reference: <https://gist.github.com/dd-han/09853f07efdf67f0f4af3f7531ac7abf>

This runs on an ASUS router to update the dynamic IP address with a Cloudflare A record.

### `start_pfsense.sh`

Starts the headless virtualbox.

Was used previously when I was running pfSense in a virtualbox as the router.

### `get_dhcp.sh`

Assures the enp2s0 interface has a local IP.

## Setting up a new Raspberry Pi node

After flashing the image, create a file named `ssh` in `/boot` or `/system-boot`

Edit `cmdline.txt` and append `ipv6.disable=1`

Configure available settings: `sudo raspi-config`

Run upgrades: `sudo apt update && sudo apt full-upgrade -y`

Create a new user

```sh
sudo adduser gordonpn
sudo passwd root
su root
adduser gordonpn sudo
exit
```

Add new user to groups that the `pi` belonged to

`groups | sed 's/pi //g' | sed 's/ /,/g' | xargs -I{} sudo usermod -a -G {} gordonpn`

Log out and log in with newly created user

Delete `pi` user

`sudo deluser --remove-home pi`

Lock the `root` user

`sudo passwd -l root`

On your client computer, copy your public key to the Pi

`ssh-copy-id -i ~/.ssh/id_rsa.pub gordonpn@192.168.50.186`

Disable SSH password auth on Pi and edit the following lines:

`sudo vi /etc/ssh/sshd_config`

```
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM no
```

Set a static IP to the Pi:

`sudo vi /etc/dhcpcd.conf`

```
interface eth0
static ip_address=192.168.50.186/24
static routers=192.168.50.1
static domain_name_servers=8.8.8.8 8.8.4.4
```

Change the hostname in both these config files:

`sudo vi /etc/hosts`

`sudo vi /etc/hostname`

Install UFW

`sudo apt-get update && sudo apt-get install -y ufw`

Edit `/etc/default/ufw` to disable ipv6:

`sudo vi /etc/default/ufw`

`sudo ufw enable`

Allow SSH from local network only

`sudo ufw allow from 192.168.50.0/24 proto tcp to any port 22`

<https://www.digitalocean.com/community/tutorials/ufw-essentials-common-firewall-rules-and-commands>

Block wifi and bluetooth

`sudo rfkill block wifi && sudo rfkill block bluetooth`

Disable bluetooth

`echo "dtoverlay=disable-bt" | sudo tee -a /boot/config.txt`

Disable avahi and TriggerHappy

```bash
sudo systemctl disable bluetooth
sudo systemctl stop bluetooth
sudo systemctl disable avahi-daemon
sudo systemctl stop avahi-daemon
sudo systemctl disable triggerhappy
sudo systemctl stop triggerhappy
```

Remove some unused software

`sudo apt remove --purge -y bluez wolfram-engine triggerhappy xserver-common lightdm logrotate fake-hwclock samba-common && sudo apt autoremove -y --purge`

Install unattended-upgrades

`sudo apt-get update && sudo apt-get install -y unattended-upgrades && sudo dpkg-reconfigure --priority=low unattended-upgrades`

Install Docker

`curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh`

`sudo usermod -aG docker $USER && newgrp docker`

`sudo systemctl enable docker.service && sudo systemctl enable containerd.service`

Enable experimental features and log rotation:

```bash
cat << EOF | sudo tee -a /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "experimental": true,
  "features": {
    "buildkit": true
  }
}
EOF
```

Enable ports for Docker Swarm

```sh
sudo ufw allow from 192.168.50.0/24 proto tcp to any port 2377
sudo ufw allow from 192.168.50.0/24 proto udp to any port 4789
sudo ufw allow from 192.168.50.0/24 to any port 7946
```

`docker swarm init --advertise-addr <MANAGER-IP>`

Or join

`docker swarm join --token #token`

Add label to the node

`docker node update --label-add master rpi0`

Install Docker Compose

```sh
sudo curl -L "https://github.com/docker/compose/releases/download/v2.2.3/docker-compose-linux-aarch64" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

Reduce swapiness

Add `vm.swappiness=0` by using `sudo vi /etc/sysctl.conf`

Disable swap and remove

```sh
sudo systemctl disable dphys-swapfile && \
sudo dphys-swapfile swapoff && \
sudo dphys-swapfile uninstall && \
sudo update-rc.d dphys-swapfile remove
```

Make flush writes only every 15 mins

Add `,commit=900` after `defaults` in `/etc/fstab`

Migrate some temp files to `tmpfs`

```sh
echo "tmpfs  /tmp  tmpfs  defaults,noatime,nosuid,nodev  0  0" | sudo tee -a /etc/fstab
echo "tmpfs  /var/spool/rsyslog  tmpfs  defaults,noatime,nosuid,nodev,noexec,size=50M  0  0" | sudo tee -a /etc/fstab
echo "tmpfs /var/log tmpfs defaults,noatime,nosuid,mode=0755,size=100m 0 0" | sudo tee -a /etc/fstab
```

Disable system log using mask

```sh
sudo systemctl mask rsyslog.service && \
sudo systemctl mask systemd-journald.service
```

Install GlusterFS

```sh
sudo apt-get -y install glusterfs-server glusterfs-client
sudo systemctl enable glusterd
sudo systemctl start glusterd
sudo systemctl status glusterd
```

Set up external drive

```sh
lsblk -f
sudo fdisk /dev/sda
sudo mkfs.ext4 /dev/sda1
sudo mkdir -p /media/drive
sudo mount -t auto /dev/sda1 /media/drive
sudo blkid /dev/sda1
sudo vi /etc/fstab
```

Add to bottom

`echo "UUID=a613a12d-8abb-4d86-9ea8-fc6a44f548c8 /media/drive ext4 defaults,auto,users,rw,nofail,noatime 0 0" | sudo tee -a /etc/fstab`

Add at the bottom of `/etc/rc.local`

```sh
sleep 20
sudo mount -a
```

Open ports for GlusterFS

```sh
sudo ufw allow from 192.168.50.0/24 proto tcp to any port 24007
sudo ufw allow from 192.168.50.0/24 proto tcp to any port 49152
```

View other ports needed by GlusterFS

```sh
echo "Open ports for Gluster volumes"
PORTS=`service glusterd status | grep "listen-port" | sed 's/.*\.listen-port=//'|sort -u`
echo "$PORTS"
```

Create GlusterFS volume

```sh
sudo mkdir -p /media/drive/glusterfs
sudo chown -R gordonpn:gordonpn /media
sudo gluster volume create gfsvol \
  192.168.50.82:/media/drive/glusterfs/docker \
  192.168.50.31:/media/drive/glusterfs/docker \
  192.168.50.9:/media/drive/glusterfs/docker \
  force
sudo gluster volume start gfsvol
sudo gluster v status
sudo gluster volume info
docker node update --label-add persistence rpi1
```

Mount the GlusterFS volume on each node

```sh
sudo umount /mnt
echo 'localhost:/gfsvol /mnt/glusterfs glusterfs defaults,_netdev,backupvolfile-server=localhost 0 0' | sudo tee /etc/fstab
sudo mkdir /mnt/glusterfs
sudo mount.glusterfs localhost:/gfsvol /mnt/glusterfs
sudo chown -R gordonpn:gordonpn /mnt
```

Move Docker storage directory off of the SD card

```sh
sudo systemctl stop docker && \
sudo rm -rf /var/lib/docker && \
sudo mkdir /var/lib/docker && \
sudo mkdir /media/drive/docker && \
sudo mount --rbind /media/drive/docker /var/lib/docker && \
sudo systemctl start docker
```

Set cron tasks

```
@reboot /home/gordonpn/workspace/server-services-configs/scripts/get_dhcp.sh
0 3 * * * /home/gordonpn/workspace/server-services-configs/scripts/backup.sh >> /home/gordonpn/logs/backup.log 2>&1
0 5 * * * /home/gordonpn/workspace/server-services-configs/scripts/update_containers.sh >> /home/gordonpn/logs/container_update.log 2>&1
@reboot sleep 600 && /usr/bin/docker swarm ca --rotate --quiet
0 */2 * * * /home/gordonpn/workspace/server-services-configs/scripts/force_rebalance.sh >> /home/gordonpn/logs/force_rebalance.log 2>&1
0 */6 * * * /home/gordonpn/workspace/temporary/shoppies_api_key.sh
```
