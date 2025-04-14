# 设置输出编码为 UTF-8
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 强制启用ANSI转义支持（PowerShell 7.2+）
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $PSStyle.OutputRendering = 'Ansi'  # [[1]][[8]]
}

# 颜色定义（修正转义字符）
$ESC = [char]27
$RED = "$ESC[31m"
$GREEN = "$ESC[32m"
$YELLOW = "$ESC[33m"
$BLUE = "$ESC[37m"
$NC = "$ESC[0m"

# 定义 hosts 文件路径
$HOSTS_FILE = "$env:SystemRoot\System32\drivers\etc\hosts"
$BACKUP_DIR = "$env:SystemRoot\System32\drivers\etc"

# 定义要查找的行
$TARGET_LINE = "192.168.2.125 one-dev.gs.com"

# 显示 Logo
function Show-Logo {
    Clear-Host
    Write-Host @"
$YELLOW
    ________  ____________    ____________________
         ____  __    _____   _____ _______ 
        / __ \/_ |  |  __ \ / ____|__   __|
        | |  | || | | |__) | |       | |   
        | |  | || | |  _  /| |       | |   
        | |__| || | | | \ \| |____   | |   
        \____/ |_|  |_|  \_\\_____|  |_|   
    ________  ____________    ____________________
                                        
                                            
    $NC o1-server 远程配置工具
    $NC 作者: semon
    $NC 版本: 1.3
"@
}

# 检查管理员权限
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "$RED[错误]$NC 请以管理员身份运行此脚本"
    Start-Process powershell "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# 备份 hosts 文件
function Backup-HostsFile {
    param (
        [string]$BackupDir,
        [string]$HostsFile
    )
    $BackupFile = Join-Path $BackupDir "hosts.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    try {
        Copy-Item -Path $HostsFile -Destination $BackupFile -ErrorAction Stop
        Write-Host "$GREEN[信息]$NC 已备份 hosts 文件到: $BackupFile"
        return $BackupFile
    }
    catch {
        Write-Host "$RED[错误]$NC 备份 hosts 文件失败: $_"
        exit 1
    }
}

# 列出所有备份文件
function List-BackupFiles {
    param (
        [string]$BackupDir
    )
    $backupFiles = Get-ChildItem -Path $BackupDir -Filter "hosts.backup_*" | Sort-Object CreationTime -Descending
    if ($backupFiles.Count -eq 0) {
        Write-Host "$YELLOW[警告]$NC 未找到任何备份文件"
        return $null
    }

    Write-Host "$BLUE[信息]$NC 可用备份文件列表："
    for ($i = 0; $i -lt $backupFiles.Count; $i++) {
        Write-Host "$($i + 1)) $($backupFiles[$i].Name) ($($backupFiles[$i].CreationTime))"
    }
    return $backupFiles
}

# 恢复指定备份文件
function Restore-BackupFile {
    param (
        [string]$BackupFile,
        [string]$HostsFile
    )
    try {
        Copy-Item -Path $BackupFile -Destination $HostsFile -Force -ErrorAction Stop
        Write-Host "$GREEN[信息]$NC 已恢复 hosts 文件: $BackupFile"
    }
    catch {
        Write-Host "$RED[错误]$NC 恢复 hosts 文件失败: $_"
        exit 1
    }
}

# 主逻辑开始
Show-Logo

# 检查 hosts 文件是否存在
if (-not (Test-Path $HOSTS_FILE)) {
    Write-Host "$RED[错误]$NC 未找到 hosts 文件: $HOSTS_FILE"
    exit 1
}

# 备份 hosts 文件
$BACKUP_FILE = Backup-HostsFile -BackupDir $BACKUP_DIR -HostsFile $HOSTS_FILE

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
    Write-Host "$GREEN[信息]$NC o1-server 配置已存在: $TARGET_LINE"
}
else {
    Write-Host "$YELLOW[信息]$NC o1-server 配置未写入: $TARGET_LINE"
}

# 主循环
while ($true) {
    # 提供操作选项
    Write-Host ""
    Write-Host "$YELLOW[操作选项]$NC"
    if ($lineExists) {
        Write-Host "1) 删除 o1-server 配置"
    } else {
        Write-Host "1) 写入 o1-server 配置"
    }
    Write-Host "2) 恢复指定备份"
    Write-Host "3) 退出"
    $choice = Read-Host "请输入选项 (3)"

    switch ($choice) {
        1 {
            try {
                if ($lineExists) {
                    # 删除目标行并清理多余空行
                    $newContent = ($hostsContent -split "`n" | Where-Object { $_.Trim() -ne $TARGET_LINE.Trim() }) -join "`n"
                    [System.IO.File]::WriteAllText($HOSTS_FILE, $newContent, [System.Text.Encoding]::UTF8)
                    Write-Host "$GREEN[信息]$NC 已删除 o1-server 配置: $TARGET_LINE"
                }
                else {
                    # 写入目标行
                    Add-Content -Path $HOSTS_FILE -Value $TARGET_LINE -Encoding UTF8 -ErrorAction Stop
                    Write-Host "$GREEN[信息]$NC 已写入 o1-server 配置: $TARGET_LINE"
                }
                # 更新状态
                $hostsContent = Get-Content $HOSTS_FILE -Raw
                $lineExists = ($hostsContent -split "`n" | ForEach-Object { $_.Trim() }) -contains $TARGET_LINE.Trim()
            }
            catch {
                Write-Host "$RED[错误]$NC 操作失败: $_"
                # 恢复备份
                Restore-BackupFile -BackupFile $BACKUP_FILE -HostsFile $HOSTS_FILE
            }
        }
        2 {
            # 列出备份文件并恢复
            $backupFiles = List-BackupFiles -BackupDir $BACKUP_DIR
            if ($backupFiles -ne $null) {
                $selected = Read-Host "请选择要恢复的备份编号"
                if ([int]$selected -ge 1 -and [int]$selected -le $backupFiles.Count) {
                    $selectedBackup = $backupFiles[[int]$selected - 1].FullName
                    Restore-BackupFile -BackupFile $selectedBackup -HostsFile $HOSTS_FILE
                    # 更新状态
                    $hostsContent = Get-Content $HOSTS_FILE -Raw
                    $lineExists = ($hostsContent -split "`n" | ForEach-Object { $_.Trim() }) -contains $TARGET_LINE.Trim()
                }
                else {
                    Write-Host "$RED[错误]$NC 无效的编号，取消恢复操作"
                }
            }
        }
        3 {
            Write-Host "$GREEN[信息]$NC 退出脚本"
            exit 0
        }
        default {
            Write-Host "$RED[错误]$NC 无效选项，请重新选择"
        }
    }

    # 刷新页面
    Show-Logo

    # 显示当前状态
    if ($lineExists) {
        Write-Host "$GREEN[信息]$NC o1-server 配置已存在: $TARGET_LINE"
    }
    else {
        Write-Host "$YELLOW[信息]$NC o1-server 配置未写入: $TARGET_LINE"
    }
}