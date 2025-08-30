#!/bin/bash
"""
Multi-Project Webhook Router Setup Script
Sets up centralized webhook receiver for multiple Django projects
"""

set -e

echo "🔄 Setting up Multi-Project Webhook Router..."

# Configuration
WEBHOOK_SECRET=${1:-$(openssl rand -hex 32)}
SERVICE_USER="django"
WEBHOOK_PATH="/var/www/webhook-manager"
WEBHOOK_ROUTER_PATH="$WEBHOOK_PATH/webhook-router.py"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Create webhook manager directory
echo -e "${YELLOW}📦 Setting up webhook manager...${NC}"
mkdir -p "$WEBHOOK_PATH"

# Copy webhook router
cp "$(dirname "$0")/webhook-router.py" "$WEBHOOK_ROUTER_PATH"
chown -R django:www-data "$WEBHOOK_PATH"
chmod +x "$WEBHOOK_ROUTER_PATH"

# Install Flask if not present
echo -e "${YELLOW}📦 Installing Flask...${NC}"
sudo -u django bash -c "cd $WEBHOOK_PATH && python3 -m venv venv && source venv/bin/activate && pip install flask"

# Create webhook secret file
echo -e "${YELLOW}🔐 Setting up webhook secret...${NC}"
echo "WEBHOOK_SECRET=$WEBHOOK_SECRET" > "$WEBHOOK_PATH/.env"
chown django:www-data "$WEBHOOK_PATH/.env"
chmod 600 "$WEBHOOK_PATH/.env"

echo -e "${GREEN}🔑 Webhook Secret: $WEBHOOK_SECRET${NC}"
echo -e "${YELLOW}📝 Save this secret - you'll need it for GitHub webhook configuration!${NC}"

# Create systemd service file
echo -e "${YELLOW}⚙️  Creating systemd service...${NC}"
cat > /etc/systemd/system/django-webhook-router.service << EOF
[Unit]
Description=Django Multi-Project Webhook Router
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=www-data
WorkingDirectory=$WEBHOOK_PATH
Environment=PYTHONPATH=$WEBHOOK_PATH
EnvironmentFile=$WEBHOOK_PATH/.env
ExecStart=$WEBHOOK_PATH/venv/bin/python $WEBHOOK_ROUTER_PATH
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Create main nginx configuration with webhook routing
echo -e "${YELLOW}🌐 Configuring Nginx for multi-project...${NC}"
cat > /etc/nginx/sites-available/django-multi-projects << 'EOF'
server {
    listen 80 default_server;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Webhook endpoints (centralized)
    location /webhook {
        proxy_pass http://127.0.0.1:8001/webhook;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:8001/health;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Deployment status endpoint
    location /deploy-status {
        proxy_pass http://127.0.0.1:8001/status;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Root endpoint - show project list
    location = / {
        proxy_pass http://127.0.0.1:8001/health;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Include project-specific configurations
    include /etc/nginx/conf.d/projects/*.conf;
}
EOF

# Create directory for project-specific nginx configs
mkdir -p /etc/nginx/conf.d/projects/

# Disable default nginx site and enable multi-project
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/django-multi-projects /etc/nginx/sites-enabled/django-multi-projects

# Start and enable services
echo -e "${YELLOW}🚀 Starting services...${NC}"
systemctl daemon-reload
systemctl enable django-webhook-router.service
systemctl start django-webhook-router.service

# Test nginx and restart
nginx -t && systemctl restart nginx

# Check service status
if systemctl is-active --quiet django-webhook-router.service; then
    echo -e "${GREEN}✅ Multi-Project Webhook Router is running${NC}"
else
    echo -e "${RED}❌ Webhook router failed to start${NC}"
    echo "Check logs: journalctl -u django-webhook-router.service -f"
    exit 1
fi

echo -e "${GREEN}🎉 Multi-Project Webhook Setup Complete!${NC}"
echo
echo -e "${YELLOW}📋 Configuration:${NC}"
echo -e "1. 🔐 Webhook Secret: ${GREEN}$WEBHOOK_SECRET${NC}"
echo -e "2. 🌐 Webhook URL: ${GREEN}http://YOUR_VPS_IP/webhook${NC}"
echo -e "3. 📊 Status URL: ${GREEN}http://YOUR_VPS_IP/deploy-status${NC}"
echo -e "4. ❤️  Health Check: ${GREEN}http://YOUR_VPS_IP/health${NC}"
echo
echo -e "${YELLOW}📝 GitHub Webhook Setup:${NC}"
echo -e "- Go to each repository → Settings → Webhooks → Add webhook"
echo -e "- Payload URL: http://YOUR_VPS_IP/webhook"
echo -e "- Content type: application/json"
echo -e "- Secret: $WEBHOOK_SECRET"
echo -e "- Events: Just the push event"
echo
echo -e "${YELLOW}🚀 Deploy Projects:${NC}"
echo -e "sudo bash deploy/deploy-project.sh https://github.com/user/repo.git"
echo
echo -e "${YELLOW}🔍 Monitoring:${NC}"
echo -e "- Router logs: ${GREEN}journalctl -u django-webhook-router.service -f${NC}"
echo -e "- All projects: ${GREEN}http://YOUR_VPS_IP/deploy-status${NC}"
echo
echo -e "${GREEN}🎯 Your VPS now supports unlimited Django projects with auto-deploy!${NC}"