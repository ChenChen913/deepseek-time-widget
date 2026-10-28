#Requires -Version 5.1
<#
.SYNOPSIS
  DeepSeek 计费时段判断核心逻辑（纯函数，不依赖界面，便于单元测试）。

.DESCRIPTION
  规则来源：DeepSeek 官网“空闲时段与高峰时段”说明：
    · 高峰时段：北京时间周一至周五（不含中国法定节假日）09:00-12:00、14:00-18:00
    · 空闲时段：其余所有时间，包括周末及中国法定节假日全天
    · 空闲时段价格为高峰时段价格的一半

  说明：严格按官网字面规则实现。周末即使遇到“调休上班日”，仍按空闲时段处理。
  所有边界按“分钟”对齐：09:00:00 起进入高峰，12:00:00 起进入空闲，
  14:00:00 起进入高峰，18:00:00 起进入空闲。
#>

function ConvertTo-BeijingTime {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [DateTimeOffset]$Time
    )
    return $Time.ToOffset([TimeSpan]::FromHours(8))
}

function Get-BeijingNow {
    [CmdletBinding()]
    param()
    return [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8))
}

function Get-BeijingDateKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [DateTimeOffset]$Time
    )
    return $Time.ToString('yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)
}

function Test-IsHolidayDate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [DateTimeOffset]$Time,
        [string[]]$Holidays = @()
    )
    if ($null -eq $Holidays -or $Holidays.Count -eq 0) { return $false }
    $key = Get-BeijingDateKey -Time $Time
    foreach ($item in $Holidays) {
        if ($null -eq $item -or $item -eq '') { continue }
        if ([string]::Equals([string]$item, $key, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Test-IsPeakDay {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [DateTimeOffset]$Time,
        [string[]]$Holidays = @()
    )
    $beijing = ConvertTo-BeijingTime -Time $Time
    $dayOfWeek = $beijing.DayOfWeek
    if ($dayOfWeek -eq [System.DayOfWeek]::Saturday -or $dayOfWeek -eq [System.DayOfWeek]::Sunday) {
        return $false
    }
    if (Test-IsHolidayDate -Time $beijing -Holidays $Holidays) {
        return $false
    }
    return $true
}

function Test-IsPeakTime {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [DateTimeOffset]$Time,
        [string[]]$Holidays = @()
    )
    $beijing = ConvertTo-BeijingTime -Time $Time
    if (-not (Test-IsPeakDay -Time $beijing -Holidays $Holidays)) {
        return $false
    }
    $minuteOfDay = ($beijing.Hour * 60) + $beijing.Minute
    if (($minuteOfDay -ge 540) -and ($minuteOfDay -lt 720)) { return $true }
    if (($minuteOfDay -ge 840) -and ($minuteOfDay -lt 1080)) { return $true }
    return $false
}

function Find-NextTransition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [DateTimeOffset]$Time,
        [string[]]$Holidays = @()
    )
    $beijing = ConvertTo-BeijingTime -Time $Time
    $currentIsPeak = Test-IsPeakTime -Time $beijing -Holidays $Holidays
    $offset = [TimeSpan]::FromHours(8)
    $boundaries = @(540, 720, 840, 1080)
    for ($dayOffset = 0; $dayOffset -le 14; $dayOffset++) {
        $day = $beijing.Date.AddDays($dayOffset)
        foreach ($minuteOfDay in $boundaries) {
            $candidate = [System.DateTimeOffset]::new($day.AddMinutes($minuteOfDay), $offset)
            if ($candidate -le $beijing) { continue }
            if ((Test-IsPeakTime -Time $candidate -Holidays $Holidays) -ne $currentIsPeak) {
                return $candidate
            }
        }
    }
    return $null
}

function Get-DurationText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [TimeSpan]$Span
    )
    if ($Span.TotalSeconds -lt 0) { $Span = [TimeSpan]::Zero }
    $totalSeconds = [long][Math]::Floor($Span.TotalSeconds)
    $days = [long][Math]::Floor($totalSeconds / 86400)
    $hours = [long][Math]::Floor(($totalSeconds % 86400) / 3600)
    $minutes = [long][Math]::Floor(($totalSeconds % 3600) / 60)
    $seconds = [long]($totalSeconds % 60)
    if ($days -gt 0) {
        return ('{0}天 {1:00}:{2:00}:{3:00}' -f $days, $hours, $minutes, $seconds)
    }
    return ('{0:00}:{1:00}:{2:00}' -f $hours, $minutes, $seconds)
}

