#!/usr/bin/env python3
"""
Multi-Project GitHub Webhook Router
Routes webhook requests to appropriate Django projects based on repository name
Supports unlimited Django projects on single VPS
"""

import os
import sys
import json
import hmac
import hashlib
import subprocess
import logging
import glob
from datetime import datetime
from flask import Flask, request, jsonify
from threading import Thread
import time

# Configuration
WEBHOOK_SECRET = os.environ.get('WEBHOOK_SECRET', 'your-webhook-secret-here')
PROJECTS_BASE_PATH = '/var/www'
ALLOWED_BRANCHES = ['main', 'master']
LOG_FILE = '/var/log/django/webhook-router.log'

# Setup logging
os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
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

def discover_projects():
    """Discover all Django projects in /var/www"""
    projects = {}
    
    # Look for directories with manage.py (Django projects)
    for project_dir in glob.glob(f"{PROJECTS_BASE_PATH}/*/"):
        project_name = os.path.basename(project_dir.rstrip('/'))
        
        # Skip hidden directories and system files
        if project_name.startswith('.') or project_name == 'html':
            continue
            
        manage_py_path = os.path.join(project_dir, 'manage.py')
        if os.path.exists(manage_py_path):
            projects[project_name] = {
                'path': project_dir.rstrip('/'),
                'service': f'gunicorn-{project_name}.service'
            }
    
    logger.info(f"🔍 Discovered {len(projects)} Django projects: {list(projects.keys())}")
    return projects

def extract_repo_name_from_url(repo_url):
    """Extract repository name from GitHub URL"""
    # Examples:
    # https://github.com/user/project-name.git -> project-name
    # https://github.com/user/project-name -> project-name
    # git@github.com:user/project-name.git -> project-name
    
    import re
    # Remove .git suffix and extract last part
    repo_name = re.sub(r'\.git$', '', repo_url)
    repo_name = repo_name.split('/')[-1]
    return repo_name

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

