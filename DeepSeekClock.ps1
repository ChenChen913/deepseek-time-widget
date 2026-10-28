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
$script:IconPath = Join-Path $script:AppDir 'assets\deepseek-clock.ico'
$script:LauncherPath = Join-Path $script:AppDir '启动挂件.vbs'
$script:RequestedCapturePath = $CapturePath

$script:LibPath = Join-Path $script:AppDir 'lib\DeepSeekTime.ps1'
if (-not (Test-Path -LiteralPath $script:LibPath)) {
    throw ('Core library not found: ' + $script:LibPath)
}
. $script:LibPath

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

function Load-HolidayData {
    $result = [pscustomobject]@{
        Holidays = @()
        Years    = @()
        Names    = @{}
        Updated  = ''
        Source   = ''
        Loaded   = $false
        Error    = ''
    }
    if (-not (Test-Path -LiteralPath $script:DataPath)) {
        $result.Error = '找不到 holidays.json'
        return $result
    }
    try {
        $rawText = Get-Content -LiteralPath $script:DataPath -Raw -Encoding UTF8
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

    $mergedHolidays = [ordered]@{}
    foreach ($year in @($script:Data.Years | Sort-Object)) {
        $prefix = [string]$year + '-'
        $existing = @($script:Data.Holidays | Where-Object { ([string]$_).StartsWith($prefix) } | Sort-Object -Unique)
        if ($existing.Count -gt 0) { $mergedHolidays[[string]$year] = $existing }
    }
    foreach ($year in @($fetchedHolidays.Keys | Sort-Object)) {
        $mergedHolidays[[string]$year] = @($fetchedHolidays[$year] | Sort-Object -Unique)
    }

    $mergedNames = [ordered]@{}
    foreach ($key in $script:Data.Names.Keys) { $mergedNames[[string]$key] = [string]$script:Data.Names[$key] }
    foreach ($key in $fetchedNames.Keys) { $mergedNames[[string]$key] = [string]$fetchedNames[$key] }
    $sortedNames = [ordered]@{}
    foreach ($key in @($mergedNames.Keys | Sort-Object)) { $sortedNames[[string]$key] = [string]$mergedNames[$key] }

    $payload = [ordered]@{
        updated       = $now.ToString('yyyy-MM-dd')
        source        = '国务院办公厅节假日安排（通过 timor.tech API 同步）'
        coverageYears = @($mergedHolidays.Keys | ForEach-Object { [int]$_ })
        holidays      = $mergedHolidays
        holidayNames  = $sortedNames
    }
    $jsonText = $payload | ConvertTo-Json -Depth 6
    if (Test-Path -LiteralPath $script:DataPath) {
        Copy-Item -LiteralPath $script:DataPath -Destination ($script:DataPath + '.bak') -Force
    }
    [System.IO.File]::WriteAllText($script:DataPath, $jsonText, (New-Object System.Text.UTF8Encoding($false)))

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
    $settings = [pscustomobject]@{ Left = $null; Top = $null; Topmost = $true }
    try {
        if (Test-Path -LiteralPath $script:SettingsPath) {
            $raw = Get-Content -LiteralPath $script:SettingsPath -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($raw)) {
                $json = $raw | ConvertFrom-Json
                if ($null -ne $json.Left) { $settings.Left = [double]$json.Left }
                if ($null -ne $json.Top) { $settings.Top = [double]$json.Top }
                if ($null -ne $json.Topmost) { $settings.Topmost = [bool]$json.Topmost }
            }
        }
    } catch { }
    return $settings
}

