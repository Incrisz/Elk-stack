#!/bin/bash
set -e

echo "=== Updating system and installing Docker & Docker Compose... ==="
sudo apt update
sudo apt upgrade -y
sudo apt install -y docker.io docker-compose
sudo systemctl enable docker --now

echo "=== Creating /home/elk-stack directory... ==="
sudo mkdir -p /home/elk-stack
cd /home/elk-stack

echo "=== Creating docker-compose.yml... ==="
sudo tee docker-compose.yml <<EOF
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.13.4
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - bootstrap.memory_lock=true
      - ES_JAVA_OPTS=-Xms1g -Xmx1g
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - es_data:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"

  kibana:
    image: docker.elastic.co/kibana/kibana:8.13.4
    container_name: kibana
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch

  logstash:
    image: docker.elastic.co/logstash/logstash:8.13.4
    container_name: logstash
    ports:
      - "5044:5044"
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf:ro
    depends_on:
      - elasticsearch

volumes:
  es_data:
EOF

echo "=== Creating logstash.conf to monitor SSH logins... ==="
sudo tee logstash.conf <<EOF
input {
  file {
    path => "/var/log/auth.log"
    start_position => "beginning"
    sincedb_path => "/dev/null"
  }
}

filter {
  grok {
    match => { "message" => "%{SYSLOGTIMESTAMP:timestamp} %{HOSTNAME:host} %{DATA:program}(?:\\[%{POSINT:pid}\\])?: %{GREEDYDATA:message}" }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "ssh-logins-%{+YYYY.MM.dd}"
  }
  stdout { codec => rubydebug }
}
EOF

echo "=== Launching the ELK stack... ==="
{
  cd /home/elk-stack
  sudo docker-compose up -d
}


echo "=== Installing Filebeat for file integrity monitoring... ==="
sudo curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.13.4-amd64.deb
sudo dpkg -i filebeat-8.13.4-amd64.deb

echo "=== Enabling file integrity module in Filebeat... ==="
sudo filebeat modules enable file_integrity

echo "=== Configuring Filebeat output to Logstash... ==="
sudo tee -a /etc/filebeat/filebeat.yml <<EOF

output.logstash:
  hosts: ["localhost:5044"]
EOF

echo "=== Starting Filebeat... ==="
sudo systemctl enable filebeat
sudo systemctl start filebeat

echo ""
echo "🎉 All set! Access your ELK stack:"
echo "  - Elasticsearch: http://your-vps-ip:9200"#!/bin/bash
set -e

echo "=== Updating system and installing Docker & Docker Compose... ==="
sudo apt update
sudo apt upgrade -y
sudo apt install -y docker.io docker-compose
sudo systemctl enable docker --now

echo "=== Creating /home/elk-stack directory... ==="
sudo mkdir -p /home/elk-stack
cd /home/elk-stack

echo "=== Creating docker-compose.yml... ==="
sudo tee docker-compose.yml <<EOF
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.13.4
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - bootstrap.memory_lock=true
      - ES_JAVA_OPTS=-Xms1g -Xmx1g
    ulimits:
      memlock:
        soft: -1
        hard: -1
    volumes:
      - es_data:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"

  kibana:
    image: docker.elastic.co/kibana/kibana:8.13.4
    container_name: kibana
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch

  logstash:
    image: docker.elastic.co/logstash/logstash:8.13.4
    container_name: logstash
    ports:
      - "5044:5044"
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf:ro
    depends_on:
      - elasticsearch

volumes:
  es_data:
EOF

echo "=== Creating logstash.conf to monitor SSH logins... ==="
sudo tee logstash.conf <<EOF
input {
  file {
    path => "/var/log/auth.log"
    start_position => "beginning"
    sincedb_path => "/dev/null"
  }
}

filter {
  grok {
    match => { "message" => "%{SYSLOGTIMESTAMP:timestamp} %{HOSTNAME:host} %{DATA:program}(?:\\[%{POSINT:pid}\\])?: %{GREEDYDATA:message}" }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "ssh-logins-%{+YYYY.MM.dd}"
  }
  stdout { codec => rubydebug }
}
EOF

echo "=== Launching the ELK stack... ==="
(
  cd /home/elk-stack
  sudo docker-compose up -d
)

echo "=== Installing Filebeat for file integrity monitoring... ==="
sudo curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.13.4-amd64.deb
sudo dpkg -i filebeat-8.13.4-amd64.deb

echo "=== Configuring Filebeat for file integrity monitoring... ==="
sudo tee /etc/filebeat/filebeat.yml <<EOF
filebeat.inputs:
  - type: filestream
    id: file_integrity_monitor
    paths:
      - /etc/**/*
      - /usr/bin/*
      - /usr/sbin/*

output.logstash:
  hosts: ["localhost:5044"]
EOF

echo "=== Starting Filebeat... ==="
sudo systemctl enable filebeat
sudo systemctl start filebeat

echo ""
echo "🎉 All set! Access your ELK stack:"
echo "  - Elasticsearch: http://your-vps-ip:9200"
echo "  - Kibana: http://your-vps-ip:5601"
echo "👉 In Kibana, create index patterns 'ssh-logins-*' and 'filebeat-*' to see logs and file changes."

echo "  - Kibana: http://your-vps-ip:5601"
echo "👉 In Kibana, create index patterns 'ssh-logins-*' and 'filebeat-*' to see logs and file changes."
