#Requires -Version 5.1
<#
.SYNOPSIS
  DeepSeek 计费时段桌面挂件（Windows 桌面小挂件）。

.DESCRIPTION
  实时显示当前处于 DeepSeek 高峰时段还是空闲时段：
    · 高峰时段：北京时间周一至周五（不含中国法定节假日）09:00-12:00、14:00-18:00
    · 空闲时段：其余所有时间，包括周末及中国法定节假日全天（价格减半）

.PARAMETER PreviewTime
  调试/截图用：把“当前时间”固定到指定的 ISO 8601 时刻（如 2026-10-28T20:15:00+08:00）。

.PARAMETER CapturePath
  调试/截图用：窗口渲染完成后截图保存到该路径，然后自动退出。

.PARAMETER PrintStatus
  命令行调试用：不显示界面，直接输出当前时段状态 JSON 后退出。

.PARAMETER InstallDesktopShortcut
  命令行用：创建/修复桌面快捷方式后退出。
#>
[CmdletBinding()]
param(
    [string]$PreviewTime = '',
    [string]$CapturePath = '',
    [string]$CycleCapture = '',
    [string]$UiScheme = '',
    [switch]$PrintStatus,
    [switch]$InstallDesktopShortcut,
    [switch]$EnableAutoStart,
    [switch]$DisableAutoStart
)

$ErrorActionPreference = 'Stop'

$script:AppDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($script:AppDir)) {
    $script:AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$script:DataPath = Join-Path $script:AppDir 'holidays.json'
$script:SettingsDir = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'DeepSeekClock'
$script:SettingsPath = Join-Path $script:SettingsDir 'settings.json'
# 联网更新后的节假日数据写到用户目录，避免程序装在 Program Files 等只读位置时写入失败
$script:UserDataPath = Join-Path $script:SettingsDir 'holidays.json'
$script:IconPath = Join-Path $script:AppDir 'assets\deepseek-clock.ico'
$script:LauncherPath = Join-Path $script:AppDir '启动挂件.vbs'
$script:RequestedCapturePath = $CapturePath
$script:CycleCaptureDir = $CycleCapture

$script:LibPath = Join-Path $script:AppDir 'lib\DeepSeekTime.ps1'
if (-not (Test-Path -LiteralPath $script:LibPath)) {
    throw ('Core library not found: ' + $script:LibPath)
}
. $script:LibPath

$script:SchemesPath = Join-Path $script:AppDir 'lib\Schemes.ps1'
if (-not (Test-Path -LiteralPath $script:SchemesPath)) {
    throw ('Scheme library not found: ' + $script:SchemesPath)
}
. $script:SchemesPath

# ============================ 通用函数 ============================

function ConvertTo-Brush {
    param([string]$ColorText)
    $color = [System.Windows.Media.ColorConverter]::ConvertFromString($ColorText)
    return [System.Windows.Media.SolidColorBrush]::new($color)
}

function Show-Dialog {
    param(
        [string]$Message,
        [string]$Title = 'DeepSeek 时段挂件',
        [string]$Kind = 'Information'
    )
    $button = [System.Windows.MessageBoxButton]::OK
    $image = [System.Windows.MessageBoxImage]::Information
    if ($Kind -eq 'Warning') { $image = [System.Windows.MessageBoxImage]::Warning }
    if ($Kind -eq 'Error') { $image = [System.Windows.MessageBoxImage]::Error }
    if ($null -ne $script:Window) {
        [void][System.Windows.MessageBox]::Show($script:Window, $Message, $Title, $button, $image)
        return
    }
    [void][System.Windows.MessageBox]::Show($Message, $Title, $button, $image)
}

function Get-HolidayDataPath {
    # 用户目录里的数据优先（联网更新写在这里），否则用程序自带的 holidays.json
    if (Test-Path -LiteralPath $script:UserDataPath) { return $script:UserDataPath }
    return $script:DataPath
}

function Load-HolidayData {
    $result = [pscustomobject]@{
        Holidays = @()
        Years    = @()
        Names    = @{}
        Updated  = ''
        Source   = ''
        Loaded   = $false
        Error    = ''
        Path     = ''
    }
    $readPath = Get-HolidayDataPath
    $result.Path = $readPath
    if (-not (Test-Path -LiteralPath $readPath)) {
        $result.Error = '找不到 holidays.json'
        return $result
    }
    try {
        $rawText = Get-Content -LiteralPath $readPath -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($rawText)) {
            $result.Error = '数据文件为空'
            return $result
        }
        $json = $rawText | ConvertFrom-Json
        $holidayList = New-Object System.Collections.Generic.List[string]
        $yearList = New-Object System.Collections.Generic.List[int]
        if ($null -ne $json.holidays) {
            foreach ($prop in $json.holidays.PSObject.Properties) {
                $year = 0
                if ([int]::TryParse($prop.Name, [ref]$year)) { $yearList.Add($year) }
                foreach ($item in @($prop.Value)) {
                    if ($null -ne $item -and $item -ne '') { $holidayList.Add([string]$item) }
                }
            }
        }
        $names = @{}
        if ($null -ne $json.holidayNames) {
            foreach ($prop in $json.holidayNames.PSObject.Properties) {
                $names[[string]$prop.Name] = [string]$prop.Value
            }
        }
        $result.Holidays = $holidayList.ToArray()
        $result.Years = $yearList.ToArray()
        $result.Names = $names
        $result.Updated = [string]$json.updated
        $result.Source = [string]$json.source
        $result.Loaded = $true
    } catch {
        $result.Error = '数据文件解析失败：' + $_.Exception.Message
    }
    return $result
}

function Get-CoverageText {
    param([object]$Data)
    if ($null -eq $Data -or -not $Data.Loaded -or $Data.Years.Count -eq 0) {
        return '节假日数据：未加载'
    }
    $years = @($Data.Years | Sort-Object | ForEach-Object { [string]$_ })
    return ('节假日数据：' + ($years -join '、') + ' 年')
}

function New-ShortcutFile {
    param(
        [string]$ShortcutPath,
        [string]$TargetPath,
        [string]$Arguments,
        [string]$WorkingDirectory,
        [string]$Description
    )
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = $TargetPath
    $shortcut.Arguments = $Arguments
    $shortcut.WorkingDirectory = $WorkingDirectory
    $shortcut.Description = $Description
    if (Test-Path -LiteralPath $script:IconPath) {
        $shortcut.IconLocation = $script:IconPath + ',0'
    }
    $shortcut.Save()
}

function Get-DesktopShortcutPath {
    $desktop = [Environment]::GetFolderPath('Desktop')
    if ([string]::IsNullOrWhiteSpace($desktop)) { $desktop = Join-Path $env:USERPROFILE 'Desktop' }
    return (Join-Path $desktop 'DeepSeek 时段挂件.lnk')
}

function Get-StartupShortcutPath {
    $startup = [Environment]::GetFolderPath('Startup')
    return (Join-Path $startup 'DeepSeek 时段挂件.lnk')
}

function Get-LauncherArguments {
    return ('"' + $script:LauncherPath + '"')
}