function Save-Settings {
    try {
        $left = [double]$script:Window.Left
        $top = [double]$script:Window.Top
        if ([double]::IsNaN($left) -or [double]::IsNaN($top)) { return }
        if ($left -lt -10000 -or $left -gt 10000 -or $top -lt -10000 -or $top -gt 10000) { return }
        if (-not (Test-Path -LiteralPath $script:SettingsDir)) {
            New-Item -ItemType Directory -Path $script:SettingsDir -Force | Out-Null
        }
        $payload = [ordered]@{
            Left    = $left
            Top     = $top
            Topmost = [bool]$script:Window.Topmost
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
        [void][DeepSeekClock.Win32Api]::SetProcessDPIAware()
    }
} catch { }

$script:InstanceMutex = New-Object -TypeName System.Threading.Mutex -ArgumentList @($false, 'Local\DeepSeekClockWidget')
$script:HasMutex = $false
try {
    $script:HasMutex = $script:InstanceMutex.WaitOne(0, $false)
} catch [System.Threading.AbandonedMutexException] {
    $script:HasMutex = $true
}
if (-not $script:HasMutex) {
    [Console]::Error.WriteLine('DeepSeek 时段挂件已在运行（单实例模式），本次启动已退出。')
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
  <Grid>
    <Border x:Name="Card" CornerRadius="18" Margin="14">
      <Border.Background>
        <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
          <GradientStop Color="#FC182233" Offset="0" />
          <GradientStop Color="#FC0B1018" Offset="1" />
        </LinearGradientBrush>
      </Border.Background>
      <Border.BorderBrush>
        <SolidColorBrush Color="#26FFFFFF" />
      </Border.BorderBrush>
      <Border.BorderThickness>1</Border.BorderThickness>
      <Border.Effect>
        <DropShadowEffect BlurRadius="20" ShadowDepth="5" Direction="270" Opacity="0.5" Color="#000000" />
      </Border.Effect>
      <Grid Margin="16,13,16,13">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto" />
          <RowDefinition Height="Auto" />
          <RowDefinition Height="Auto" />
          <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>

        <Grid Grid.Row="0">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*" />
            <ColumnDefinition Width="Auto" />
          </Grid.ColumnDefinitions>
          <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <Ellipse x:Name="StatusDot" Width="9" Height="9" Fill="#34D399" VerticalAlignment="Center">
              <Ellipse.Effect>
                <DropShadowEffect BlurRadius="10" ShadowDepth="0" Opacity="0.95" Color="#34D399" />
              </Ellipse.Effect>
            </Ellipse>
            <TextBlock x:Name="StatusText" Text="空闲时段" Margin="8,0,0,0" FontSize="18" FontWeight="SemiBold" Foreground="#34D399" VerticalAlignment="Center" />
          </StackPanel>
          <Border x:Name="RateBadge" Grid.Column="1" CornerRadius="9" Padding="8,3" Background="#2234D399" VerticalAlignment="Center">
            <TextBlock x:Name="RateText" Text="价格 0.5×" FontSize="10.5" Foreground="#6EE7B7" />
          </Border>
        </Grid>

        <Grid Grid.Row="1" Margin="0,10,0,0">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto" />
            <ColumnDefinition Width="*" />
          </Grid.ColumnDefinitions>
          <TextBlock x:Name="ClockText" Text="08:54:21" FontFamily="Segoe UI Variable Display, Segoe UI, Microsoft YaHei UI" FontSize="34" FontWeight="Bold" Foreground="#F8FAFC" VerticalAlignment="Center" />
          <StackPanel Grid.Column="1" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="12,0,0,0">
            <TextBlock x:Name="WeekText" Text="周三" FontSize="13" Foreground="#CBD5E1" HorizontalAlignment="Right" />
            <TextBlock x:Name="DateText" Text="10月28日" FontSize="11" Foreground="#7C8AA5" HorizontalAlignment="Right" Margin="0,3,0,0" TextTrimming="CharacterEllipsis" MaxWidth="170" />
          </StackPanel>
        </Grid>

        <Grid Grid.Row="2" Margin="0,10,0,0" Height="10">
          <Canvas x:Name="TimelineCanvas" Height="10" ClipToBounds="True" HorizontalAlignment="Stretch">
            <Rectangle x:Name="TimelineTrack" Canvas.Left="0" Canvas.Top="2" Height="6" RadiusX="3" RadiusY="3" Fill="#332A3A4D" />
            <Rectangle x:Name="PeakSegment1" Canvas.Top="2" Height="6" RadiusX="3" RadiusY="3" Fill="#F59E0B" Visibility="Collapsed" />
            <Rectangle x:Name="PeakSegment2" Canvas.Top="2" Height="6" RadiusX="3" RadiusY="3" Fill="#F59E0B" Visibility="Collapsed" />
            <Rectangle x:Name="TimeMarker" Canvas.Top="0" Width="2" Height="10" RadiusX="1" RadiusY="1" Fill="#F8FAFC" />
          </Canvas>
        </Grid>

        <Grid Grid.Row="3" Margin="0,8,0,0">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*" />
            <ColumnDefinition Width="Auto" />
          </Grid.ColumnDefinitions>
          <TextBlock x:Name="CountdownText" Text="距高峰时段还有 00:12:00" FontSize="12" Foreground="#94A3B8" VerticalAlignment="Center" TextTrimming="CharacterEllipsis" />
          <TextBlock x:Name="HintText" Grid.Column="1" Text="拖动 / 右键" FontSize="10" Foreground="#5B6B82" Margin="10,2,0,0" VerticalAlignment="Center" />
        </Grid>
      </Grid>
    </Border>
  </Grid>
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

function Get-UiElement {
    param([string]$Name)
    $element = $script:Window.FindName($Name)
    if ($null -eq $element) { throw ('XAML 元素缺失：' + $Name) }
    return $element
}

$script:Card = Get-UiElement 'Card'
$script:StatusDot = Get-UiElement 'StatusDot'
$script:StatusText = Get-UiElement 'StatusText'
$script:RateBadge = Get-UiElement 'RateBadge'
$script:RateText = Get-UiElement 'RateText'
$script:ClockText = Get-UiElement 'ClockText'
$script:WeekText = Get-UiElement 'WeekText'
$script:DateText = Get-UiElement 'DateText'
$script:TimelineCanvas = Get-UiElement 'TimelineCanvas'
$script:TimelineTrack = Get-UiElement 'TimelineTrack'
$script:PeakSegment1 = Get-UiElement 'PeakSegment1'
$script:PeakSegment2 = Get-UiElement 'PeakSegment2'
$script:TimeMarker = Get-UiElement 'TimeMarker'
$script:CountdownText = Get-UiElement 'CountdownText'

$script:ThemeKey = ''
$script:LastNextIsPeak = $null
$script:LastIsPeakDay = $null
$script:LastTimelineWidth = $null
$script:LastTooltip = ''
$script:LastStatus = $null

function Apply-Theme {
    param([object]$Status)
    $accentColor = '#34D399'
    $accentSoft = '#6EE7B7'
    $badgeBackground = '#2234D399'
    if ($Status.IsPeak) {
        $accentColor = '#F59E0B'
        $accentSoft = '#FCD34D'
        $badgeBackground = '#22F59E0B'
    }
    $script:StatusDot.Fill = ConvertTo-Brush $accentColor
    $script:StatusText.Foreground = ConvertTo-Brush $accentColor
    $script:RateBadge.Background = ConvertTo-Brush $badgeBackground
    $script:RateText.Foreground = ConvertTo-Brush $accentSoft
    $glow = $script:StatusDot.Effect
    if ($null -ne $glow) {
        $glow.Color = [System.Windows.Media.ColorConverter]::ConvertFromString($accentColor)
    }
    $nextColor = '#6EE7B7'
    if ($Status.NextChangeIsPeak) { $nextColor = '#FCD34D' }
    $script:CountdownText.Foreground = ConvertTo-Brush $nextColor
    $segmentColor = ConvertTo-Brush '#F59E0B'
    $script:PeakSegment1.Fill = $segmentColor
    $script:PeakSegment2.Fill = $segmentColor
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

    $script:StatusText.Text = $status.StatusText
    $script:RateText.Text = $status.RateText
    $script:ClockText.Text = $status.TimeText
    $script:WeekText.Text = $status.WeekText

    $dateLine = $status.DateText
    if ($status.HolidayName) {
        $dateLine = $dateLine + ' · ' + $status.HolidayName
    } elseif ($status.IsWeekend) {
        $dateLine = $dateLine + ' · 周末'
    }
    if ($script:Data.Years.Count -eq 0) {
        $dateLine = $dateLine + ' · 数据缺失'
    } elseif (-not $status.YearCovered) {
        $dateLine = $dateLine + ' · 数据待更新'
    }
    $script:DateText.Text = $dateLine
    $script:CountdownText.Text = $status.CountdownText

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
            if ($status.IsPeakDay) {
                $script:TimelineTrack.Fill = ConvertTo-Brush '#332A3A4D'
            } else {
                $script:TimelineTrack.Fill = ConvertTo-Brush '#3D34D399'
            }
        }
        $markerLeft = [Math]::Round($timelineWidth * $status.DayFraction) - 1
        if ($markerLeft -lt 0) { $markerLeft = 0 }
        if ($markerLeft -gt ($timelineWidth - 2)) { $markerLeft = $timelineWidth - 2 }
        [System.Windows.Controls.Canvas]::SetLeft($script:TimeMarker, $markerLeft)
    }

    $tipLines = @()
    $tipLines += 'DeepSeek 时段挂件'
    $tipLines += ''
    $tipLines += '规则：北京时间周一至周五（不含中国法定节假日）09:00-12:00、14:00-18:00 为高峰时段；其余时间（含周末与法定节假日全天）为空闲时段，价格为高峰时段的一半。'
    $tipLines += ''
    $tipLines += $status.TodayText
    $tipLines += (Get-CoverageText -Data $script:Data)
    if ($script:Data.Updated) { $tipLines += ('数据更新日期：' + $script:Data.Updated) }
    $tipLines += ''
    $tipLines += '拖动可移动 · 右键打开菜单'
    $tipText = $tipLines -join [Environment]::NewLine
    if ($script:LastTooltip -ne $tipText) {
        $script:LastTooltip = $tipText
        $tipBlock = New-Object System.Windows.Controls.TextBlock
        $tipBlock.Text = $tipText
        $tipBlock.TextWrapping = [System.Windows.TextWrapping]::Wrap
        $tipBlock.MaxWidth = 380
        $toolTip = New-Object System.Windows.Controls.ToolTip
        $toolTip.Content = $tipBlock
        $script:Card.ToolTip = $toolTip
    }
}

