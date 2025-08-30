#!/bin/bash
"""
Auto-Deployment Service Setup Script
Sets up the webhook receiver as a systemd service
"""

set -e

echo "🔄 Setting up Auto-Deployment Service..."

# Configuration
WEBHOOK_SECRET=${1:-$(openssl rand -hex 32)}
SERVICE_USER="django"
APP_PATH="/var/www/django-app"
WEBHOOK_PATH="$APP_PATH/deploy/webhook-receiver.py"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Install Flask if not present
echo -e "${YELLOW}📦 Installing Flask...${NC}"
sudo -u django bash -c "cd $APP_PATH && source venv/bin/activate && pip install flask"

# Create webhook secret file
echo -e "${YELLOW}🔐 Setting up webhook secret...${NC}"
echo "WEBHOOK_SECRET=$WEBHOOK_SECRET" > /var/www/django-app/.env.webhook
chown django:www-data /var/www/django-app/.env.webhook
chmod 600 /var/www/django-app/.env.webhook

echo -e "${GREEN}🔑 Webhook Secret: $WEBHOOK_SECRET${NC}"
echo -e "${YELLOW}📝 Save this secret - you'll need it for GitHub webhook configuration!${NC}"

# Create systemd service file
echo -e "${YELLOW}⚙️  Creating systemd service...${NC}"
cat > /etc/systemd/system/django-webhook.service << EOF
[Unit]
Description=Django Auto-Deployment Webhook Receiver
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
Group=www-data
WorkingDirectory=$APP_PATH
Environment=PYTHONPATH=$APP_PATH
EnvironmentFile=$APP_PATH/.env.webhook
ExecStart=$APP_PATH/venv/bin/python $WEBHOOK_PATH
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Create nginx configuration for webhook
echo -e "${YELLOW}🌐 Configuring Nginx proxy...${NC}"
cat > /etc/nginx/sites-available/django-webhook << 'EOF'
server {
    listen 80;
    server_name webhook.YOUR_DOMAIN.com;  # Replace with your subdomain

    location /webhook {
        proxy_pass http://127.0.0.1:8001/webhook;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /health {
        proxy_pass http://127.0.0.1:8001/health;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /status {
        proxy_pass http://127.0.0.1:8001/status;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Optional: Add basic auth for status endpoint
        # auth_basic "Deployment Status";
        # auth_basic_user_file /etc/nginx/.htpasswd;
    }
}
EOF

# Enable webhook nginx site (optional - you might want to use main domain with /webhook path)
echo -e "${YELLOW}ℹ️  Webhook Nginx config created at /etc/nginx/sites-available/django-webhook${NC}"
echo -e "${YELLOW}ℹ️  You can enable it with: ln -s /etc/nginx/sites-available/django-webhook /etc/nginx/sites-enabled/${NC}"

# Or add webhook endpoint to existing site
echo -e "${YELLOW}🔧 Adding webhook endpoint to main site...${NC}"
MAIN_NGINX_CONFIG="/etc/nginx/sites-available/django-app"
if [ -f "$MAIN_NGINX_CONFIG" ]; then
    # Add webhook location block before the last closing brace
    sed -i '/^}/i\
    # GitHub Webhook endpoint\
    location /webhook {\
        proxy_pass http://127.0.0.1:8001/webhook;\
        proxy_set_header Host $host;\
        proxy_set_header X-Real-IP $remote_addr;\
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\
        proxy_set_header X-Forwarded-Proto $scheme;\
    }\
\
    # Deployment status endpoint\
    location /deploy-status {\
        proxy_pass http://127.0.0.1:8001/status;\
        proxy_set_header Host $host;\
        proxy_set_header X-Real-IP $remote_addr;\
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\
        proxy_set_header X-Forwarded-Proto $scheme;\
    }' "$MAIN_NGINX_CONFIG"
fi

# Make webhook receiver executable
chmod +x $WEBHOOK_PATH

# Start and enable services
echo -e "${YELLOW}🚀 Starting services...${NC}"
systemctl daemon-reload
systemctl enable django-webhook.service
systemctl start django-webhook.service

# Restart nginx
nginx -t && systemctl restart nginx

# Check service status
if systemctl is-active --quiet django-webhook.service; then
    echo -e "${GREEN}✅ Webhook service is running${NC}"
else
    echo -e "${RED}❌ Webhook service failed to start${NC}"
    echo "Check logs: journalctl -u django-webhook.service -f"
    exit 1
fi

echo -e "${GREEN}🎉 Auto-Deployment Setup Complete!${NC}"
echo
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo -e "1. 🔐 Webhook Secret: ${GREEN}$WEBHOOK_SECRET${NC}"
echo -e "2. 🌐 Webhook URL: ${GREEN}http://YOUR_VPS_IP/webhook${NC}"
echo -e "3. 📝 Go to GitHub → Settings → Webhooks → Add webhook"
echo -e "4. 🔧 Configure webhook:"
echo -e "   - Payload URL: http://YOUR_VPS_IP/webhook"
echo -e "   - Content type: application/json"
echo -e "   - Secret: $WEBHOOK_SECRET"
echo -e "   - Events: Just the push event"
echo
echo -e "${YELLOW}🔍 Monitoring:${NC}"
echo -e "- Service logs: ${GREEN}journalctl -u django-webhook.service -f${NC}"
echo -e "- Deployment status: ${GREEN}http://YOUR_VPS_IP/deploy-status${NC}"
echo -e "- Health check: ${GREEN}http://YOUR_VPS_IP/health${NC}"
echo
echo -e "${GREEN}🚀 Your VPS now works like Render - just push to GitHub!${NC}"