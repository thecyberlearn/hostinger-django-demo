# Django Demo Project

A production-ready Django application template optimized for VPS hosting deployment. This project serves as a foundation for testing VPS deployment workflows and can be used as a template for future Django projects.

## ✨ Features

- **Minimal Dependencies**: Clean, lightweight setup with only essential packages
- **Environment Configuration**: Production settings managed via environment variables
- **Database Flexible**: Works with SQLite for development and PostgreSQL for production
- **Static Files Handling**: Configured with WhiteNoise for efficient static file serving
- **Contact Form**: Functional contact form with email validation
- **Simple Blog System**: Basic blog functionality with admin interface
- **Bootstrap UI**: Responsive design using Bootstrap 5
- **Production Security**: Security headers, HTTPS support, and production optimizations
- **VPS Deployment**: Complete deployment scripts and configuration files

## 🛠 Tech Stack

- **Backend**: Django 4.2.7
- **Database**: SQLite (development) / PostgreSQL (production)
- **Web Server**: Gunicorn + Nginx
- **Frontend**: Bootstrap 5, Vanilla JavaScript
- **Static Files**: WhiteNoise
- **Configuration**: python-decouple

## 🚀 Quick Start (Development)

1. **Clone and setup**:
   ```bash
   git clone <repository-url>
   cd hostinger-django-demo
   python3 -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r requirements.txt
   ```

2. **Configure environment**:
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

3. **Initialize database**:
   ```bash
   python manage.py migrate
   python manage.py createsuperuser
   python manage.py collectstatic
   ```

4. **Run development server**:
   ```bash
   python manage.py runserver
   ```

5. **Access the application**:
   - Homepage: http://127.0.0.1:8000
   - Admin: http://127.0.0.1:8000/admin

## 🌐 VPS Deployment

### Prerequisites

- Ubuntu 20.04+ VPS
- Root or sudo access
- Domain name (optional, can use IP address)

### Automated Deployment

1. **Upload project files** to your VPS:
   ```bash
   scp -r . user@your-vps-ip:/home/ubuntu/django-demo
   ```

2. **Run deployment script**:
   ```bash
   cd /home/ubuntu/django-demo
   sudo bash deploy/deploy.sh
   ```

3. **Configure your settings**:
   - Edit `.env` file with production settings
   - Update domain in `deploy/nginx.conf`
   - Restart services: `sudo systemctl restart django-demo nginx`

### Manual Deployment Steps

If you prefer manual setup, follow these steps:

1. **Install system packages**:
   ```bash
   sudo apt update
   sudo apt install python3 python3-venv python3-pip nginx postgresql postgresql-contrib
   ```

2. **Setup project**:
   ```bash
   cd /home/ubuntu/django-demo
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

3. **Configure environment**:
   ```bash
   cp .env.example .env
   # Edit .env with production settings
   ```

4. **Setup database and static files**:
   ```bash
   python manage.py migrate
   python manage.py collectstatic --noinput
   python manage.py createsuperuser
   ```

5. **Configure services**:
   ```bash
   sudo cp deploy/systemd.service /etc/systemd/system/django-demo.service
   sudo cp deploy/nginx.conf /etc/nginx/sites-available/django-demo
   sudo ln -s /etc/nginx/sites-available/django-demo /etc/nginx/sites-enabled/
   sudo systemctl enable django-demo
   sudo systemctl start django-demo
   sudo systemctl restart nginx
   ```

## ⚙️ Configuration

### Environment Variables

Create a `.env` file based on `.env.example`:

```env
# Required
SECRET_KEY=your-super-secret-key-here
DEBUG=False
ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com

# Database (choose one method)
# Method 1: DATABASE_URL
DATABASE_URL=postgresql://username:password@hostname:port/database_name

# Method 2: Individual settings
USE_POSTGRES=True
DB_NAME=demo_db
DB_USER=demo_user
DB_PASSWORD=your_password
DB_HOST=localhost
DB_PORT=5432

# Security
SECURE_SSL_REDIRECT=True  # Set to True if using HTTPS
```

### Database Options

1. **SQLite (Development)**: Default, no additional setup required
2. **PostgreSQL (Production)**: Set `USE_POSTGRES=True` or provide `DATABASE_URL`

## 🔧 Management Commands

### Development
```bash
python manage.py runserver          # Start development server
python manage.py migrate           # Apply database migrations
python manage.py createsuperuser   # Create admin user
python manage.py collectstatic     # Collect static files
```

### Production
```bash
sudo systemctl restart django-demo # Restart Django service
sudo systemctl status django-demo  # Check service status
sudo journalctl -u django-demo -f  # View live logs
sudo bash deploy/update.sh         # Deploy updates
```

## 📁 Project Structure

```
django-demo/
├── core/                   # Main Django app
│   ├── templates/          # HTML templates
│   ├── static/            # CSS, JS files
│   ├── models.py          # Database models
│   ├── views.py           # View functions
│   ├── forms.py           # Django forms
│   └── admin.py           # Admin configuration
├── demo_project/          # Django project settings
│   ├── settings.py        # Main settings
│   ├── urls.py            # URL configuration
│   └── wsgi.py            # WSGI application
├── deploy/                # Deployment files
│   ├── deploy.sh          # Deployment script
│   ├── update.sh          # Update script
│   ├── gunicorn.conf.py   # Gunicorn configuration
│   ├── nginx.conf         # Nginx configuration
│   └── systemd.service    # Systemd service file
├── requirements.txt       # Python dependencies
├── .env.example          # Environment variables template
└── README.md             # This file
```

## 🔍 Troubleshooting

### Common Issues

1. **Static files not loading**:
   ```bash
   python manage.py collectstatic --noinput
   sudo systemctl restart django-demo
   ```

2. **Database connection errors**:
   - Check `.env` file database settings
   - Ensure PostgreSQL is running: `sudo systemctl status postgresql`

3. **Permission errors**:
   ```bash
   sudo chown -R www-data:www-data /home/ubuntu/django-demo
   ```

4. **Service not starting**:
   ```bash
   sudo journalctl -u django-demo -f  # Check logs
   sudo systemctl status django-demo   # Check status
   ```

### Log Files

- Django logs: `sudo journalctl -u django-demo -f`
- Nginx access: `/var/log/nginx/access.log`
- Nginx errors: `/var/log/nginx/error.log`
- Custom Django logs: `/var/log/django/`

## 🔒 Security Considerations

- Change `SECRET_KEY` in production
- Set `DEBUG=False` in production
- Use HTTPS in production (`SECURE_SSL_REDIRECT=True`)
- Regularly update dependencies
- Configure firewall (UFW) properly
- Use strong passwords for database users

## 🚀 Deployment Checklist

- [ ] Update `.env` with production settings
- [ ] Set `DEBUG=False`
- [ ] Configure proper `ALLOWED_HOSTS`
- [ ] Set strong `SECRET_KEY`
- [ ] Configure database settings
- [ ] Update domain in nginx configuration
- [ ] Set up SSL certificate (recommended)
- [ ] Configure firewall rules
- [ ] Test all functionality

## 📝 License

This project is open source and available under the MIT License.

## 🤝 Contributing

This is a demo project, but improvements are welcome! Please feel free to submit issues and pull requests.