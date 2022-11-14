#!/bin/bash
# ES cluster on AWS
# OS Ubuntu
# Maintainer Muhammad Asim <info@cloudgeeks.ca>

# Useful Official Links
# https://www.elastic.co/guide/en/elasticsearch/reference/current/high-availability-cluster-small-clusters.html
# https://www.elastic.co/guide/en/elasticsearch/reference/7.17/configuring-tls-docker.html

zonename='cloudgeeks.tk'
localip=$(curl -fs http://169.254.169.254/latest/meta-data/local-ipv4)
localip_host=$(echo "$((${-+"(${localip//./"+256*("}))))"}>>24&255))")

##############################
# Elastic Search Master Node 1
##############################
ELASTIC_IMAGE='docker.elastic.co/elasticsearch/elasticsearch'
ELASTIC_VERSION='7.17.7'
HOST1='elasticsearch-node1.cloudgeeks.tk'
HOST2='elasticsearch-node2.cloudgeeks.tk'
HOST3='elasticsearch-node3.cloudgeeks.tk'
ELASTIC_CONTAINER_NAME='master-node-1'


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
  enabled: true' > $PWD/metricbeat.yml

cat << EOF >> $PWD/metricbeat.yml
processors:
  - add_cloud_metadata: ~

output.elasticsearch:
  hosts: 'http://${localip}:9200'
EOF

############
# APM Server
############
KIBANA_URL='kibana.cloudgeeks.tk'
# https://raw.githubusercontent.com/elastic/apm-server/master/apm-server.docker.yml
cat << EOF > apm-server.yml
---
apm-server:
  host: 0.0.0.0:8200
  ssl.enabled: false

output.elasticsearch:
  hosts: ["http://${localip}:9200"]

kibana:
  enabled: true
  host: ["http://${KIBANA_URL}:5601"]

monitoring:
  enabled: true
EOF
#################
# Route53 Section
#################
hostedzoneid=$(aws route53 list-hosted-zones-by-name --output json |  jq --arg name "${zonename}." -r '.HostedZones | .[] | select(.Name=="\($name)") | .Id' | awk -F '/' '{print $3}')
file=/tmp/record.json

cat << EOF > $file
{
  "Comment": "Update the A record set",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${HOST1}",
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
export ELASTIC_IMAGE
export ELASTIC_VERSION
export HOST1
export HOST2
export HOST3
export ELASTIC_CONTAINER_NAME


############
# MetricBeat
############
cat << EOF > MetricBeatDockerfile
FROM docker.elastic.co/beats/metricbeat:${ELASTIC_VERSION}
COPY metricbeat.yml /usr/share/metricbeat/metricbeat.yml
EOF


############
# APM Server
############
cat << EOF > APMServerDockerfile
FROM docker.elastic.co/apm/apm-server:${ELASTIC_VERSION}
COPY apm-server.yml /usr/share/apm-server/apm-server.yml
EOF

cat << EOF > docker-compose.yaml
services:

  elasticsearch:
    image: ${ELASTIC_IMAGE}:${ELASTIC_VERSION}
    shm_size: '2gb'   # shared mem
    network_mode: host
    logging:
       driver: "awslogs"
       options:
         awslogs-group: "elasticsearch"
         awslogs-region: "us-east-1"
         awslogs-stream: ${ELASTIC_CONTAINER_NAME}
    container_name: ${ELASTIC_CONTAINER_NAME}
    hostname: ${HOST1}
    restart: unless-stopped

    volumes:
      - /data:/usr/share/elasticsearch/data

    environment:
      - "node.name=${HOST1}"
      - "bootstrap.memory_lock=true"
      - "cluster.name=es-cluster"
      - "node.master=true" 
      - "node.data=false" 
      - "node.ingest=false"
      - "logger.discovery: DEBUG"
  #    - "logger.level=ERROR"
      - "discovery.seed_hosts=${HOST2},${HOST3}"
      - "cluster.initial_master_nodes=${HOST1},${HOST2},${HOST3}"
      - "ES_JAVA_OPTS=-Xms2g -Xmx2g -Des.index.number_of_replicas=0 -Des.enforce.bootstrap.checks=true"
      - "xpack.security.http.ssl.enabled=false"
      - "xpack.ml.enabled=false"
      - "xpack.graph.enabled=false"
      - "xpack.monitoring.collection.enabled=true"
      - "xpack.watcher.enabled=false"
      - xpack.security.enabled=false
      - ELASTIC_PASSWORD=cloudgeeks
      - xpack.security.transport.ssl.enabled=false

    
    ulimits:
      memlock:
        soft: -1
        hard: -1
  
  metricbeat:
    build:
      context: .
      dockerfile: MetricBeatDockerfile
    image: metricbeat:metricbeat
    network_mode: host
    container_name: metricbeat
    restart: unless-stopped
    depends_on: ['elasticsearch']
    hostname: metricbeat
    command: ["--strict.perms=false", "-system.hostfs=/hostfs"]

    volumes:
      - /proc:/hostfs/proc:ro
      - /sys/fs/cgroup:/hostfs/sys/fs/cgroup:ro
      - /:/hostfs:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro

  apm_server:
    build:
     context: .
     dockerfile: APMServerDockerfile
    image: apm:apm
    network_mode: host
    depends_on: ['elasticsearch']
    container_name: apm
    command: -e --strict.perms=false
    restart: unless-stopped
EOF

docker compose -p elasticsearch up -d --build
# End
