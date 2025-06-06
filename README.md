# 🚀 Centralized ELK Stack: Multi-Server Security Monitoring

Deploy a **centralized ELK Stack** that monitors multiple VPS servers from one dashboard:

✅ **Centralized SSH monitoring** across all servers  
✅ **File integrity monitoring** for critical system files  
✅ **Real-time security dashboards** with geolocation  
✅ **Automated deployment** with Docker Compose

---

## 🏗️ Architecture

```
[Central ELK Server] ← [Remote Server 1 + Filebeat]
                    ← [Remote Server 2 + Filebeat]  
                    ← [Remote Server N + Filebeat]
```

---

## 🚀 Quick Setup

### Step 1: Deploy Central ELK Server
```bash
curl -sSL https://raw.githubusercontent.com/Incrisz/elk-stack/main/central-elk-setup.sh | bash
```

### Step 2: Install Agents on Remote Servers
```bash
# Replace with your ELK server IP
SERVER_IP="your.elk.server.ip" curl -sSL https://raw.githubusercontent.com/Incrisz/elk-stack/main/remote-agent-setup.sh | bash
```

---

## 🔐 Access & Login

1. **Access Kibana**: `http://your-elk-server-ip:5601`
2. **Login Credentials**:
   - Username: `elastic`
   - Password: `changeme123`

### If Kibana asks for verification code:
```bash
sudo docker exec kibana /usr/share/kibana/bin/kibana-verification-code
```

---

## 📊 Create Dashboards

In Kibana, create these index patterns:
- `ssh-logs-*` (SSH authentication events)
- `file-integrity-*` (File changes)
- `general-logs-*` (System logs)

---

## 🔍 What's Monitored

### From Each Server:
- **SSH Events**: Login attempts, source IPs, geolocation
- **File Changes**: `/etc/`, `/usr/bin/`, `/usr/sbin/`, SSH keys
- **System Logs**: General system events and errors

### Security Features:
- Failed login tracking with source IP geolocation
- Real-time file integrity monitoring
- Multi-server correlation in single dashboard

---

## 🛠️ Management

### Check ELK services:
```bash
cd /home/elk-stack && sudo docker-compose ps
```

### View logs:
```bash
sudo docker logs kibana
sudo docker logs logstash
sudo docker logs elasticsearch
```

### Check remote agent:
```bash
sudo systemctl status filebeat
```

---

## 🔒 Security

⚠️ **Change default password**:
```bash
sudo docker exec elasticsearch /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic
```

**Firewall**: Ports 5601 (Kibana), 5044 (Logstash) need to be accessible

---

## 📋 Requirements

- **Central Server**: 4GB RAM minimum (8GB recommended)
- **Remote Servers**: 512MB RAM minimum
- **Storage**: 20GB+ for log retention
- **OS**: Ubuntu/Debian Linux

---

## 🆘 Quick Troubleshooting

### Remote server not sending logs:
```bash
# Check Filebeat status
sudo systemctl status filebeat
sudo tail -f /var/log/filebeat/filebeat

# Test connection to ELK server
nc -z your.elk.server.ip 5044
```

### Kibana issues:
```bash
sudo docker logs kibana
```

---

## 🧹 Complete Removal

```bash
# On ELK server
cd /home/elk-stack && sudo docker-compose down -v && sudo rm -rf /home/elk-stack

# On remote servers  
sudo systemctl stop filebeat && sudo apt remove --purge -y filebeat
```