#!/bin/bash

# UI Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${RED}======================================================${NC}"
echo -e "${RED}     DEVIL CF SCANNER - REAL LIVE TRACE MODE          ${NC}"
echo -e "${RED}======================================================${NC}"

# Target Domain from your successful scan
TARGET_DOM="chatgpt.com"

RANGES_URL="https://raw.githubusercontent.com/joknorea-del/cf-scanner/main/ranges.txt"
LOCAL_RANGES="ranges.txt"

echo -e "${CYAN}[*] Fetching ranges.txt from GitHub...${NC}"
curl -s -L "$RANGES_URL" -o "$LOCAL_RANGES"

if [ ! -s "$LOCAL_RANGES" ] || grep -q "404" "$LOCAL_RANGES"; then
    echo -e "${RED}[!] Error: Could not fetch ranges.txt from GitHub or file is empty!${NC}"
    exit 1
fi

RESULT_FILE="devil_clean_ips.txt"
echo -e "IP\t\tPing" > $RESULT_FILE
echo "----------------------------------------" >> $RESULT_FILE

# Core function exported for xargs usage
test_concrete_ip() {
    local ip=$1
    local target=$2
    
    # 🎯 LIGHTWEIGHT REAL WORLD TEST (Like your working scanner)
    # Check if port 443 responds within 3 seconds
    if ! nc -z -w 3 "$ip" 443 2>/dev/null; then
        return 1
    fi

    # Measure exact HTTPS Response Time using curl with the chosen Domain
    local start_time=$(date +%s%N)
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 4 \
        --resolve "$target:443:$ip" "https://$target")
    local end_time=$(date +%s%N)

    # If the IP returns any valid HTTP status code, it means the handshake succeeded!
    if [ -n "$http_code" ] && [ "$http_code" -ne 000 ]; then
        local ping_ms=$(( (end_time - start_time) / 1000000 ))
        
        # Show everything that is alive! No more hidden drops.
        echo -e "\033[0;32m[✔ LIVE IP] $ip | Ping: ${ping_ms}ms | Status: $http_code\033[0m"
        echo -e "$ip\t${ping_ms}ms" >> "$RESULT_FILE"
    fi
}
export -f test_concrete_ip

# Shuffle the rows of ranges.txt
shuffled_ranges=$(shuf "$LOCAL_RANGES")

while IFS= read -r raw_range; do
    [ -z "$raw_range" ] && continue

    # Ultra clean sanitization
    clean_range=$(echo "$raw_range" | sed -E 's/\.0\/24//g' | sed -E 's/\/24//g' | sed -E 's/\.$//g' | tr -d '\r' | tr -d ' ')
    clean_range="${clean_range%.}"

    echo -e "${CYAN}[*] Selected Random Range: $clean_range.0/24${NC}"
    echo -e "${YELLOW}[+] Scanning 254 IPs using real target engine ($TARGET_DOM)...${NC}"
    
    # Run the parallel engine smoothly
    shuf -i 1-254 | sed "s/^/$clean_range./" | xargs -P 20 -I {} bash -c 'test_concrete_ip "{}" "$1"' _ "$TARGET_DOM"
    
    echo -e "${GREEN}[✔] Finished range $clean_range.0/24.${NC}\n"
    sleep 0.5
    
done <<< "$shuffled_ranges"

rm -f "$LOCAL_RANGES"

echo -e "\n${GREEN}[★] Scan finished! Results saved to $RESULT_FILE${NC}"
cat $RESULT_FILE
