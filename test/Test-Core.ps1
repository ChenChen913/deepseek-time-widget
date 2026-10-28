#Requires -Version 5.1
<#
.SYNOPSIS
  DeepSeek 时段判断逻辑单元测试。
.DESCRIPTION
  运行方式（在项目目录下执行）：
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\Test-Core.ps1
  退出码 0 = 全部通过；非 0 = 存在失败。
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$script:Root = Split-Path -Parent $PSScriptRoot
$script:LibPath = Join-Path $script:Root 'lib\DeepSeekTime.ps1'
if (-not (Test-Path -LiteralPath $script:LibPath)) {
    throw ('找不到核心逻辑文件：' + $script:LibPath)
}
. $script:LibPath

$script:PassCount = 0
$script:FailCount = 0
$script:FailureList = New-Object System.Collections.Generic.List[string]

function Assert-AreEqual {
    param($Expected, $Actual, [string]$Message)
    $expectedText = [string]$Expected
    $actualText = [string]$Actual
    if ($expectedText -ceq $actualText) {
        $script:PassCount = $script:PassCount + 1
        return
    }
    $script:FailCount = $script:FailCount + 1
    [void]$script:FailureList.Add(('{0} | 期望: {1} | 实际: {2}' -f $Message, $expectedText, $actualText))
}

function Assert-IsTrue {
    param([bool]$Condition, [string]$Message)
    if ($Condition) {
        $script:PassCount = $script:PassCount + 1
        return
    }
    $script:FailCount = $script:FailCount + 1
    [void]$script:FailureList.Add(($Message + ' | 期望为 True，实际为 False'))
}

function ConvertFrom-IsoTime {
    param([string]$Iso)
    return [DateTimeOffset]::Parse($Iso, [System.Globalization.CultureInfo]::InvariantCulture)
}

function Get-TestStatus {
    param(
        [string]$Iso,
        [string[]]$Holidays = @(),
        [int[]]$Years = @(2025, 2026),
        [hashtable]$Names = @{}
    )
    return Get-DeepSeekTimeStatus -Time (ConvertFrom-IsoTime $Iso) -Holidays $Holidays -CoveredYears $Years -HolidayNames $Names
}

# ---------- 载入真实节假日数据 ----------
$script:DataPath = Join-Path $script:Root 'holidays.json'
$script:RealHolidays = @()
$script:RealYears = @()
$script:RealNames = @{}
$script:RealJson = $null
if (Test-Path -LiteralPath $script:DataPath) {
    $script:RealJson = Get-Content -LiteralPath $script:DataPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $holidayList = New-Object System.Collections.Generic.List[string]
    $yearList = New-Object System.Collections.Generic.List[int]
    foreach ($prop in $script:RealJson.holidays.PSObject.Properties) {
        $yearList.Add([int]$prop.Name)
        foreach ($dateText in @($prop.Value)) { $holidayList.Add([string]$dateText) }
    }
    $script:RealHolidays = $holidayList.ToArray()
    $script:RealYears = $yearList.ToArray()
    if ($script:RealJson.holidayNames) {
        foreach ($prop in $script:RealJson.holidayNames.PSObject.Properties) {
            $script:RealNames[$prop.Name] = [string]$prop.Value
        }
    }
} else {
    Write-Warning ('未找到 holidays.json，部分真实数据用例将被跳过：' + $script:DataPath)
}

# ---------- 1. 工作日边界（2026-10-28 周三，普通工作日） ----------
$boundaryCases = @(
    @{ Time = '2026-10-28T00:00:00+08:00'; Peak = $false },
    @{ Time = '2026-10-28T08:59:59+08:00'; Peak = $false },
    @{ Time = '2026-10-28T09:00:00+08:00'; Peak = $true },
    @{ Time = '2026-10-28T11:59:59+08:00'; Peak = $true },
    @{ Time = '2026-10-28T12:00:00+08:00'; Peak = $false },
    @{ Time = '2026-10-28T13:59:59+08:00'; Peak = $false },
    @{ Time = '2026-10-28T14:00:00+08:00'; Peak = $true },
    @{ Time = '2026-10-28T17:59:59+08:00'; Peak = $true },
    @{ Time = '2026-10-28T18:00:00+08:00'; Peak = $false },
    @{ Time = '2026-10-28T23:59:59+08:00'; Peak = $false }
)
foreach ($case in $boundaryCases) {
    $status = Get-TestStatus -Iso $case.Time -Holidays $script:RealHolidays -Years $script:RealYears -Names $script:RealNames
    Assert-AreEqual $case.Peak $status.IsPeak ('时段边界：' + $case.Time)
}

