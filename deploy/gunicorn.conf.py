"""Gunicorn configuration for production deployment"""

import multiprocessing
import os

# Server socket
bind = "127.0.0.1:8000"
backlog = 2048

# Worker processes
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "sync"
worker_connections = 1000
timeout = 30
keepalive = 2
max_requests = 1000
max_requests_jitter = 100

# Restart workers after this many requests, with up to max_requests_jitter additional requests
preload_app = True

# Logging
accesslog = "/var/log/django/access.log"
errorlog = "/var/log/django/error.log"
loglevel = "info"

# Process naming
proc_name = "django_demo_project"

# Server mechanics
daemon = False
pidfile = "/var/run/gunicorn/django_demo.pid"
user = "www-data"
group = "www-data"
tmp_upload_dir = None