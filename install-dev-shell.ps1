<#
Dev Shell Bootstrap (clean & stable)

适用:
- Windows 10/11: 在 PowerShell / pwsh 中运行
- Linux/macOS: 在 pwsh 中运行（建议已安装 PowerShell 7）

功能:
- 自动安装 / 检查:
    - PowerShell 7（仅 Windows，从 5.1 升级）
    - Oh My Posh
    - zoxide
    - PSReadLine
- 写入统一 PowerShell Profile（追加，不清空原有其它设置）:
    - Oh My Posh 使用 "amro" 主题（不存在则回退默认）
    - PSReadLine 智能历史预测
    - zoxide 智能 cd (z 命令)
#>

$ErrorActionPreference = "Stop"
Write-Host "=== Dev Shell Bootstrap ===" -ForegroundColor Cyan

# ---------- 平台检测 ----------
$devShellIsWindowsSys = $false
$devShellIsLinuxSys   = $false
$devShellIsMacSys     = $false

# 优先使用内置只读标志（只读, 只读没问题）
try {
    if (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue) {
        if ($IsWindows) { $devShellIsWindowsSys = $true }
    }
    if (Get-Variable -Name IsLinux -ErrorAction SilentlyContinue) {
        if ($IsLinux) { $devShellIsLinuxSys = $true }
    }
    if (Get-Variable -Name IsMacOS -ErrorAction SilentlyContinue) {
        if ($IsMacOS) { $devShellIsMacSys = $true }
    }
} catch { }

# 如果还没判断出来，再根据 OS 字符串兜底
if (-not ($devShellIsWindowsSys -or $devShellIsLinuxSys -or $devShellIsMacSys)) {
    if ($PSVersionTable | Get-Member -Name OS -ErrorAction SilentlyContinue) {
        $os = $PSVersionTable.OS
        if ($os -like '*Windows*') {
            $devShellIsWindowsSys = $true
        }
        elseif ($os -like '*Darwin*' -or $os -like '*macOS*') {
            $devShellIsMacSys = $true
        }
        elseif ($os) {
            # 有值且不是 Windows/macOS，大概率是 Linux（例如 "Ubuntu 24.04.3 LTS"）
            $devShellIsLinuxSys = $true
        }
    }
}

# 再兜一层 uname
if (-not ($devShellIsWindowsSys -or $devShellIsLinuxSys -or $devShellIsMacSys)) {
    if (Get-Command uname -ErrorAction SilentlyContinue) {
        try {
            $uname = uname
            if ($uname -like '*Linux*') {
                $devShellIsLinuxSys = $true
            } elseif ($uname -like '*Darwin*') {
                $devShellIsMacSys = $true
            }
        } catch { }
    }
}

$platform = if ($devShellIsWindowsSys) { 'Windows' } elseif ($devShellIsLinuxSys) { 'Linux' } elseif ($devShellIsMacSys) { 'macOS' } else { 'Unknown' }
Write-Host "[+] 检测到平台: $platform"

function Ensure-Command {
    param([Parameter(Mandatory = $true)][string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# ---------- Windows: 安装 PowerShell 7 ----------
if ($devShellIsWindowsSys -and $PSVersionTable.PSVersion.Major -lt 7) {
    if (Ensure-Command "winget") {
        Write-Host "[*] 检测到 Windows PowerShell，使用 winget 安装 PowerShell 7..."
        try {
            winget install Microsoft.PowerShell -s winget -h
            Write-Host "[+] PowerShell 7 安装完成，请使用 pwsh 重新运行本命令。" -ForegroundColor Yellow
        } catch {
            Write-Warning "自动安装 PowerShell 7 失败，请手动安装: https://learn.microsoft.com/powershell/"
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
        Write-Warning "无法自动安装 Oh My Posh，请参考: https://ohmyposh.dev"
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
        Write-Warning "请手动安装 zoxide: https://github.com/ajeetdsouza/zoxide"
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
        Write-Warning "PSReadLine 安装失败: $($_.Exception.Message)"
    }
}

# ---------- 执行安装 ----------
Install-OhMyPosh
Install-Zoxide
Ensure-PSReadLine

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
if ($null -eq $old) { $old = "" }

# 移除旧的 dev-shell 块
if ($old -match [regex]::Escape($markerStart)) {
    $old = $old -replace "$([regex]::Escape($markerStart)).*?$([regex]::Escape($markerEnd))", ""
}

# 用单引号 here-string，避免在生成时插值；实际执行发生在加载 profile 时
$devShellBlock = @'
# >>> dev-shell profile >>>

Import-Module PSReadLine -ErrorAction SilentlyContinue

Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Windows

# Linux/macOS: 确保 ~/.local/bin 在 PATH 中（zoxide / oh-my-posh 默认安装位置）
try {
    $isLinuxFlag  = (Get-Variable -Name IsLinux  -ErrorAction SilentlyContinue -ValueOnly)
    $isMacOSFlag  = (Get-Variable -Name IsMacOS  -ErrorAction SilentlyContinue -ValueOnly)
} catch { }

if ($isLinuxFlag -or $isMacOSFlag) {
    $localBin = "$HOME/.local/bin"
    if (Test-Path $localBin) {
        $paths = $env:PATH -split ':'
        if ($paths -notcontains $localBin) {
            $env:PATH = "${localBin}:" + $env:PATH
        }
    }
}

# Oh My Posh: 优先使用 amro 主题，不存在则回退默认配置
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    try {
        oh-my-posh init pwsh --config "amro" | Invoke-Expression
    } catch {
        oh-my-posh init pwsh | Invoke-Expression
    }
}

# zoxide: 智能 cd (z 命令)
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init pwsh | Out-String) })
}

# <<< dev-shell profile <<<
'@

$newProfile = (([string]$old).TrimEnd(), "", $devShellBlock.Trim()) -join "`n"
Set-Content -Path $profilePath -Value $newProfile -Encoding UTF8

Write-Host "[+] 已写入 Profile: $profilePath" -ForegroundColor Green
Write-Host ""
Write-Host "完成：" -ForegroundColor Cyan
Write-Host " - 重启 PowerShell / 运行 'pwsh' 生效" -ForegroundColor Cyan
Write-Host " - 功能: Oh My Posh 主题 + PSReadLine 智能提示 + zoxide 智能 cd" -ForegroundColor Cyan
