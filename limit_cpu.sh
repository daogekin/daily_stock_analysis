#!/bin/bash

CPU_LIMIT_PERCENT=80

echo "正在设置CPU最大使用率限制为${CPU_LIMIT_PERCENT}%"

# 检查是否有可用的cpufreq目录
for cpu_dir in /sys/devices/system/cpu/cpu*/cpufreq/; do
    if [ -d "$cpu_dir" ]; then
        echo "找到CPU变频目录: $cpu_dir"
        # 获取最大频率
        if [ -f "${cpu_dir}cpuinfo_max_freq" ]; then
            max_freq=$(cat "${cpu_dir}cpuinfo_max_freq")
            target_freq=$(( max_freq * CPU_LIMIT_PERCENT / 100 ))
            echo "设置目标频率: ${target_freq} kHz"
            if [ -f "${cpu_dir}scaling_max_freq" ]; then
                echo $target_freq > "${cpu_dir}scaling_max_freq" 2>/dev/null
            fi
        fi
    fi
done

# 使用cgroup v2限制CPU使用
if [ -f "/sys/fs/cgroup/cpu.max" ]; then
    echo "检测到cgroup v2，正在设置CPU限制"
    # 创建子cgroup
    CGROUP_DIR="/sys/fs/cgroup/cpu_limit"
    mkdir -p "$CGROUP_DIR"
    # 启用CPU控制器
    echo "+cpu" > /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null
    # cgroup v2格式: max 100000 (例如: 80000 100000 表示80%)
    echo "${CPU_LIMIT_PERCENT}000 100000" > "${CGROUP_DIR}/cpu.max"
    echo "CPU限制已设置: ${CPU_LIMIT_PERCENT}%"
    echo "要限制特定进程，请将进程PID添加到: ${CGROUP_DIR}/cgroup.procs"
elif [ -d "/sys/fs/cgroup" ]; then
    echo "使用cgroup v1限制CPU"
    CGROUP_DIR="/sys/fs/cgroup/cpu/cpu_limit"
    mkdir -p "$CGROUP_DIR" 2>/dev/null
    # 设置CPU使用率为80% (cpu.cfs_quota_us / cpu.cfs_period_us)
    echo 100000 > "${CGROUP_DIR}/cpu.cfs_period_us" 2>/dev/null
    echo 80000 > "${CGROUP_DIR}/cpu.cfs_quota_us" 2>/dev/null
    echo "CPU限制已设置: 80%"
fi

# 另外，创建一个使用cpulimit的脚本作为备用方案
cat > /workspace/limit_process.sh << 'EOF'
#!/bin/bash
# 使用cpulimit限制特定进程
# 用法: ./limit_process.sh <PID>
if [ -z "$1" ]; then
    echo "用法: $0 <进程PID>"
    exit 1
fi
cpulimit -p "$1" -l 80 &
echo "已限制进程 $1 为80% CPU使用率"
EOF
chmod +x /workspace/limit_process.sh

echo "CPU限制设置完成！"
echo "可用的方法："
echo "1. 使用cgroup: 将要限制的进程PID添加到 /sys/fs/cgroup/cpu_limit/cgroup.procs"
echo "2. 使用cpulimit: 运行 /workspace/limit_process.sh <PID>"

