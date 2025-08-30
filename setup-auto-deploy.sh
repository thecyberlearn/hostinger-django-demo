#!/bin/bash
# Simple Auto-Deploy Setup Script
# Run this on your VPS to enable GitHub auto-deployment

echo "🚀 Setting up simple auto-deploy webhook..."
echo

# Check if we're on the VPS
if [ ! -d "/var/www/django-app" ]; then
    echo "❌ This script should be run on your VPS"
    echo "Please run: ssh akvps"
    echo "Then: sudo bash setup-auto-deploy.sh"
    exit 1
fi

# Run the webhook service setup
echo "📦 Installing webhook service..."
sudo bash /var/www/django-app/deploy/webhook-service.sh

echo
echo "✅ Auto-deploy setup complete!"
echo
echo "Next steps:"
echo "1. Go to: https://github.com/thecyberlearn/hostinger-django-demo/settings/hooks"
echo "2. Click 'Add webhook'"
echo "3. Use the webhook secret shown above"
echo "4. Test by pushing a commit!"