function Create-DesktopShortcut {
    $shortcutPath = Get-DesktopShortcutPath
    New-ShortcutFile -ShortcutPath $shortcutPath -TargetPath (Join-Path $env:SystemRoot 'System32\wscript.exe') -Arguments (Get-LauncherArguments) -WorkingDirectory $script:AppDir -Description 'DeepSeek 计费时段挂件：显示当前高峰/空闲时段'
    return $shortcutPath
}

function Test-AutoStartEnabled {
    return (Test-Path -LiteralPath (Get-StartupShortcutPath))
}

function Set-AutoStartEnabled {
    param([bool]$Enabled)
    $shortcutPath = Get-StartupShortcutPath
    if ($Enabled) {
        New-ShortcutFile -ShortcutPath $shortcutPath -TargetPath (Join-Path $env:SystemRoot 'System32\wscript.exe') -Arguments (Get-LauncherArguments) -WorkingDirectory $script:AppDir -Description 'DeepSeek 计费时段挂件（开机自动启动）'
        return
    }
    if (Test-Path -LiteralPath $shortcutPath) {
        Remove-Item -LiteralPath $shortcutPath -Force
    }
}

function Get-HttpText {
    param([string]$Url, [int]$TimeoutMs = 12000)
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls11 -bor [System.Net.SecurityProtocolType]::Tls
    } catch { }
    $request = [System.Net.WebRequest]::Create($Url)
    $request.Method = 'GET'
    $request.Timeout = $TimeoutMs
    $request.ReadWriteTimeout = $TimeoutMs
    $request.UserAgent = 'DeepSeekClockWidget/1.0'
    $request.Accept = 'application/json'
    $response = $request.GetResponse()
    try {
        $stream = $response.GetResponseStream()
        $reader = New-Object -TypeName System.IO.StreamReader -ArgumentList @($stream, [System.Text.Encoding]::UTF8)
        return $reader.ReadToEnd()
    } finally {
        $response.Close()
    }
}

function Update-HolidaysOnline {
    $now = Get-BeijingNow
    $currentYear = [int]$now.Year
    $targetYears = @($currentYear, ($currentYear + 1))
    $fetchedHolidays = @{}
    $fetchedNames = @{}
    $errors = New-Object System.Collections.Generic.List[string]

    foreach ($year in $targetYears) {
        $url = 'https://timor.tech/api/holiday/year/' + $year
        try {
            $text = Get-HttpText -Url $url
            $json = $text | ConvertFrom-Json
            if ($null -eq $json -or $json.code -ne 0 -or $null -eq $json.holiday) {
                $errors.Add(('{0} 年：接口无有效数据' -f $year))
                continue
            }
            $dates = New-Object System.Collections.Generic.List[string]
            foreach ($prop in $json.holiday.PSObject.Properties) {
                $value = $prop.Value
                if ($null -eq $value) { continue }
                if ($value.holiday -ne $true) { continue }
                $dateText = [string]$value.date
                if ($dateText -notmatch '^\d{4}-\d{2}-\d{2}$') { continue }
                if (-not $dates.Contains($dateText)) { $dates.Add($dateText) }
                if ($value.name -and -not $fetchedNames.ContainsKey($dateText)) {
                    $fetchedNames[$dateText] = [string]$value.name
                }
            }
            if ($dates.Count -eq 0) {
                $errors.Add(('{0} 年：暂未公布节假日数据' -f $year))
                continue
            }
            $fetchedHolidays[$year] = $dates.ToArray()
        } catch {
            $errors.Add(('{0} 年：{1}' -f $year, $_.Exception.Message))
        }
    }

    if ($fetchedHolidays.Count -eq 0) {
        return [pscustomobject]@{ Success = $false; Message = ('联网更新失败：' + ($errors -join '；')) }
    }

    # 先读出现有数据，完整保留 holidays.json 里的其它字段（makeupWorkdays / sources / notes 等），
    # 只覆盖本次真正更新的字段，避免"联网更新一次就把证据链抹掉"。
    $readPath = Get-HolidayDataPath
    $existing = $null
    if (Test-Path -LiteralPath $readPath) {
        try {
            $rawText = Get-Content -LiteralPath $readPath -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($rawText)) { $existing = $rawText | ConvertFrom-Json }
        } catch {
            $existing = $null
        }
    }

    $mergedHolidays = [ordered]@{}
    if ($null -ne $existing -and $null -ne $existing.holidays) {
        foreach ($prop in $existing.holidays.PSObject.Properties) {
            $dates = @($prop.Value | Sort-Object -Unique)
            if ($dates.Count -gt 0) { $mergedHolidays[[string]$prop.Name] = $dates }
        }
    }
    foreach ($year in @($fetchedHolidays.Keys | Sort-Object)) {
        $mergedHolidays[[string]$year] = @($fetchedHolidays[$year] | Sort-Object -Unique)
    }

    $mergedNames = [ordered]@{}
    if ($null -ne $existing -and $null -ne $existing.holidayNames) {
        foreach ($prop in $existing.holidayNames.PSObject.Properties) { $mergedNames[[string]$prop.Name] = [string]$prop.Value }
    }
    foreach ($key in $fetchedNames.Keys) { $mergedNames[[string]$key] = [string]$fetchedNames[$key] }
    $sortedNames = [ordered]@{}
    foreach ($key in @($mergedNames.Keys | Sort-Object)) { $sortedNames[[string]$key] = [string]$mergedNames[$key] }

    $payload = [ordered]@{}
    if ($null -ne $existing) {
        foreach ($prop in $existing.PSObject.Properties) { $payload[[string]$prop.Name] = $prop.Value }
    }
    $payload['updated'] = $now.ToString('yyyy-MM-dd')
    $payload['source'] = '国务院办公厅节假日安排（通过 timor.tech API 同步）'
    $payload['coverageYears'] = @($mergedHolidays.Keys | ForEach-Object { [int]$_ })
    $payload['holidays'] = $mergedHolidays
    $payload['holidayNames'] = $sortedNames

    $jsonText = $payload | ConvertTo-Json -Depth 6
    if (-not (Test-Path -LiteralPath $script:SettingsDir)) {
        New-Item -ItemType Directory -Path $script:SettingsDir -Force | Out-Null
    }
    if (Test-Path -LiteralPath $readPath) {
        try { Copy-Item -LiteralPath $readPath -Destination ($readPath + '.bak') -Force } catch { }
    }
    [System.IO.File]::WriteAllText($script:UserDataPath, $jsonText, (New-Object System.Text.UTF8Encoding($false)))

    $counts = @()
    foreach ($year in @($fetchedHolidays.Keys | Sort-Object)) {
        $counts += ('{0} 年 {1} 天' -f $year, @($fetchedHolidays[$year]).Count)
    }
    $message = '节假日数据已更新：' + ($counts -join '，') + '。'
    $pendingYears = @()
    foreach ($year in $targetYears) {
        if (-not $fetchedHolidays.ContainsKey($year)) { $pendingYears += [string]$year }
    }
    if ($pendingYears.Count -gt 0) {
        $message = $message + ($pendingYears -join '、') + ' 年暂未公布，后续可再次更新。'
    }
    return [pscustomobject]@{ Success = $true; Message = $message }
}

