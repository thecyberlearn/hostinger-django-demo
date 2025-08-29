#!/bin/bash

# Django Demo Project Deployment Script
# Run this script on your VPS to deploy the application

set -e

echo "🚀 Starting Django Demo Project deployment..."

# Configuration
PROJECT_DIR="/home/ubuntu/django-demo"
SERVICE_NAME="django-demo"
NGINX_SITE="django-demo"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run this script as root (use sudo)${NC}"
    exit 1
fi

echo -e "${YELLOW}📦 Installing system packages...${NC}"
apt update
apt install -y python3 python3-venv python3-pip nginx postgresql postgresql-contrib

echo -e "${YELLOW}👤 Setting up project user and directories...${NC}"
# Create project directory
mkdir -p $PROJECT_DIR
mkdir -p /var/log/django
mkdir -p /var/run/gunicorn

# Set ownership
chown -R www-data:www-data /var/log/django
chown -R www-data:www-data /var/run/gunicorn

echo -e "${YELLOW}🐍 Setting up Python virtual environment...${NC}"
cd $PROJECT_DIR
python3 -m venv venv
source venv/bin/activate

echo -e "${YELLOW}📋 Installing Python packages...${NC}"
pip install --upgrade pip
pip install -r requirements.txt

echo -e "${YELLOW}⚙️  Configuring environment...${NC}"
if [ ! -f ".env" ]; then
    echo "Creating .env file from example..."
    cp .env.example .env
    echo -e "${RED}⚠️  IMPORTANT: Edit .env file with your production settings!${NC}"
    echo "   - Set a secure SECRET_KEY"
    echo "   - Set DEBUG=False"
    echo "   - Configure ALLOWED_HOSTS with your domain"
    echo "   - Configure database settings if using PostgreSQL"
fi

echo -e "${YELLOW}🗄️  Setting up database...${NC}"
python manage.py collectstatic --noinput
python manage.py migrate

echo -e "${YELLOW}👤 Creating Django superuser (optional)...${NC}"
echo "Would you like to create a superuser? (y/N)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    python manage.py createsuperuser
fi

echo -e "${YELLOW}🔧 Setting up systemd service...${NC}"
cp deploy/systemd.service /etc/systemd/system/${SERVICE_NAME}.service
systemctl daemon-reload
systemctl enable $SERVICE_NAME

echo -e "${YELLOW}🌐 Setting up Nginx...${NC}"
cp deploy/nginx.conf /etc/nginx/sites-available/$NGINX_SITE
ln -sf /etc/nginx/sites-available/$NGINX_SITE /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t

echo -e "${YELLOW}🔄 Starting services...${NC}"
systemctl restart $SERVICE_NAME
systemctl restart nginx

echo -e "${YELLOW}🔍 Checking service status...${NC}"
systemctl is-active --quiet $SERVICE_NAME && echo -e "${GREEN}✅ Django service is running${NC}" || echo -e "${RED}❌ Django service failed${NC}"
systemctl is-active --quiet nginx && echo -e "${GREEN}✅ Nginx is running${NC}" || echo -e "${RED}❌ Nginx failed${NC}"

echo -e "${GREEN}🎉 Deployment completed!${NC}"
echo ""
echo "Next steps:"
echo "1. Edit .env file with your production settings"
echo "2. Update domain name in nginx.conf"
echo "3. Set up SSL certificate (recommended: Let's Encrypt)"
echo "4. Configure firewall (ufw) to allow HTTP/HTTPS traffic"
echo ""
echo "Useful commands:"
echo "  - Restart Django: sudo systemctl restart $SERVICE_NAME"
echo "  - View logs: sudo journalctl -u $SERVICE_NAME -f"
echo "  - Restart Nginx: sudo systemctl restart nginx"
echo "  - Check status: sudo systemctl status $SERVICE_NAME"