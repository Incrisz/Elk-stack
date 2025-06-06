#!/bin/bash
set -e

# Configuration - Get ELK server IP from environment or parameter
ELK_SERVER_IP="${SERVER_IP:-${1:-}}"

if [ -z "$ELK_SERVER_IP" ]; then
    echo "❌ ERROR: ELK server IP not provided!"
    echo "Usage options:"
    echo "  SERVER_IP=your.elk.server.ip bash remote-agent-setup.sh"
    echo "  bash remote-agent-setup.sh your.elk.server.ip"
    echo "  curl -sSL script.sh | SERVER_IP=your.elk.server.ip bash"
    exit 1
fi

echo "=== Setting up Filebeat Agent for Central ELK Collection ==="
echo "📡 ELK Server: $ELK_SERVER_IP"
echo "🖥️  This Server: $(hostname)"

echo "=== Testing connection to ELK server... ==="
if command -v nc >/dev/null 2>&1; then
    if ! nc -z $ELK_SERVER_IP 5044 2>/dev/null; then
        echo "⚠️  Cannot reach ELK server at $ELK_SERVER_IP:5044"
        echo "   Continuing anyway - firewall may be blocking test"
    else
        echo "✅ Connection to ELK server successful"
    fi
else
    echo "ℹ️  Netcat not available, skipping connection test"
fi

echo "=== Installing Filebeat... ==="
sudo curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.13.4-amd64.deb
sudo dpkg -i filebeat-8.13.4-amd64.deb

echo "=== Configuring Filebeat for remote monitoring... ==="
sudo tee /etc/filebeat/filebeat.yml <<EOF
# Filebeat configuration for remote server monitoring
filebeat.inputs:
  # SSH Authentication Logs
  - type: log
    id: ssh_auth_logs
    enabled: true
    paths:
      - /var/log/auth.log
      - /var/log/secure
    fields:
      log_type: ssh_auth
      server_name: $(hostname)
      server_ip: $(hostname -I | awk '{print $1}')
      environment: production
    fields_under_root: true
    multiline.pattern: '^\w{3}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}'
    multiline.negate: true
    multiline.match: after

  # File Integrity Monitoring
  - type: filestream
    id: file_integrity_monitor
    enabled: true
    paths:
      - /etc/**/*
      - /usr/bin/*
      - /usr/sbin/*
      - /home/*/.ssh/*
      - /root/.ssh/*
    fields:
      log_type: file_integrity
      server_name: $(hostname)
      server_ip: $(hostname -I | awk '{print $1}')
      environment: production
    fields_under_root: true

  # System Logs (optional)
  - type: log
    id: system_logs
    enabled: true
    paths:
      - /var/log/syslog
      - /var/log/messages
    fields:
      log_type: system
      server_name: $(hostname)
      server_ip: $(hostname -I | awk '{print $1}')
      environment: production
    fields_under_root: true

# Output to central Logstash
output.logstash:
  hosts: ["$ELK_SERVER_IP:5044"]
  
# Processor to add metadata
processors:
  - add_host_metadata:
      when.not.contains.tags: forwarded
  - add_docker_metadata: ~
  - add_kubernetes_metadata: ~

# Logging configuration
logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat
  keepfiles: 7
  permissions: 0644

# Monitoring
monitoring.enabled: false
EOF

echo "=== Starting Filebeat service... ==="
sudo systemctl enable filebeat
sudo systemctl start filebeat

echo "=== Checking Filebeat status... ==="
sleep 5
sudo systemctl status filebeat --no-pager

echo "=== Testing log transmission... ==="
echo "Generating test log entry..."
logger "FILEBEAT_TEST: Remote monitoring setup completed for $(hostname)"

echo ""
echo "🎉 Remote Filebeat Agent Setup Complete!"
echo "=================================================="
echo "📡 Sending logs to: $ELK_SERVER_IP:5044"
echo "🖥️  Server: $(hostname)"
echo "📋 Monitoring:"
echo "  ✅ SSH authentication logs"
echo "  ✅ File integrity monitoring"
echo "  ✅ System logs"
echo ""
echo "🔍 Verification:"
echo "  - Check Kibana for logs from server: $(hostname)"
echo "  - Look for test log message in general-logs index"
echo ""
echo "📊 Create these index patterns in Kibana:"
echo "  - ssh-logs-*"
echo "  - file-integrity-*"
echo "  - general-logs-*"
echo ""
echo "🔧 Troubleshooting:"
echo "  sudo systemctl status filebeat"
echo "  sudo tail -f /var/log/filebeat/filebeat"