function Load-Settings {
    $settings = [pscustomobject]@{ Left = $null; Top = $null; Topmost = $true; LaunchCount = 0; UiScheme = 'default' }
    try {
        if (Test-Path -LiteralPath $script:SettingsPath) {
            $raw = Get-Content -LiteralPath $script:SettingsPath -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($raw)) {
                $json = $raw | ConvertFrom-Json
                if ($null -ne $json.Left) { $settings.Left = [double]$json.Left }
                if ($null -ne $json.Top) { $settings.Top = [double]$json.Top }
                if ($null -ne $json.Topmost) { $settings.Topmost = [bool]$json.Topmost }
                if ($null -ne $json.LaunchCount) { $settings.LaunchCount = [int]$json.LaunchCount }
                if (-not [string]::IsNullOrWhiteSpace([string]$json.UiScheme)) { $settings.UiScheme = [string]$json.UiScheme }
            }
        }
    } catch { }
    if ([string]$settings.UiScheme -eq 'classic') { $settings.UiScheme = 'default' }
    if ([string]$settings.UiScheme -eq 'ember') { $settings.UiScheme = 'b5' }
    if ([string]$settings.UiScheme -eq 'block') { $settings.UiScheme = 'c6' }
    if ([string]$settings.UiScheme -eq 'brutal') { $settings.UiScheme = 'e3' }
    return $settings
}

function Save-Settings {
    # 截图 / 循环截图是临时进程，绝不能回写用户的 settings.json
    if ((-not [string]::IsNullOrWhiteSpace($script:RequestedCapturePath)) -or (-not [string]::IsNullOrWhiteSpace($script:CycleCaptureDir))) { return }
    try {
        $left = [double]$script:Window.Left
        $top = [double]$script:Window.Top
        if ([double]::IsNaN($left) -or [double]::IsNaN($top)) { return }
        if ($left -lt -10000 -or $left -gt 10000 -or $top -lt -10000 -or $top -gt 10000) { return }
        if (-not (Test-Path -LiteralPath $script:SettingsDir)) {
            New-Item -ItemType Directory -Path $script:SettingsDir -Force | Out-Null
        }
        $payload = [ordered]@{
            Left        = $left
            Top         = $top
            Topmost     = [bool]$script:Window.Topmost
            LaunchCount = [int]$script:Settings.LaunchCount
            UiScheme    = [string]$script:Settings.UiScheme
        }
        $jsonText = $payload | ConvertTo-Json
        [System.IO.File]::WriteAllText($script:SettingsPath, $jsonText, (New-Object System.Text.UTF8Encoding($false)))
    } catch { }
}

function ConvertFrom-PreviewTimeText {
    param([string]$Text)
    $parsed = [DateTimeOffset]::MinValue
    $ok = [DateTimeOffset]::TryParse($Text, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)
    if (-not $ok) {
        throw ('无法识别的时间参数 -PreviewTime：' + $Text + '。正确示例：2026-10-28T20:15:00+08:00')
    }
    return $parsed
}

# ============================ 命令行模式 ============================

if ($InstallDesktopShortcut) {
    $shortcutPath = Create-DesktopShortcut
    Write-Output ('桌面快捷方式已创建：' + $shortcutPath)
    return
}

if ($EnableAutoStart) {
    Set-AutoStartEnabled -Enabled $true
    Write-Output ('已开启开机自动启动：' + (Get-StartupShortcutPath))
    return
}

if ($DisableAutoStart) {
    Set-AutoStartEnabled -Enabled $false
    Write-Output '已关闭开机自动启动。'
    return
}

if ($PrintStatus) {
    $statusData = Load-HolidayData
    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
    $now = Get-BeijingNow
    if ($PreviewTime) {
        try {
            $now = ConvertFrom-PreviewTimeText -Text $PreviewTime
        } catch {
            [Console]::Error.WriteLine($_.Exception.Message)
            exit 2
        }
    }
    $status = Get-DeepSeekTimeStatus -Time $now -Holidays $statusData.Holidays -CoveredYears $statusData.Years -HolidayNames $statusData.Names
    $nextChangeText = ''
    if ($null -ne $status.NextChange) { $nextChangeText = $status.NextChange.ToString('yyyy-MM-dd HH:mm:ss zzz') }
    $output = [pscustomobject]@{
        Now              = $status.Now.ToString('yyyy-MM-dd HH:mm:ss zzz')
        IsPeak           = $status.IsPeak
        StatusText       = $status.StatusText
        RateText         = $status.RateText
        DateText         = $status.DateText
        WeekText         = $status.WeekText
        TimeText         = $status.TimeText
        HolidayName      = $status.HolidayName
        YearCovered      = $status.YearCovered
        NextChange       = $nextChangeText
        NextChangeIsPeak = $status.NextChangeIsPeak
        NextChangeText   = $status.NextChangeText
        CountdownText    = $status.CountdownText
        TodayText        = $status.TodayText
        DataYears        = ($statusData.Years -join ',')
        DataLoaded       = $statusData.Loaded
        DataError        = $statusData.Error
    }
    $output | ConvertTo-Json -Depth 4
    return
}

# ============================ 界面模式 ============================

if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    [Console]::Error.WriteLine('DeepSeek 时段挂件需要 STA 线程运行，请通过“启动挂件.vbs”或桌面快捷方式启动。')
    exit 1
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

