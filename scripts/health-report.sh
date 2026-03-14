#!/bin/bash

# Server Health Check Report Script
# Cron: 0 9-23 * * * (every hour from 9 AM to 11 PM)

# Get current time
NOW=$(date "+%Y-%m-%d %H:%M")

# Get uptime - cleaner format
UPTIME_DAYS=$(uptime | grep -oP '\d+ days' | head -1)
UPTIME_HOURS=$(uptime | grep -oP '\d+:\d+' | head -1)
LOAD_AVG=$(uptime | grep -oP 'load average: .*' | sed 's/load average: //')

if [ -z "$UPTIME_DAYS" ]; then
    UPTIME_STR="已运行 $UPTIME_HOURS"
else
    UPTIME_STR="已运行 $UPTIME_DAYS $UPTIME_HOURS"
fi

# Get CPU info
CPU_LINE=$(top -bn1 | grep "Cpu(s)")
CPU_IDLE=$(echo "$CPU_LINE" | sed -n 's/.*, *\([0-9.]*\)%* id.*/\1/p')
CPU_USER=$(echo "$CPU_LINE" | sed -n 's/\([0-9.]*\)%* us.*/\1/p')
if [ -z "$CPU_USER" ]; then
    CPU_USER=$(echo "$CPU_LINE" | sed -n 's/\([0-9.]*\)%* user.*/\1/p')
fi
CPU_SYSTEM=$(echo "$CPU_LINE" | sed -n 's/.*, *\([0-9.]*\)%* sy.*/\1/p')

if [ -z "$CPU_IDLE" ]; then
    CPU_IDLE=0
fi
CPU_USED=$(echo "100 - $CPU_IDLE" | bc -l | awk '{printf "%.1f", $1}')

# Get memory info
MEM_TOTAL=$(free -m | grep Mem | awk '{print $2}')
MEM_USED=$(free -m | grep Mem | awk '{print $3}')
MEM_FREE=$(free -m | grep Mem | awk '{print $7}')
MEM_PERCENT=$(echo "scale=1; $MEM_USED * 100 / $MEM_TOTAL" | bc)

# Get disk info
DISK_TOTAL=$(df -h / | tail -1 | awk '{print $2}')
DISK_USED=$(df -h / | tail -1 | awk '{print $3}')
DISK_FREE=$(df -h / | tail -1 | awk '{print $4}')
DISK_PERCENT=$(df -h / | tail -1 | awk '{print $5}')

# Calculate health score
HEALTH_SCORE=100
if [ -n "$MEM_PERCENT" ] && (( $(echo "$MEM_PERCENT > 80" | bc -l 2>/dev/null) )); then
    HEALTH_SCORE=$((HEALTH_SCORE - 20))
fi
DISK_PCT_NUM=${DISK_PERCENT%\%}
if [ -n "$DISK_PCT_NUM" ] && [ "$DISK_PCT_NUM" -gt 80 ] 2>/dev/null; then
    HEALTH_SCORE=$((HEALTH_SCORE - 20))
fi
if [ -n "$CPU_IDLE" ] && (( $(echo "$CPU_IDLE < 20" | bc -l 2>/dev/null) )); then
    HEALTH_SCORE=$((HEALTH_SCORE - 10))
fi

# Generate suggestions
if [ $HEALTH_SCORE -ge 90 ]; then
    SUGGESTION="系统运行良好，资源使用正常。建议关注磁盘空间，当使用率超过80%时考虑清理。"
elif [ $HEALTH_SCORE -ge 70 ]; then
    SUGGESTION="资源使用偏中等，建议关注内存和磁盘使用情况。"
else
    SUGGESTION="资源使用较高，建议立即检查并优化。"
fi

# Format the report
REPORT="服务器健康检查报告
📅 时间：$NOW
🖥️ 运行状态：$UPTIME_STR | 负载 $LOAD_AVG
📊 CPU：使用率 ${CPU_USED}%（用户${CPU_USER}% + 系统${CPU_SYSTEM}%）| 空闲 ${CPU_IDLE}%
💾 内存：总计${MEM_TOTAL}MB | 已用${MEM_USED}MB（${MEM_PERCENT}%）| 可用${MEM_FREE}MB
💿 磁盘：根分区 ${DISK_TOTAL} | 已用${DISK_USED}（${DISK_PERCENT}）| 可用${DISK_FREE}
⭐ 健康度评分：${HEALTH_SCORE}/100
💡 建议：$SUGGESTION"

echo "$REPORT"

# Send to Feishu if webhook URL is provided
if [ -n "$FEISHU_WEBHOOK_URL" ]; then
    curl -s -X POST "$FEISHU_WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{\"msg_type\": \"text\", \"content\": {\"text\": \"$REPORT\"}}"
    echo ""
    echo "✓ Report sent to Feishu"
fi
