# Server service configs and tools

![Healthchecks](https://healthchecks.io/badge/d5b6a7bd-1598-4684-8b91-1128b377a198/Er4g1DRe.svg)
![License](https://badgen.net/github/license/gordonpn/server-services-configs)

[![Buy Me A Coffee](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/gordonpn)

## Description

This repository contains configuration (docker-compose.yml files) to set up the services I run on my home server. As well as, some useful scripts in the `./scripts` directory.

![nodes](./docs/nodes.png)

## Setting up a new Raspberry Pi node

### Downloading and installing image

Download [Raspberry Pi OS Lite 64-bit](https://www.raspberrypi.com/software/operating-systems/).

Use the Raspberry Pi Imager and configure ssh and a user.

After flashing the image, create a file named `ssh` in `/boot` or `/system-boot`

Edit `cmdline.txt` and append `ipv6.disable=1`

Configure locale settings: `sudo raspi-config`

Run upgrades: `sudo apt update && sudo apt full-upgrade -y`

### Basic set up

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

### Set up firewall

Install UFW

`sudo apt-get update && sudo apt-get install -y ufw`

Edit `/etc/default/ufw` to disable ipv6:

`sudo vi /etc/default/ufw`

`sudo ufw enable`

Allow SSH from local network only

`sudo ufw allow from 192.168.50.0/24 proto tcp to any port 22`

<https://www.digitalocean.com/community/tutorials/ufw-essentials-common-firewall-rules-and-commands>

### Remove and disable unnecessary connectivity

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

### Remove some unused software

`sudo apt remove --purge -y bluez wolfram-engine triggerhappy xserver-common lightdm logrotate fake-hwclock samba-common && sudo apt autoremove -y --purge`

### Install unattended-upgrades

`sudo apt-get update && sudo apt-get install -y unattended-upgrades && sudo dpkg-reconfigure --priority=low unattended-upgrades`

### Set up external drive

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

`echo "UUID=$(sudo lsblk -f | grep sda1 | awk '{print $4}') /media/drive ext4 defaults,auto,users,rw,nofail,noatime 0 0" | sudo tee -a /etc/fstab`

Add at the bottom of `/etc/rc.local`

```sh
sleep 20
sudo mount -a
```

### Install Docker

`curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh`

`sudo usermod -aG docker $USER && newgrp docker`

Move Docker storage location elsewhere

`sudo rsync -aP /var/lib/docker/ /media/drive/docker`

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
  },
  "data-root": "/media/drive/docker"
}
EOF
```

Verify that the new directory is being used to store images after running `docker run hello-world`

`docker inspect $(docker images | grep hello-world | awk '{print $3}') | grep WorkDir`

Remove old Docker data storage directory

`sudo rm -rf /var/lib/docker`

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

`docker node update --label-add name=rpi0 rpi0`

#### Install Docker Compose

```sh
sudo curl -L "https://github.com/docker/compose/releases/download/v2.5.0/docker-compose-linux-aarch64" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### Reduce writes to Micro SD card

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

### Set up cron tasks

Here are some examples

```
@reboot /home/gordonpn/workspace/server-services-configs/scripts/get_dhcp.sh
0 3 * * * /home/gordonpn/workspace/server-services-configs/scripts/backup.sh >> /home/gordonpn/logs/backup.log 2>&1
0 5 * * * /home/gordonpn/workspace/server-services-configs/scripts/update_containers.sh >> /home/gordonpn/logs/container_update.log 2>&1
@reboot sleep 600 && /usr/bin/docker swarm ca --rotate --quiet
0 */2 * * * /home/gordonpn/workspace/server-services-configs/scripts/force_rebalance.sh >> /home/gordonpn/logs/force_rebalance.log 2>&1
0 2 * * * cd /home/gordonpn/workspace/dotfiles && /usr/bin/git pull origin master
```

### Open ports

If you are using a reverse proxy somewhere then you need to allow port 80 and 443

```sh
sudo ufw allow http
sudo ufw allow https
```

If you want to allow your personal computer to connect to any of the ports

```sh
sudo ufw allow from 192.168.50.214
```

### Setup NFS on host and clients

On the host, install NFS:

```bash
sudo apt-get update && sudo apt-get install -y nfs-common nfs-kernel-server
```

Create a directory to share and an NFS root directory

```bash
mkdir -p /media/drive/share
mkdir -p /srv/nfs4/share
```

Bind mount the directories

```bash
sudo mount --bind /media/drive/share /srv/nfs4/share
```

Make the mount permanent

```bash
echo "/media/drive/share /srv/nfs4/share none bind 0 0" | sudo tee -a /etc/fstab
```

Add the directory to be exported

```bash
echo "/srv/nfs4 192.168.33.0/24(rw,sync,insecure,no_subtree_check,crossmnt,fsid=0) " | sudo tee -a /etc/exports
echo "/srv/nfs4/share 192.168.33.0/24(rw,sync,insecure,no_subtree_check) " | sudo tee -a /etc/exports
```

Save and export the shares

```bash
sudo exportfs -ar
```

Verify

```bash
sudo exportfs -v
```

On host and all clients, open port for NFS:

```bash
sudo ufw allow from 192.168.50.0/24 to any port nfs
```

Install on all clients

```bash
sudo apt-get update && sudo apt-get install -y nfs-common
```

Create new directory for mount points

```bash
mkdir -p /mnt/share
```

Mount the remote NFS

```bash
sudo mount -t nfs -o vers=4 192.168.50.9:/share /mnt/share
```

Make mount permanent

```bash
echo "192.168.50.9:/share /mnt/share nfs defaults,timeo=900,retrans=5,_netdev 0 0" | sudo tee -a /etc/fstab
```
