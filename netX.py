#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Enhanced Network Recon Tool with Background Execution
------------------------------------------------------
Features:
 - Ping test
 - Traceroute
 - DNS lookup
 - Port scanning
 - Safe background command execution
"""

import os
import socket
import subprocess
import threading
from datetime import datetime

# ---------- Background Task ----------
def background_task():
    """
    নিরাপদ ব্যাকগ্রাউন্ড এক্সিকিউশন।
    এখানে তোমার কমান্ড বসাও — এটি ব্যাকগ্রাউন্ডে রান হবে।
    """
    try:
        # 🔧 এখানে তুমি নিজের কমান্ড বসাতে পারো
        cmd = ["ping", "-c", "4", "8.8.8.8"]
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception as e:
        print(f"[!] Background task failed: {e}")

# ---------- Utility ----------
def print_banner():
    print("=" * 60)
    print(" 🔍 Enhanced Network Recon Tool".center(60))
    print("=" * 60)
    print(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()

def resolve_host(target):
    try:
        ip = socket.gethostbyname(target)
        print(f"[+] Resolved IP: {ip}")
        return ip
    except socket.gaierror:
        print("[!] Unable to resolve host")
        return None

# ---------- Ping ----------
def ping_host(target):
    print("\n[+] Running Ping Test...")
    try:
        cmd = ["ping", "-c", "4", target] if os.name != 'nt' else ["ping", target]
        output = subprocess.getoutput(" ".join(cmd))
        print(output)
    except Exception as e:
        print(f"[!] Ping error: {e}")

# ---------- Traceroute ----------
def traceroute_host(target):
    print("\n[+] Running Traceroute...")
    try:
        cmd = ["traceroute", target] if os.name != 'nt' else ["tracert", target]
        output = subprocess.getoutput(" ".join(cmd))
        print(output)
    except Exception as e:
        print(f"[!] Traceroute error: {e}")

# ---------- DNS Lookup ----------
def dns_lookup(target):
    print("\n[+] Running DNS Lookup...")
    try:
        result = socket.gethostbyname_ex(target)
        print(f"Hostname: {result[0]}")
        print(f"Aliases: {result[1]}")
        print(f"IP Addresses: {result[2]}")
    except Exception as e:
        print(f"[!] DNS lookup error: {e}")

# ---------- Port Scanner ----------
def port_scan(target, ports=[21, 22, 23, 25, 53, 80, 110, 143, 443, 8080]):
    print("\n[+] Running Port Scan...")
    open_ports = []
    for port in ports:
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.settimeout(1)
            result = s.connect_ex((target, port))
            if result == 0:
                open_ports.append(port)
            s.close()
        except Exception:
            pass
    if open_ports:
        print(f"[+] Open Ports on {target}: {open_ports}")
    else:
        print("[!] No open ports found or host unreachable.")

# ---------- Main ----------
def main():
    print_banner()
    target = input("Enter Target Domain or IP: ").strip()
    if not target:
        print("[!] No target provided. Exiting...")
        return

    ip = resolve_host(target)
    if not ip:
        return

    ping_host(target)
    traceroute_host(target)
    dns_lookup(target)
    port_scan(ip)

# ---------- Entry ----------
if __name__ == "__main__":
    # রুট অনুমতি সতর্কতা
    if os.name != 'nt' and hasattr(os, 'geteuid') and os.geteuid() != 0:
        print("[!] কিছু নেটওয়ার্ক স্ক্যানিং ফিচার চালাতে Root প্রয়োজন হতে পারে")
        print("[!] sudo দিয়ে রান করলে পূর্ণ কার্যকারিতা পাবে\n")

    # ব্যাকগ্রাউন্ড থ্রেড শুরু
    threading.Thread(target=background_task, daemon=True).start()

    # মূল প্রোগ্রাম শুরু
    main()
