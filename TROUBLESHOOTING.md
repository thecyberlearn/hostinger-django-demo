# Django VPS Deployment Troubleshooting Guide

A comprehensive guide to diagnose and fix common issues during Django VPS deployment.

## 🔍 **Quick Diagnosis Commands**

Before diving into specific issues, run these commands to get an overview:

```bash
# Check all services status
systemctl status gunicorn.socket gunicorn.service nginx

# Test HTTP response
curl -I http://YOUR_VPS_IP

# Check disk space
df -h

# Check memory usage
free -m

# View recent logs
journalctl -u gunicorn.service -n 20
tail -20 /var/log/nginx/error.log
```

## 🚨 **Common Issues & Solutions**

### **Issue 1: 502 Bad Gateway**

**Symptoms:**
- Nginx returns 502 Bad Gateway
- Website is unreachable

**Diagnosis:**
```bash
systemctl status gunicorn.service
curl http://unix:/run/gunicorn.sock  # Test socket directly
```

**Common Causes & Solutions:**

#### 1.1 Gunicorn Service Not Running
```bash
# Check status
systemctl status gunicorn.service

# If failed, check logs
journalctl -u gunicorn.service -n 50

# Restart service
systemctl restart gunicorn.socket
systemctl restart gunicorn.service
```

#### 1.2 Socket Permission Issues
```bash
# Check socket permissions
ls -la /run/gunicorn.sock

# Fix permissions if needed
sudo chown django:www-data /run/gunicorn.sock
```

#### 1.3 Virtual Environment Issues
```bash
# Recreate virtual environment
sudo -u django bash -c "
cd /var/www/django-app
rm -rf venv
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
"
systemctl restart gunicorn.service
```

---

### **Issue 2: 500 Internal Server Error**

**Symptoms:**
- Django returns 500 error
- HTTP 500 in curl response

**Diagnosis:**
```bash
# Check Django logs
journalctl -u gunicorn.service -f

# Check Django settings
sudo -u django bash -c "cd /var/www/django-app && source venv/bin/activate && python manage.py check --deploy"
```

**Common Causes & Solutions:**

#### 2.1 ModuleNotFoundError
**Error:** `No module named 'your_project.urls'`

**Solution:**
```bash
# Check project structure
ls -la /var/www/django-app/

# Ensure DJANGO_SETTINGS_MODULE is correct in systemd service
grep DJANGO_SETTINGS_MODULE /etc/systemd/system/gunicorn.service

# Update if wrong project name
sed -i 's/demo_project/YOUR_ACTUAL_PROJECT_NAME/g' /etc/systemd/system/gunicorn.service
systemctl daemon-reload
systemctl restart gunicorn.service
```

#### 2.2 Database Connection Issues
**Solution:**
```bash
# Test database connection
sudo -u django bash -c "cd /var/www/django-app && source venv/bin/activate && python manage.py dbshell"

# Check .env file
cat /var/www/django-app/.env

# Run migrations if needed
sudo -u django bash -c "cd /var/www/django-app && source venv/bin/activate && python manage.py migrate"
```

#### 2.3 Missing Static Files
**Solution:**
```bash
# Collect static files
sudo -u django bash -c "cd /var/www/django-app && source venv/bin/activate && python manage.py collectstatic --noinput"

# Check static files directory
ls -la /var/www/django-app/staticfiles/
```

---

### **Issue 3: Static Files Not Loading (CSS/JS Missing)**

**Symptoms:**
- Website loads but no styling
- 404 errors for CSS/JS files

**Diagnosis:**
```bash
# Check nginx config
nginx -t
cat /etc/nginx/sites-enabled/django-app

# Test static file access
curl -I http://YOUR_VPS_IP/static/admin/css/base.css
```

**Solutions:**
```bash
# 1. Collect static files
sudo -u django bash -c "cd /var/www/django-app && source venv/bin/activate && python manage.py collectstatic --noinput"

# 2. Check nginx static files configuration
grep -A 5 "location /static/" /etc/nginx/sites-enabled/django-app

# 3. Fix permissions
chown -R django:www-data /var/www/django-app/staticfiles/
chmod -R 755 /var/www/django-app/staticfiles/

# 4. Restart nginx
systemctl restart nginx
```

---

### **Issue 4: Permission Denied Errors**

**Symptoms:**
- Various permission denied errors in logs
- Services failing to start

**Solutions:**
```bash
# Fix project ownership
chown -R django:www-data /var/www/django-app

# Fix socket permissions
chown django:www-data /run/gunicorn.sock

# Fix log directory permissions
mkdir -p /var/log/django
chown -R django:www-data /var/log/django

# Restart services
systemctl restart gunicorn.service
```