# ---------- 2. 时区无关 ----------
$utcStatus = Get-TestStatus -Iso '2026-10-28T02:00:00Z' -Holidays $script:RealHolidays -Years $script:RealYears
Assert-AreEqual $true $utcStatus.IsPeak 'UTC 输入应换算为北京时间（10:00 高峰）'
Assert-AreEqual '10:00:00' $utcStatus.TimeText 'UTC 输入换算后的时间文案'
Assert-AreEqual 8 $utcStatus.Now.Offset.TotalHours '内部统一换算为北京时间（UTC+8）'

# ---------- 3. 星期判断 ----------
$sat = Get-TestStatus -Iso '2026-10-31T10:00:00+08:00' -Holidays $script:RealHolidays -Years $script:RealYears
Assert-AreEqual $false $sat.IsPeak '周六 10:00 应为空闲'
Assert-AreEqual $true $sat.IsWeekend '周六 IsWeekend=True'
Assert-AreEqual '今日周末，全天空闲' $sat.TodayText '周末今日文案'
$sun = Get-TestStatus -Iso '2026-11-01T10:00:00+08:00' -Holidays $script:RealHolidays -Years $script:RealYears
Assert-AreEqual $false $sun.IsPeak '周日 10:00 应为空闲'

# ---------- 4. 法定节假日（真实数据） ----------
$nationalDay = Get-TestStatus -Iso '2026-10-01T10:00:00+08:00' -Holidays $script:RealHolidays -Years $script:RealYears -Names $script:RealNames
Assert-AreEqual $false $nationalDay.IsPeak '国庆节 10:00 应为空闲'
Assert-AreEqual $true $nationalDay.IsHoliday '国庆节 IsHoliday=True'
Assert-AreEqual '国庆节' $nationalDay.HolidayName '国庆节节假日名称'
Assert-AreEqual '今日法定节假日，全天空闲' $nationalDay.TodayText '节假日今日文案'

$springFestival = Get-TestStatus -Iso '2026-02-19T14:30:00+08:00' -Holidays $script:RealHolidays -Years $script:RealYears
Assert-AreEqual $false $springFestival.IsPeak '春节假期内 14:30 应为空闲'

