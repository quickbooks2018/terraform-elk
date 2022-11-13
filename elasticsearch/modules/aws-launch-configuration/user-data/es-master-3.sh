#!/bin/bash
# ES cluster on AWS
# OS Ubuntu
# Maintainer Muhammad Asim <info@cloudgeeks.ca>

# Useful Official Links
# https://www.elastic.co/guide/en/elasticsearch/reference/current/high-availability-cluster-small-clusters.html
# https://www.elastic.co/guide/en/elasticsearch/reference/7.17/configuring-tls-docker.html

#######################
# Elastic Search Node 3
#######################
ELASTIC_IMAGE='docker.elastic.co/elasticsearch/elasticsearch'
ELASTIC_VERSION='8.5.0'
HOST1='elasticsearch-node1.cloudgeeks.tk'
HOST2='elasticsearch-node2.cloudgeeks.tk'
HOST3='elasticsearch-node3.cloudgeeks.tk'
ELASTIC_CONTAINER_NAME='master-node-3'

############
# MetricBeat
############
# https://raw.githubusercontent.com/elastic/beats/8.5/deploy/docker/metricbeat.docker.yml
echo '
---
metricbeat.config:
  modules:
    path: ${path.config}/modules.d/*.yml
    # Reload module configs as they change:
    reload.enabled: false

metricbeat.autodiscover:
  providers:
    - type: docker
      hints.enabled: true

metricbeat.modules:
- module: docker
  metricsets:
    - "container"
    - "cpu"
    - "diskio"
    - "healthcheck"
    - "info"
    #- "image"
    - "memory"
    - "network"
  hosts: ["unix:///var/run/docker.sock"]
  period: 10s
  enabled: true

processors:
  - add_cloud_metadata: ~

output.elasticsearch:
  hosts: 'http://:elasticsearch:9200' ' > $PWD/metricbeat.yml


###########
# HeartBeat
###########
# https://raw.githubusercontent.com/elastic/beats/8.5/deploy/docker/heartbeat.docker.yml
echo '
---
heartbeat.monitors:
- type: http
  schedule: '@every 5s'
  urls:
    - http://elasticsearch:9200
    - http://kibana:5601

- type: icmp
  schedule: '@every 5s'
  hosts:
    - elasticsearch
    - kibana

processors:
- add_cloud_metadata: ~

output.elasticsearch:
  hosts: 'http://:elasticsearch:9200' ' > heartbeat.yml

#########
#FileBeat
#########
# https://raw.githubusercontent.com/elastic/beats/8.5/deploy/docker/filebeat.docker.yml
echo '
---
filebeat.config:
  modules:
    path: ${path.config}/modules.d/*.yml
    reload.enabled: false

filebeat.autodiscover:
  providers:
    - type: docker
      hints.enabled: true

processors:
- add_cloud_metadata: ~

output.elasticsearch:
  hosts: 'http://elasticsearch:9200' ' > filebeat.yml

############
# APM Server
############
# https://raw.githubusercontent.com/elastic/apm-server/master/apm-server.docker.yml
echo '
---
apm-server:
  host: 0.0.0.0:8200
  ssl.enabled: false

output.elasticsearch:
  hosts: ["http://elasticsearch:9200"]


monitoring:
  enabled: true '  > apm-server.yml


#################
# Route53 Section
#################
zonename='cloudgeeks.tk'
localip=$(curl -fs http://169.254.169.254/latest/meta-data/local-ipv4)
localip_host=$(echo "$((${-+"(${localip//./"+256*("}))))"}>>24&255))")
hostedzoneid=$(aws route53 list-hosted-zones-by-name --output json |  jq --arg name "${zonename}." -r '.HostedZones | .[] | select(.Name=="\($name)") | .Id' | awk -F '/' '{print $3}')
file=/tmp/record.json

cat << EOF > $file
{
  "Comment": "Update the A record set",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${HOST3}",
        "Type": "A",
        "TTL": 10,
        "ResourceRecords": [
          {
            "Value": "$localip"
          }
        ]
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets --hosted-zone-id $hostedzoneid --change-batch file://$file


#########
# NETWORK
#########
# We will use host network
export ELASTIC_IMAGE
export ELASTIC_VERSION
export HOST1
export HOST2
export HOST3
export ELASTIC_CONTAINER_NAME


cat << EOF > docker-compose.yaml
services:

  elasticsearch:
    image: ${ELASTIC_IMAGE}:${ELASTIC_VERSION}
    shm_size: '2gb'   # shared mem
    logging:
       driver: "awslogs"
       options:
         awslogs-group: "elasticsearch"
         awslogs-region: "us-east-1"
         awslogs-stream: ${ELASTIC_CONTAINER_NAME}
    ELASTIC_CONTAINER_NAME: ${ELASTIC_CONTAINER_NAME}
    hostname: ${HOST3}
    restart: unless-stopped
    ports:
      - 9200:9200
      - 9300:9300
    volumes:
      - /data:/usr/share/elasticsearch/data
      - /data:/usr/share/elasticsearch/logs

    environment:
      - "node.name=${HOST3}"
      - "bootstrap.memory_lock=true"
      - "cluster.name=es-cluster"
      - "node.master=true" 
      - "node.data=false" 
      - "node.ingest=false"
      - "logger.discovery: DEBUG"
   #   - "logger.level=ERROR"
      - "discovery.seed_hosts=${HOST1},${HOST2}"
      - "cluster.initial_master_nodes=${HOST1},${HOST2},${HOST3}"
      - "ES_JAVA_OPTS=-Xms2g -Xmx2g -Des.index.number_of_replicas=0 -Des.enforce.bootstrap.checks=true"
      - "xpack.ml.enabled=false"
      - "xpack.graph.enabled=false"
      - "xpack.watcher.enabled=false"
      - "xpack.monitoring.collection.enabled=false"
      - xpack.security.enabled=false
      - ELASTIC_PASSWORD=cloudgeeks
      - xpack.security.transport.ssl.enabled=false
  
    ulimits:
      memlock:
        soft: -1
        hard: -1

 metricbeat:
    image: docker.elastic.co/beats/metricbeat:${ELASTIC_VERSION}
    container_name: metricbeat
    restart: unless-stopped
    depends_on: ['elasticsearch']
    hostname: metricbeat
    command: ["--strict.perms=false", "-system.hostfs=/hostfs"]
    secrets:
      - source: metricbeat.yml
        target: /usr/share/metricbeat/metricbeat.yml
    volumes:
      - /proc:/hostfs/proc:ro
      - /sys/fs/cgroup:/hostfs/sys/fs/cgroup:ro
      - /:/hostfs:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro

  heartbeat:
    image: docker.elastic.co/beats/heartbeat:${ELASTIC_VERSION}
    depends_on: ['elasticsearch']
    command: -e --strict.perms=false
    secrets:
      - source: heartbeat.yml
        target: /usr/share/heartbeat/heartbeat.yml
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

  filebeat:
    image: docker.elastic.co/beats/filebeat:${ELASTIC_VERSION}
    user: root
    depends_on: ['elasticsearch']
    command: -e --strict.perms=false
    secrets:
      - source: filebeat.yml
        target: /usr/share/filebeat/filebeat.yml
    volumes:
      - /data:/usr/share/elasticsearch/logs
      - /var/lib/docker/containers:/hostfs/var/lib/docker/containers
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - system.hostfs=/hostfs
    restart: unless-stopped
    healthcheck:
      test: filebeat --strict.perms=false test config


  apm_server:
    image: docker.elastic.co/apm/apm-server:${ELASTIC_VERSION}
    depends_on: ['elasticsearch']
    command: -e --strict.perms=false

    secrets:
      - source: apm-server.yml
        target: /usr/share/apm-server/apm-server.yml
    restart: unless-stopped
EOF

docker compose -p elasticsearch up -d --build
# End
