<#
Dev Shell Bootstrap (no fzf / PSFzf)

适用：
- Windows 10/11: 在 PowerShell / pwsh 中运行
- Linux/macOS: 在 pwsh 中运行（建议已安装 PowerShell 7）

功能：
- 安装 / 检查：
    - PowerShell 7（仅 Windows，从 5.1 升级）
    - Oh My Posh
    - zoxide
    - PSReadLine
    - (Linux) tmux（轻量多窗口）
- 写入统一 PowerShell Profile（追加）：
    - Oh My Posh 使用 "amro" 主题（不存在则回退默认）
    - PSReadLine 智能历史预测
    - zoxide: z 关键字智能 cd
    - Linux: 可选的 systemctl / journalctl 快捷函数
#>

$ErrorActionPreference = "Stop"

Write-Host "=== Dev Shell Bootstrap ===" -ForegroundColor Cyan

# ---------- 平台检测（不用内置只读常量名，避免冲突） ----------
$devShellIsWindowsSys = $false
$devShellIsLinuxSys   = $false
$devShellIsMacSys     = $false

if ($PSVersionTable.PSEdition -eq 'Core' -and $PSVersionTable.OS) {
    $os = $PSVersionTable.OS
    if ($os -like '*Windows*') {
        $devShellIsWindowsSys = $true
    } elseif ($os -like '*Linux*') {
        $devShellIsLinuxSys = $true
    } elseif ($os -like '*Darwin*' -or $os -like '*macOS*') {
        $devShellIsMacSys = $true
    }
} elseif ($env:OS -like '*Windows*') {
    # 兼容 Windows PowerShell 5.1
    $devShellIsWindowsSys = $true
}

$platform = if ($devShellIsWindowsSys) { 'Windows' } elseif ($devShellIsLinuxSys) { 'Linux' } elseif ($devShellIsMacSys) { 'macOS' } else { 'Unknown' }
Write-Host "[+] 检测到平台: $platform"

