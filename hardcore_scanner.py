import os
import sys
import random
import urllib.request
import socket
import ssl
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

# UI Colors
GREEN = '\033[0;32m'
RED = '\033[0;31'
YELLOW = '\033[1;33m'
CYAN = '\033[0;36m'
NC = '\033[0m'

os.system('clear')
print(f"{RED}======================================================{NC}")
print(f"{RED}     DEVIL CF SCANNER - PYTHON ULTRA RANGE MODE       {NC}")
print(f"{RED}======================================================{NC}")

RANGES_URL = "https://raw.githubusercontent.com/joknorea-del/cf-scanner/main/ranges.txt"
TARGET_DOM = "chatgpt.com"
RESULT_FILE = "devil_clean_ips.txt"

# Fetch ranges from GitHub
print(f"{CYAN}[*] Fetching ranges.txt from GitHub...{NC}")
try:
    with urllib.request.urlopen(RANGES_URL, timeout=10) as response:
        ranges = response.read().decode('utf-8').splitlines()
except Exception as e:
    print(f"{RED}[!] Error fetching ranges: {e}{NC}")
    sys.exit(1)

# Clean and filter ranges
clean_ranges = []
for r in ranges:
    r = r.strip()
    if not r:
        continue
    # Strip any masks or trailing dots
    r = r.replace(".0/24", "").replace("/24", "")
    if r.endswith('.'):
        r = r[:-1]
    clean_ranges.append(r)

# Shuffle the ranges randomly
random.shuffle(clean_ranges)

# Initialize result file
with open(RESULT_FILE, "w") as f:
    f.write("IP\t\tPing\n----------------------------------------\n")

def test_concrete_ip(ip):
    try:
        # Step 1: Fast TCP Port 443 check
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(2.5)
        start_time = time.time()
        sock.connect((ip, 443))
        
        # Step 2: HTTPS real handshake using the target domain
        context = ssl.create_default_context()
        # Bypass certificate verification because we connect via IP directly
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        
        ssl_sock = context.wrap_socket(sock, server_hostname=TARGET_DOM)
        end_time = time.time()
        
        ping_ms = int((end_time - start_time) * 1000)
        ssl_sock.close()
        
        # If it didn't throw an error, the IP is absolutely alive!
        print(f"{GREEN}[✔ LIVE IP] {ip} | Ping: {ping_ms}ms{NC}")
        with open(RESULT_FILE, "a") as f:
            f.write(f"{ip}\t{ping_ms}ms\n")
            
    except Exception:
        pass

# Main Loop over shuffled ranges
for current_range in clean_ranges:
    print(f"\n{CYAN}[*] Selected Random Range: {current_range}.0/24{NC}")
    print(f"{YELLOW}[+] Scanning 254 IPs with Python ThreadEngine ({TARGET_DOM})...{NC}")
    
    # Generate all 254 IPs for this range and shuffle them internally
    ips_to_scan = [f"{current_range}.{i}" for i in range(1, 255)]
    random.shuffle(ips_to_scan)
    
    # Use ThreadPoolExecutor for highly visible parallel processing
    with ThreadPoolExecutor(max_workers=30) as executor:
        executor.map(test_concrete_ip, ips_to_scan)
        
    print(f"{GREEN}[✔] Finished range {current_range}.0/24.{NC}")
    time.sleep(0.5)

print(f"\n{GREEN}[★] Scan finished! Results saved to {RESULT_FILE}{NC}")
