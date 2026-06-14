#!/usr/bin/env bash
#
# Deploy the OpenAI-Compatible Embedding Service onto a fresh Linux server.
# Mirrors the production setup on 192.168.2.5 (host "phoebus").
#
# Usage:
#   EMBED_API_KEY="your-secret-key" ./deploy.sh
#
# Optional env:
#   APP_DIR     install location   (default: /var/www/embedding-service)
#   RUN_USER    service user        (default: current user)
#   GPU=1       install CUDA torch instead of CPU build
#
set -euo pipefail

APP_DIR="${APP_DIR:-/var/www/embedding-service}"
RUN_USER="${RUN_USER:-$(whoami)}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "${EMBED_API_KEY:-}" ]; then
  echo "ERROR: set EMBED_API_KEY before running, e.g.  EMBED_API_KEY=secret ./deploy.sh" >&2
  exit 1
fi

echo ">> Creating $APP_DIR"
sudo mkdir -p "$APP_DIR"
sudo chown "$RUN_USER":"$RUN_USER" "$APP_DIR"

echo ">> Copying app.py + requirements.txt"
cp "$SCRIPT_DIR/app.py" "$APP_DIR/"
cp "$SCRIPT_DIR/requirements.txt" "$APP_DIR/"

echo ">> Building venv"
python3 -m venv "$APP_DIR/venv"
"$APP_DIR/venv/bin/pip" install --upgrade pip

echo ">> Installing torch"
if [ "${GPU:-0}" = "1" ]; then
  "$APP_DIR/venv/bin/pip" install torch==2.10.0 --index-url https://download.pytorch.org/whl/cu124
else
  "$APP_DIR/venv/bin/pip" install torch==2.10.0+cpu --index-url https://download.pytorch.org/whl/cpu
fi

echo ">> Installing remaining deps"
"$APP_DIR/venv/bin/pip" install -r "$APP_DIR/requirements.txt"

echo ">> Installing systemd unit"
sudo tee /etc/systemd/system/embedding.service >/dev/null <<UNIT
[Unit]
Description=Phoebus Embedding Service
After=network.target

[Service]
User=$RUN_USER
WorkingDirectory=$APP_DIR
Environment=EMBED_API_KEY=$EMBED_API_KEY
ExecStart=$APP_DIR/venv/bin/python -m uvicorn app:app --host 0.0.0.0 --port 8000 --workers 1
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT

echo ">> Starting service (first start downloads the model ~1GB)"
sudo systemctl daemon-reload
sudo systemctl enable --now embedding.service

echo ">> Done. Test with:"
echo "   curl -X POST http://localhost:8000/embeddings -H 'Content-Type: application/json' -H 'X-API-Key: $EMBED_API_KEY' -d '{\"input\":\"hello\"}'"