function Place-WindowBottomRight {
    $workArea = [System.Windows.SystemParameters]::WorkArea
    $width = $script:Window.ActualWidth
    $height = $script:Window.ActualHeight
    if ($width -le 10) { $width = 316 }
    if ($height -le 10) { $height = 176 }
    $script:Window.Left = [Math]::Max($workArea.Left, $workArea.Right - $width - 24)
    $script:Window.Top = [Math]::Max($workArea.Top, $workArea.Bottom - $height - 24)
}

function Clamp-WindowPosition {
    $virtualLeft = [System.Windows.SystemParameters]::VirtualScreenLeft
    $virtualTop = [System.Windows.SystemParameters]::VirtualScreenTop
    $virtualRight = $virtualLeft + [System.Windows.SystemParameters]::VirtualScreenWidth
    $virtualBottom = $virtualTop + [System.Windows.SystemParameters]::VirtualScreenHeight
    $width = $script:Window.ActualWidth
    $height = $script:Window.ActualHeight
    if ($width -le 10) { $width = 316 }
    if ($height -le 10) { $height = 176 }
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
        '· 鼠标悬停在挂件上可查看规则和今日时段说明',
        '',
        '节假日数据：',
        '· 右键“联网更新节假日数据”可获取当年及次年数据',
        '· 也可直接编辑程序目录下的 holidays.json 后重启挂件',
        '',
        '说明：按 DeepSeek 官网字面规则，周末即使遇到调休上班日也属于空闲时段。'
    )
    Show-Dialog -Message ($lines -join [Environment]::NewLine) -Kind 'Information'
}

