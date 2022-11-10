#!/bin/bash
# ES Monitoring on AWS
# OS Ubuntu
# Maintainer Muhammad Asim <info@cloudgeeks.ca>

######################################
# Docker & Docker Compose Installation
######################################
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm -f get-docker.sh

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


ELASTIC_VERSION="7.17.7"
export ELASTIC_VERSION

cat << EOF > docker-compose.yaml
services:

  grafana:
    image: grafana/grafana:latest
    container_name: grafana-server
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=cloudgeeks
    ports:
      - '80:3000'
    volumes:
      - grafana_data:/var/lib/grafana

  kibana:
    image: bitnami/kibana:${ELASTIC_VERSION}
    container_name: kibana
    restart: unless-stopped
    ports:
      - '5601:5601'
    environment:
      - KIBANA_ELASTICSEARCH_URL=elasticsearch-node1.cloudgeeks.tk
    volumes:
        - kibana:/bitnami
volumes:
  grafana_data: {}
  kibana:
EOF

docker compose -p grafana up -d

# END
