#!/bin/bash
# Purpose: Build an AMI for our Elasticsearch Cluster

######################################
# Docker & Docker Compose Installation
######################################
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm -f get-docker.sh

# Set to max mem 256GB
echo "vm.max_map_count=2097152" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

#########
# AWS CLI
#########
apt install -y unzip jq net-tools
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws
rm -f *.zip
aws --version

###############
# Disk Mounting
###############

mkdir /data
mkfs -t xfs /dev/nvme1n1
lsblk
mount /dev/nvme1n1 /data
df -hT
umount /dev/nvme1n1
# for xfs:
xfs_admin -L ES /dev/nvme1n1
lsblk -o name,mountpoint,label,size,uuid
cat << EOF >> /etc/fstab
LABEL=ES /data  xfs  defaults,nofail  0  2
EOF

mount -a
df -hT
lsblk -o name,mountpoint,label,size,uuid
chmod 0777 /data/

curl -# -LO https://raw.githubusercontent.com/quickbooks2018/cloudflare-tls/main/ssl.sh
chmod +x ssl.sh
bash -uvx ssl.sh
chmod 0444 -R ${HOME}/tls
# End
