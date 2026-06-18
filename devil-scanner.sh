#!/bin/bash

# UI Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${RED}======================================================${NC}"
echo -e "${RED}    DEVIL CF SCANNER - DEEP PRECISE MULTI-TEST ENGINE ${NC}"
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

# Ant-Disconnect Engine: Use Local cache if github fails or check connectivity
echo -e "${YELLOW}[*] Syncing ranges from GitHub to local secure cache...${NC}"
if curl -s --connect-timeout 5 "$GITHUB_RAW_URL" -o "$CACHE_FILE.tmp"; then
    if [ -s "$CACHE_FILE.tmp" ] && ! grep -q "404" "$CACHE_FILE.tmp"; then
        mv "$CACHE_FILE.tmp" "$CACHE_FILE"
        echo -e "${GREEN}[✔] Cache updated successfully from Cloud!${NC}"
    fi
fi
rm -f "$CACHE_FILE.tmp"

if [ ! -s "$CACHE_FILE" ]; then
    echo -e "${RED}[!] Error: No cached ranges found and GitHub is unreachable! Check internet.${NC}"
    exit 1
fi

# Load and shuffle from local secure cache to prevent subshell drop-outs
shuffled_ranges=$(shuf "$CACHE_FILE")
total_ranges=$(echo "$shuffled_ranges" | wc -l)
echo -e "${GREEN}[✔] Loaded $total_ranges ranges. Engine starting smoothly...${NC}\n"

current_count=0

while IFS= read -r raw_range; do
    [ -z "$raw_range" ] && continue
    ((current_count++))

    clean_range=$(echo "$raw_range" | sed -E 's/\.0\/24//g' | sed -E 's/\/24//g' | sed -E 's/\.$//g' | tr -d '\r' | tr -d ' ')
    clean_range="${clean_range%.}"

    echo -e "${CYAN}[*] [$current_count/$total_ranges] Deep Scanning: $clean_range.0/24${NC}"
    
    for i in {1..254}; do
        ip="$clean_range.$i"
        
        (
            # Phase 1: Fast TCP check to filter dead meat
            if : 2>/dev/null >"/dev/tcp/$ip/443"; then
                
                total_ping=0
                valid_tests=0
                
                # Phase 2: Deep 3-Step Handshake Test for high precision pings
                for test_round in {1..3}; do
                    start_time=$(date +%s%N)
                    http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 1.2 --max-time 1.5 \
                        --resolve "$TARGET_DOM:443:$ip" "https://$TARGET_DOM")
                    end_time=$(date +%s%N)

                    if [ -n "$http_code" ] && [ "$http_code" -ne 000 ]; then
                        ping_ms=$(( (end_time - start_time) / 1000000 ))
                        total_ping=$(( total_ping + ping_ms ))
                        ((valid_tests++))
                    fi
                    # Micro sleep between tests to get realistic network feedback
                    sleep 0.02
                done

                # If all 3 steps successfully handshake, calculate real average
                if [ "$valid_tests" -eq 3 ]; then
                    avg_ping=$(( total_ping / 3 ))
                    
                    # Hard Filter: Only accept premium low ping IPs
                    if [ "$avg_ping" -lt 1100 ]; then
                        echo -e "${GREEN}[★ PREMIUM IP] $ip | Real Avg Ping: ${avg_ping}ms | Status: 403${NC}"
                        echo -e "$ip\t${avg_ping}ms" >> "$RESULT_FILE"
                    else
                        echo -e "${YELLOW}[▲ MEDIOCRE IP] $ip | Avg Ping: ${avg_ping}ms (Filtered)${NC}"
                    fi
                fi
            fi
        ) &
        
        # 🏎️ Super calm throttling (15 IPs per batch) to give your phone's antenna breathing room
        if (( i % 15 == 0 )); then
            sleep 0.08
        fi
    done
    
    # Wait for the range batch to finish up completely
    wait
    
done <<< "$shuffled_ranges"
