#!/bin/bash
# ES cluster on AWS
# OS Ubuntu
# Maintainer Muhammad Asim <info@cloudgeeks.ca>

# Useful Official Links
# https://www.elastic.co/guide/en/elasticsearch/reference/current/high-availability-cluster-small-clusters.html
# https://www.elastic.co/guide/en/elasticsearch/reference/7.17/configuring-tls-docker.html


#######################
# Elastic Search Node 1
#######################
ELASTIC_IMAGE='docker.elastic.co/elasticsearch/elasticsearch'
ELASTIC_VERSION='7.17.7'
HOST1='elasticsearch-node1.cloudgeeks.tk'
HOST2='elasticsearch-node2.cloudgeeks.tk'
HOST3='elasticsearch-node3.cloudgeeks.tk'
CONTAINER_NAME='elasticsearch-node-1'
IMAGE='es'
VERSION='latest'

############
# Enable TLS
############
CERTS_DIR='/usr/share/elasticsearch/config/certificates'
DOMAIN='cloudgeeks.tk'

#################
# Route53 Section
#################
zonename='cloudgeeks.tk'
localip=$(curl -fs http://169.254.169.254/latest/meta-data/local-ipv4)
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
# We will use host network
export ELASTIC_IMAGE
export ELASTIC_VERSION
export HOST1
export HOST2
export HOST3
export CONTAINER_NAME
export DOMAIN
export CERTS_DIR
export IMAGE
export VERSION

cat << EOF > Dockerfile
FROM ${ELASTIC_IMAGE}:${ELASTIC_VERSION}
RUN mkdir -p ${CERTS_DIR}
COPY tls ${CERTS_DIR}
RUN yes | elasticsearch-plugin install discovery-ec2
EOF


cat << EOF > docker-compose.yaml
services:

  elasticsearch:
    build:
      context: .
      dockerfile: Dockerfile
    image: ${IMAGE}:${VERSION}
    shm_size: '2gb'   # shared mem
    network_mode: host
    logging:
       driver: "awslogs"
       options:
         awslogs-group: "elasticsearch"
         awslogs-region: "us-east-1"
         awslogs-stream: ${CONTAINER_NAME}
    container_name: ${CONTAINER_NAME}
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
      - xpack.security.enabled=true
      - ELASTIC_PASSWORD=cloudgeeks
      - xpack.security.transport.ssl.enabled=true
      - xpack.security.transport.ssl.verification_mode=certificate
      - xpack.security.transport.ssl.certificate_authorities=${CERTS_DIR}/CA.crt
      - xpack.security.transport.ssl.certificate=${CERTS_DIR}/$DOMAIN.crt
      - xpack.security.transport.ssl.key=${CERTS_DIR}/$DOMAIN.key
    
    ulimits:
      memlock:
        soft: -1
        hard: -1
  
  metricbeat:
    image: docker.elastic.co/beats/metricbeat:${ELASTIC_VERSION}
    network_mode: host
    restart: unless-stopped
    container_name: metricbeat
    hostname: metricbeat-${HOST1}
    command: ["--strict.perms=false", "-system.hostfs=/hostfs"]
    volumes:
      - /proc:/hostfs/proc:ro
      - /sys/fs/cgroup:/hostfs/sys/fs/cgroup:ro
      - /:/hostfs:ro
      - /var/run/docker.sock:/var/run/docker.sock
      - metricbeat:/usr/share/metricbeat/data
    environment:
      - "ELASTICSEARCH_HOSTS=${HOST1}"



volumes:
  metricbeat:

EOF

docker compose -p elasticsearch up -d --build
# End
