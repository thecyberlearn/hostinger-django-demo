# 🚀 Django VPS Deployment Toolkit

**Universal toolkit to deploy ANY Django project to VPS with zero configuration.**

## ✨ Features

- 🎯 **Universal** - Deploy any Django project from GitHub
- 🏷️ **Auto-naming** - Extracts project name from repo URL  
- 🔄 **Multi-project** - Unlimited Django projects per VPS
- 🔧 **Zero config** - Automatic nginx + gunicorn + systemd setup
- 🚀 **One command** - Complete deployment in minutes
- 🔒 **Secure** - Non-root deployment with proper permissions
- 📡 **Auto-deploy** - GitHub webhook integration for CI/CD

## 🚀 Quick Deploy

### Setup VPS (Once per VPS)
```bash
# 1. Fix SSH after VPS reset
ssh-keygen -f '~/.ssh/known_hosts' -R 'YOUR_VPS_IP'

# 2. Upload and run user setup
scp setup-django-user.sh root@YOUR_VPS_IP:/root/
ssh root@YOUR_VPS_IP "sudo bash /root/setup-django-user.sh"

# 3. Clone this toolkit
ssh root@YOUR_VPS_IP "cd /home/django && git clone https://github.com/thecyberlearn/hostinger-django-demo.git django-vps-toolkit"
```

### Deploy Any Django Project
```bash
# Deploy any Django project with one command!
ssh root@YOUR_VPS_IP "cd /home/django/django-vps-toolkit && sudo bash deploy-django-project.sh https://github.com/USER/PROJECT.git"
```

**Examples:**
```bash
# Deploy a blog
sudo bash deploy-django-project.sh https://github.com/johndoe/my-blog.git
# → Live at: http://YOUR_VPS_IP/my-blog/

# Deploy an e-commerce site  
sudo bash deploy-django-project.sh https://github.com/company/shop-backend.git
# → Live at: http://YOUR_VPS_IP/shop-backend/

# Deploy a portfolio
sudo bash deploy-django-project.sh https://github.com/jane/portfolio-site.git
# → Live at: http://YOUR_VPS_IP/portfolio-site/
```

## 🎯 What It Does

1. **Extracts project name** from GitHub URL
2. **Clones project** to `/var/www/PROJECT_NAME/`
3. **Creates virtual environment** and installs dependencies
4. **Runs Django migrations** and collects static files
5. **Creates systemd service** `gunicorn-PROJECT_NAME.service`
6. **Configures nginx** for path-based routing
7. **Starts everything** and tests deployment

## 📁 Toolkit Files

**🚀 Main Scripts:**
- `deploy-django-project.sh` - Deploy any Django project
- `setup-django-user.sh` - VPS user setup (run once)

**🔧 Advanced Features:**
- `setup-multi-webhook.sh` - GitHub auto-deploy webhooks
- `webhook-router.py` - Multi-project webhook handler
- `MULTI_PROJECT_SETUP.md` - Advanced webhook guide

**📝 Templates:**
- `templates/nginx.conf.template` - Nginx configuration
- `templates/gunicorn.service.template` - Systemd service
- `templates/production_settings.py` - Django production settings

## 🔄 Auto-Deploy Setup

Want GitHub auto-deploy like Render/Vercel?

```bash
# Setup webhook system
sudo bash setup-multi-webhook.sh

# Add webhook to your GitHub repos:
# URL: http://YOUR_VPS_IP/webhook  
# Secret: [from setup output]
# Events: Push events

# Now push to GitHub → Auto-deploy! 🚀
```

## 💡 Examples

### Deploy Multiple Projects
```bash
# Each project gets its own URL path
sudo bash deploy-django-project.sh https://github.com/user/blog.git
sudo bash deploy-django-project.sh https://github.com/user/shop.git  
sudo bash deploy-django-project.sh https://github.com/user/api.git

# Results:
# http://YOUR_VPS_IP/blog/
# http://YOUR_VPS_IP/shop/  
# http://YOUR_VPS_IP/api/
```

### Project Management
```bash
# Check project status
systemctl status gunicorn-blog.service
systemctl status gunicorn-shop.service

# View project logs
journalctl -u gunicorn-blog.service -f

# Restart project
systemctl restart gunicorn-blog.service

# Update project
cd /var/www/blog && sudo -u django git pull && systemctl restart gunicorn-blog.service
```

## 🎯 Requirements

**Your Django Project Needs:**
- `requirements.txt` file
- Working `manage.py`
- Proper Django project structure

**VPS Requirements:**
- Ubuntu 20.04+ or similar
- Root/sudo access
- 1GB+ RAM recommended

## 🚨 Troubleshooting

**Deployment fails?**
```bash
# Check logs
journalctl -u gunicorn-PROJECT_NAME.service -f

# Test Django
cd /var/www/PROJECT_NAME
sudo -u django bash -c "source venv/bin/activate && python manage.py check"

# Test nginx
nginx -t
```

**Can't access site?**
```bash
# Check services
systemctl status gunicorn-PROJECT_NAME.service nginx

# Check firewall
ufw status
```

## 🎉 Success!

You now have a **universal Django deployment toolkit** that can deploy any Django project to VPS with zero configuration!

**Just provide a GitHub URL and get a working Django site!** 🚀