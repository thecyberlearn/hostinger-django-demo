#!/bin/bash

# Django Demo Project Update Script
# Run this script to deploy updates to your running application

set -e

echo "🔄 Starting application update..."

# Configuration
PROJECT_DIR="/home/ubuntu/django-demo"
SERVICE_NAME="django-demo"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root (use sudo)"
    exit 1
fi

echo -e "${YELLOW}📁 Navigating to project directory...${NC}"
cd $PROJECT_DIR

echo -e "${YELLOW}🐍 Activating virtual environment...${NC}"
source venv/bin/activate

echo -e "${YELLOW}📦 Installing/updating dependencies...${NC}"
pip install -r requirements.txt

echo -e "${YELLOW}🗄️  Running database migrations...${NC}"
python manage.py migrate

echo -e "${YELLOW}📄 Collecting static files...${NC}"
python manage.py collectstatic --noinput

echo -e "${YELLOW}🔄 Restarting Django service...${NC}"
systemctl restart $SERVICE_NAME

echo -e "${YELLOW}🔍 Checking service status...${NC}"
if systemctl is-active --quiet $SERVICE_NAME; then
    echo -e "${GREEN}✅ Service is running successfully${NC}"
else
    echo "❌ Service failed to start. Check logs:"
    echo "sudo journalctl -u $SERVICE_NAME -f"
    exit 1
fi

echo -e "${GREEN}✅ Update completed successfully!${NC}"