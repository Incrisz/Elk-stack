# 🚀 ELK Stack: Elasticsearch, Logstash, and Kibana Deployment

This project provides an automated way to deploy the **ELK Stack** (Elasticsearch, Logstash, and Kibana) on a single VPS, with:

✅ SSH login monitoring  
✅ File integrity monitoring  
✅ Docker Compose for easy management

---

## 📦 Features

- **Elasticsearch**: Store and index logs for powerful search and analysis.
- **Logstash**: Collect logs from your system (including SSH logins).
- **Kibana**: Visualize logs and data in real-time dashboards.
- **Filebeat**: File integrity monitoring to track changes in critical system files.

---

## ⚙️ Quick Setup

Run this one-liner on your VPS to automatically install and configure everything:

```bash
sudo curl -sSL https://raw.githubusercontent.com/Incrisz/elk-stack/main/setup-elk.sh | bash
```

---

## 🔐 Initial Setup & Access

After the script completes:

1. **Copy the enrollment token** displayed in the terminal
2. **Access Kibana** at `http://your-vps-ip:5601`
3. **Paste the enrollment token** when prompted

### Getting the Verification Code

If Kibana asks for a verification code, run one of these commands:

```bash
sudo docker logs kibana 2>&1 | grep -E "verification|code"
```

### Login Credentials

- **Username**: `elastic`
- **Password**: `changeme123`

⚠️ **Important**: Change the default password after first login:
```bash
sudo docker exec elasticsearch /usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic
```

---

## 📊 Setting Up Dashboards

Once logged into Kibana:

1. Go to **Stack Management** → **Index Patterns**
2. Create these index patterns:
   - `ssh-logins-*` (for SSH monitoring)
   - `filebeat-*` (for file integrity monitoring)
3. Navigate to **Discover** to start exploring your logs

---

## 🛠️ Management Commands

### Check service status:
```bash
cd /home/elk-stack
sudo docker-compose ps
```

### View logs:
```bash
sudo docker logs elasticsearch
sudo docker logs kibana
sudo docker logs logstash
```

### Restart services:
```bash
cd /home/elk-stack
sudo docker-compose restart
```

### Stop all services:
```bash
cd /home/elk-stack
sudo docker-compose down
```

---

## 🔒 Security Notes

- The setup uses basic authentication with a default password
- For production use, consider:
  - Enabling SSL/TLS encryption
  - Setting up proper firewall rules
  - Using stronger passwords
  - Implementing network security groups

---

## 🌐 Access Points

- **Elasticsearch**: `http://your-vps-ip:9200`
- **Kibana**: `http://your-vps-ip:5601`
- **Logstash**: `http://your-vps-ip:5044` (for log ingestion)

---

## 📝 What's Being Monitored

### SSH Logins
- All authentication attempts
- Successful and failed logins
- Source IP addresses
- Timestamps

### File Integrity
- Changes to `/etc/` directory
- Modifications to `/usr/bin/` and `/usr/sbin/`
- File creation, deletion, and modification events

---

## 🆘 Troubleshooting

### Kibana won't start or shows errors:
```bash
sudo docker logs kibana
```

### Elasticsearch memory issues:
```bash
# Increase memory limits in docker-compose.yml
ES_JAVA_OPTS=-Xms2g -Xmx2g
```

### Logstash not processing logs:
```bash
sudo docker logs logstash
# Check if /var/log/auth.log exists and is readable
```

---

## 📋 System Requirements

- **RAM**: Minimum 4GB (8GB recommended)
- **Storage**: At least 8GB free space
- **OS**: Ubuntu/Debian-based Linux
- **Network**: Ports 5601, 9200, and 5044 accessible

---

## 🤝 Contributing

Feel free to submit issues and pull requests to improve this ELK stack deployment!