function Ensure-Command {
    param([Parameter(Mandatory = $true)][string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# ---------- Windows: 安装 PowerShell 7（从 5.1 升级） ----------
if ($devShellIsWindowsSys -and $PSVersionTable.PSVersion.Major -lt 7) {
    if (Ensure-Command "winget") {
        Write-Host "[*] 检测到 Windows PowerShell，使用 winget 安装 PowerShell 7..."
        try {
            winget install Microsoft.PowerShell -s winget -h
            Write-Host "[+] PowerShell 7 安装完成，请使用 pwsh 重新运行本命令。" -ForegroundColor Yellow
        } catch {
            Write-Warning "自动安装 PowerShell 7 失败，请手动安装：https://learn.microsoft.com/powershell/"
        }
    } else {
        Write-Warning "未找到 winget，请手动安装 PowerShell 7。"
    }
    return
}

# ---------- 安装 Oh My Posh ----------
function Install-OhMyPosh {
    if (Ensure-Command "oh-my-posh") {
        Write-Host "[+] Oh My Posh 已存在。"
        return
    }

    if ($devShellIsWindowsSys -and (Ensure-Command "winget")) {
        Write-Host "[*] 安装 Oh My Posh (winget)..."
        winget install JanDeDobbeleer.OhMyPosh -s winget -h
    }
    elseif (($devShellIsLinuxSys -or $devShellIsMacSys) -and (Ensure-Command "curl")) {
        Write-Host "[*] 安装 Oh My Posh (官方脚本)..."
        curl -s https://ohmyposh.dev/install.sh | bash -s
    }
    else {
        Write-Warning "无法自动安装 Oh My Posh，请参考：https://ohmyposh.dev"
    }
}

# ---------- 安装 zoxide ----------
function Install-Zoxide {
    if (Ensure-Command "zoxide") {
        Write-Host "[+] zoxide 已存在。"
        return
    }

    if ($devShellIsWindowsSys -and (Ensure-Command "winget")) {
        Write-Host "[*] 安装 zoxide (winget)..."
        winget install ajeetdsouza.zoxide -s winget -h
    }
    elseif (Ensure-Command "curl") {
        Write-Host "[*] 安装 zoxide (官方脚本)..."
        curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
    }
    else {
        Write-Warning "请手动安装 zoxide：https://github.com/ajeetdsouza/zoxide"
    }
}

# ---------- 确保 PSReadLine ----------
function Ensure-PSReadLine {
    if (Get-Module -ListAvailable -Name PSReadLine) {
        Write-Host "[+] PSReadLine 可用。"
        return
    }
    try {
        Write-Host "[*] 安装 PSReadLine..."
        Install-Module PSReadLine -Scope CurrentUser -Force -AllowClobber
    } catch {
        Write-Warning "PSReadLine 安装失败：$($_.Exception.Message)"
    }
}

# ---------- Linux: 安装 tmux（可选，多窗口） ----------
function Install-Tmux {
    if (-not $devShellIsLinuxSys) { return }
    if (Ensure-Command "tmux") {
        Write-Host "[+] tmux 已存在。"
        return
    }
    if (Ensure-Command "apt") {
        Write-Host "[*] 安装 tmux (apt)..."
        sudo apt install -y tmux
    }
}

# ---------- 执行安装 ----------
Install-OhMyPosh
Install-Zoxide
Ensure-PSReadLine
Install-Tmux

# ---------- 写入统一 Profile ----------
Write-Host "[*] 配置 PowerShell Profile..."

$profilePath = $PROFILE
$profileDir = Split-Path $profilePath -Parent
if (!(Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

$markerStart = "# >>> dev-shell profile >>>"
$markerEnd   = "# <<< dev-shell profile <<<"

$old = ""
if (Test-Path $profilePath) {
    $old = Get-Content $profilePath -Raw
}

if ($old -match [regex]::Escape($markerStart)) {
    $old = $old -replace "$([regex]::Escape($markerStart)).*?$([regex]::Escape($markerEnd))", ""
}

$devShellBlock = @"
$markerStart

Import-Module PSReadLine -ErrorAction SilentlyContinue

Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows

# Oh My Posh: 尝试使用 amro 主题，不存在则回退默认
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    try {
        oh-my-posh init pwsh --config "amro" | Invoke-Expression
    } catch {
        oh-my-posh init pwsh | Invoke-Expression
    }
}

# zoxide: 智能 cd (z 关键字)
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init pwsh | Out-String) })
}

# Linux 系统上提供轻量快捷命令（可按需删除）
# sstatus nginx      -> systemctl status nginx
# srestart nginx     -> systemctl restart nginx
# sjournal nginx     -> tail 跟踪日志
# sjournalerr nginx  -> 最近错误日志
$devShellIsLinuxLocal = $false
if ($PSVersionTable.PSEdition -eq 'Core' -and $PSVersionTable.OS -like '*Linux*') {
    $devShellIsLinuxLocal = $true
}
if ($devShellIsLinuxLocal) {
    function sstatus {
        param(
            [Parameter(Mandatory = $true)][string]$Name
        )
        sudo systemctl status $Name
    }
    function srestart {
        param(
            [Parameter(Mandatory = $true)][string]$Name
        )
        sudo systemctl restart $Name
    }
    function sjournal {
        param(
            [Parameter(Mandatory = $true)][string]$Name
        )
        sudo journalctl -u $Name -e -f
    }
    function sjournalerr {
        param(
            [Parameter(Mandatory = $true)][string]$Name
        )
        sudo journalctl -u $Name -p err -n 100
    }
    if (Get-Command tmux -ErrorAction SilentlyContinue) {
        Set-Alias tmx tmux
    }
}

$markerEnd
"@

$newProfile = ($old.TrimEnd(), "", $devShellBlock.Trim()) -join "`n"
Set-Content -Path $profilePath -Value $newProfile -Encoding UTF8

Write-Host "[+] 已写入 Profile: $profilePath" -ForegroundColor Green
Write-Host ""
Write-Host "完成：" -ForegroundColor Cyan
Write-Host " - 重启 PowerShell / 在服务器上运行 'pwsh' 生效" -ForegroundColor Cyan
Write-Host " - Linux 可用：sstatus / srestart / sjournal / sjournalerr / tmx（如不需要可手动删掉该块）" -ForegroundColor Cyan