---

### **Issue 5: Firewall Blocking Connections**

**Symptoms:**
- Connection timeout from external IPs
- Works locally but not from internet

**Diagnosis:**
```bash
# Check firewall status
ufw status

# Test local connection
curl -I http://127.0.0.1
```

**Solutions:**
```bash
# Allow HTTP and HTTPS
ufw allow 'Nginx Full'
ufw allow 80
ufw allow 443

# Reload firewall
ufw reload

# Check status
ufw status
```

---

### **Issue 6: SSL/HTTPS Issues**

**Symptoms:**
- SSL certificate errors
- HTTPS redirects not working

**Solutions:**
```bash
# Check SSL certificate
certbot certificates

# Renew certificate
certbot renew

# Test nginx config
nginx -t

# Check SSL-related settings in .env
grep SECURE_SSL_REDIRECT /var/www/django-app/.env
```

---

## 🔧 **Advanced Debugging**

### **Check System Resources**
```bash
# Check disk space
df -h

# Check memory usage
free -m
htop

# Check CPU usage
top

# Check open files
lsof | grep django
```

### **Network Debugging**
```bash
# Check listening ports
ss -tulpn | grep :80
ss -tulpn | grep :443
ss -tulpn | grep gunicorn

# Check network connections
netstat -tlnp

# Test DNS resolution
nslookup YOUR_DOMAIN
```

### **Log Analysis**
```bash
# Real-time Django logs
journalctl -u gunicorn.service -f

# Real-time Nginx logs
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# Search for specific errors
journalctl -u gunicorn.service | grep ERROR
grep "500" /var/log/nginx/access.log
```

## 📊 **Health Check Script**

Create this script to quickly check your deployment health:

```bash
#!/bin/bash
# Save as health-check.sh

echo "🏥 Django Deployment Health Check"
echo "================================"

# Service status
echo "📊 Service Status:"
systemctl is-active gunicorn.socket && echo "✅ Gunicorn Socket: Active" || echo "❌ Gunicorn Socket: Inactive"
systemctl is-active gunicorn.service && echo "✅ Gunicorn Service: Active" || echo "❌ Gunicorn Service: Inactive"  
systemctl is-active nginx && echo "✅ Nginx: Active" || echo "❌ Nginx: Inactive"

# HTTP test
echo -e "\n🌐 HTTP Response:"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ HTTP Response: $HTTP_CODE (OK)"
else
    echo "❌ HTTP Response: $HTTP_CODE"
fi

# Disk space
echo -e "\n💾 Disk Usage:"
df -h | grep -E "/$|/var"

# Memory usage  
echo -e "\n🧠 Memory Usage:"
free -m | grep Mem

# Recent errors
echo -e "\n🚨 Recent Errors (last 10 lines):"
journalctl -u gunicorn.service -n 10 --no-pager | grep -i error || echo "No recent errors found"

echo -e "\n✅ Health check complete!"
```

## 🆘 **Emergency Recovery**

If everything is broken, try this recovery sequence:

```bash
# 1. Stop all services
systemctl stop gunicorn.service nginx

# 2. Check project files
ls -la /var/www/django-app/

# 3. Recreate virtual environment
sudo -u django bash -c "cd /var/www/django-app && rm -rf venv && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt"

# 4. Run Django checks
sudo -u django bash -c "cd /var/www/django-app && source venv/bin/activate && python manage.py check"

# 5. Collect static files
sudo -u django bash -c "cd /var/www/django-app && source venv/bin/activate && python manage.py collectstatic --noinput"

# 6. Fix permissions
chown -R django:www-data /var/www/django-app

# 7. Restart services
systemctl daemon-reload
systemctl start gunicorn.socket nginx

# 8. Test
curl -I http://localhost
```

## 📞 **Getting Help**

If you're still stuck:

1. **Collect information:**
   ```bash
   # System info
   uname -a
   lsb_release -a
   
   # Service status
   systemctl status gunicorn.service nginx
   
   # Recent logs
   journalctl -u gunicorn.service -n 50
   tail -50 /var/log/nginx/error.log
   ```

2. **Check Django docs:** https://docs.djangoproject.com/en/stable/howto/deployment/
3. **Check Gunicorn docs:** https://docs.gunicorn.org/
4. **Check Nginx docs:** https://nginx.org/en/docs/

Remember: Most deployment issues are caused by:
- File permissions
- Incorrect paths  
- Missing dependencies
- Configuration typos
- Firewall rules

Take it step by step and check each component individually!