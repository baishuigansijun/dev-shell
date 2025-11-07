<#
Dev Shell Bootstrap

适用：
- Windows 10/11: PowerShell 或 pwsh 下直接运行
- Linux/macOS: 在 pwsh 下运行 (建议先按官方文档安装 PowerShell 7)

功能：
- 安装 / 检查：
    - PowerShell 7（在 Windows 上）
    - Oh My Posh
    - fzf
    - zoxide
    - PSReadLine
    - PSFzf
    - (Linux) tmux (轻量多窗口)
- 写入统一 PowerShell Profile（追加，不粗暴清空）：
    - Oh My Posh 使用 "amro" 主题（不存在则回退默认配置）
    - PSReadLine 智能历史预测
    - fzf + PSFzf：Ctrl+T 文件 / Ctrl+R 历史
    - zoxide：z 关键字智能 cd
    - Linux 上提供 systemctl / 日志 快捷函数
#>

$ErrorActionPreference = "Stop"

Write-Host "=== Dev Shell Bootstrap ===" -ForegroundColor Cyan

# 容错处理 IsWindows/IsLinux/IsMacOS（在老环境可能不存在）
$isWindows = (Get-Variable IsWindows -ErrorAction SilentlyContinue)?.Value -eq $true
$isLinux   = (Get-Variable IsLinux   -ErrorAction SilentlyContinue)?.Value -eq $true
$isMacOS   = (Get-Variable IsMacOS   -ErrorAction SilentlyContinue)?.Value -eq $true

if (-not ($isWindows -or $isLinux -or $isMacOS)) {
    # 简单兜底
    $os = $PSVersionTable.OS
    if ($os -like "*Windows*") { $isWindows = $true }
    elseif ($os -like "*Linux*") { $isLinux = $true }
    elseif ($os -like "*Darwin*") { $isMacOS = $true }
}

$platform =
    if ($isWindows) { "Windows" }
    elseif ($isLinux) { "Linux" }
    elseif ($isMacOS) { "macOS" }
    else { "Unknown" }

Write-Host "[+] 检测到平台: $platform"

function Ensure-Command {
    param([Parameter(Mandatory = $true)][string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# ---------- 安装 PowerShell 7（仅 Windows，方便从 WinPS 5.1 升级） ----------
if ($isWindows -and $PSVersionTable.PSVersion.Major -lt 7) {
    if (Ensure-Command "winget") {
        Write-Host "[*] 检测到 Windows PowerShell，使用 winget 安装 PowerShell 7..."
        try {
            winget install Microsoft.PowerShell -s winget -h
            Write-Host "[+] PowerShell 7 安装完成，请使用 pwsh 运行本脚本以获得最佳效果。" -ForegroundColor Yellow
        } catch {
            Write-Warning "自动安装 PowerShell 7 失败，请手动安装：https://learn.microsoft.com/powershell/"
        }
    } else {
        Write-Warning "未找到 winget，请手动安装 PowerShell 7。"
    }
}

# ---------- 安装 Oh My Posh ----------
function Install-OhMyPosh {
    if (Ensure-Command "oh-my-posh") {
        Write-Host "[+] Oh My Posh 已存在。"
        return
    }

    if ($isWindows -and (Ensure-Command "winget")) {
        Write-Host "[*] 安装 Oh My Posh (winget)..."
        winget install JanDeDobbeleer.OhMyPosh -s winget -h
    }
    elseif ($isLinux -or $isMacOS) {
        Write-Host "[*] 安装 Oh My Posh (官方脚本)..."
        curl -s https://ohmyposh.dev/install.sh | bash -s
    }
    else {
        Write-Warning "无法自动安装 Oh My Posh，请参考官网文档。"
    }
}

# ---------- 安装 fzf ----------
function Install-Fzf {
    if (Ensure-Command "fzf") {
        Write-Host "[+] fzf 已存在。"
        return
    }

    if ($isWindows -and (Ensure-Command "winget")) {
        Write-Host "[*] 安装 fzf (winget)..."
        winget install Junegunn.Fzf -s winget -h
    }
    elseif ($isLinux -and (Ensure-Command "apt")) {
        Write-Host "[*] 安装 fzf (apt)..."
        sudo apt update && sudo apt install -y fzf
    }
    elseif ($isMacOS -and (Ensure-Command "brew")) {
        Write-Host "[*] 安装 fzf (brew)..."
        brew install fzf
    }
    else {
        Write-Warning "请手动安装 fzf。"
    }
}

# ---------- 安装 zoxide ----------
function Install-Zoxide {
    if (Ensure-Command "zoxide") {
        Write-Host "[+] zoxide 已存在。"
        return
    }

    if ($isWindows -and (Ensure-Command "winget")) {
        Write-Host "[*] 安装 zoxide (winget)..."
        winget install ajeetdsouza.zoxide -s winget -h
    }
    else {
        Write-Host "[*] 安装 zoxide (官方脚本)..."
        curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
    }
}

# ---------- 确保 PSReadLine / PSFzf ----------
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

function Ensure-PSFzf {
    if (Get-Module -ListAvailable -Name PSFzf) {
        Write-Host "[+] PSFzf 可用。"
        return
    }
    try {
        Write-Host "[*] 安装 PSFzf..."
        Install-Module -Name PSFzf -Scope CurrentUser -Force -AllowClobber
    } catch {
        Write-Warning "PSFzf 安装失败（可选），错误：$($_.Exception.Message)"
    }
}

# ---------- Linux: 安装 tmux（轻量多窗口） ----------
function Install-Tmux {
    if (-not $isLinux) { return }
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
Install-Fzf
Install-Zoxide
Ensure-PSReadLine
Ensure-PSFzf
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

# Oh My Posh: 优先使用 amro 主题，不存在则使用默认
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

# fzf + PSFzf：Ctrl+T 文件搜索，Ctrl+R 历史搜索
if (Get-Module -ListAvailable -Name PSFzf) {
    Import-Module PSFzf -ErrorAction SilentlyContinue
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# Linux 专用：简化 systemctl / journalctl （不重）
if ($IsLinux) {
    function sstatus {
        param([Parameter(Mandatory = $true)][string]$Name)
        sudo systemctl status $Name
    }
    function srestart {
        param([Parameter(Mandatory = $true)][string]$Name)
        sudo systemctl restart $Name
    }
    function sjournal {
        param([Parameter(Mandatory = $true)][string]$Name)
        # 实时查看日志末尾
        sudo journalctl -u $Name -e -f
    }
    function sjournalerr {
        param([Parameter(Mandatory = $true)][string]$Name)
        sudo journalctl -u $Name -p err -n 100
    }
    # tmux 快捷：快速进入多窗会话
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
Write-Host "完成："
Write-Host " - 重新打开 PowerShell / 在服务器上运行 'pwsh' 生效" -ForegroundColor Cyan
Write-Host " - Linux 下可用：sstatus / srestart / sjournal / sjournalerr / tmux（如已装）" -ForegroundColor Cyan
