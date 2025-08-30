# Django VPS Demo Project

Simple Django project optimized for VPS deployment with multi-project support.

## ✨ Features

- **Minimal Dependencies**: Clean, lightweight setup with only essential packages
- **Environment Configuration**: Production settings managed via environment variables
- **Database Flexible**: Works with SQLite for development and PostgreSQL for production
- **Static Files Handling**: Configured with WhiteNoise for efficient static file serving
- **Contact Form**: Functional contact form with email validation
- **Simple Blog System**: Basic blog functionality with admin interface
- **Bootstrap UI**: Responsive design using Bootstrap 5
- **Production Security**: Security headers, HTTPS support, and production optimizations
- **VPS Deployment**: Complete deployment scripts and configuration files

## 🛠 Tech Stack

- **Backend**: Django 4.2.7
- **Database**: SQLite (development) / PostgreSQL (production)
- **Web Server**: Gunicorn + Nginx
- **Frontend**: Bootstrap 5, Vanilla JavaScript
- **Static Files**: WhiteNoise
- **Configuration**: python-decouple

## 🚀 Deploy to VPS

### After VPS Reset:
```bash
# 1. Fix SSH key
ssh-keygen -f '/home/amit/.ssh/known_hosts' -R '69.62.81.168'

# 2. Setup django user  
scp setup-django-user.sh akvps:/root/
ssh akvps "sudo bash /root/setup-django-user.sh"

# 3. Clone and deploy (choose one option below)
```

### Option 1: Simple Single Project
```bash
ssh akvps "cd /home/django && git clone https://github.com/thecyberlearn/hostinger-django-demo.git"
ssh akvps "cd /home/django/hostinger-django-demo && sudo bash deploy/production-deploy.sh"
```

### Option 2: Multi-Project System  
```bash
ssh akvps "cd /home/django && git clone https://github.com/thecyberlearn/hostinger-django-demo.git"
ssh akvps "cd /home/django/hostinger-django-demo && sudo bash deploy/deploy-project.sh https://github.com/thecyberlearn/hostinger-django-demo.git"
```

**Your site**: http://69.62.81.168/

## 📁 Key Files

**Main Deployment Scripts:**
- `deploy/production-deploy.sh` - Simple single project deployment
- `deploy/deploy-project.sh` - Multi-project system with auto repo naming

**Documentation:**
- `MULTI_PROJECT_SETUP.md` - Complete multi-project guide

**Setup:**
- `setup-django-user.sh` - Create django user on fresh VPS
- `requirements.txt` - Python dependencies

## 🎯 That's It!

For detailed multi-project setup, see `MULTI_PROJECT_SETUP.md`

Simple, clean, and no confusion! 🚀