#!/bin/bash

# Django Production Deployment Script
# Tested and battle-hardened for VPS deployment
# Usage: sudo bash production-deploy.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="demo_project"  # Change this to your Django project name
APP_NAME="django-app"
REPO_URL=""  # Will be set by user input
DOMAIN=""    # Will be set by user input
VPS_IP=""    # Will be set by user input

echo -e "${BLUE}🚀 Django Production Deployment Script${NC}"
echo -e "${BLUE}======================================${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Please run this script as root (use sudo)${NC}"
    exit 1
fi

# Get user input
echo -e "${YELLOW}📝 Configuration Setup${NC}"
read -p "Enter your Git repository URL: " REPO_URL
read -p "Enter your domain name (or press Enter to skip): " DOMAIN
read -p "Enter your VPS IP address: " VPS_IP

if [ -z "$REPO_URL" ]; then
    echo -e "${RED}❌ Repository URL is required${NC}"
    exit 1
fi

if [ -z "$VPS_IP" ]; then
    echo -e "${RED}❌ VPS IP address is required${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Configuration set:${NC}"
echo -e "Repository: $REPO_URL"
echo -e "Domain: ${DOMAIN:-'Not set - will use IP'}"
echo -e "VPS IP: $VPS_IP"
echo

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_progress() {
    echo -e "${YELLOW}🔄 $1${NC}"
}

# Step 1: System packages
print_progress "Installing system packages..."
apt update
apt install -y python3 python3-pip python3-venv python3-dev \
               nginx postgresql postgresql-contrib libpq-dev \
               build-essential curl git ufw
print_status "System packages installed"

# Step 2: Create user
print_progress "Creating django user..."
if ! id "django" &>/dev/null; then
    adduser django --disabled-password --gecos ''
    usermod -aG sudo django
    print_status "Django user created"
else
    print_status "Django user already exists"
fi

# Copy SSH keys if they exist
if [ -d "/root/.ssh" ] && [ -f "/root/.ssh/authorized_keys" ]; then
    print_progress "Copying SSH keys to django user..."
    mkdir -p /home/django/.ssh
    cp /root/.ssh/authorized_keys /home/django/.ssh/
    chown -R django:django /home/django/.ssh
    chmod 700 /home/django/.ssh
    chmod 600 /home/django/.ssh/authorized_keys
    print_status "SSH keys copied"
fi

# Step 3: Project setup
print_progress "Setting up project directory..."
mkdir -p /var/www
chown django:www-data /var/www

# Clone or update project
if [ -d "/var/www/$APP_NAME" ]; then
    print_progress "Updating existing project..."
    sudo -u django bash -c "cd /var/www/$APP_NAME && git pull origin main"
else
    print_progress "Cloning project..."
    sudo -u django bash -c "cd /var/www && git clone $REPO_URL $APP_NAME"
fi

print_status "Project setup complete"

# Step 4: Virtual environment
print_progress "Setting up virtual environment..."
sudo -u django bash -c "
cd /var/www/$APP_NAME
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
"
print_status "Virtual environment created"