try {
    if (-not ('DeepSeekClock.Win32Api' -as [type])) {
        Add-Type -Namespace DeepSeekClock -Name Win32Api -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool SetProcessDPIAware();

[System.Runtime.InteropServices.DllImport("user32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
public static extern uint RegisterWindowMessage(string lpString);

[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true)]
public static extern bool PostMessage(System.IntPtr hWnd, uint msg, System.IntPtr wParam, System.IntPtr lParam);

[System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
public struct RECT
{
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
}

[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool GetWindowRect(System.IntPtr hWnd, out RECT rect);
'@
    }
    [void][DeepSeekClock.Win32Api]::SetProcessDPIAware()
} catch { }

# 单实例：第二个实例不再静默退出，而是广播一条自定义消息，让已在运行的挂件自己回到前台。
$script:ShowMessage = 0
try {
    $script:ShowMessage = [int][DeepSeekClock.Win32Api]::RegisterWindowMessage('DeepSeekClockWidgetShow')
} catch { }

# 截图/调试模式用独立互斥体，避免和正在运行的挂件抢单实例锁
$script:MutexName = 'Local\DeepSeekClockWidget'
if ((-not [string]::IsNullOrWhiteSpace($script:RequestedCapturePath)) -or (-not [string]::IsNullOrWhiteSpace($script:CycleCaptureDir))) {
    $script:MutexName = 'Local\DeepSeekClockWidgetCapture'
}
$script:InstanceMutex = New-Object -TypeName System.Threading.Mutex -ArgumentList @($false, $script:MutexName)
$script:HasMutex = $false
try {
    $script:HasMutex = $script:InstanceMutex.WaitOne(0, $false)
} catch [System.Threading.AbandonedMutexException] {
    $script:HasMutex = $true
}
if (-not $script:HasMutex) {
    if ($script:ShowMessage -ne 0) {
        try {
            [void][DeepSeekClock.Win32Api]::PostMessage([System.IntPtr]0xFFFF, [uint32]$script:ShowMessage, [System.IntPtr]::Zero, [System.IntPtr]::Zero)
        } catch { }
    }
    [Console]::Error.WriteLine('DeepSeek 时段挂件已在运行，已通知它回到前台，本次启动退出。')
    if ($script:RequestedCapturePath) { exit 2 }
    return
}

$script:PreviewBase = $null
$script:PreviewStartedAt = $null
if ($PreviewTime) {
    try {
        $script:PreviewBase = ConvertFrom-PreviewTimeText -Text $PreviewTime
    } catch {
        [Console]::Error.WriteLine($_.Exception.Message)
        exit 2
    }
    $script:PreviewStartedAt = [DateTimeOffset]::UtcNow
}

function Get-VirtualNow {
    if ($null -ne $script:PreviewBase) {
        if ($script:RequestedCapturePath) { return $script:PreviewBase }
        $elapsed = [DateTimeOffset]::UtcNow - $script:PreviewStartedAt
        return $script:PreviewBase.Add($elapsed)
    }
    return Get-BeijingNow
}

$script:Data = Load-HolidayData
$script:Settings = Load-Settings
# 启动次数用于控制一次性操作提示的显示时长（前 3 次启动才提示）
$script:Settings.LaunchCount = [int]$script:Settings.LaunchCount + 1
# 截图模式可以直接指定方案，不必去改用户目录里的 settings.json
# （以前靠改 settings 来切方案，万一被正在运行的挂件回写，会把用户的位置一起弄乱）
if ((-not [string]::IsNullOrWhiteSpace($UiScheme)) -and ((-not [string]::IsNullOrWhiteSpace($script:RequestedCapturePath)) -or (-not [string]::IsNullOrWhiteSpace($script:CycleCaptureDir)))) {
    $script:Settings.UiScheme = $UiScheme
}

$xamlText = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="DeepSeek 时段挂件"
        Width="316"
        SizeToContent="Height"
        WindowStyle="None"
        AllowsTransparency="True"
        Background="Transparent"
        ResizeMode="NoResize"
        ShowInTaskbar="False"
        Topmost="True"
        UseLayoutRounding="True"
        SnapsToDevicePixels="True"
        FontFamily="Microsoft YaHei UI"
        WindowStartupLocation="Manual">
  <Grid x:Name="Shell" />
</Window>
'@

$script:Window = [System.Windows.Markup.XamlReader]::Parse($xamlText)
$script:Window.Topmost = [bool]$script:Settings.Topmost
if (($null -ne $script:Settings.Left) -and ($null -ne $script:Settings.Top)) {
    $script:Window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
    $script:Window.Left = [double]$script:Settings.Left
    $script:Window.Top = [double]$script:Settings.Top
}

if (Test-Path -LiteralPath $script:IconPath) {
    try {
        $iconUri = [System.Uri]::new($script:IconPath)
        $script:Window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create($iconUri)
    } catch { }
}

$script:ThemeKey = ''
$script:LastNextIsPeak = $null
$script:LastIsPeakDay = $null
$script:LastTimelineWidth = $null
$script:LastStatus = $null

# ============================ 界面方案（右键可切） ============================
# 方案的配方与渲染都在 lib/Schemes.ps1 里，这里只做「主题回调」的接线：
# 高峰/空闲状态一变，就把当前方案 + 状态交给 Apply-SchemeState。

$script:ActiveLayout = ''
$script:SchemeMenuItems = @{}

function Apply-Theme {
    param([object]$Status)
    $spec = Get-SchemeSpec -Key ([string]$script:Settings.UiScheme)
    Apply-SchemeState -Spec $spec -Status $Status
}

# 右键菜单「上一个 / 下一个方案」用：按清单顺序循环切
function Step-UiScheme {
    param([int]$Step)
    $next = Get-SchemeNeighbor -Key ([string]$script:Settings.UiScheme) -Step $Step
    Set-UiScheme -Key $next
    Save-Settings
}

# 卡片上的拖动交互：每次换布局都会换一颗 Card，所以封装成可重复调用的函数
function Attach-CardInteractions {
    if ($null -eq $script:Card) { return }
    $script:Card.Add_MouseLeftButtonDown({
        param($sender, $mouseArgs)
        if ($mouseArgs.ButtonState -ne [System.Windows.Input.MouseButtonState]::Pressed) { return }
        try { $script:Window.DragMove() } catch { }
        Save-Settings
        Update-Widget
    })
}

function Update-Widget {
    $now = Get-VirtualNow
    $status = Get-DeepSeekTimeStatus -Time $now -Holidays $script:Data.Holidays -CoveredYears $script:Data.Years -HolidayNames $script:Data.Names
    $script:LastStatus = $status

    $themeKey = 'idle'
    if ($status.IsPeak) { $themeKey = 'peak' }
    if (($script:ThemeKey -ne $themeKey) -or ($script:LastNextIsPeak -ne $status.NextChangeIsPeak)) {
        $script:ThemeKey = $themeKey
        Apply-Theme -Status $status
    }
    $script:LastNextIsPeak = $status.NextChangeIsPeak

    $spec = Get-SchemeSpec -Key ([string]$script:Settings.UiScheme)

    $script:StatusText.Text = $status.StatusText
    if ([bool]$spec.PlainRate) {
        $script:RateText.Text = ([string]$status.RateText) -replace '^价格\s*', ''
    } else {
        $script:RateText.Text = $status.RateText
    }

    # 网页稿里时钟几乎都是「10:30」大 + 「:24」小灰，只有仪表类是全同号，
    # 模板里有 ClockSec 就拆成两段，没有就整串显示。
    $clockFull = [string]$status.TimeText
    if (($null -ne $script:ClockSec) -and ($clockFull.Length -ge 8)) {
        $script:ClockText.Text = $clockFull.Substring(0, 5)
        $script:ClockSec.Text = $clockFull.Substring(5)
    } else {
        $script:ClockText.Text = $clockFull
    }

    # 周末不再额外挂「· 周末」：周几那一行已经写明周六 / 周日，
    # 而且调休上班的周六本就不该被标成周末。
    # 节日名放哪儿看布局：卡片布局的日期列被时钟挤窄了，只能挪到周几那一行，
    # 否则会变成「10月31日 · 周…」这种被截断的样子；胶囊 / 表盘横向有余量，跟在日期后面。
    $weekLine = $status.WeekText
    $dateLine = $status.DateText
    if ($status.HolidayName) {
        if ([bool]$script:CompactDate) {
            $weekLine = [string]$status.HolidayName
        } else {
            $dateLine = $dateLine + ' · ' + [string]$status.HolidayName
        }
    }
    $script:WeekText.Text = $weekLine
    if ($script:Data.Years.Count -eq 0) {
        $dateLine = $dateLine + ' · 数据缺失'
    } elseif (-not $status.YearCovered) {
        $dateLine = $dateLine + ' · 数据待更新'
    }
    $script:DateText.Text = $dateLine

    # 网页稿的倒计时基本都是「左边标签 + 右边数值」两列（距空闲 / 01:29:36），
    # 模板里有 CountdownValue 就拆开，没有就整句显示。
    if ($null -ne $script:CountdownValue) {
        $cdLabel = [string]$spec.CdIdle
        if ($status.NextChangeIsPeak) { $cdLabel = [string]$spec.CdPeak }
        if ([string]::IsNullOrWhiteSpace($cdLabel)) {
            if ($status.NextChangeIsPeak) { $cdLabel = '距高峰' } else { $cdLabel = '距空闲' }
        }
        $script:CountdownText.Text = $cdLabel
        $script:CountdownValue.Text = [string]$status.NextChangeText
    } else {
        $script:CountdownText.Text = $status.CountdownText
    }
    # 操作提示只在最初几次启动时显示，之后收起，把空间让给倒计时
    if ([int]$script:Settings.LaunchCount -le 3) {
        $script:HintText.Visibility = [System.Windows.Visibility]::Visible
    } else {
        $script:HintText.Visibility = [System.Windows.Visibility]::Collapsed
    }

    $timelineWidth = $script:TimelineCanvas.ActualWidth
    if ($timelineWidth -gt 20) {
        if (($null -eq $script:LastTimelineWidth) -or ([Math]::Abs($script:LastTimelineWidth - $timelineWidth) -gt 0.5)) {
            $script:TimelineTrack.Width = $timelineWidth
            $script:LastTimelineWidth = $timelineWidth
        }
        $peakWindows = @($status.PeakWindows)
        if ($status.IsPeakDay -and $peakWindows.Count -ge 2) {
            $script:PeakSegment1.Visibility = [System.Windows.Visibility]::Visible
            $script:PeakSegment2.Visibility = [System.Windows.Visibility]::Visible
            [System.Windows.Controls.Canvas]::SetLeft($script:PeakSegment1, $timelineWidth * $peakWindows[0].Start)
            $script:PeakSegment1.Width = $timelineWidth * ($peakWindows[0].End - $peakWindows[0].Start)
            [System.Windows.Controls.Canvas]::SetLeft($script:PeakSegment2, $timelineWidth * $peakWindows[1].Start)
            $script:PeakSegment2.Width = $timelineWidth * ($peakWindows[1].End - $peakWindows[1].Start)
        } else {
            $script:PeakSegment1.Visibility = [System.Windows.Visibility]::Collapsed
            $script:PeakSegment2.Visibility = [System.Windows.Visibility]::Collapsed
        }
        if (($null -eq $script:LastIsPeakDay) -or ($script:LastIsPeakDay -ne $status.IsPeakDay)) {
            $script:LastIsPeakDay = $status.IsPeakDay
        }
        $markerLeft = [Math]::Round($timelineWidth * $status.DayFraction) - 1
        if ($markerLeft -lt 0) { $markerLeft = 0 }
        if ($markerLeft -gt ($timelineWidth - 2)) { $markerLeft = $timelineWidth - 2 }
        [System.Windows.Controls.Canvas]::SetLeft($script:TimeMarker, $markerLeft)
    }

    # 圆表指针 / 波形亮点这类「每秒要动一下」的装饰，在这里单独推进
    Update-SchemeDecorTick -Status $status
}

function Get-WindowSizeEstimate {
    # 窗口尺寸在 Loaded / ContentRendered 阶段可能还没算出来（ActualWidth 会是 0 或极小值），
    # 直接用会把窗口算到屏幕外，这里按当前方案给一个合理下限。
    $spec = Get-SchemeSpec -Key ([string]$script:Settings.UiScheme)
    $fallbackWidth = [double]$spec.Width
    $fallbackHeight = 196.0
    if ([double]$spec.Height -gt 0) { $fallbackHeight = [double]$spec.Height }
    $width = [double]$script:Window.ActualWidth
    $height = [double]$script:Window.ActualHeight
    if ([double]::IsNaN($width) -or $width -lt 200) { $width = $fallbackWidth }
    if ([double]::IsNaN($height) -or $height -lt 100) { $height = $fallbackHeight }
    return @($width, $height)
}

function Place-WindowBottomRight {
    $workArea = [System.Windows.SystemParameters]::WorkArea
    $size = Get-WindowSizeEstimate
    $width = $size[0]
    $height = $size[1]
    $script:Window.Left = [Math]::Max($workArea.Left, $workArea.Right - $width - 24)
    $script:Window.Top = [Math]::Max($workArea.Top, $workArea.Bottom - $height - 24)
}

function Clamp-WindowPosition {
    $virtualLeft = [System.Windows.SystemParameters]::VirtualScreenLeft
    $virtualTop = [System.Windows.SystemParameters]::VirtualScreenTop
    $virtualRight = $virtualLeft + [System.Windows.SystemParameters]::VirtualScreenWidth
    $virtualBottom = $virtualTop + [System.Windows.SystemParameters]::VirtualScreenHeight
    $size = Get-WindowSizeEstimate
    $width = $size[0]
    $height = $size[1]
    $minLeft = $virtualLeft - $width + 80
    $maxLeft = $virtualRight - 80
    $minTop = $virtualTop
    $maxTop = $virtualBottom - 40
    if ($script:Window.Left -lt $minLeft) { $script:Window.Left = $minLeft }
    if ($script:Window.Left -gt $maxLeft) { $script:Window.Left = $maxLeft }
    if ($script:Window.Top -lt $minTop) { $script:Window.Top = $minTop }
    if ($script:Window.Top -gt $maxTop) { $script:Window.Top = $maxTop }
}

function Save-WindowSnapshot {
    param([string]$Path)
    $script:Window.UpdateLayout()
    $content = $script:Window.Content
    if ($null -eq $content) { throw '窗口内容为空' }
    $width = [int][Math]::Ceiling($script:Window.ActualWidth)
    $height = [int][Math]::Ceiling($script:Window.ActualHeight)
    if ($width -le 0 -or $height -le 0) { throw ('窗口尺寸异常：' + $width + 'x' + $height) }
    $dpiScale = 1.0
    try {
        $dpiInfo = [System.Windows.Media.VisualTreeHelper]::GetDpi($script:Window)
        if ($dpiInfo.DpiScaleX -gt 0) { $dpiScale = $dpiInfo.DpiScaleX }
    } catch { }
    $pixelWidth = [int][Math]::Ceiling($width * $dpiScale)
    $pixelHeight = [int][Math]::Ceiling($height * $dpiScale)
    $renderBitmap = New-Object -TypeName System.Windows.Media.Imaging.RenderTargetBitmap -ArgumentList @($pixelWidth, $pixelHeight, (96.0 * $dpiScale), (96.0 * $dpiScale), [System.Windows.Media.PixelFormats]::Pbgra32)
    $renderBitmap.Render($content)
    $encoder = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($renderBitmap))
    $directory = Split-Path -Parent $Path
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $fileStream = [System.IO.File]::Create($Path)
    try {
        $encoder.Save($fileStream)
    } finally {
        $fileStream.Close()
    }
}

function Start-CycleCapture {
    # 在同一个进程里把所有方案切一遍并逐个截图：
    # 这样能同时验证「card → capsule → dial」的布局重建和勾选状态同步。
    if (-not (Test-Path -LiteralPath $script:CycleCaptureDir)) {
        New-Item -ItemType Directory -Path $script:CycleCaptureDir -Force | Out-Null
    }
    $script:CycleIndex = 0
    $script:CyclePending = $null
    $script:CycleTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:CycleTimer.Interval = [TimeSpan]::FromMilliseconds(420)
    $script:CycleTimer.Add_Tick({
        if ($null -ne $script:CyclePending) {
            $path = Join-Path $script:CycleCaptureDir ('cycle-' + $script:CyclePending + '.png')
            try {
                Save-WindowSnapshot -Path $path
                [Console]::Out.WriteLine('OK ' + $script:CyclePending)
            } catch {
                [Console]::Error.WriteLine('FAIL ' + $script:CyclePending + ' ' + $_.Exception.Message)
            }
            $script:CyclePending = $null
            return
        }
        if ($script:CycleIndex -ge $script:UiSchemes.Count) {
            $script:CycleTimer.Stop()
            try { $script:Window.Close() } catch { }
            return
        }
        $key = [string]$script:UiSchemes[$script:CycleIndex].Key
        $script:CycleIndex = $script:CycleIndex + 1
        try {
            Set-UiScheme -Key $key
            $script:CyclePending = $key
        } catch {
            [Console]::Error.WriteLine('SWITCH-FAIL ' + $key + ' ' + $_.Exception.Message)
        }
    })
    $script:CycleTimer.Start()
}

function Start-CaptureSequence {
    $script:CaptureTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:CaptureTimer.Interval = [TimeSpan]::FromMilliseconds(1200)
    $script:CaptureTimer.Add_Tick({
        $script:CaptureTimer.Stop()
        try {
            Save-WindowSnapshot -Path $script:RequestedCapturePath
            [Console]::Out.WriteLine('截图已保存：' + $script:RequestedCapturePath)
        } catch {
            [Console]::Error.WriteLine('截图失败：' + $_.Exception.Message)
        }
        try { $script:Window.Close() } catch { }
    })
    $script:CaptureTimer.Start()
}

function Show-Rules {
    $lines = @(
        'DeepSeek 时段挂件',
        '',
        '计费规则（来自 DeepSeek 官网）：',
        '· 高峰时段：北京时间周一至周五（不含中国法定节假日）09:00-12:00、14:00-18:00',
        '· 空闲时段：其余所有时间，包括周末和法定节假日全天',
        '· 空闲时段价格为高峰时段价格的一半',
        '',
        '操作：',
        '· 按住鼠标左键拖动可移动挂件位置',
        '· 右键打开菜单：置顶、开机自启、更新节假日数据、退出等',
        '· 托盘图标左键单击可显示 / 隐藏挂件；重复启动也会把它叫回前台',
        '',
        '节假日数据：',
        '· 右键“联网更新节假日数据”可获取当年及次年数据',
        '· 更新后的数据保存在 %APPDATA%\DeepSeekClock\holidays.json，不会改动程序目录',
        '· 也可直接编辑程序目录下的 holidays.json 后重启挂件',
        '',
        '说明：按 DeepSeek 官网字面规则，周末即使遇到调休上班日也属于空闲时段。'
    )
    Show-Dialog -Message ($lines -join [Environment]::NewLine) -Kind 'Information'
}

# ============================ 右键菜单（自定义样式） ============================
# 不使用系统默认的 ContextMenu 外观（直角、系统蓝高亮、默认行高），
# 用自定义 ControlTemplate 重绘：圆角玻璃面板 + 柔和悬停 + 勾选标记 + 危险项配色。

$script:MenuStyleXaml = @'
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">

  <Style x:Key="GlassMenu" TargetType="{x:Type ContextMenu}">
    <Setter Property="OverridesDefaultStyle" Value="True" />
    <Setter Property="HasDropShadow" Value="True" />
    <Setter Property="SnapsToDevicePixels" Value="True" />
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="{x:Type ContextMenu}">
          <Border Margin="12" CornerRadius="12" BorderThickness="1" BorderBrush="#28FFFFFF">
            <Border.Background>
              <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                <GradientStop Color="#F71B2432" Offset="0" />
                <GradientStop Color="#F70D131E" Offset="1" />
              </LinearGradientBrush>
            </Border.Background>
            <Border.Effect>
              <DropShadowEffect BlurRadius="22" ShadowDepth="4" Direction="270" Opacity="0.42" Color="#000000" />
            </Border.Effect>
            <ScrollViewer MaxHeight="540" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="0">
              <StackPanel IsItemsHost="True" Margin="0,6" KeyboardNavigation.DirectionalNavigation="Cycle" />
            </ScrollViewer>
          </Border>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style x:Key="GlassMenuItem" TargetType="{x:Type MenuItem}">
    <Setter Property="Foreground" Value="#C6D1E0" />
    <Setter Property="FontSize" Value="12.5" />
    <Setter Property="FontFamily" Value="Microsoft YaHei UI" />
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="{x:Type MenuItem}">
          <Border x:Name="Row" Margin="5,1" Height="31" CornerRadius="7" Padding="9,0,11,0" Background="Transparent">
            <Grid>
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="15" />
                <ColumnDefinition Width="*" />
                <ColumnDefinition Width="Auto" />
              </Grid.ColumnDefinitions>
              <TextBlock x:Name="Tick" Grid.Column="0" Text="&#x2713;" FontSize="10.5" FontWeight="Bold"
                         Foreground="#5EEAD4" VerticalAlignment="Center" Visibility="Collapsed" />
              <ContentPresenter Grid.Column="1" ContentSource="Header" VerticalAlignment="Center" RecognizesAccessKey="True" />
              <TextBlock Grid.Column="2" Margin="14,0,0,0" VerticalAlignment="Center"
                         FontSize="9.5" Foreground="#5C6A80"
                         Text="{Binding InputGestureText, RelativeSource={RelativeSource TemplatedParent}}" />
            </Grid>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsHighlighted" Value="True">
              <Setter TargetName="Row" Property="Background" Value="#1FFFFFFF" />
              <Setter Property="Foreground" Value="#FFFFFF" />
            </Trigger>
            <MultiTrigger>
              <MultiTrigger.Conditions>
                <Condition Property="IsHighlighted" Value="True" />
                <Condition Property="Tag" Value="danger" />
              </MultiTrigger.Conditions>
              <MultiTrigger.Setters>
                <Setter TargetName="Row" Property="Background" Value="#33F87171" />
                <Setter Property="Foreground" Value="#FECACA" />
              </MultiTrigger.Setters>
            </MultiTrigger>
            <Trigger Property="IsChecked" Value="True">
              <Setter TargetName="Tick" Property="Visibility" Value="Visible" />
            </Trigger>
            <Trigger Property="IsEnabled" Value="False">
              <Setter Property="Foreground" Value="#5A6577" />
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style x:Key="GlassMenuHeader" TargetType="{x:Type MenuItem}">
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="{x:Type MenuItem}">
          <StackPanel Margin="24,7,14,8">
            <TextBlock FontSize="12.5" FontWeight="SemiBold" Foreground="#E9EFF8"
                       Text="{Binding Header, RelativeSource={RelativeSource TemplatedParent}}" />
            <TextBlock Margin="0,3,0,0" FontSize="10" Foreground="#6B7891"
                       Text="{Binding Tag, RelativeSource={RelativeSource TemplatedParent}}" />
          </StackPanel>
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

  <Style x:Key="GlassSeparator" TargetType="{x:Type Separator}">
    <Setter Property="Template">
      <Setter.Value>
        <ControlTemplate TargetType="{x:Type Separator}">
          <Border Height="1" Margin="14,5" Background="#1AFFFFFF" />
        </ControlTemplate>
      </Setter.Value>
    </Setter>
  </Style>

</ResourceDictionary>
'@

$script:MenuStyles = $null
try {
    $script:MenuStyles = [System.Windows.Markup.XamlReader]::Parse($script:MenuStyleXaml)
} catch {
    [Console]::Error.WriteLine('右键菜单样式解析失败，已回退系统默认样式：' + $_.Exception.Message)
    $script:MenuStyles = $null
}

function Get-MenuStyle {
    param([string]$Key)
    if ($null -eq $script:MenuStyles) { return $null }
    if ($script:MenuStyles.Contains($Key)) { return $script:MenuStyles[$Key] }
    return $null
}

function New-ContextMenuItem {
    param(
        [string]$Header,
        [bool]$Checkable = $false,
        [bool]$Checked = $false,
        [string]$Tag = '',
        [string]$StyleKey = 'GlassMenuItem'
    )
    $item = New-Object System.Windows.Controls.MenuItem
    $item.Header = $Header
    if ($Tag -ne '') { $item.Tag = $Tag }
    if ($Checkable) {
        $item.IsCheckable = $true
        $item.IsChecked = $Checked
    }
    $style = Get-MenuStyle -Key $StyleKey
    if ($null -ne $style) { $item.Style = $style }
    return $item
}

function New-MenuSeparator {
    $separator = New-Object System.Windows.Controls.Separator
    $style = Get-MenuStyle -Key 'GlassSeparator'
    if ($null -ne $style) { $separator.Style = $style }
    return $separator
}

function Build-ContextMenu {
    $menu = New-Object System.Windows.Controls.ContextMenu
    $menuStyle = Get-MenuStyle -Key 'GlassMenu'
    if ($null -ne $menuStyle) { $menu.Style = $menuStyle }
    $menu.MinWidth = 214
    $menu.HasDropShadow = $true
    $menu.Padding = New-Object -TypeName System.Windows.Thickness -ArgumentList 0

    # 头部：项目名 + 数据覆盖情况（不可点击，也不参与高亮）
    $script:MenuHeader = New-ContextMenuItem -Header 'DeepSeek 时段挂件' -StyleKey 'GlassMenuHeader'
    $script:MenuHeader.Tag = (Get-CoverageText -Data $script:Data)
    $script:MenuHeader.IsEnabled = $false
    [void]$menu.Items.Add($script:MenuHeader)
    [void]$menu.Items.Add((New-MenuSeparator))

    $script:MenuTopmost = New-ContextMenuItem -Header '窗口置顶' -Checkable $true -Checked ([bool]$script:Window.Topmost)
    $script:MenuTopmost.Add_Click({
        $script:Window.Topmost = [bool]$script:MenuTopmost.IsChecked
        Save-Settings
    })
    [void]$menu.Items.Add($script:MenuTopmost)

    $script:MenuAutoStart = New-ContextMenuItem -Header '开机自动启动' -Checkable $true -Checked (Test-AutoStartEnabled)
    $script:MenuAutoStart.Add_Click({
        $desired = [bool]$script:MenuAutoStart.IsChecked
        try {
            Set-AutoStartEnabled -Enabled $desired
            if ($desired) {
                Show-Dialog -Message '已开启开机自动启动：下次登录 Windows 后挂件会自动出现。' -Kind 'Information'
            } else {
                Show-Dialog -Message '已关闭开机自动启动。' -Kind 'Information'
            }
        } catch {
            $script:MenuAutoStart.IsChecked = -not $desired
            Show-Dialog -Message ('设置开机自启动失败：' + $_.Exception.Message) -Kind 'Error'
        }
    })
    [void]$menu.Items.Add($script:MenuAutoStart)

    # ---------- 界面方案 ----------
    [void]$menu.Items.Add((New-MenuSeparator))

    $script:MenuSchemeHeader = New-ContextMenuItem -Header '界面方案' -StyleKey 'GlassMenuHeader'
    $script:MenuSchemeHeader.Tag = '当前：' + [string](Get-SchemeSpec -Key ([string]$script:Settings.UiScheme)).Name
    $script:MenuSchemeHeader.IsEnabled = $false
    [void]$menu.Items.Add($script:MenuSchemeHeader)

    $itemPrev = New-ContextMenuItem -Header '上一个方案'
    $itemPrev.Add_Click({ Step-UiScheme -Step -1 })
    [void]$menu.Items.Add($itemPrev)

    $itemNext = New-ContextMenuItem -Header '下一个方案'
    $itemNext.Add_Click({ Step-UiScheme -Step 1 })
    [void]$menu.Items.Add($itemNext)

    [void]$menu.Items.Add((New-MenuSeparator))

    # 每个菜单项自己带 Key（Tag），点击时从 $sender 取——
    # 不再靠遍历 IsChecked 反推点了哪一项，这样切走再切回来一定正确。
    $schemeClick = {
        param($sender, $e)
        $key = ''
        if ($null -ne $sender) { $key = [string]$sender.Tag }
        if ([string]::IsNullOrEmpty($key)) { $key = [string]$this.Tag }
        if ([string]::IsNullOrEmpty($key)) { return }
        Set-UiScheme -Key $key
        Save-Settings
    }

    foreach ($scheme in $script:UiSchemes) {
        $schemeItem = New-ContextMenuItem -Header $scheme.Name -Checkable $true -Checked ($scheme.Key -eq [string]$script:Settings.UiScheme)
        $schemeItem.Tag = [string]$scheme.Key
        $schemeItem.ToolTip = $scheme.Hint
        $schemeItem.Add_Click($schemeClick)
        $script:SchemeMenuItems[$scheme.Key] = $schemeItem
        [void]$menu.Items.Add($schemeItem)
    }

    [void]$menu.Items.Add((New-MenuSeparator))

    $itemGallery = New-ContextMenuItem -Header '查看全部方案…'
    $itemGallery.Add_Click({
        $galleryPath = Join-Path $script:AppDir 'design\all-schemes.html'
        if (Test-Path -LiteralPath $galleryPath) {
            Start-Process -FilePath $galleryPath
        } else {
            Show-Dialog -Message ('没找到方案审查台：' + $galleryPath) -Kind 'Warning'
        }
    })
    [void]$menu.Items.Add($itemGallery)

    [void]$menu.Items.Add((New-MenuSeparator))

    $script:MenuSync = New-ContextMenuItem -Header '联网更新节假日数据'
    $script:MenuSync.Add_Click({
        $script:MenuSync.IsEnabled = $false
        try {
            $result = Update-HolidaysOnline
            $script:Data = Load-HolidayData
            $script:MenuHeader.Tag = Get-CoverageText -Data $script:Data
            $script:ThemeKey = ''
            $script:LastIsPeakDay = $null
            $script:LastTimelineWidth = $null
            Update-Widget
            if ($result.Success) {
                Show-Dialog -Message $result.Message -Kind 'Information'
            } else {
                Show-Dialog -Message $result.Message -Kind 'Warning'
            }
        } catch {
            Show-Dialog -Message ('更新节假日数据失败：' + $_.Exception.Message) -Kind 'Error'
        } finally {
            $script:MenuSync.IsEnabled = $true
        }
    })
    [void]$menu.Items.Add($script:MenuSync)

    [void]$menu.Items.Add((New-MenuSeparator))

    $itemOpenFolder = New-ContextMenuItem -Header '打开程序文件夹'
    $itemOpenFolder.Add_Click({ Start-Process -FilePath $script:AppDir })
    [void]$menu.Items.Add($itemOpenFolder)

    $itemCreateShortcut = New-ContextMenuItem -Header '创建桌面快捷方式'
    $itemCreateShortcut.Add_Click({
        try {
            $path = Create-DesktopShortcut
            Show-Dialog -Message ('已创建桌面快捷方式：' + $path) -Kind 'Information'
        } catch {
            Show-Dialog -Message ('创建快捷方式失败：' + $_.Exception.Message) -Kind 'Error'
        }
    })
    [void]$menu.Items.Add($itemCreateShortcut)

    $itemRules = New-ContextMenuItem -Header '使用说明'
    $itemRules.Add_Click({ Show-Rules })
    [void]$menu.Items.Add($itemRules)

    [void]$menu.Items.Add((New-MenuSeparator))

    $itemExit = New-ContextMenuItem -Header '退出挂件' -Tag 'danger'
    $itemExit.Add_Click({ $script:Window.Close() })
    [void]$menu.Items.Add($itemExit)

    return $menu
}

# 先建菜单，再装布局：Install-Layout 会把菜单挂到新卡片上
$script:ContextMenuRef = Build-ContextMenu
# 装布局 + 应用上次选中的界面方案（Install-Layout 会把菜单挂到新卡片上）
Set-UiScheme -Key ([string]$script:Settings.UiScheme)

# ---------- 单实例唤起 ----------
# 第二个实例广播自定义窗口消息，已运行的挂件收到后把自己拉回前台，
# 解决"重复启动没反应""卡片被全屏挡住后叫不回来"的问题。
function Bring-WidgetToFront {
    try {
        if (-not $script:Window.IsVisible) { $script:Window.Show() }
        $previousTopmost = $script:Window.Topmost
        $script:Window.Topmost = $true
        $script:Window.Activate()
        $script:Window.Topmost = $previousTopmost
        $script:Window.Focus()
    } catch { }
}

$script:Window.Add_SourceInitialized({
    try {
        if ($script:ShowMessage -eq 0) { return }
        $interopHelper = New-Object -TypeName System.Windows.Interop.WindowInteropHelper -ArgumentList $script:Window
        $hwndSource = [System.Windows.Interop.HwndSource]::FromHwnd($interopHelper.Handle)
        if ($null -eq $hwndSource) { return }
        $hook = [System.Windows.Interop.HwndSourceHook]{
            param($hWnd, $msg, $wParam, $lParam, $handled)
            if ($msg -eq $script:ShowMessage) {
                try { Bring-WidgetToFront } catch { }
            }
            return [System.IntPtr]::Zero
        }
        $hwndSource.AddHook($hook)
    } catch { }
})

# ---------- 托盘图标 ----------
# 卡片被其他窗口遮挡、或被拖到屏幕边缘之外时，托盘是唯一的恢复入口。
$script:TrayIcon = $null

function Initialize-TrayIcon {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $icon = $null
        if (Test-Path -LiteralPath $script:IconPath) {
            try { $icon = New-Object -TypeName System.Drawing.Icon -ArgumentList @($script:IconPath, 16, 16) } catch { $icon = $null }
        }
        if ($null -eq $icon) { $icon = [System.Drawing.SystemIcons]::Application }
        $script:TrayIcon = New-Object System.Windows.Forms.NotifyIcon
        $script:TrayIcon.Icon = $icon
        $script:TrayIcon.Text = 'DeepSeek 时段挂件（左键显示 / 隐藏）'
        $script:TrayIcon.Add_MouseClick({
            param($sender, $eventArgs)
            try {
                if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
                    if ($script:Window.IsVisible) {
                        $script:Window.Hide()
                    } else {
                        Bring-WidgetToFront
                    }
                }
            } catch { }
        })
        $script:TrayIcon.Visible = $true
    } catch {
        $script:TrayIcon = $null
    }
}

