# Hostinger VPS Deployment Commands

## VPS Details
- **IP**: 69.62.81.168
- **SSH**: ssh root@69.62.81.168
- **Provider**: Hostinger

## Step-by-Step Deployment

### 1. Connect to VPS
```bash
ssh root@69.62.81.168
```

### 2. Clone Repository
```bash
cd /home/ubuntu || cd /root
mkdir -p /home/ubuntu
cd /home/ubuntu
git clone https://github.com/YOUR_USERNAME/YOUR_REPO_NAME.git django-demo
cd django-demo
```

### 3. Run Deployment Script
```bash
sudo bash deploy/deploy.sh
```

### 4. Configure Environment
```bash
sudo nano .env
```

**Set these values:**
```env
SECRET_KEY=your-super-secret-key-change-this-to-something-long-and-random
DEBUG=False
ALLOWED_HOSTS=69.62.81.168,localhost,127.0.0.1
DATABASE_URL=postgresql://demo_user:your_secure_password@localhost:5432/demo_db
SECURE_SSL_REDIRECT=False
```

### 5. Update Nginx Configuration
```bash
sudo nano /etc/nginx/sites-available/django-demo
```

Replace `yourdomain.com` with `69.62.81.168` in the server_name line.

### 6. Restart Services
```bash
sudo systemctl restart django-demo
sudo systemctl restart nginx
```

### 7. Check Status
```bash
sudo systemctl status django-demo
sudo systemctl status nginx
```

### 8. Test Application
Visit: http://69.62.81.168

## Troubleshooting Commands

```bash
# View Django logs
sudo journalctl -u django-demo -f

# View Nginx logs
sudo tail -f /var/log/nginx/error.log

# Restart services
sudo systemctl restart django-demo nginx

# Check if ports are open
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :8000
```

## Creating Admin User
```bash
cd /home/ubuntu/django-demo
source venv/bin/activate
python manage.py createsuperuser
```

Access admin at: http://69.62.81.168/admin