#!/bin/bash
# Multi-Project Django Deployment Script
# Automatically extracts GitHub repo name for project naming
# Usage: sudo bash deploy-project.sh <GITHUB_REPO_URL>
# Example: sudo bash deploy-project.sh https://github.com/thecyberlearn/hostinger-django-demo.git

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Multi-Project Django Deployment Script${NC}"
echo -e "${BLUE}===========================================${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Please run this script as root (use sudo)${NC}"
    exit 1
fi

# Get repository URL from argument
REPO_URL="$1"

if [ -z "$REPO_URL" ]; then
    echo -e "${YELLOW}📝 Enter your GitHub repository URL:${NC}"
    read -p "Repository URL: " REPO_URL
fi

if [ -z "$REPO_URL" ]; then
    echo -e "${RED}❌ Repository URL is required${NC}"
    exit 1
fi

# Extract project name from GitHub URL
# Examples:
# https://github.com/user/project-name.git -> project-name
# https://github.com/user/project-name -> project-name
# git@github.com:user/project-name.git -> project-name
PROJECT_NAME=$(echo "$REPO_URL" | sed -E 's|.*/([^/]+)/?$|\1|' | sed 's|\.git$||')

if [ -z "$PROJECT_NAME" ]; then
    echo -e "${RED}❌ Could not extract project name from URL: $REPO_URL${NC}"
    exit 1
fi

# Configuration
VPS_IP=$(curl -s ifconfig.me 2>/dev/null || echo "YOUR_VPS_IP")
PROJECT_PATH="/var/www/$PROJECT_NAME"

echo -e "${GREEN}✅ Configuration:${NC}"
echo -e "Repository: $REPO_URL"
echo -e "Project Name: $PROJECT_NAME"
echo -e "Deploy Path: $PROJECT_PATH"
echo -e "VPS IP: $VPS_IP"
echo

# Confirmation
echo -e "${YELLOW}🤔 Continue with deployment? (y/n)${NC}"
read -p "Confirm: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}❌ Deployment cancelled${NC}"
    exit 0
fi

# Helper functions
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_progress() {
    echo -e "${YELLOW}🔄 $1${NC}"
}

# Step 1: Install system packages (only if first deployment)
if [ ! -f "/var/www/.system_setup_done" ]; then
    print_progress "Installing system packages (first time setup)..."
    apt update
    apt install -y python3 python3-pip python3-venv python3-dev \
                   nginx postgresql postgresql-contrib libpq-dev \
                   build-essential curl git ufw
    
    # Create django user if doesn't exist
    if ! id "django" &>/dev/null; then
        adduser django --disabled-password --gecos ''
        usermod -aG sudo django
        print_status "Django user created"
    fi
    
    # Copy SSH keys if they exist
    if [ -d "/root/.ssh" ] && [ -f "/root/.ssh/authorized_keys" ]; then
        mkdir -p /home/django/.ssh
        cp /root/.ssh/authorized_keys /home/django/.ssh/
        chown -R django:django /home/django/.ssh
        chmod 700 /home/django/.ssh
        chmod 600 /home/django/.ssh/authorized_keys
    fi
    
    # Create /var/www directory
    mkdir -p /var/www
    chown django:www-data /var/www
    
    # Mark system setup as done
    touch /var/www/.system_setup_done
    print_status "System setup complete"
else
    print_status "System already configured, skipping package installation"
fi

# Step 2: Clone or update project
print_progress "Setting up project: $PROJECT_NAME..."
if [ -d "$PROJECT_PATH" ]; then
    print_progress "Updating existing project..."
    sudo -u django bash -c "cd $PROJECT_PATH && git pull origin main"
    print_status "Project updated"
else
    print_progress "Cloning new project..."
    sudo -u django bash -c "cd /var/www && git clone $REPO_URL $PROJECT_NAME"
    print_status "Project cloned"
fi

# Step 3: Virtual environment
print_progress "Setting up virtual environment..."
sudo -u django bash -c "cd $PROJECT_PATH && python3 -m venv venv"
print_status "Virtual environment created"

# Step 4: Install dependencies
print_progress "Installing Python dependencies..."
sudo -u django bash -c "cd $PROJECT_PATH && source venv/bin/activate && pip install --upgrade pip && pip install -r requirements.txt"
print_status "Dependencies installed"

# Step 5: Django setup
print_progress "Setting up Django..."

# Create environment file if it doesn't exist
if [ ! -f "$PROJECT_PATH/.env" ]; then
    print_progress "Creating environment file..."
    SECRET_KEY=$(python3 -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())")
    cat > "$PROJECT_PATH/.env" << EOF
SECRET_KEY=$SECRET_KEY
DEBUG=False
ALLOWED_HOSTS=$VPS_IP,localhost,127.0.0.1
DATABASE_URL=
EOF
    chown django:django "$PROJECT_PATH/.env"
    chmod 600 "$PROJECT_PATH/.env"
    print_status "Environment file created"
fi