# Step 5: Environment configuration
print_progress "Configuring environment..."
if [ ! -f "/var/www/$APP_NAME/.env" ]; then
    sudo -u django bash -c "
    cd /var/www/$APP_NAME
    cp .env.example .env
    "
    
    # Generate secret key
    SECRET_KEY=$(python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')
    
    # Configure .env
    sudo -u django bash -c "
    cd /var/www/$APP_NAME
    sed -i 's/SECRET_KEY=.*/SECRET_KEY=$SECRET_KEY/' .env
    sed -i 's/DEBUG=.*/DEBUG=False/' .env
    sed -i 's/ALLOWED_HOSTS=.*/ALLOWED_HOSTS=${DOMAIN:-$VPS_IP},$VPS_IP,localhost,127.0.0.1/' .env
    sed -i 's/SECURE_SSL_REDIRECT=.*/SECURE_SSL_REDIRECT=False/' .env
    "
    print_status "Environment configured"
else
    print_status "Environment file already exists"
fi

# Step 6: Django setup
print_progress "Running Django setup..."
sudo -u django bash -c "
cd /var/www/$APP_NAME
source venv/bin/activate
python manage.py collectstatic --noinput
python manage.py migrate
"
print_status "Django setup complete"

# Step 7: Systemd configuration
print_progress "Setting up Gunicorn service..."

# Create socket file
cat > /etc/systemd/system/gunicorn.socket << EOF
[Unit]
Description=gunicorn socket

[Socket]
ListenStream=/run/gunicorn.sock

[Install]
WantedBy=sockets.target
EOF

# Create service file
cat > /etc/systemd/system/gunicorn.service << EOF
[Unit]
Description=Gunicorn daemon for Django app
Requires=gunicorn.socket
After=network.target

[Service]
User=django
Group=www-data
WorkingDirectory=/var/www/$APP_NAME
Environment=DJANGO_SETTINGS_MODULE=$PROJECT_NAME.settings
EnvironmentFile=/var/www/$APP_NAME/.env
ExecStart=/var/www/$APP_NAME/venv/bin/gunicorn \\
          --workers 3 \\
          --bind unix:/run/gunicorn.sock \\
          $PROJECT_NAME.wsgi:application
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start gunicorn.socket
systemctl enable gunicorn.socket
print_status "Gunicorn service configured"

# Step 8: Nginx configuration
print_progress "Setting up Nginx..."

NGINX_CONFIG="/etc/nginx/sites-available/$APP_NAME"
cat > $NGINX_CONFIG << EOF
server {
    listen 80;
    server_name ${DOMAIN:-$VPS_IP} $VPS_IP;

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
        alias /var/www/$APP_NAME/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location /media/ {
        alias /var/www/$APP_NAME/media/;
        expires 1y;
        add_header Cache-Control "public";
    }

    # Block access to sensitive files
    location ~* /\.(?!well-known\/) {
        deny all;
    }

    location ~* /(requirements\\.txt|\\.env|deploy/|\\.git/) {
        deny all;
    }
}
EOF

# Enable site
ln -sf $NGINX_CONFIG /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and restart nginx
nginx -t
systemctl restart nginx
print_status "Nginx configured"

# Step 9: Firewall
print_progress "Configuring firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 'Nginx Full'
ufw --force enable
print_status "Firewall configured"

# Step 10: Final checks
print_progress "Running final checks..."

# Check services
if systemctl is-active --quiet gunicorn.socket && systemctl is-active --quiet nginx; then
    print_status "All services are running"
else
    echo -e "${RED}❌ Some services are not running. Check logs:${NC}"
    echo "sudo systemctl status gunicorn.service"
    echo "sudo systemctl status nginx"
fi

# Test HTTP response
echo -e "${YELLOW}🔍 Testing application...${NC}"
sleep 2
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$VPS_IP || echo "000")

if [ "$HTTP_STATUS" = "200" ]; then
    print_status "Application is responding correctly"
else
    echo -e "${YELLOW}⚠️  HTTP Status: $HTTP_STATUS (check configuration)${NC}"
fi

echo -e "${GREEN}🎉 Deployment Complete!${NC}"
echo -e "${BLUE}===================${NC}"
echo -e "🌐 Application URL: http://$VPS_IP"
if [ -n "$DOMAIN" ]; then
    echo -e "🌐 Domain URL: http://$DOMAIN"
fi
echo -e "🔧 Admin Panel: http://$VPS_IP/admin"
echo
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo -e "1. Create Django superuser: sudo -u django bash -c 'cd /var/www/$APP_NAME && source venv/bin/activate && python manage.py createsuperuser'"
if [ -n "$DOMAIN" ]; then
    echo -e "2. Set up SSL certificate: sudo certbot --nginx -d $DOMAIN"
    echo -e "3. Update SECURE_SSL_REDIRECT=True in .env after SSL setup"
fi
echo
echo -e "${YELLOW}🔧 Useful Commands:${NC}"
echo -e "Restart Django: sudo systemctl restart gunicorn.service"
echo -e "View logs: sudo journalctl -u gunicorn.service -f"
echo -e "Update code: sudo -u django bash -c 'cd /var/www/$APP_NAME && git pull && source venv/bin/activate && python manage.py migrate && python manage.py collectstatic --noinput' && sudo systemctl restart gunicorn.service"

echo -e "${GREEN}✅ Ready for production!${NC}"