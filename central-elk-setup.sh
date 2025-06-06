#!/bin/bash
set -e

echo "=== Setting up CENTRAL ELK Server for Remote Log Collection ==="
echo "=== Updating system and installing Docker & Docker Compose... ==="
sudo apt update
sudo apt upgrade -y
sudo apt install -y docker.io docker-compose
sudo systemctl enable docker --now

echo "=== Creating /home/elk-stack directory... ==="
sudo mkdir -p /home/elk-stack
cd /home/elk-stack

echo "=== Creating docker-compose.yml for Central ELK... ==="
sudo tee docker-compose.yml <<EOF
version: '3.8'

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.13.4
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - bootstrap.memory_lock=true
      - ES_JAVA_OPTS=-Xms2g -Xmx2g
      - ELASTIC_PASSWORD=changeme123
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
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=elastic
      - ELASTICSEARCH_PASSWORD=changeme123
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
      - /var/log:/var/log:ro
    depends_on:
      - elasticsearch

volumes:
  es_data:
EOF

echo "=== Creating enhanced logstash.conf for remote log collection... ==="
sudo tee logstash.conf <<EOF
input {
  # Local SSH logs (from this ELK server itself)
  file {
    path => "/var/log/auth.log"
    start_position => "beginning"
    sincedb_path => "/tmp/sincedb_auth"
    add_field => { "log_source" => "elk_server_local" }
    add_field => { "log_type" => "ssh_auth" }
    tags => ["local", "ssh"]
  }

  # Remote logs from Filebeat agents
  beats {
    port => 5044
  }
}

filter {
  # Parse SSH authentication logs
  if [log_type] == "ssh_auth" or "ssh" in [tags] {
    grok {
      match => { 
        "message" => "%{SYSLOGTIMESTAMP:timestamp} %{HOSTNAME:host} %{DATA:program}(?:\\[%{POSINT:pid}\\])?: %{GREEDYDATA:log_message}" 
      }
    }
    
    # Extract failed login attempts
    if [log_message] =~ /Failed password/ {
      grok {
        match => { 
          "log_message" => "Failed password for (?:invalid user )?%{USERNAME:failed_user} from %{IP:source_ip} port %{INT:source_port}" 
        }
      }
      mutate {
        add_field => { "event_type" => "failed_login" }
        add_field => { "severity" => "warning" }
      }
    }
    
    # Extract successful logins
    if [log_message] =~ /Accepted/ {
      grok {
        match => { 
          "log_message" => "Accepted %{WORD:auth_method} for %{USERNAME:successful_user} from %{IP:source_ip} port %{INT:source_port}" 
        }
      }
      mutate {
        add_field => { "event_type" => "successful_login" }
        add_field => { "severity" => "info" }
      }
    }
  }

  # Add timestamp
  date {
    match => [ "timestamp", "MMM  d HH:mm:ss", "MMM dd HH:mm:ss" ]
  }

  # Add geolocation for source IPs (optional)
  if [source_ip] and [source_ip] !~ /^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)/ {
    geoip {
      source => "source_ip"
      target => "geoip"
    }
  }
}

output {
  # SSH logs to dedicated index
  if [log_type] == "ssh_auth" or "ssh" in [tags] {
    elasticsearch {
      hosts => ["elasticsearch:9200"]
      index => "ssh-logs-%{+YYYY.MM.dd}"
      user => "elastic"
      password => "changeme123"
    }
  }
  
  # File integrity logs to dedicated index
  else if [log_type] == "file_integrity" {
    elasticsearch {
      hosts => ["elasticsearch:9200"]
      index => "file-integrity-%{+YYYY.MM.dd}"
      user => "elastic"
      password => "changeme123"
    }
  }
  
  # All other logs to general index
  else {
    elasticsearch {
      hosts => ["elasticsearch:9200"]
      index => "general-logs-%{+YYYY.MM.dd}"
      user => "elastic"
      password => "changeme123"
    }
  }
  
  # Debug output (remove in production)
  stdout { codec => rubydebug }
}
EOF

echo "=== Configuring firewall for remote log collection... ==="
sudo ufw allow 5044/tcp comment "Logstash - Remote log collection"
sudo ufw allow 5601/tcp comment "Kibana - Web interface"
sudo ufw allow 9200/tcp comment "Elasticsearch - API access"

echo "=== Launching Elasticsearch first... ==="
(
  cd /home/elk-stack
  sudo docker-compose up -d elasticsearch
)

echo "=== Waiting for Elasticsearch to start... ==="
sleep 30

echo "=== Generating Kibana enrollment token... ==="
ENROLLMENT_TOKEN=$(sudo docker exec elasticsearch /usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana)

echo ""
echo "🔑 KIBANA ENROLLMENT TOKEN:"
echo "=================================================="
echo "$ENROLLMENT_TOKEN"
echo "=================================================="
echo ""

echo "=== Starting Kibana and Logstash... ==="
(
  cd /home/elk-stack
  sudo docker-compose up -d kibana logstash
)

echo "=== Waiting for services to initialize... ==="
sleep 15

echo "=== Installing Filebeat locally (optional - monitors this ELK server) ==="
read -p "Install Filebeat on this ELK server to monitor itself? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  sudo curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.13.4-amd64.deb
  sudo dpkg -i filebeat-8.13.4-amd64.deb

  sudo tee /etc/filebeat/filebeat.yml <<EOF
filebeat.inputs:
  - type: filestream
    id: local_file_integrity
    paths:
      - /etc/**/*
      - /usr/bin/*
      - /usr/sbin/*
    fields:
      log_type: file_integrity
      server_name: elk-central-server
      environment: production
    fields_under_root: true

output.logstash:
  hosts: ["localhost:5044"]
EOF

  sudo systemctl enable filebeat
  sudo systemctl start filebeat
fi

# Get server IP
SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')

echo ""
echo "🎉 Central ELK Server Setup Complete!"
echo "=================================================="
echo "📡 Server IP: $SERVER_IP"
echo "🌐 Access Points:"
echo "  - Kibana: http://$SERVER_IP:5601"
echo "  - Elasticsearch: http://$SERVER_IP:9200"
echo "  - Logstash (for remote agents): $SERVER_IP:5044"
echo ""
echo "📋 Login Credentials:"
echo "  - Username: elastic"
echo "  - Password: changeme123"
echo ""
echo "🔑 KIBANA ENROLLMENT TOKEN:"
echo "=================================================="
echo "$ENROLLMENT_TOKEN"
echo "=================================================="
echo ""
echo "💡 If Kibana asks for verification code:"
echo "   sudo docker exec kibana /usr/share/kibana/bin/kibana-verification-code"
echo ""
echo "📤 Next Steps:"
echo "1. Access Kibana and complete setup"
echo "2. Deploy Filebeat agents on remote servers using:"
echo "   curl -sSL https://your-repo/remote-agent-setup.sh | SERVER_IP=$SERVER_IP bash"
echo ""
echo "⚠️  IMPORTANT: Change default password after setup!"
echo "   sudo docker exec elasticsearch /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic"