# Simple Django VPS Deployment

## 🎯 What This Is
A Django demo project that deploys to any VPS with one command.

## 🚀 Deploy to VPS

### After VPS Reset:
```bash
# 1. Fix SSH key
ssh-keygen -f '/home/amit/.ssh/known_hosts' -R '69.62.81.168'

# 2. Setup django user  
scp setup-django-user.sh akvps:/root/
ssh akvps "sudo bash /root/setup-django-user.sh"

# 3. Clone and deploy
ssh akvps "cd /home/django && git clone https://github.com/thecyberlearn/hostinger-django-demo.git"
ssh akvps "cd /home/django/hostinger-django-demo && echo -e 'https://github.com/thecyberlearn/hostinger-django-demo.git\n\n69.62.81.168' | sudo bash deploy/production-deploy.sh"
```

## 🔧 Update After Changes
```bash
# Push changes to GitHub first
git add . && git commit -m "update" && git push

# Then update VPS
ssh akvps "cd /var/www/django-app && sudo -u django git pull && sudo systemctl restart gunicorn nginx"
```

## 📱 Your Site
**URL**: http://69.62.81.168/

That's it! 🎉