# Run Django management commands
sudo -u django bash -c "cd $PROJECT_PATH && source venv/bin/activate && python manage.py migrate"
sudo -u django bash -c "cd $PROJECT_PATH && source venv/bin/activate && python manage.py collectstatic --noinput"
print_status "Django setup complete"

# Step 6: Gunicorn configuration
print_progress "Setting up Gunicorn for $PROJECT_NAME..."

# Detect Django project directory name (the one with settings.py)
DJANGO_PROJECT_DIR=$(sudo -u django find "$PROJECT_PATH" -name "settings.py" -exec dirname {} \; | head -1)
DJANGO_PROJECT_NAME=$(basename "$DJANGO_PROJECT_DIR")

# Create Gunicorn configuration
mkdir -p "$PROJECT_PATH/deploy"
cat > "$PROJECT_PATH/deploy/gunicorn.conf.py" << EOF
# Gunicorn configuration for $PROJECT_NAME
bind = "unix:/run/gunicorn-$PROJECT_NAME.sock"
workers = 3
user = "django"
group = "www-data"
timeout = 30
keepalive = 2
max_requests = 1000
max_requests_jitter = 100
EOF

# Create systemd socket file
cat > "/etc/systemd/system/gunicorn-$PROJECT_NAME.socket" << EOF
[Unit]
Description=gunicorn socket for $PROJECT_NAME

[Socket]
ListenStream=/run/gunicorn-$PROJECT_NAME.sock

[Install]
WantedBy=sockets.target
EOF

# Create systemd service file
cat > "/etc/systemd/system/gunicorn-$PROJECT_NAME.service" << EOF
[Unit]
Description=gunicorn daemon for $PROJECT_NAME
Requires=gunicorn-$PROJECT_NAME.socket
After=network.target

[Service]
Type=notify
User=django
Group=www-data
RuntimeDirectory=gunicorn-$PROJECT_NAME
WorkingDirectory=$PROJECT_PATH
Environment=PYTHONPATH=$PROJECT_PATH
EnvironmentFile=$PROJECT_PATH/.env
ExecStart=$PROJECT_PATH/venv/bin/gunicorn \\
          --config $PROJECT_PATH/deploy/gunicorn.conf.py \\
          $DJANGO_PROJECT_NAME.wsgi:application
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

print_status "Gunicorn configuration created"

# Step 7: Nginx configuration
print_progress "Setting up Nginx for $PROJECT_NAME..."

# Create Nginx site configuration
cat > "/etc/nginx/sites-available/$PROJECT_NAME" << EOF
server {
    listen 80;
    server_name $VPS_IP;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # Root location for this project
    location /$PROJECT_NAME/ {
        include proxy_params;
        proxy_pass http://unix:/run/gunicorn-$PROJECT_NAME.sock/;
        
        # Remove the project name from the path when passing to Django
        rewrite ^/$PROJECT_NAME/(.*) /\$1 break;
    }
    
    # Static files for this project
    location /$PROJECT_NAME/static/ {
        alias $PROJECT_PATH/staticfiles/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Media files for this project  
    location /$PROJECT_NAME/media/ {
        alias $PROJECT_PATH/media/;
        expires 1y;
        add_header Cache-Control "public";
    }
}
EOF

# Enable the site
ln -sf "/etc/nginx/sites-available/$PROJECT_NAME" "/etc/nginx/sites-enabled/$PROJECT_NAME"
print_status "Nginx configuration created"

# Step 8: Start services
print_progress "Starting services for $PROJECT_NAME..."
systemctl daemon-reload
systemctl enable "gunicorn-$PROJECT_NAME.socket"
systemctl start "gunicorn-$PROJECT_NAME.socket"
systemctl enable "gunicorn-$PROJECT_NAME.service"

# Test nginx configuration
nginx -t
systemctl restart nginx

print_status "Services started"

# Step 9: Test deployment
print_progress "Testing deployment..."
sleep 3

if systemctl is-active --quiet "gunicorn-$PROJECT_NAME.service"; then
    print_status "✅ $PROJECT_NAME deployed successfully!"
    echo
    echo -e "${GREEN}🎉 Deployment Complete!${NC}"
    echo -e "${YELLOW}📋 Project Details:${NC}"
    echo -e "Project Name: $PROJECT_NAME"
    echo -e "Project Path: $PROJECT_PATH"
    echo -e "Project URL: http://$VPS_IP/$PROJECT_NAME/"
    echo -e "Static Files: http://$VPS_IP/$PROJECT_NAME/static/"
    echo
    echo -e "${YELLOW}🔧 Management Commands:${NC}"
    echo -e "Check status: systemctl status gunicorn-$PROJECT_NAME.service"
    echo -e "View logs: journalctl -u gunicorn-$PROJECT_NAME.service -f"
    echo -e "Restart: systemctl restart gunicorn-$PROJECT_NAME.service"
    echo
else
    echo -e "${RED}❌ Deployment failed for $PROJECT_NAME${NC}"
    echo "Check logs: journalctl -u gunicorn-$PROJECT_NAME.service -f"
    exit 1
fi