#!/bin/bash
# Setup django user and SSH access after VPS reset
# Run this FIRST after VPS reset before uploading projects

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🔧 Setting up django user and SSH access...${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Please run this script as root (use sudo)${NC}"
    exit 1
fi

# Create django user if doesn't exist
if ! id "django" &>/dev/null; then
    echo -e "${YELLOW}👤 Creating django user...${NC}"
    adduser django --disabled-password --gecos ''
    usermod -aG sudo django
    echo -e "${GREEN}✅ Django user created${NC}"
else
    echo -e "${GREEN}✅ Django user already exists${NC}"
fi

# Setup SSH access for django user
echo -e "${YELLOW}🔑 Setting up SSH access for django user...${NC}"

# Create .ssh directory for django user
mkdir -p /home/django/.ssh
chmod 700 /home/django/.ssh

# Copy SSH keys from root if they exist
if [ -d "/root/.ssh" ] && [ -f "/root/.ssh/authorized_keys" ]; then
    cp /root/.ssh/authorized_keys /home/django/.ssh/
    echo -e "${GREEN}✅ SSH keys copied from root to django user${NC}"
else
    echo -e "${YELLOW}⚠️  No SSH keys found in /root/.ssh/${NC}"
    echo -e "${YELLOW}💡 You'll need to copy your public key to /home/django/.ssh/authorized_keys${NC}"
fi

# Set proper ownership and permissions
chown -R django:django /home/django/.ssh
chmod 600 /home/django/.ssh/authorized_keys 2>/dev/null || true

# Update SSH config to allow django user
echo -e "${YELLOW}🔧 Updating SSH configuration...${NC}"

# Ensure django user can sudo without password for specific commands
cat > /etc/sudoers.d/django-deploy << 'EOF'
# Django user deployment permissions
django ALL=(ALL) NOPASSWD: /bin/systemctl restart gunicorn*.service
django ALL=(ALL) NOPASSWD: /bin/systemctl start gunicorn*.service  
django ALL=(ALL) NOPASSWD: /bin/systemctl stop gunicorn*.service
django ALL=(ALL) NOPASSWD: /bin/systemctl enable gunicorn*.service
django ALL=(ALL) NOPASSWD: /bin/systemctl status gunicorn*.service
django ALL=(ALL) NOPASSWD: /bin/systemctl daemon-reload
django ALL=(ALL) NOPASSWD: /usr/sbin/nginx -t
django ALL=(ALL) NOPASSWD: /bin/systemctl restart nginx
django ALL=(ALL) NOPASSWD: /bin/systemctl reload nginx
EOF

echo -e "${GREEN}✅ Django user sudo permissions configured${NC}"

# Create project directory in django user home
mkdir -p /home/django
chown django:django /home/django

echo -e "${GREEN}🎉 Django user setup complete!${NC}"
echo
echo -e "${YELLOW}📝 Next steps:${NC}"
echo -e "1. Test SSH access: ${GREEN}ssh akvps 'sudo -u django whoami'${NC}"
echo -e "2. Upload project: ${GREEN}scp -r . akvps:/home/django/project-name${NC}"
echo -e "3. Deploy project: ${GREEN}cd /home/django/project-name && sudo bash deploy/...${NC}"
echo
echo -e "${YELLOW}💡 SSH alias for django user:${NC}"
echo -e "Add to ~/.ssh/config:"
echo -e "${GREEN}Host akvps-django${NC}"
echo -e "${GREEN}    HostName $(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_VPS_IP')${NC}"
echo -e "${GREEN}    User django${NC}"
echo -e "${GREEN}    IdentityFile ~/.ssh/id_rsa${NC}"