function Get-DeepSeekTimeStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [DateTimeOffset]$Time,
        [string[]]$Holidays = @(),
        [int[]]$CoveredYears = @(),
        [hashtable]$HolidayNames = @{}
    )
    $beijing = ConvertTo-BeijingTime -Time $Time
    $dateKey = Get-BeijingDateKey -Time $beijing
    $isWeekend = ($beijing.DayOfWeek -eq [System.DayOfWeek]::Saturday) -or ($beijing.DayOfWeek -eq [System.DayOfWeek]::Sunday)
    $isHoliday = Test-IsHolidayDate -Time $beijing -Holidays $Holidays
    $isPeakDay = Test-IsPeakDay -Time $beijing -Holidays $Holidays
    $isPeak = Test-IsPeakTime -Time $beijing -Holidays $Holidays

    $weekNames = @{
        'Monday' = '周一'; 'Tuesday' = '周二'; 'Wednesday' = '周三'; 'Thursday' = '周四'
        'Friday' = '周五'; 'Saturday' = '周六'; 'Sunday' = '周日'
    }
    $weekText = [string]$weekNames[[string]$beijing.DayOfWeek]
    $dateText = ('{0}月{1}日' -f $beijing.Month, $beijing.Day)

    $holidayName = ''
    if ($isHoliday -and $null -ne $HolidayNames -and $HolidayNames.ContainsKey($dateKey)) {
        $holidayName = [string]$HolidayNames[$dateKey]
    }

    $nextChange = Find-NextTransition -Time $beijing -Holidays $Holidays
    $nextChangeIsPeak = $false
    $nextChangeText = ''
    $countdownText = ''
    if ($null -ne $nextChange) {
        $nextChangeIsPeak = Test-IsPeakTime -Time $nextChange -Holidays $Holidays
        $nextChangeText = Get-DurationText -Span ($nextChange - $beijing)
        if ($nextChangeIsPeak) {
            $countdownText = '距高峰时段还有 ' + $nextChangeText
        } else {
            $countdownText = '距空闲时段还有 ' + $nextChangeText
        }
    } else {
        $countdownText = '无法计算下次切换'
    }

    $yearCovered = $true
    if ($null -ne $CoveredYears -and $CoveredYears.Count -gt 0) {
        $yearCovered = ($CoveredYears -contains $beijing.Year)
    }

    $statusText = '空闲时段'
    $rateText = '价格 0.5×'
    $ratePercent = 50
    if ($isPeak) {
        $statusText = '高峰时段'
        $rateText = '价格 1.0×'
        $ratePercent = 100
    }

    if ($isHoliday) {
        $todayText = '今日法定节假日，全天空闲'
    } elseif ($isWeekend) {
        $todayText = '今日周末，全天空闲'
    } else {
        $todayText = '今日高峰 09:00-12:00、14:00-18:00'
    }

    $peakWindows = @()
    if ($isPeakDay) {
        $peakWindows = @(
            [pscustomobject]@{ Start = (9.0 / 24.0); End = (12.0 / 24.0) },
            [pscustomobject]@{ Start = (14.0 / 24.0); End = (18.0 / 24.0) }
        )
    }
    $dayFraction = (($beijing.Hour * 3600) + ($beijing.Minute * 60) + $beijing.Second) / 86400.0

    return [pscustomobject]@{
        Now             = $beijing
        IsPeak          = $isPeak
        IsPeakDay       = $isPeakDay
        IsHoliday       = $isHoliday
        IsWeekend       = $isWeekend
        HolidayName     = $holidayName
        StatusText      = $statusText
        RateText        = $rateText
        RatePercent     = $ratePercent
        DateText        = $dateText
        WeekText        = $weekText
        TimeText        = $beijing.ToString('HH:mm:ss')
        YearCovered     = $yearCovered
        NextChange      = $nextChange
        NextChangeIsPeak = $nextChangeIsPeak
        NextChangeText  = $nextChangeText
        CountdownText   = $countdownText
        TodayText       = $todayText
        DayFraction     = $dayFraction
        PeakWindows     = $peakWindows
    }
}