function Remove-TrayIcon {
    if ($null -ne $script:TrayIcon) {
        try { $script:TrayIcon.Visible = $false } catch { }
        try { $script:TrayIcon.Dispose() } catch { }
        $script:TrayIcon = $null
    }
}

Attach-CardInteractions

$script:Window.Add_Loaded({
    try {
        $script:Window.UpdateLayout()
        if (($null -ne $script:Settings.Left) -and ($null -ne $script:Settings.Top)) {
            Clamp-WindowPosition
        } else {
            Place-WindowBottomRight
        }
        Update-Widget
        if (-not [string]::IsNullOrWhiteSpace($script:CycleCaptureDir)) {
            Start-CycleCapture
        } elseif ($script:RequestedCapturePath) {
            Start-CaptureSequence
        } else {
            Initialize-TrayIcon
        }
    } catch {
        [Console]::Error.WriteLine('初始化界面失败：' + $_.Exception.Message)
    }
})

$script:Window.Add_ContentRendered({
    try {
        if (($null -eq $script:Settings.Left) -or ($null -eq $script:Settings.Top)) {
            Place-WindowBottomRight
        }
    } catch { }
})

$script:Window.Add_Closing({
    try { Save-Settings } catch { }
    try { Remove-TrayIcon } catch { }
    try { [void]$script:InstanceMutex.ReleaseMutex() } catch { }
})

$script:TickTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:TickTimer.Interval = [TimeSpan]::FromMilliseconds(150)
$script:TickTimer.Add_Tick({
    try {
        Update-Widget
        $now = Get-VirtualNow
        $delay = 1000 - $now.Millisecond
        if ($delay -lt 40) { $delay = $delay + 1000 }
        $script:TickTimer.Interval = [TimeSpan]::FromMilliseconds($delay)
    } catch {
        [Console]::Error.WriteLine('挂件刷新异常：' + $_.Exception.Message)
    }
})
$script:TickTimer.Start()

[void]$script:Window.ShowDialog()
try { $script:TickTimer.Stop() } catch { }