def run_deployment(project_name, project_path, commit_info):
    """Execute deployment for specific project in background thread"""
    try:
        logger.info(f"🚀 Starting deployment for {project_name}...")
        
        # Change to project directory
        os.chdir(project_path)
        
        # Store current commit for rollback
        subprocess.run(['bash', '-c', f'echo "$(git rev-parse HEAD)" > /tmp/last_working_commit_{project_name}.txt'])
        
        # Run deployment script
        result = subprocess.run([
            'sudo', '-u', 'django', 'bash', '-c',
            f'''
            cd {project_path}
            
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
            # Restart project-specific service
            service_name = f'gunicorn-{project_name}.service'
            subprocess.run(['systemctl', 'restart', service_name], check=True)
            
            # Wait and check if service is running
            time.sleep(3)
            service_check = subprocess.run(['systemctl', 'is-active', service_name], 
                                         capture_output=True, text=True)
            
            if service_check.stdout.strip() == 'active':
                logger.info(f"✅ Deployment successful for {project_name}!")
                send_notification(f"✅ {project_name}: Deployment successful!", "success", commit_info)
            else:
                logger.error(f"❌ Service failed to start for {project_name}")
                rollback(project_name, project_path)
        else:
            logger.error(f"❌ Deployment failed for {project_name}: {result.stderr}")
            rollback(project_name, project_path)
            
    except subprocess.TimeoutExpired:
        logger.error(f"❌ Deployment timed out for {project_name}")
        rollback(project_name, project_path)
    except Exception as e:
        logger.error(f"❌ Deployment error for {project_name}: {str(e)}")
        rollback(project_name, project_path)

def rollback(project_name, project_path):
    """Rollback to previous working commit for specific project"""
    try:
        logger.info(f"🔄 Rolling back {project_name} to previous commit...")
        
        rollback_file = f'/tmp/last_working_commit_{project_name}.txt'
        if os.path.exists(rollback_file):
            with open(rollback_file, 'r') as f:
                last_commit = f.read().strip()
            
            subprocess.run([
                'sudo', '-u', 'django', 'bash', '-c',
                f'cd {project_path} && git reset --hard {last_commit}'
            ], check=True)
            
            service_name = f'gunicorn-{project_name}.service'
            subprocess.run(['systemctl', 'restart', service_name], check=True)
            logger.info(f"✅ Rollback completed for {project_name}")
            send_notification(f"🔄 {project_name}: Rolled back due to deployment failure", "warning", {})
        else:
            logger.error(f"❌ No previous commit found for rollback: {project_name}")
            
    except Exception as e:
        logger.error(f"❌ Rollback failed for {project_name}: {str(e)}")

def send_notification(message, status="info", commit_info={}):
    """Send deployment notification"""
    logger.info(f"📢 Notification: {message}")
    
    # You can extend this to send notifications to:
    # - Slack webhook
    # - Discord webhook  
    # - Email
    # - SMS

@app.route('/webhook/<project_name>', methods=['POST'])
def handle_project_webhook(project_name):
    """Handle GitHub webhook for specific project"""
    
    # Verify signature
    signature = request.headers.get('X-Hub-Signature-256')
    if not verify_signature(request.data, signature):
        logger.warning(f"❌ Invalid webhook signature for {project_name}")
        return jsonify({"error": "Invalid signature"}), 403
    
    # Parse payload
    try:
        payload = request.json
    except:
        logger.warning(f"❌ Invalid JSON payload for {project_name}")
        return jsonify({"error": "Invalid JSON"}), 400
    
    # Check if it's a push event
    if request.headers.get('X-GitHub-Event') != 'push':
        logger.info(f"ℹ️  Ignoring non-push event for {project_name}: {request.headers.get('X-GitHub-Event')}")
        return jsonify({"message": "Not a push event"}), 200
    
    # Extract branch name
    ref = payload.get('ref', '')
    branch = ref.replace('refs/heads/', '')
    
    # Check if it's a branch we care about
    if branch not in ALLOWED_BRANCHES:
        logger.info(f"ℹ️  Ignoring push to branch {branch} for {project_name}")
        return jsonify({"message": f"Ignoring branch {branch}"}), 200
    
    # Discover current projects
    projects = discover_projects()
    
    # Check if project exists
    if project_name not in projects:
        logger.warning(f"❌ Project not found: {project_name}")
        return jsonify({"error": f"Project {project_name} not found"}), 404
    
    # Get project details
    project_path = projects[project_name]['path']
    
    # Extract commit information
    commit_hash = payload.get('after', 'unknown')
    commit_message = ""
    if payload.get('head_commit'):
        commit_message = payload['head_commit'].get('message', '')
    
    commit_info = {
        'hash': commit_hash[:8],
        'message': commit_message[:100],
        'branch': branch
    }
    
    logger.info(f"🔔 Deployment triggered for {project_name}")
    logger.info(f"📝 Branch: {branch}, Commit: {commit_hash[:8]} - {commit_message[:100]}")
    
    # Start deployment in background thread
    deployment_thread = Thread(target=run_deployment, args=(project_name, project_path, commit_info))
    deployment_thread.start()
    
    return jsonify({
        "message": "Deployment started", 
        "project": project_name,
        "branch": branch,
        "commit": commit_hash[:8]
    }), 200

@app.route('/webhook', methods=['POST'])
def handle_generic_webhook():
    """Handle generic webhook - try to determine project from repository URL"""
    
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
    
    # Extract repository URL
    repo_url = payload.get('repository', {}).get('clone_url', '')
    if not repo_url:
        repo_url = payload.get('repository', {}).get('html_url', '')
    
    if not repo_url:
        logger.warning("❌ No repository URL found in payload")
        return jsonify({"error": "No repository URL found"}), 400
    
    # Extract project name from repo URL
    project_name = extract_repo_name_from_url(repo_url)
    logger.info(f"🔍 Extracted project name: {project_name} from URL: {repo_url}")
    
    # Redirect to project-specific webhook handler
    return handle_project_webhook(project_name)

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    projects = discover_projects()
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "projects_count": len(projects),
        "projects": list(projects.keys())
    })

@app.route('/status', methods=['GET'])
def deployment_status():
    """Get current deployment status for all projects"""
    try:
        projects = discover_projects()
        status_data = {
            "timestamp": datetime.now().isoformat(),
            "projects": {}
        }
        
        for project_name, project_info in projects.items():
            # Check service status
            service_name = project_info['service']
            service_check = subprocess.run(['systemctl', 'is-active', service_name], 
                                         capture_output=True, text=True)
            
            # Get current commit
            try:
                os.chdir(project_info['path'])
                commit_result = subprocess.run(['git', 'rev-parse', 'HEAD'], 
                                             capture_output=True, text=True)
                current_commit = commit_result.stdout.strip()[:8] if commit_result.returncode == 0 else "unknown"
            except:
                current_commit = "unknown"
            
            status_data["projects"][project_name] = {
                "service_status": service_check.stdout.strip(),
                "current_commit": current_commit,
                "path": project_info['path'],
                "service": service_name
            }
        
        return jsonify(status_data)
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    # Create log directory if it doesn't exist
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    
    logger.info("🚀 Starting Multi-Project GitHub Webhook Router...")
    
    # Discover existing projects
    projects = discover_projects()
    logger.info(f"📁 Managing {len(projects)} Django projects")
    for name, info in projects.items():
        logger.info(f"  - {name}: {info['path']}")
    
    # Run Flask app
    app.run(host='127.0.0.1', port=8001, debug=False)