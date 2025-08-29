# Django VPS Quick Start Guide

🚀 **One-command deployment for Django on VPS!**

## ⚡ **Super Quick Start (5 minutes)**

1. **SSH into your VPS:**
   ```bash
   ssh root@YOUR_VPS_IP
   ```

2. **Run the automated deployment:**
   ```bash
   curl -sSL https://raw.githubusercontent.com/thecyberlearn/hostinger-django-demo/main/deploy/production-deploy.sh | sudo bash
   ```
   
3. **Follow the prompts:**
   - Enter your Git repository URL
   - Enter your domain name (optional)  
   - Enter your VPS IP address

4. **Done!** Your Django app will be live at `http://YOUR_VPS_IP`

## 📋 **Manual Quick Start (10 minutes)**

If you prefer step-by-step control:

### **Step 1: System Setup (2 minutes)**
```bash
# Update system
apt update && apt upgrade -y

# Install packages
apt install -y python3 python3-pip python3-venv python3-dev \
               nginx postgresql postgresql-contrib libpq-dev \
               build-essential curl git ufw

# Create user
adduser django --disabled-password --gecos ''
usermod -aG sudo django
```

### **Step 2: Clone Project (1 minute)**
```bash
# Setup directory
mkdir -p /var/www && chown django:www-data /var/www

# Clone your project
sudo -u django bash -c "cd /var/www && git clone YOUR_REPO_URL django-app"
```

### **Step 3: Python Setup (2 minutes)**
```bash
sudo -u django bash -c "
cd /var/www/django-app
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
"
```

### **Step 4: Django Configuration (2 minutes)**
```bash
# Copy environment file
sudo -u django bash -c "cd /var/www/django-app && cp .env.example .env"

# Edit .env file with your settings
nano /var/www/django-app/.env

# Run Django setup
sudo -u django bash -c "
cd /var/www/django-app
source venv/bin/activate
python manage.py migrate
python manage.py collectstatic --noinput
"
```

### **Step 5: Services Setup (3 minutes)**
```bash
# Create Gunicorn socket
cat > /etc/systemd/system/gunicorn.socket << 'EOF'
[Unit]
Description=gunicorn socket

[Socket]
ListenStream=/run/gunicorn.sock

[Install]
WantedBy=sockets.target
EOF

# Create Gunicorn service (replace demo_project with your project name)
cat > /etc/systemd/system/gunicorn.service << 'EOF'
[Unit]
Description=Gunicorn daemon for Django app
Requires=gunicorn.socket
After=network.target

[Service]
User=django
Group=www-data
WorkingDirectory=/var/www/django-app
Environment=DJANGO_SETTINGS_MODULE=demo_project.settings
EnvironmentFile=/var/www/django-app/.env
ExecStart=/var/www/django-app/venv/bin/gunicorn \
          --workers 3 \
          --bind unix:/run/gunicorn.sock \
          demo_project.wsgi:application
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Start services
systemctl daemon-reload
systemctl start gunicorn.socket
systemctl enable gunicorn.socket

# Configure Nginx (replace YOUR_VPS_IP)
cat > /etc/nginx/sites-available/django-app << 'EOF'
server {
    listen 80;
    server_name YOUR_VPS_IP;

    location / {
        include proxy_params;
        proxy_pass http://unix:/run/gunicorn.sock;
    }

    location /static/ {
        alias /var/www/django-app/staticfiles/;
    }
}
EOF

# Enable Nginx
ln -sf /etc/nginx/sites-available/django-app /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

# Configure firewall
ufw allow ssh && ufw allow 'Nginx Full' && ufw --force enable
```

## ✅ **Verification**

Your Django app should now be live! Test with:
```bash
curl -I http://YOUR_VPS_IP
```

You should see `HTTP/1.1 200 OK`

## 🔧 **Post-Deployment**

1. **Create superuser:**
   ```bash
   sudo -u django bash -c "cd /var/www/django-app && source venv/bin/activate && python manage.py createsuperuser"
   ```

2. **Access admin:** `http://YOUR_VPS_IP/admin`

3. **Add SSL certificate (optional):**
   ```bash
   apt install certbot python3-certbot-nginx
   certbot --nginx -d yourdomain.com
   ```

## 🚨 **If Something Goes Wrong**

1. **Check service status:**
   ```bash
   systemctl status gunicorn.service nginx
   ```

2. **View logs:**
   ```bash
   journalctl -u gunicorn.service -f
   tail -f /var/log/nginx/error.log
   ```

3. **Common fixes:**
   ```bash
   # Restart services
   systemctl restart gunicorn.service nginx
   
   # Fix permissions
   chown -R django:www-data /var/www/django-app
   
   # Recreate virtual environment
   sudo -u django bash -c "cd /var/www/django-app && rm -rf venv && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt"
   ```

## 📚 **What's Different from Before**

Our **old problematic approach:**
- ❌ Used root user
- ❌ Wrong directory (`/root/django-demo`)  
- ❌ TCP socket instead of Unix socket
- ❌ Hardcoded paths in virtual environment

Our **new bulletproof approach:**
- ✅ Non-root `django` user
- ✅ Standard `/var/www/django-app` directory
- ✅ Unix socket for better performance
- ✅ Proper file permissions and security
- ✅ Follows Django deployment best practices

## 🎯 **Why This Works Better**

1. **Security:** Non-root user with minimal privileges
2. **Performance:** Unix sockets are faster than TCP
3. **Reliability:** Socket activation prevents startup issues  
4. **Maintainability:** Standard directory structure
5. **Scalability:** Proper systemd integration

This setup is **production-ready** and follows **Django best practices**!

---

**Need help?** Check `TROUBLESHOOTING.md` for detailed solutions to common issues.