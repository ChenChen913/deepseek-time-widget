#Requires -Version 5.1
<#
  test/Test-Installer.ps1 —— 安装包冒烟测试

  验证真实安装包的关键链路：
    静默安装 -> 检查文件和安装标记 -> CLI 运行 -> 启动器拉起挂件
    -> 检查自启项 -> 静默卸载 -> 检查清理和设置保留

  运行前请先退出正在运行的挂件，否则安装器的 AppMutex 会阻止安装。

  跑法：
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\Test-Installer.ps1
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\Test-Installer.ps1 -SetupPath .\dist\DeepSeekClock-Setup-v1.2.0.exe -TestAutoStart

  退出码 0 = 全部通过；非 0 = 存在失败。
#>
[CmdletBinding()]
param(
    [string]$SetupPath = '',
    [switch]$TestAutoStart
)

$ErrorActionPreference = 'Stop'

$script:Root = Split-Path -Parent $PSScriptRoot
$script:AppName = 'DeepSeek 时段挂件'
$script:RunKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$script:RunValueName = 'DeepSeekClockWidget'
$script:ApprovedKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
$script:Pass = 0
$script:Fail = 0
$script:Fatal = $null

function Assert-True {
    param([bool]$Condition, [string]$Name, [string]$Detail = '')
    if ($Condition) {
        $script:Pass++
    } else {
        $script:Fail++
        $line = '  [FAIL] ' + $Name
        if ($Detail) { $line = $line + ' | ' + $Detail }
        Write-Host $line -ForegroundColor Red
    }
}

function Get-WidgetProcesses {
    param([string]$PathPattern = '')
    $result = @()
    foreach ($process in @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue)) {
        if ($process.CommandLine -notmatch '-STA') { continue }
        if ($process.CommandLine -notmatch 'DeepSeekClock\.ps1') { continue }
        if ($PathPattern -and ($process.CommandLine -notmatch ([regex]::Escape($PathPattern)))) { continue }
        $result += $process
    }
    return $result
}

function Get-InstallEntry {
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
    if (-not (Test-Path -LiteralPath $key)) { return $null }
    $entry = Get-ChildItem -LiteralPath $key -ErrorAction SilentlyContinue |
        ForEach-Object { Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue } |
        Where-Object { $_.DisplayName -eq $script:AppName } |
        Select-Object -First 1
    return $entry
}

