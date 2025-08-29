# Production Django Deployment Guide

A comprehensive, battle-tested guide for deploying Django applications on VPS with proper security and performance.

## 🎯 **Overview**

This guide follows Django best practices and avoids common pitfalls we encountered:

- ❌ **Avoid**: Running as root, wrong directories, TCP sockets, hardcoded paths
- ✅ **Use**: Non-root user, `/var/www/`, Unix sockets, proper systemd configuration

## 📋 **Prerequisites**

- Ubuntu 20.04+ VPS with root access
- Domain name (optional, can use IP address)
- Git repository with Django project

## 🚀 **Step 1: VPS Initial Setup**

### Connect and Update System
```bash
ssh root@YOUR_VPS_IP
apt update && apt upgrade -y
```

### Install Required Packages
```bash
apt install -y python3 python3-pip python3-venv python3-dev \
               nginx postgresql postgresql-contrib libpq-dev \
               build-essential curl git ufw
```

### Create Non-Root User
```bash
adduser django --disabled-password --gecos ''
usermod -aG sudo django
```

### Configure SSH for New User (Optional)
```bash
mkdir -p /home/django/.ssh
cp /root/.ssh/authorized_keys /home/django/.ssh/
chown -R django:django /home/django/.ssh
chmod 700 /home/django/.ssh
chmod 600 /home/django/.ssh/authorized_keys
```

## 🗂️ **Step 2: Project Setup**

### Create Project Directory
```bash
mkdir -p /var/www
chown django:www-data /var/www
```

### Clone Project (as django user)
```bash
sudo -u django bash -c "
cd /var/www
git clone YOUR_REPO_URL django-app
cd django-app
"
```

### Create Virtual Environment
```bash
sudo -u django bash -c "
cd /var/www/django-app
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
"
```

## ⚙️ **Step 3: Django Configuration**

### Environment Variables
```bash
sudo -u django bash -c "
cd /var/www/django-app
cp .env.example .env
# Edit .env with production settings
"
```

**Required .env settings:**
```env
SECRET_KEY=your-super-secret-key-generate-new-one
DEBUG=False
ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com,YOUR_VPS_IP
DATABASE_URL=postgresql://dbuser:dbpassword@localhost/dbname
SECURE_SSL_REDIRECT=False  # Set True after SSL setup
```

### Run Django Setup
```bash
sudo -u django bash -c "
cd /var/www/django-app
source venv/bin/activate
python manage.py collectstatic --noinput
python manage.py migrate
python manage.py createsuperuser
"
```

## 🔧 **Step 4: Gunicorn with systemd**

### Create Gunicorn Socket
```bash
cat > /etc/systemd/system/gunicorn.socket << 'EOF'
[Unit]
Description=gunicorn socket

[Socket]
ListenStream=/run/gunicorn.sock

[Install]
WantedBy=sockets.target
EOF
```

### Create Gunicorn Service
```bash
cat > /etc/systemd/system/gunicorn.service << 'EOF'
[Unit]
Description=Gunicorn daemon for Django app
Requires=gunicorn.socket
After=network.target

[Service]
User=django
Group=www-data
WorkingDirectory=/var/www/django-app
Environment=DJANGO_SETTINGS_MODULE=PROJECT_NAME.settings
EnvironmentFile=/var/www/django-app/.env
ExecStart=/var/www/django-app/venv/bin/gunicorn \
          --workers 3 \
          --bind unix:/run/gunicorn.sock \
          PROJECT_NAME.wsgi:application
Restart=always

[Install]
WantedBy=multi-user.target
EOF
```

**⚠️ Replace `PROJECT_NAME` with your actual Django project name!**

### Start Services
```bash
systemctl daemon-reload
systemctl start gunicorn.socket
systemctl enable gunicorn.socket
systemctl status gunicorn.socket
```

## 🌐 **Step 5: Nginx Configuration**

### Create Nginx Site Config
```bash
cat > /etc/nginx/sites-available/django-app << 'EOF'
server {
    listen 80;
    server_name YOUR_DOMAIN.com www.YOUR_DOMAIN.com YOUR_VPS_IP;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    location / {
        include proxy_params;
        proxy_pass http://unix:/run/gunicorn.sock;
    }

    location /static/ {
        alias /var/www/django-app/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location /media/ {
        alias /var/www/django-app/media/;
        expires 1y;
        add_header Cache-Control "public";
    }

    # Block access to sensitive files
    location ~* /\.(?!well-known\/) {
        deny all;
    }

    location ~* /(requirements\.txt|\.env|deploy/|\.git/) {
        deny all;
    }
}
EOF
```

### Enable Site
```bash
ln -s /etc/nginx/sites-available/django-app /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx
```

## 🔒 **Step 6: Security & Firewall**

### Configure UFW Firewall
```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable
ufw status
```

## 🔐 **Step 7: SSL Certificate (Optional)**

### Install Certbot
```bash
apt install certbot python3-certbot-nginx -y
```

### Get SSL Certificate
```bash
certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

### Update Environment for HTTPS
```bash
# In /var/www/django-app/.env
SECURE_SSL_REDIRECT=True
```

## ✅ **Step 8: Verification**

### Test Application
```bash
curl -I http://YOUR_VPS_IP  # Should return 200 OK
```

### Check Services
```bash
systemctl status gunicorn.socket
systemctl status gunicorn.service  
systemctl status nginx
```

### View Logs
```bash
journalctl -u gunicorn.service -f  # Django logs
tail -f /var/log/nginx/error.log   # Nginx logs
```

## 🔄 **Deployment Updates**

### Update Code
```bash
sudo -u django bash -c "
cd /var/www/django-app
git pull origin main
source venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py collectstatic --noinput
"
systemctl restart gunicorn.service
```

## 🚨 **Common Issues & Solutions**

### Issue: 502 Bad Gateway
**Cause**: Gunicorn not running or socket issues
**Solution**: 
```bash
systemctl status gunicorn.service
systemctl restart gunicorn.socket
```

### Issue: Static files not loading
**Cause**: Nginx can't access staticfiles directory
**Solution**:
```bash
sudo -u django bash -c "cd /var/www/django-app && source venv/bin/activate && python manage.py collectstatic --noinput"
```

### Issue: Permission denied
**Cause**: Wrong file ownership
**Solution**:
```bash
chown -R django:www-data /var/www/django-app
```

### Issue: ModuleNotFoundError
**Cause**: Virtual environment not recreated after moving files
**Solution**:
```bash
sudo -u django bash -c "cd /var/www/django-app && rm -rf venv && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt"
```

## 📝 **Quick Commands Reference**

```bash
# Service management
systemctl restart gunicorn.service
systemctl restart nginx
systemctl status gunicorn.service

# View logs
journalctl -u gunicorn.service -f
tail -f /var/log/nginx/access.log

# Django management
sudo -u django bash -c "cd /var/www/django-app && source venv/bin/activate && python manage.py COMMAND"
```

## 🎯 **Key Differences from Our Initial Approach**

1. **User**: Use `django` user instead of `root`
2. **Location**: Use `/var/www/django-app` instead of `/root/django-demo` 
3. **Socket**: Use Unix socket instead of TCP
4. **Virtual Environment**: Always recreate in target location
5. **Systemd**: Use socket activation with proper service file
6. **Security**: Proper file permissions and firewall rules

This configuration is production-ready, secure, and follows Django best practices.