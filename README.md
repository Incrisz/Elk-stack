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
curl -sSL https://raw.githubusercontent.com/Incrisz/elk-stack/main/setup-elk.sh | bash
