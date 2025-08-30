# Multi-Project Django VPS Setup Guide

## 🚀 Research-Based Multi-Project System

This system follows **2024 Django deployment best practices** and supports unlimited Django projects on a single VPS with automatic GitHub repo name extraction.

## ✨ Features

- ✅ **Auto-Extract GitHub Repo Names** → No manual project naming
- ✅ **Unlimited Django Projects** → `/var/www/project1/`, `/var/www/project2/`, etc.
- ✅ **Path-Based Routing** → `yourip.com/project1/`, `yourip.com/project2/`
- ✅ **Centralized Webhook Router** → One webhook URL handles all projects
- ✅ **Individual Services** → Separate `gunicorn-project.service` per project
- ✅ **Auto-Discovery** → Automatically detects existing Django projects

## 🏗️ Architecture

```
VPS Structure:
/var/www/
├── hostinger-django-demo/     ← From: github.com/user/hostinger-django-demo
├── my-blog-site/              ← From: github.com/user/my-blog-site
├── ecommerce-app/             ← From: github.com/user/ecommerce-app
└── webhook-manager/           ← Centralized webhook router

URLs:
http://YOUR_IP/                    → Project list & health check
http://YOUR_IP/hostinger-django-demo/    → First project
http://YOUR_IP/my-blog-site/            → Second project  
http://YOUR_IP/ecommerce-app/           → Third project
http://YOUR_IP/webhook                  → GitHub webhooks (all projects)
http://YOUR_IP/deploy-status            → Deployment status (all projects)
```

## 🚀 Quick Setup (3 Commands)

### Step 1: Upload & Setup Multi-Project System
```bash
# Upload this project to your VPS (django user home)
scp -r . akvps:/home/django/hostinger-django-demo

# Setup multi-project webhook system
ssh akvps
cd /home/django/hostinger-django-demo
sudo bash deploy/setup-multi-webhook.sh
```

### Step 2: Deploy Your First Project
```bash
# Deploy current project (auto-extracts name: hostinger-django-demo)
sudo bash deploy/deploy-project.sh https://github.com/thecyberlearn/hostinger-django-demo.git

# Your project is now live at: http://YOUR_IP/hostinger-django-demo/
```

### Step 3: Configure GitHub Webhook
```bash
# Use the webhook secret from Step 1
# Go to: https://github.com/thecyberlearn/hostinger-django-demo/settings/hooks
# Add webhook:
#   - URL: http://YOUR_IP/webhook
#   - Secret: [from setup script]
#   - Content-type: application/json
#   - Events: Just push event
```

## 📦 Add More Projects

### Deploy Additional Projects
```bash
# Each new project gets deployed automatically with correct naming
sudo bash deploy/deploy-project.sh https://github.com/yourusername/my-blog-app.git
sudo bash deploy/deploy-project.sh https://github.com/yourusername/portfolio-site.git
sudo bash deploy/deploy-project.sh https://github.com/yourusername/api-backend.git

# Projects auto-deploy to:
# http://YOUR_IP/my-blog-app/
# http://YOUR_IP/portfolio-site/
# http://YOUR_IP/api-backend/
```

### GitHub Webhook Configuration
**Single webhook handles ALL projects!**
- Each repo needs the SAME webhook URL: `http://YOUR_IP/webhook`
- Same secret for all repositories
- Router automatically detects which project to deploy based on repo name

## 🔧 Management Commands

### Check All Projects Status
```bash
curl http://YOUR_IP/deploy-status
# Shows all projects, services, and commit hashes
```

### Individual Project Management
```bash
# Check specific project service
systemctl status gunicorn-hostinger-django-demo.service
systemctl status gunicorn-my-blog-app.service

# View logs for specific project
journalctl -u gunicorn-hostinger-django-demo.service -f
journalctl -u gunicorn-my-blog-app.service -f

# Restart specific project
systemctl restart gunicorn-hostinger-django-demo.service
```

### Webhook Router Management
```bash
# Check webhook router status
systemctl status django-webhook-router.service

# View webhook router logs
journalctl -u django-webhook-router.service -f

# Restart webhook router
systemctl restart django-webhook-router.service
```

## 🧪 Testing Auto-Deploy

### Test Project Deployment
```bash
# Make a change in any project repository
echo "# Multi-project test" >> README.md
git add .
git commit -m "Test multi-project auto-deploy"
git push origin main

# Watch deployment happen
journalctl -u django-webhook-router.service -f
```

### Verify Deployment
```bash
# Check if all services are running
curl http://YOUR_IP/deploy-status

# Test each project URL
curl http://YOUR_IP/hostinger-django-demo/
curl http://YOUR_IP/my-blog-app/
curl http://YOUR_IP/portfolio-site/
```

## 🔍 Monitoring & Logs

### Centralized Monitoring
```bash
# All projects status
curl http://YOUR_IP/deploy-status | jq

# Webhook router health  
curl http://YOUR_IP/health | jq

# Project discovery
curl http://YOUR_IP/health
```

### Log Locations
```bash
# Webhook router logs
tail -f /var/log/django/webhook-router.log

# Individual project logs
journalctl -u gunicorn-PROJECT_NAME.service -f

# Nginx logs
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

## 🎯 Benefits

### For Developers
- **No Manual Configuration** → Just provide GitHub URL
- **Unlimited Projects** → Add as many Django apps as you want  
- **Consistent Naming** → Uses actual repository names
- **Single Webhook** → One URL handles all your repositories

### For Operations  
- **Industry Standard** → Follows 2024 Django deployment best practices
- **Resource Efficient** → Shared nginx, individual gunicorn processes
- **Easy Monitoring** → Centralized status and logging
- **Auto-Discovery** → Automatically detects existing projects

## 🚨 Troubleshooting

### Project Not Deploying
```bash
# Check if project was discovered
curl http://YOUR_IP/health

# Check project service
systemctl status gunicorn-PROJECT_NAME.service

# Check deployment logs
journalctl -u django-webhook-router.service -f
```

### Webhook Not Triggering
```bash
# Verify webhook secret in GitHub matches
cat /var/www/webhook-manager/.env

# Check webhook router logs
journalctl -u django-webhook-router.service -f

# Test webhook manually
curl -X POST http://YOUR_IP/webhook \
  -H "Content-Type: application/json" \
  -d '{"test": "webhook"}'
```

### Service Issues
```bash
# Reload systemd if services don't start
systemctl daemon-reload

# Check nginx configuration
nginx -t

# Restart all services
systemctl restart django-webhook-router.service
systemctl restart nginx
```

## 🎉 Success!

You now have a **production-ready multi-project Django VPS** that:
- Auto-extracts GitHub repository names
- Supports unlimited Django projects  
- Auto-deploys on git push (like Render/Vercel)
- Follows industry best practices for 2024
- Scales effortlessly as you add more projects

**Just push to GitHub and watch your projects deploy automatically!** 🚀