if ($script:RealJson) {
    $badPeakDates = New-Object System.Collections.Generic.List[string]
    foreach ($dateText in $script:RealHolidays) {
        $when = ConvertFrom-IsoTime ($dateText + 'T10:00:00+08:00')
        if ($when.DayOfWeek -eq [System.DayOfWeek]::Saturday -or $when.DayOfWeek -eq [System.DayOfWeek]::Sunday) { continue }
        $status = Get-DeepSeekTimeStatus -Time $when -Holidays $script:RealHolidays -CoveredYears $script:RealYears
        if ($status.IsPeak) { $badPeakDates.Add($dateText) }
    }
    Assert-AreEqual 0 $badPeakDates.Count ('所有法定节假日 10:00 都应为空闲；异常：' + ($badPeakDates -join ','))

    $mismatchPeakDates = New-Object System.Collections.Generic.List[string]
    $mismatchIdleDates = New-Object System.Collections.Generic.List[string]
    $day = [datetime]::new(2026, 1, 1)
    while ($day.Year -eq 2026) {
        $key = $day.ToString('yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)
        $isWeekend = ($day.DayOfWeek -eq [System.DayOfWeek]::Saturday) -or ($day.DayOfWeek -eq [System.DayOfWeek]::Sunday)
        $isHoliday = ($script:RealHolidays -contains $key)
        $when = ConvertFrom-IsoTime ($key + 'T10:00:00+08:00')
        $status = Get-DeepSeekTimeStatus -Time $when -Holidays $script:RealHolidays -CoveredYears $script:RealYears
        if ((-not $isWeekend) -and (-not $isHoliday)) {
            if (-not $status.IsPeak) { $mismatchPeakDates.Add($key) }
        } else {
            if ($status.IsPeak) { $mismatchIdleDates.Add($key) }
        }
        $day = $day.AddDays(1)
    }
    Assert-AreEqual 0 $mismatchPeakDates.Count ('2026 年所有非节假日的周一至周五 10:00 应为高峰；异常：' + ($mismatchPeakDates -join ','))
    Assert-AreEqual 0 $mismatchIdleDates.Count ('2026 年所有周末/法定节假日 10:00 应为空闲；异常：' + ($mismatchIdleDates -join ','))

    $badFormats = New-Object System.Collections.Generic.List[string]
    foreach ($dateText in $script:RealHolidays) {
        if (-not ($dateText -match '^\d{4}-\d{2}-\d{2}$')) { $badFormats.Add($dateText) }
    }
    Assert-AreEqual 0 $badFormats.Count ('节假日数据日期格式异常：' + ($badFormats -join ','))
    $duplicates = @($script:RealHolidays | Group-Object | Where-Object { $_.Count -gt 1 })
    Assert-AreEqual 0 $duplicates.Count '节假日数据无重复日期'
    Assert-IsTrue ($script:RealYears -contains 2026) '节假日数据覆盖 2026 年'
    Assert-IsTrue ($script:RealYears -contains 2025) '节假日数据覆盖 2025 年'
}

# ---------- 5. 下次切换与倒计时（真实数据） ----------
$countdownCases = @(
    @{ Time = '2026-10-28T08:00:00+08:00'; Next = '2026-10-28T09:00:00+08:00'; NextPeak = $true; Text = '01:00:00'; Countdown = '距高峰时段还有 01:00:00' },
    @{ Time = '2026-10-28T10:00:00+08:00'; Next = '2026-10-28T12:00:00+08:00'; NextPeak = $false; Text = '02:00:00'; Countdown = '距空闲时段还有 02:00:00' },
    @{ Time = '2026-10-28T12:30:00+08:00'; Next = '2026-10-28T14:00:00+08:00'; NextPeak = $true; Text = '01:30:00'; Countdown = '距高峰时段还有 01:30:00' },
    @{ Time = '2026-10-28T17:00:00+08:00'; Next = '2026-10-28T18:00:00+08:00'; NextPeak = $false; Text = '01:00:00'; Countdown = '距空闲时段还有 01:00:00' },
    @{ Time = '2026-10-28T19:00:00+08:00'; Next = '2026-10-29T09:00:00+08:00'; NextPeak = $true; Text = '14:00:00'; Countdown = '距高峰时段还有 14:00:00' },
    @{ Time = '2026-10-30T19:00:00+08:00'; Next = '2026-11-02T09:00:00+08:00'; NextPeak = $true; Text = '2天 14:00:00'; Countdown = '距高峰时段还有 2天 14:00:00' }
)
foreach ($case in $countdownCases) {
    $status = Get-TestStatus -Iso $case.Time -Holidays $script:RealHolidays -Years $script:RealYears
    Assert-AreEqual ($case.Next) $status.NextChange.ToString('yyyy-MM-ddTHH:mm:sszzz') ('下次切换时间：' + $case.Time)
    Assert-AreEqual $case.NextPeak $status.NextChangeIsPeak ('下次切换目标：' + $case.Time)
    Assert-AreEqual $case.Text $status.NextChangeText ('倒计时时长：' + $case.Time)
    Assert-AreEqual $case.Countdown $status.CountdownText ('倒计时文案：' + $case.Time)
}

# 跨周末：周五傍晚 -> 周一早上
$weekendGap = Get-TestStatus -Iso '2026-10-30T19:00:00+08:00' -Holidays @()
Assert-AreEqual '2026-11-02T09:00:00+08:00' $weekendGap.NextChange.ToString('yyyy-MM-ddTHH:mm:sszzz') '无节假日数据时跨周末应跳到周一 09:00'

# 跨多天节假日（合成数据）
$syntheticHolidays = @('2026-10-29', '2026-10-30')
$holidayGap = Get-TestStatus -Iso '2026-10-28T19:00:00+08:00' -Holidays $syntheticHolidays
Assert-AreEqual '2026-11-02T09:00:00+08:00' $holidayGap.NextChange.ToString('yyyy-MM-ddTHH:mm:sszzz') '连续节假日+周末后应跳到周一 09:00'
Assert-AreEqual '4天 14:00:00' $holidayGap.NextChangeText '连续节假日+周末的倒计时文案'

# ---------- 6. 展示字段 ----------
$peakStatus = Get-TestStatus -Iso '2026-10-28T10:00:00+08:00' -Holidays $script:RealHolidays -Years $script:RealYears
Assert-AreEqual '高峰时段' $peakStatus.StatusText '高峰状态文案'
Assert-AreEqual '价格 1.0×' $peakStatus.RateText '高峰价格文案'
Assert-AreEqual 100 $peakStatus.RatePercent '高峰价格百分比'
Assert-AreEqual '10月28日' $peakStatus.DateText '日期文案'
Assert-AreEqual '周三' $peakStatus.WeekText '星期文案'
Assert-AreEqual '10:00:00' $peakStatus.TimeText '时间文案'
Assert-AreEqual $true $peakStatus.IsPeakDay '工作日 IsPeakDay=True'
Assert-AreEqual 2 @($peakStatus.PeakWindows).Count '工作日有两个高峰窗口'

$idleStatus = Get-TestStatus -Iso '2026-10-28T20:15:07+08:00' -Holidays $script:RealHolidays -Years $script:RealYears
Assert-AreEqual '空闲时段' $idleStatus.StatusText '空闲状态文案'
Assert-AreEqual '价格 0.5×' $idleStatus.RateText '空闲价格文案'
Assert-AreEqual 50 $idleStatus.RatePercent '空闲价格百分比'
Assert-AreEqual '20:15:07' $idleStatus.TimeText '空闲时间文案'
Assert-AreEqual $true $idleStatus.IsPeakDay '工作日 IsPeakDay=True（空闲时段内）'

# ---------- 7. 节假日数据覆盖率提醒 ----------
$outsideCoverage = Get-DeepSeekTimeStatus -Time (ConvertFrom-IsoTime '2027-01-04T10:00:00+08:00') -Holidays $script:RealHolidays -CoveredYears @(2025, 2026) -HolidayNames @{}
Assert-AreEqual $false $outsideCoverage.YearCovered '2027 年未覆盖时 YearCovered=False'
Assert-AreEqual $true $outsideCoverage.IsPeak '2027-01-04 周一 10:00 按星期规则判高峰'
Assert-AreEqual '周一' $outsideCoverage.WeekText '2027-01-04 是周一'

# 未知年份无数据时不应崩溃
$unknownYear = Get-DeepSeekTimeStatus -Time (ConvertFrom-IsoTime '2030-01-02T10:00:00+08:00') -Holidays @() -CoveredYears @()
Assert-AreEqual $true $unknownYear.IsPeak '无数据时 2030-01-02 10:00 按星期规则判高峰（周三）'
Assert-AreEqual $true $unknownYear.YearCovered '未提供覆盖年份时默认不报未覆盖'

# ---------- 8. 倒计时格式化 ----------
Assert-AreEqual '00:00:59' (Get-DurationText -Span ([TimeSpan]::FromSeconds(59))) '倒计时格式 59 秒'
Assert-AreEqual '00:01:00' (Get-DurationText -Span ([TimeSpan]::FromSeconds(60))) '倒计时格式 60 秒'
Assert-AreEqual '01:00:00' (Get-DurationText -Span ([TimeSpan]::FromSeconds(3600))) '倒计时格式 1 小时'
Assert-AreEqual '1天 00:00:00' (Get-DurationText -Span ([TimeSpan]::FromDays(1))) '倒计时格式 1 天'
Assert-AreEqual '00:00:00' (Get-DurationText -Span ([TimeSpan]::FromSeconds(-5))) '负时长归零'

# ---------- 输出结果 ----------
Write-Host ''
Write-Host ('测试完成：通过 {0} 项，失败 {1} 项。' -f $script:PassCount, $script:FailCount)
if ($script:FailCount -gt 0) {
    Write-Host '失败明细：' -ForegroundColor Red
    foreach ($failure in $script:FailureList) {
        Write-Host ('  - ' + $failure) -ForegroundColor Red
    }
    exit 1
}
Write-Host '全部通过。' -ForegroundColor Green
exit 0
