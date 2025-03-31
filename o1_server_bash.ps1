# 设置输出编码为 UTF-8
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 颜色定义
$RED = "`e[31m"
$GREEN = "`e[32m"
$YELLOW = "`e[33m"
$BLUE = "`e[34m"
$NC = "`e[0m"

# 定义 hosts 文件路径
$HOSTS_FILE = "$env:SystemRoot\System32\drivers\etc\hosts"

# 定义要查找的行
$TARGET_LINE = "192.168.2.125 o1-server.gs.com"

# 检查管理员权限
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "$RED[错误]$NC 请以管理员身份运行此脚本"
    Start-Process powershell "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# 检查 hosts 文件是否存在
if (-not (Test-Path $HOSTS_FILE)) {
    Write-Host "$RED[错误]$NC 未找到 hosts 文件: $HOSTS_FILE"
    exit 1
}

# 备份 hosts 文件
$BACKUP_FILE = "$env:SystemRoot\System32\drivers\etc\hosts.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
try {
    Copy-Item -Path $HOSTS_FILE -Destination $BACKUP_FILE -ErrorAction Stop
    Write-Host "$GREEN[信息]$NC 已备份 hosts 文件到: $BACKUP_FILE"
}
catch {
    Write-Host "$RED[错误]$NC 备份 hosts 文件失败: $_"
    exit 1
}

# 读取 hosts 文件内容
try {
    $hostsContent = Get-Content $HOSTS_FILE -Raw -ErrorAction Stop
}
catch {
    Write-Host "$RED[错误]$NC 读取 hosts 文件失败: $_"
    exit 1
}

# 判断是否存在目标行（忽略前后空格并处理换行符）
$lineExists = ($hostsContent -split "`n" | ForEach-Object { $_.Trim() }) -contains $TARGET_LINE.Trim()

# 显示当前状态
if ($lineExists) {
    Write-Host "$GREEN[信息]$NC 已找到目标行: $TARGET_LINE"
}
else {
    Write-Host "$YELLOW[信息]$NC 未找到目标行: $TARGET_LINE"
}

# 提供操作选项
Write-Host ""
Write-Host "$YELLOW[操作选项]$NC"
if ($lineExists) {
    Write-Host "1) 删除目标行"
} else {
    Write-Host "1) 写入目标行"
}

Write-Host "2) 退出"
$choice = Read-Host "请输入选项 (2)"

# 处理用户选择
switch ($choice) {
    1 {
        try {
            if ($lineExists) {
                # 删除目标行并清理多余空行
                $newContent = ($hostsContent -split "`n" | Where-Object { $_ -ne $TARGET_LINE }) -join "`n"
                [System.IO.File]::WriteAllText($HOSTS_FILE, $newContent, [System.Text.Encoding]::UTF8)
                Write-Host "$GREEN[信息]$NC 已删除目标行: $TARGET_LINE"
            }
            else {
                # 写入目标行
                Add-Content -Path $HOSTS_FILE -Value $TARGET_LINE -Encoding UTF8 -ErrorAction Stop
                Write-Host "$GREEN[信息]$NC 已写入目标行: $TARGET_LINE"
            }
        }
        catch {
            Write-Host "$RED[错误]$NC 操作失败: $_"
            # 恢复备份
            try {
                Copy-Item -Path $BACKUP_FILE -Destination $HOSTS_FILE -Force -ErrorAction Stop
                Write-Host "$GREEN[信息]$NC 已恢复 hosts 文件"
            }
            catch {
                Write-Host "$RED[错误]$NC 恢复 hosts 文件失败: $_"
            }
            exit 1
        }
    }
    2 {
        Write-Host "$GREEN[信息]$NC 退出脚本"
        exit 0
    }
    default {
        Write-Host "$RED[错误]$NC 无效选项，退出脚本"
        exit 1
    }
}

Write-Host ""
Read-Host "按回车键退出"
exit 0