function Restore-RegistryValue {
    param(
        [string]$Key,
        [string]$Name,
        [object]$Value,
        [bool]$HadValue,
        [string]$PropertyType = 'String'
    )
    try {
        if (-not (Test-Path -LiteralPath $Key)) {
            New-Item -Path $Key -Force | Out-Null
        }
        if ($HadValue) {
            New-ItemProperty -LiteralPath $Key -Name $Name -Value $Value -PropertyType $PropertyType -Force | Out-Null
        } else {
            Remove-ItemProperty -LiteralPath $Key -Name $Name -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Warning ('恢复注册表值失败：' + $Key + '\' + $Name + '，' + $_.Exception.Message)
    }
}

if ([string]::IsNullOrWhiteSpace($SetupPath)) {
    $setup = Get-ChildItem -LiteralPath (Join-Path $script:Root 'dist') -Filter 'DeepSeekClock-Setup-v*.exe' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $setup) {
        throw '找不到安装包，请先运行 tools\build-release.ps1。'
    }
    $SetupPath = $setup.FullName
}
if (-not (Test-Path -LiteralPath $SetupPath)) {
    throw ('安装包不存在：' + $SetupPath)
}

$running = @(Get-WidgetProcesses)
if ($running.Count -gt 0) {
    throw '检测到挂件正在运行，请先退出挂件后再运行安装包测试。'
}

$existing = Get-InstallEntry
if ($null -ne $existing) {
    throw ('检测到已安装版本，请先卸载：' + [string]$existing.InstallLocation)
}

$runBackup = $null
$hasRunBackup = $false
try {
    if (Test-Path -LiteralPath $script:RunKey) {
        $runBackup = Get-ItemPropertyValue -Path $script:RunKey -Name $script:RunValueName -ErrorAction Stop
        $hasRunBackup = $true
    }
} catch { }

$approvedBackup = $null
$hasApprovedBackup = $false
try {
    if (Test-Path -LiteralPath $script:ApprovedKey) {
        $approvedBackup = Get-ItemPropertyValue -Path $script:ApprovedKey -Name $script:RunValueName -ErrorAction Stop
        $hasApprovedBackup = $true
    }
} catch { }

$settingsDir = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'DeepSeekClock'
$settingsExisted = Test-Path -LiteralPath $settingsDir
$installDir = Join-Path $env:TEMP ('dsc-installer-test-' + [Guid]::NewGuid().ToString('N'))
$setupLog = Join-Path $env:TEMP ('dsc-installer-setup-' + [Guid]::NewGuid().ToString('N') + '.log')
$uninstallLog = Join-Path $env:TEMP ('dsc-installer-uninstall-' + [Guid]::NewGuid().ToString('N') + '.log')
$startMenuDir = Join-Path ([Environment]::GetFolderPath('Programs')) $script:AppName
$launcherExe = Join-Path $installDir 'DeepSeekClock.exe'
$appScript = Join-Path $installDir 'DeepSeekClock.ps1'

Write-Host ('安装包：' + $SetupPath)
Write-Host ('测试目录：' + $installDir)

try {
    $setupArgs = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /NOICONS /DIR="' + $installDir + '" /LOG="' + $setupLog + '"'
    if ($TestAutoStart) {
        $setupArgs = $setupArgs + ' /TASKS="autostart"'
    } else {
        $setupArgs = $setupArgs + ' /TASKS=""'
    }
    $setupProcess = Start-Process -FilePath $SetupPath -ArgumentList $setupArgs -Wait -PassThru
    Assert-True ($setupProcess.ExitCode -eq 0) '安装器退出码为 0' ([string]$setupProcess.ExitCode)
    if ($setupProcess.ExitCode -ne 0) { throw '安装器执行失败。' }

    Assert-True (Test-Path -LiteralPath $installDir) '安装目录已创建' $installDir
    Assert-True (Test-Path -LiteralPath (Join-Path $installDir 'install.marker')) '安装标记存在' ''
    Assert-True (Test-Path -LiteralPath $launcherExe) 'EXE 启动器存在' ''
    Assert-True (Test-Path -LiteralPath $appScript) '主程序存在' ''
    Assert-True (Test-Path -LiteralPath (Join-Path $installDir 'lib\DeepSeekTime.ps1')) '核心库存在' ''
    Assert-True (Test-Path -LiteralPath (Join-Path $installDir 'lib\Schemes.ps1')) '方案库存在' ''
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $installDir '启动挂件.vbs'))) '安装包不包含 VBS' ''
    Assert-True (Test-Path -LiteralPath (Join-Path $installDir 'unins000.exe')) '卸载器存在' ''
    Assert-True ($null -ne (Get-InstallEntry)) '卸载入口已注册' ''

    $cliOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $appScript -PrintStatus 2>&1 | Out-String
    $cliExit = $LASTEXITCODE
    Assert-True ($cliExit -eq 0) '安装后的 -PrintStatus 正常退出' ([string]$cliExit)
    Assert-True ($cliOutput -match '"StatusText"') '安装后的 CLI 输出包含 StatusText' ''

    Assert-True (Test-Path -LiteralPath $startMenuDir) '开始菜单组已创建' $startMenuDir

    if ($TestAutoStart) {
        $runValue = $null
        try { $runValue = Get-ItemPropertyValue -Path $script:RunKey -Name $script:RunValueName -ErrorAction Stop } catch { }
        $expected = '"' + $launcherExe + '"'
        Assert-True ($runValue -eq $expected) '安装器写入自启项' ([string]$runValue)
    }

    Start-Process -FilePath $launcherExe
    $launcherProcess = $null
    for ($i = 0; $i -lt 12; $i++) {
        Start-Sleep -Milliseconds 500
        $launcherProcess = Get-WidgetProcesses -PathPattern $installDir | Select-Object -First 1
        if ($null -ne $launcherProcess) { break }
    }
    Assert-True ($null -ne $launcherProcess) '启动器拉起了挂件进程' ''
    if ($null -ne $launcherProcess) {
        Stop-Process -Id $launcherProcess.ProcessId -Force
        Start-Sleep -Seconds 1
    }

    $uninstaller = Join-Path $installDir 'unins000.exe'
    $uninstallArgs = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /LOG="' + $uninstallLog + '"'
    $uninstallProcess = Start-Process -FilePath $uninstaller -ArgumentList $uninstallArgs -Wait -PassThru
    Assert-True ($uninstallProcess.ExitCode -eq 0) '卸载器退出码为 0' ([string]$uninstallProcess.ExitCode)
    Assert-True (-not (Test-Path -LiteralPath $installDir)) '卸载后安装目录已删除' ''
    Assert-True ($null -eq (Get-InstallEntry)) '卸载入口已移除' ''
    Assert-True (-not (Test-Path -LiteralPath $startMenuDir)) '开始菜单组已删除' ''
    Assert-True ((Test-Path -LiteralPath $settingsDir) -eq $settingsExisted) '卸载默认保留设置目录' ''
    if ($TestAutoStart) {
        $runValue = $null
        try { $runValue = Get-ItemPropertyValue -Path $script:RunKey -Name $script:RunValueName -ErrorAction Stop } catch { }
        Assert-True ($null -eq $runValue) '卸载后自启项已移除' ([string]$runValue)
    }
} catch {
    $script:Fatal = $_
    $script:Fail++
} finally {
    foreach ($process in @(Get-WidgetProcesses -PathPattern $installDir)) {
        try { Stop-Process -Id $process.ProcessId -Force } catch { }
    }
    if (Test-Path -LiteralPath $installDir) {
        $cleanupUninstaller = Join-Path $installDir 'unins000.exe'
        if (Test-Path -LiteralPath $cleanupUninstaller) {
            try {
                Start-Process -FilePath $cleanupUninstaller -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART' -Wait | Out-Null
            } catch { }
        }
        try { Remove-Item -LiteralPath $installDir -Recurse -Force } catch { }
    }
    Restore-RegistryValue -Key $script:RunKey -Name $script:RunValueName -Value $runBackup -HadValue $hasRunBackup -PropertyType 'String'
    Restore-RegistryValue -Key $script:ApprovedKey -Name $script:RunValueName -Value $approvedBackup -HadValue $hasApprovedBackup -PropertyType 'Binary'
}

Write-Host ''
Write-Host ('测试完成：通过 ' + $script:Pass + ' 项，失败 ' + $script:Fail + ' 项。')
if ($script:Fail -gt 0) {
    if ($null -ne $script:Fatal) {
        Write-Host ('致命错误：' + $script:Fatal.Exception.Message) -ForegroundColor Red
    }
    if (Test-Path -LiteralPath $setupLog) {
        Write-Host '--- 安装日志末尾 ---' -ForegroundColor Yellow
        Get-Content -LiteralPath $setupLog -ErrorAction SilentlyContinue | Select-Object -Last 20
    }
    if (Test-Path -LiteralPath $uninstallLog) {
        Write-Host '--- 卸载日志末尾 ---' -ForegroundColor Yellow
        Get-Content -LiteralPath $uninstallLog -ErrorAction SilentlyContinue | Select-Object -Last 20
    }
    exit 1
}
Write-Host '全部通过。' -ForegroundColor Green
exit 0
