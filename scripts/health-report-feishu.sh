#!/bin/bash

# Server Health Check Report Script for Cron
# This script generates the report and saves it to a file

NOW=$(date "+%Y-%m-%d %H:%M")
UPTIME_INFO=$(uptime | sed 's/.*up /已运行 /' | sed 's/,.*load/ | 负载/')
LOAD=$(uptime | grep -oP 'load average: .*' | sed 's/load average: //')

CPU_LINE=$(top -bn1 | grep "Cpu(s)" 2>/dev/null || echo "0.0 us, 0.0 sy, 100.0 id")
CPU_IDLE=$(echo "$CPU_LINE" | sed -n 's/.*, *\([0-9.]*\)%* id.*/\1/p')
CPU_USER=$(echo "$CPU_LINE" | sed -n 's/\([0-9.]*\)%* us.*/\1/p')
CPU_SYSTEM=$(echo "$CPU_LINE" | sed -n 's/.*, *\([0-9.]*\)%* sy.*/\1/p')

[ -z "$CPU_IDLE" ] && CPU_IDLE=100
CPU_USED=$(echo "100 - $CPU_IDLE" | bc -l 2>/dev/null | awk '{printf "%.1f", $1}' || echo "0")

MEM_TOTAL=$(free -m | grep Mem | awk '{print $2}')
MEM_USED=$(free -m | grep Mem | awk '{print $3}')
MEM_FREE=$(free -m | grep Mem | awk '{print $7}')
MEM_PERCENT=$(echo "scale=1; $MEM_USED * 100 / $MEM_TOTAL" | bc 2>/dev/null | awk '{printf "%.1f", $1}' || echo "0")

# Root disk
DISK_ROOT_TOTAL=$(df -h / | tail -1 | awk '{print $2}')
DISK_ROOT_USED=$(df -h / | tail -1 | awk '{print $3}')
DISK_ROOT_FREE=$(df -h / | tail -1 | awk '{print $4}')
DISK_ROOT_PERCENT=$(df -h / | tail -1 | awk '{print $5}')

# Data disk
DISK_DATA=$(df -h /data 2>/dev/null | tail -1)
DISK_DATA_TOTAL=$(echo "$DISK_DATA" | awk '{print $2}')
DISK_DATA_USED=$(echo "$DISK_DATA" | awk '{print $3}')
DISK_DATA_FREE=$(echo "$DISK_DATA" | awk '{print $4}')
DISK_DATA_PERCENT=$(echo "$DISK_DATA" | awk '{print $5}')

HEALTH_SCORE=100
[ -n "$MEM_PERCENT" ] && (( $(echo "$MEM_PERCENT > 80" | bc -l 2>/dev/null) )) && HEALTH_SCORE=$((HEALTH_SCORE - 20))
DISK_ROOT_PCT_NUM=${DISK_ROOT_PERCENT%\%}
[ -n "$DISK_ROOT_PCT_NUM" ] && [ "$DISK_ROOT_PCT_NUM" -gt 80 ] 2>/dev/null && HEALTH_SCORE=$((HEALTH_SCORE - 20))
DISK_DATA_PCT_NUM=${DISK_DATA_PERCENT%\%}
[ -n "$DISK_DATA_PCT_NUM" ] && [ "$DISK_DATA_PCT_NUM" -gt 80 ] 2>/dev/null && HEALTH_SCORE=$((HEALTH_SCORE - 10))

if [ $HEALTH_SCORE -ge 90 ]; then
    SUGGESTION="系统运行良好，资源使用正常。建议关注磁盘空间，当使用率超过80%时考虑清理。"
elif [ $HEALTH_SCORE -ge 70 ]; then
    SUGGESTION="资源使用偏中等，建议关注内存和磁盘使用情况。"
else
    SUGGESTION="资源使用较高，建议立即检查并优化。"
fi

REPORT="服务器健康检查报告
📅 时间：$NOW
🖥️ 运行状态：$UPTIME_INFO | 负载 $LOAD
📊 CPU：使用率 ${CPU_USED}%（用户${CPU_USER}% + 系统${CPU_SYSTEM}%）| 空闲 ${CPU_IDLE}%
💾 内存：总计${MEM_TOTAL}MB | 已用${MEM_USED}MB（${MEM_PERCENT}%）| 可用${MEM_FREE}MB
💿 磁盘：根分区 ${DISK_ROOT_TOTAL} | 已用${DISK_ROOT_USED}（${DISK_ROOT_PERCENT}）| 可用${DISK_ROOT_FREE}
💿 数据盘：${DISK_DATA_TOTAL} | 已用${DISK_DATA_USED}（${DISK_DATA_PERCENT}）| 可用${DISK_DATA_FREE}
⭐ 健康度评分：${HEALTH_SCORE}/100
💡 建议：$SUGGESTION"

echo "$REPORT" > /tmp/health-report/latest.txt
echo "Report saved at $(date)" >> /tmp/health-report/latest.txt
