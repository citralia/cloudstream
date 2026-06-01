#!/bin/bash
# CloudStream Backend — VPS Deploy Script
# Run on VPS: ssh ubuntu@100.112.53.35
# Usage: ./deploy.sh

set -e

echo "=== CloudStream Backend Deploy ==="

# Config — edit these before running
APP_DIR="/opt/cloudstream-backend"
PORT=8000
ENV_FILE="$APP_DIR/.env"

# Create app directory
ssh ubuntu@100.112.53.35 "mkdir -p $APP_DIR/data"

# Copy files (run from local machine)
echo "Copying backend files to VPS..."
scp -r backend/* ubuntu@100.112.53.35:$APP_DIR/

# Create .env file on VPS
ssh ubuntu@100.112.53.35 "cat > $ENV_FILE << 'EOF'
XTREAM_BASE_URL=http://YOUR_XTREAM_SERVER:PORT
XTREAM_USERNAME=your_username
XTREAM_PASSWORD=your_password
DATABASE_URL=$APP_DIR/data/cloudstream.db
PORT=$PORT
CORS_ORIGINS=*
DEBUG=false
EOF"

# Pull latest via git on VPS
ssh ubuntu@100.112.53.35 "cd $APP_DIR && git pull origin main"

# Build and start with docker
ssh ubuntu@100.112.53.35 "cd $APP_DIR && docker build -t cloudstream-api ."
ssh ubuntu@100.112.53.35 "cd $APP_DIR && docker stop cloudstream-api 2>/dev/null || true"
ssh ubuntu@100.112.53.35 "cd $APP_DIR && docker run -d \
  --name cloudstream-api \
  --restart unless-stopped \
  -p $PORT:8000 \
  --env-file $ENV_FILE \
  -v $APP_DIR/data:/app/data \
  cloudstream-api"

# Verify
sleep 3
echo ""
echo "=== Health Check ==="
curl -s http://localhost:$PORT/health | python3 -m json.tool

echo ""
echo "=== Done ==="
echo "API running at: http://100.112.53.35:$PORT"
echo "Docs at: http://100.112.53.35:$PORT/docs"
