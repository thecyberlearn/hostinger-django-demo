# VPS Deployment Guide

## Prerequisites

Before starting, make sure you have:
- [ ] Ubuntu 20.04+ VPS with root/sudo access
- [ ] Your VPS IP address
- [ ] SSH key or password for VPS access
- [ ] Domain name (optional, can use IP address)

## Step 1: Prepare Local Files

Clean up your local project:
```bash
rm -rf venv/
rm -f db.sqlite3
rm -rf staticfiles/
rm -f requirements_full.txt
```

## Step 2: Upload to VPS

### Option A: Using SCP (if you have the files locally)
```bash
# Replace YOUR_VPS_IP with your actual IP
scp -r . root@YOUR_VPS_IP:/home/ubuntu/django-demo
```

### Option B: Using Git (recommended)
```bash
# On your VPS, clone the repository
ssh root@YOUR_VPS_IP
cd /home/ubuntu
git clone YOUR_REPO_URL django-demo
```

## Step 3: Run Deployment Script

SSH into your VPS and run:
```bash
ssh root@YOUR_VPS_IP
cd /home/ubuntu/django-demo
sudo bash deploy/deploy.sh
```

## Step 4: Configure Environment

Edit the `.env` file:
```bash
sudo nano /home/ubuntu/django-demo/.env
```

Set these values:
```env
SECRET_KEY=your-super-secret-key-here-make-it-long-and-random
DEBUG=False
ALLOWED_HOSTS=your-domain.com,www.your-domain.com,YOUR_VPS_IP
DATABASE_URL=postgresql://demo_user:your_password@localhost:5432/demo_db
SECURE_SSL_REDIRECT=False  # Set to True after SSL setup
```

## Step 5: Update Domain in Nginx

Edit nginx configuration:
```bash
sudo nano /etc/nginx/sites-available/django-demo
```

Replace `yourdomain.com` with your actual domain or IP.

## Step 6: Restart Services

```bash
sudo systemctl restart django-demo
sudo systemctl restart nginx
```

## Step 7: Test Deployment

Check if everything is working:
```bash
# Check service status
sudo systemctl status django-demo
sudo systemctl status nginx

# View logs if there are issues
sudo journalctl -u django-demo -f
```

Visit your website: `http://YOUR_VPS_IP` or `http://your-domain.com`

## Troubleshooting

### Common Issues:

1. **Service won't start**:
   ```bash
   sudo journalctl -u django-demo -f
   ```

2. **Static files not loading**:
   ```bash
   cd /home/ubuntu/django-demo
   source venv/bin/activate
   python manage.py collectstatic --noinput
   sudo systemctl restart django-demo
   ```

3. **Database errors**:
   - Check PostgreSQL is running: `sudo systemctl status postgresql`
   - Verify database settings in `.env`

4. **Permission errors**:
   ```bash
   sudo chown -R www-data:www-data /home/ubuntu/django-demo
   ```

## Optional: SSL Certificate (Let's Encrypt)

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

After SSL setup, update `.env`:
```env
SECURE_SSL_REDIRECT=True
```

## Management Commands

```bash
# Restart Django
sudo systemctl restart django-demo

# View logs
sudo journalctl -u django-demo -f

# Update application
sudo bash /home/ubuntu/django-demo/deploy/update.sh

# Access Django shell
cd /home/ubuntu/django-demo
source venv/bin/activate
python manage.py shell
```