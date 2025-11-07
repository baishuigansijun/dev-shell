#!/usr/bin/env bash
set -e

echo "=== Dev Shell Bootstrap (auto PowerShell install + config) ==="

# ---------- 检测系统 ----------
if ! command -v lsb_release >/dev/null 2>&1; then
    echo "[*] lsb_release 未找到，尝试安装..."
    sudo apt update -y
    sudo apt install -y lsb-release
fi

DISTRO=$(lsb_release -is 2>/dev/null || echo "Unknown")
VERSION=$(lsb_release -rs 2>/dev/null || echo "Unknown")
echo "[+] 检测到系统: $DISTRO $VERSION"

# ---------- 安装 PowerShell 7 ----------
if command -v pwsh >/dev/null 2>&1; then
    echo "[+] PowerShell 已安装，版本：$(pwsh --version)"
else
    echo "[*] 安装 PowerShell 7..."
    if [[ "$DISTRO" == "Ubuntu" || "$DISTRO" == "Debian" ]]; then
        wget -q https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
        sudo dpkg -i packages-microsoft-prod.deb
        rm -f packages-microsoft-prod.deb
        sudo apt update -y
        sudo apt install -y powershell
    elif [[ "$DISTRO" == "AlmaLinux" || "$DISTRO" == "Rocky" || "$DISTRO" == "CentOS" ]]; then
        sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
        sudo sh -c 'echo -e "[powershell]\nname=PowerShell\nbaseurl=https://packages.microsoft.com/yumrepos/microsoft-rhel8.0-prod\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/microsoft.repo'
        sudo dnf install -y powershell
    else
        echo "⚠️ 暂不支持的发行版，请手动安装 PowerShell 7。"
        exit 1
    fi
fi

# ---------- 运行远程 PowerShell 配置脚本 ----------
echo "[*] 执行远程 PowerShell 配置脚本..."
pwsh -NoLogo -NoProfile -Command 'irm https://raw.githubusercontent.com/baishuigansijun/dev-shell/main/install-dev-shell.ps1 | iex'

echo "[✅] 所有步骤完成！"
echo "现在你可以输入：pwsh"
echo "进入统一增强终端环境。"
