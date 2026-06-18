#!/bin/bash

# UI Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${RED}======================================================${NC}"
echo -e "${RED}    DEVIL CF SCANNER - INFALLIBLE ANTI-DROP ENGINE    ${NC}"
echo -e "${RED}======================================================${NC}"

TARGET_DOM="chatgpt.com"
RESULT_FILE="devil_clean_ips.txt"
CACHE_FILE=".cached_ranges.txt"
GITHUB_RAW_URL="https://raw.githubusercontent.com/joknorea-del/cf-scanner/main/ranges.txt"

# Initialize file headers safely
if [ ! -f "$RESULT_FILE" ]; then
    echo -e "IP\t\tAvg_Ping" > $RESULT_FILE
    echo "----------------------------------------" >> $RESULT_FILE
fi

# Ant-Disconnect Cloud Sync
echo -e "${YELLOW}[*] Syncing ranges from GitHub...${NC}"
if curl -s --connect-timeout 8 "$GITHUB_RAW_URL" -o "$CACHE_FILE.tmp"; then
    if [ -s "$CACHE_FILE.tmp" ] && ! grep -q "404" "$CACHE_FILE.tmp"; then
        # Shuffle directly into the permanent cache file
        shuf "$CACHE_FILE.tmp" > "$CACHE_FILE"
        echo -e "${GREEN}[✔] Local cache synchronized and shuffled!${NC}"
    fi
fi
rm -f "$CACHE_FILE.tmp"

if [ ! -s "$CACHE_FILE" ]; then
    echo -e "${RED}[!] Error: No cached ranges found! Connect to internet at least once.${NC}"
    exit 1
fi

total_ranges=$(wc -l < "$CACHE_FILE")
echo -e "${GREEN}[✔] Loaded $total_ranges ranges from stable cache. Starting...${NC}\n"

current_count=0

# 🌟 FIX: Using File Descriptor 3 to isolate loop input from internal network curls!
while IFS= read -r raw_range <&3; do
    [ -z "$raw_range" ] && continue
    ((current_count++))

    clean_range=$(echo "$raw_range" | sed -E 's/\.0\/24//g' | sed -E 's/\/24//g' | sed -E 's/\.$//g' | tr -d '\r' | tr -d ' ')
    clean_range="${clean_range%.}"

    echo -e "${CYAN}[*] [$current_count/$total_ranges] Deep Testing Range: $clean_range.0/24${NC}"
    
    for i in {1..254}; do
        ip="$clean_range.$i"
        
        (
            # Phase 1: Silent TCP Socket ping
            if : 2>/dev/null >"/dev/tcp/$ip/443"; then
                
                total_ping=0
                valid_tests=0
                
                # Phase 2: Heavy 3-Round precise checking
                for test_round in {1..3}; do
                    start_time=$(date +%s%N)
                    # Use explicit standard input redirecting to prevent curl from hijacking the main descriptor
                    http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 1.2 --max-time 1.5 \
                        --resolve "$TARGET_DOM:443:$ip" "https://$TARGET_DOM" < /dev/null)
                    end_time=$(date +%s%N)

                    if [ -n "$http_code" ] && [ "$http_code" -ne 000 ]; then
                        ping_ms=$(( (end_time - start_time) / 1000000 ))
                        total_ping=$(( total_ping + ping_ms ))
                        ((valid_tests++))
                    fi
                    sleep 0.03
                done

                # Only lock if all 3 tests pass meticulously
                if [ "$valid_tests" -eq 3 ]; then
                    avg_ping=$(( total_ping / 3 ))
                    
                    if [ "$avg_ping" -lt 1100 ]; then
                        echo -e "${GREEN}[★ PREMIUM IP] $ip | Real Avg Ping: ${avg_ping}ms | Status: 403${NC}"
                        echo -e "$ip\t${avg_ping}ms" >> "$RESULT_FILE"
                    else
                        echo -e "${YELLOW}[▲ MEDIOCRE IP] $ip | Avg Ping: ${avg_ping}ms (Filtered)${NC}"
                    fi
                fi
            fi
        ) &
        
        # 🏎️ Super calm pacing: 12 IPs per batch for real, untouched ping statistics
        if (( i % 12 == 0 )); then
            sleep 0.09
        fi
    done
    
    # Strictly wait for this range to completely flush out before moving forward
    wait
    
done 3< "$CACHE_FILE" # Binding file descriptor 3 safely here
