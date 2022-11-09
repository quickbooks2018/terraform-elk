#!/bin/bash
# ES cluster on AWS
# OS Ubuntu
# Maintainer Muhammad Asim <info@cloudgeeks.ca>

# Useful Official Links
# https://www.elastic.co/guide/en/elasticsearch/reference/current/high-availability-cluster-small-clusters.html
# https://www.elastic.co/guide/en/elasticsearch/reference/7.17/configuring-tls-docker.html


####################
# Elastic DATA Nodes
####################
ELASTIC_IMAGE='docker.elastic.co/elasticsearch/elasticsearch'
ELASTIC_VERSION='7.17.7'
HOST1='elasticsearch-node1.cloudgeeks.tk'
HOST2='elasticsearch-node2.cloudgeeks.tk'
HOST3='elasticsearch-node3.cloudgeeks.tk'
CONTAINER_NAME='elasticsearch-data-node'
IMAGE='es'
VERSION='latest'
localip=$(curl -fs http://169.254.169.254/latest/meta-data/local-ipv4)
localip_host=$(echo "$((${-+"(${localip//./"+256*("}))))"}>>24&255))")

#############
# Disable TLS
#############
CERTS_DIR='/usr/share/elasticsearch/config/certificates'
DOMAIN='cloudgeeks.tk'

#########
# NETWORK
#########
# We will use host network
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
     - "xpack.monitoring.collection.enabled=false"
 #    - xpack.security.enabled=true
     - ELASTIC_PASSWORD=cloudgeeks
     - xpack.security.transport.ssl.enabled=true
     - xpack.security.transport.ssl.verification_mode=certificate
     - xpack.security.transport.ssl.certificate_authorities=${CERTS_DIR}/CA.crt
     - xpack.security.transport.ssl.certificate=${CERTS_DIR}/$DOMAIN.crt
     - xpack.security.transport.ssl.key=${CERTS_DIR}/$DOMAIN.key
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
  metricbeat:

EOF

docker compose -p elasticsearch up -d
# End
