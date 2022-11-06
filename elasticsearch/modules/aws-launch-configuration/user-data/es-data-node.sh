#!/bin/bash
# ES cluster on AWS
# OS Ubuntu
# Maintainer Muhammad Asim <info@cloudgeeks.ca>


####################
# Elastic DATA Nodes
####################
ELASTIC_VERSION='7.5.2'
HOST1='elasticsearch-node1.cloudgeeks.ca'
HOST2='elasticsearch-node2.cloudgeeks.ca'
HOST3='elasticsearch-node3.cloudgeeks.ca'
CONTAINER_NAME='elasticsearch-data-node'
localip=$(curl -fs http://169.254.169.254/latest/meta-data/local-ipv4)
localip_host=$(echo "$((${-+"(${localip//./"+256*("}))))"}>>24&255))")

#########
# NETWORK
#########
# We will use host network

ELASTIC_VERSION="7.5.2"
HOST1='elasticsearch-node1.cloudgeeks.ca'
HOST2='elasticsearch-node2.cloudgeeks.ca'
HOST3='elasticsearch-node3.cloudgeeks.ca'
CONTAINER_NAME='elasticsearch-node'


export ELASTIC_VERSION
export HOST1
export HOST2
export HOST3
export CONTAINER_NAME

cat << EOF > docker-compose.yaml
services:

  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:${ELASTIC_VERSION}
    shm_size: '2gb'   # shared mem
    network_mode: host
    logging:
       driver: "awslogs"
       options:
         awslogs-group: "elasticsearch"
         awslogs-region: "us-east-1"
         awslogs-stream: ${CONTAINER_NAME}-${localip_host}
    container_name: ${CONTAINER_NAME}-${localip_host}
    hostname: ${CONTAINER_NAME}-${localip_host}
    restart: unless-stopped
    volumes:
      - /data:/usr/share/elasticsearch/data

    environment:
     - node.name=${CONTAINER_NAME}-${localip_host}
     - node.master=false
     - node.data=true
     - node.ingest=true
     - node.ml=false
     - "logger.discovery: DEBUG"
   #  - logger.level=ERROR
     - data=hot
     - cluster.name=es-cluster
     - network.publish_host=${localip}
     - discovery.seed_hosts=${HOST1},${HOST2},${HOST3}
     - bootstrap.memory_lock=true
     - "ES_JAVA_OPTS=-Xms2g -Xmx2g -Des.index.number_of_replicas=1 -Des.enforce.bootstrap.checks=true"
     - xpack.monitoring.collection.enabled=true
     - xpack.security.transport.ssl.enabled=false
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9200"]
      interval: 30s
      timeout: 10s
      retries: 30
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
  es-data:
  metricbeat:

EOF

docker compose -p elasticsearch up -d
# End
