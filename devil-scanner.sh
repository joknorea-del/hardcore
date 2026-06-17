#!/bin/bash

# UI Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${RED}======================================================${NC}"
echo -e "${RED}    DEVIL CF SCANNER - GITHUB LIVE CLOUD ENGINE       ${NC}"
echo -e "${RED}======================================================${NC}"

TARGET_DOM="chatgpt.com"
RESULT_FILE="devil_clean_ips.txt"

# 🔗 آدرس مستقیم گیت‌هاب خودت از قبل ست شده است!
GITHUB_RAW_URL="https://raw.githubusercontent.com/joknorea-del/cf-scanner/main/ranges.txt"

echo -e "IP\t\tPing" > $RESULT_FILE
echo "----------------------------------------" >> $RESULT_FILE

echo -e "${YELLOW}[*] Fetching all ranges live from GitHub...${NC}"

# دانلود مستقیم کل رنج‌های جدیدت از گیت‌هاب و بُر زدن همزمان در حافظه رم
shuffled_ranges=$(curl -s "$GITHUB_RAW_URL" | shuf)

# بررسی اینکه آیا فایل درست دانلود شد یا نه
if [ -z "$shuffled_ranges" ] || echo "$shuffled_ranges" | grep -q "404"; then
    echo -e "${RED}[!] Error: Could not fetch data from GitHub! Check your repository or internet.${NC}"
    exit 1
fi

total_ranges=$(echo "$shuffled_ranges" | wc -l)
echo -e "${GREEN}[✔] Successfully downloaded and shuffled $total_ranges ranges from your GitHub!${NC}\n"

current_count=0

while IFS= read -r raw_range; do
    [ -z "$raw_range" ] && continue
    ((current_count++))

    # پاک‌سازی بسیار دقیق رنج‌ها
    clean_range=$(echo "$raw_range" | sed -E 's/\.0\/24//g' | sed -E 's/\/24//g' | sed -E 's/\.$//g' | tr -d '\r' | tr -d ' ')
    clean_range="${clean_range%.}"

    echo -e "${CYAN}[*] [$current_count/$total_ranges] Cloud Scanning Range: $clean_range.0/24${NC}"
    
    # موتور موازی ۲۵۴ لوله‌ای بَش در محیط مادر
    for i in {1..254}; do
        ip="$clean_range.$i"
        
        (
            # تست سریع پورت ۴۴۳ با سوکت داخلی بَش
            if : 2>/dev/null >"/dev/tcp/$ip/443"; then
                
                start_time=$(date +%s%N)
                http_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 \
                    --resolve "$TARGET_DOM:443:$ip" "https://$TARGET_DOM")
                end_time=$(date +%s%N)

                if [ -n "$http_code" ] && [ "$http_code" -ne 000 ]; then
                    ping_ms=$(( (end_time - start_time) / 1000000 ))
                    
                    echo -e "${GREEN}[✔ LIVE IP] $ip | Ping: ${ping_ms}ms | Status: $http_code${NC}"
                    echo -e "$ip\t${ping_ms}ms" >> "$RESULT_FILE"
                fi
            fi
        ) &
        
        # کنترل باز شدن پروسس‌ها برای جلوگیری از لگ ترموکس
        if (( i % 40 == 0 )); then
            sleep 0.1
        fi
    done
    
    # منتظر بمان تا کل ۲۵۴ آی‌پي این رنج تمام شوند، بعد برو رنج بعدی
    wait
    
done <<< "$shuffled_ranges"

echo -e "\n${GREEN}[★] Scan finished! Results saved to $RESULT_FILE${NC}"
cat $RESULT_FILE
