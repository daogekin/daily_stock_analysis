#!/bin/bash
# 使用cpulimit限制特定进程
# 用法: ./limit_process.sh <PID>
if [ -z "$1" ]; then
    echo "用法: $0 <进程PID>"
    exit 1
fi
cpulimit -p "$1" -l 80 &
echo "已限制进程 $1 为80% CPU使用率"