function New-ContextMenuItem {
    param([string]$Header, [bool]$Checkable = $false, [bool]$Checked = $false)
    $item = New-Object System.Windows.Controls.MenuItem
    $item.Header = $Header
    if ($Checkable) {
        $item.IsCheckable = $true
        $item.IsChecked = $Checked
    }
    return $item
}

function Build-ContextMenu {
    $menu = New-Object System.Windows.Controls.ContextMenu
    $menu.Background = ConvertTo-Brush '#1B2333'
    $menu.Foreground = ConvertTo-Brush '#E2E8F0'
    $menu.BorderBrush = ConvertTo-Brush '#3A4A5F'
    $menu.HasDropShadow = $true
    $menu.Padding = New-Object -TypeName System.Windows.Thickness -ArgumentList 2

    $headerItem = New-ContextMenuItem -Header 'DeepSeek 时段挂件'
    $headerItem.IsEnabled = $false
    [void]$menu.Items.Add($headerItem)

    $script:MenuDataInfo = New-ContextMenuItem -Header (Get-CoverageText -Data $script:Data)
    $script:MenuDataInfo.IsEnabled = $false
    [void]$menu.Items.Add($script:MenuDataInfo)
    [void]$menu.Items.Add((New-Object System.Windows.Controls.Separator))

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

    $script:MenuSync = New-ContextMenuItem -Header '联网更新节假日数据'
    $script:MenuSync.Add_Click({
        $script:MenuSync.IsEnabled = $false
        try {
            $result = Update-HolidaysOnline
            $script:Data = Load-HolidayData
            $script:MenuDataInfo.Header = Get-CoverageText -Data $script:Data
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

    [void]$menu.Items.Add((New-Object System.Windows.Controls.Separator))
    $itemExit = New-ContextMenuItem -Header '退出挂件'
    $itemExit.Add_Click({ $script:Window.Close() })
    [void]$menu.Items.Add($itemExit)

    return $menu
}

$script:Card.ContextMenu = Build-ContextMenu

$script:Card.Add_MouseLeftButtonDown({
    param($sender, $mouseArgs)
    if ($mouseArgs.ButtonState -eq [System.Windows.Input.MouseButtonState]::Pressed) {
        try { $script:Window.DragMove() } catch { }
        Save-Settings
        Update-Widget
    }
})

$script:Window.Add_Loaded({
    try {
        $script:Window.UpdateLayout()
        if (($null -ne $script:Settings.Left) -and ($null -ne $script:Settings.Top)) {
            Clamp-WindowPosition
        } else {
            Place-WindowBottomRight
        }
        Update-Widget
        if ($script:RequestedCapturePath) {
            Start-CaptureSequence
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
