#!/usr/bin/env python3
"""
GitHub Webhook Receiver for Auto-Deployment
Listens for GitHub push events and triggers automatic deployment
"""

import os
import sys
import json
import hmac
import hashlib
import subprocess
import logging
from datetime import datetime
from flask import Flask, request, jsonify
from threading import Thread
import time

# Configuration
WEBHOOK_SECRET = os.environ.get('WEBHOOK_SECRET', 'your-webhook-secret-here')
REPO_PATH = '/var/www/django-app'
ALLOWED_BRANCHES = ['main', 'master']
LOG_FILE = '/var/log/django/webhook.log'

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

def verify_signature(payload_body, signature_header):
    """Verify GitHub webhook signature"""
    if not signature_header:
        return False
    
    hash_object = hmac.new(
        WEBHOOK_SECRET.encode('utf-8'),
        payload_body,
        hashlib.sha256
    )
    expected_signature = "sha256=" + hash_object.hexdigest()
    
    return hmac.compare_digest(expected_signature, signature_header)

def run_deployment():
    """Execute deployment in background thread"""
    try:
        logger.info("🚀 Starting deployment...")
        
        # Change to app directory
        os.chdir(REPO_PATH)
        
        # Run deployment script
        result = subprocess.run([
            'sudo', '-u', 'django', 'bash', '-c',
            f'''
            cd {REPO_PATH}
            
            # Store current commit for rollback
            echo "$(git rev-parse HEAD)" > /tmp/last_working_commit.txt
            
            # Pull latest changes
            git fetch origin
            git reset --hard origin/main
            
            # Activate virtual environment and update
            source venv/bin/activate
            
            # Install/update dependencies
            pip install -r requirements.txt
            
            # Run Django management commands
            python manage.py migrate
            python manage.py collectstatic --noinput
            
            # Test if Django can start (quick check)
            python manage.py check --deploy
            '''
        ], capture_output=True, text=True, timeout=300)
        
        if result.returncode == 0:
            # Restart services
            subprocess.run(['systemctl', 'restart', 'gunicorn.service'], check=True)
            
            # Wait a moment and check if service is running
            time.sleep(3)
            service_check = subprocess.run(['systemctl', 'is-active', 'gunicorn.service'], 
                                         capture_output=True, text=True)
            
            if service_check.stdout.strip() == 'active':
                logger.info("✅ Deployment successful!")
                
                # Send success notification (optional)
                send_notification("✅ Deployment successful!", "success")
                
            else:
                logger.error("❌ Service failed to start after deployment")
                rollback()
        else:
            logger.error(f"❌ Deployment failed: {result.stderr}")
            rollback()
            
    except subprocess.TimeoutExpired:
        logger.error("❌ Deployment timed out")
        rollback()
    except Exception as e:
        logger.error(f"❌ Deployment error: {str(e)}")
        rollback()

def rollback():
    """Rollback to previous working commit"""
    try:
        logger.info("🔄 Rolling back to previous commit...")
        
        if os.path.exists('/tmp/last_working_commit.txt'):
            with open('/tmp/last_working_commit.txt', 'r') as f:
                last_commit = f.read().strip()
            
            subprocess.run([
                'sudo', '-u', 'django', 'bash', '-c',
                f'cd {REPO_PATH} && git reset --hard {last_commit}'
            ], check=True)
            
            subprocess.run(['systemctl', 'restart', 'gunicorn.service'], check=True)
            logger.info("✅ Rollback completed")
            send_notification("🔄 Rolled back due to deployment failure", "warning")
        else:
            logger.error("❌ No previous commit found for rollback")
            
    except Exception as e:
        logger.error(f"❌ Rollback failed: {str(e)}")

def send_notification(message, status="info"):
    """Send deployment notification (extend this for Slack/Discord/Email)"""
    logger.info(f"📢 Notification: {message}")
    
    # You can extend this to send notifications to:
    # - Slack webhook
    # - Discord webhook  
    # - Email
    # - SMS
    
    # Example Slack notification (uncomment and configure):
    # import requests
    # slack_webhook = "YOUR_SLACK_WEBHOOK_URL"
    # requests.post(slack_webhook, json={"text": f"🚀 Django App: {message}"})

@app.route('/webhook', methods=['POST'])
def handle_webhook():
    """Handle GitHub webhook"""
    
    # Verify signature
    signature = request.headers.get('X-Hub-Signature-256')
    if not verify_signature(request.data, signature):
        logger.warning("❌ Invalid webhook signature")
        return jsonify({"error": "Invalid signature"}), 403
    
    # Parse payload
    try:
        payload = request.json
    except:
        logger.warning("❌ Invalid JSON payload")
        return jsonify({"error": "Invalid JSON"}), 400
    
    # Check if it's a push event
    if request.headers.get('X-GitHub-Event') != 'push':
        logger.info(f"ℹ️  Ignoring non-push event: {request.headers.get('X-GitHub-Event')}")
        return jsonify({"message": "Not a push event"}), 200
    
    # Extract branch name
    ref = payload.get('ref', '')
    branch = ref.replace('refs/heads/', '')
    
    # Check if it's a branch we care about
    if branch not in ALLOWED_BRANCHES:
        logger.info(f"ℹ️  Ignoring push to branch: {branch}")
        return jsonify({"message": f"Ignoring branch {branch}"}), 200
    
    # Log the deployment request
    commit_hash = payload.get('after', 'unknown')
    commit_message = ""
    if payload.get('head_commit'):
        commit_message = payload['head_commit'].get('message', '')
    
    logger.info(f"🔔 Deployment triggered by push to {branch}")
    logger.info(f"📝 Commit: {commit_hash[:8]} - {commit_message[:100]}")
    
    # Start deployment in background thread
    deployment_thread = Thread(target=run_deployment)
    deployment_thread.start()
    
    return jsonify({
        "message": "Deployment started", 
        "branch": branch,
        "commit": commit_hash[:8]
    }), 200

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "repo_path": REPO_PATH
    })

@app.route('/status', methods=['GET'])
def deployment_status():
    """Get current deployment status"""
    try:
        # Check if services are running
        gunicorn_status = subprocess.run(['systemctl', 'is-active', 'gunicorn.service'], 
                                       capture_output=True, text=True)
        nginx_status = subprocess.run(['systemctl', 'is-active', 'nginx'], 
                                    capture_output=True, text=True)
        
        # Get current commit
        os.chdir(REPO_PATH)
        commit_result = subprocess.run(['git', 'rev-parse', 'HEAD'], 
                                     capture_output=True, text=True)
        current_commit = commit_result.stdout.strip()[:8] if commit_result.returncode == 0 else "unknown"
        
        return jsonify({
            "gunicorn": gunicorn_status.stdout.strip(),
            "nginx": nginx_status.stdout.strip(), 
            "current_commit": current_commit,
            "timestamp": datetime.now().isoformat()
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    # Create log directory if it doesn't exist
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    
    logger.info("🚀 Starting GitHub webhook receiver...")
    logger.info(f"📁 Monitoring repository: {REPO_PATH}")
    logger.info(f"🌿 Allowed branches: {ALLOWED_BRANCHES}")
    
    # Run Flask app
    app.run(host='127.0.0.1', port=8001, debug=False)