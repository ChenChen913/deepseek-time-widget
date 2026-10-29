#Requires -Version 5.1
<#
  test/Test-Schemes.ps1 —— 界面方案引擎的数据校验

  只检查「配方数据本身」是否自洽，不碰 WPF：
  方案键唯一、配色族/色调/布局/装饰名都存在、尺寸合理、菜单顺序能循环。

  跑法：
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\Test-Schemes.ps1
#>

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$schemesPath = Join-Path $root 'lib\Schemes.ps1'
if (-not (Test-Path -LiteralPath $schemesPath)) {
    throw ('找不到方案引擎：' + $schemesPath)
}
. $schemesPath

$script:Pass = 0
$script:Fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Name, [string]$Detail = '')
    if ($Condition) {
        $script:Pass++
    } else {
        $script:Fail++
        $line = '  [FAIL] ' + $Name
        if ($Detail) { $line = $line + ' — ' + $Detail }
        Write-Host $line -ForegroundColor Red
    }
}

$knownLayouts = @('card', 'capsule', 'dial', 'scope', 'lcd', 'split', 'brutal', 'half', 'candle', 'solid', 'hud', 'gauge')
$knownDecor = @(
    'sheen', 'glowcorner', 'ring', 'quartz', 'sectors', 'wave', 'sine',
    'candles', 'lamps', 'ticks', 'split', 'plate', 'lcd', 'scanlines', 'orb',
    'scope', 'kline', 'scalebar', 'gauge', 'hudprogress', 'lcdvig'
)

# ---------- 清单基本形态 ----------
$schemes = @($script:UiSchemes)
Assert-True ($schemes.Count -eq 22) '方案数量为 22（默认界面 + 21 个）' ("实际 " + $schemes.Count)
Assert-True ($schemes[0].Key -eq 'default') '第一条是默认界面' ([string]$schemes[0].Key)

$keys = @{}
foreach ($spec in $schemes) {
    $key = [string]$spec.Key
    Assert-True (-not [string]::IsNullOrWhiteSpace($key)) '方案键非空' ([string]$spec.Name)
    Assert-True (-not $keys.ContainsKey($key)) ('方案键唯一：' + $key) ''
    $keys[$key] = $true
}

# ---------- 配方字段合法性 ----------
foreach ($spec in $schemes) {
    $label = [string]$spec.Key

    Assert-True ($knownLayouts -contains [string]$spec.Layout) ('布局名合法：' + $label) ([string]$spec.Layout)
    Assert-True ($script:SchemeTones.ContainsKey([string]$spec.Tone)) ('色调存在：' + $label) ([string]$spec.Tone)
    Assert-True ($script:SchemePalettes.ContainsKey([string]$spec.Palette)) ('配色族存在：' + $label) ([string]$spec.Palette)

    $width = [double]$spec.Width
    Assert-True (($width -ge 200) -and ($width -le 700)) ('宽度在合理区间：' + $label) ([string]$width)

    # 卡片布局的日期列被大号时钟挤在右边，宽度只够放下「10月28日」这一行，
    # 所以节日名只能挪到周几那一行（Update-Widget 里的 CompactDate 分支）。
    # 将来真加了更宽的卡片布局，这条规则要连同日期行一起重新评估。
    if ([string]$spec.Layout -eq 'card') {
        Assert-True ($width -le 340) ('卡片布局宽度 <= 340：' + $label) ([string]$width)
    }

    $height = [double]$spec.Height
    Assert-True (($height -eq 0) -or (($height -ge 90) -and ($height -le 400))) ('高度合法（0=自适应）：' + $label) ([string]$height)

    Assert-True (([double]$spec.Radius -ge 0) -and ([double]$spec.Radius -le 200)) ('圆角合法：' + $label) ([string]$spec.Radius)
    Assert-True ([double]$spec.ClockSize -gt 10) ('时钟字号 > 10：' + $label) ([string]$spec.ClockSize)

    foreach ($decor in @($spec.Decor)) {
        Assert-True ($knownDecor -contains [string]$decor) ('装饰器存在：' + $label) ([string]$decor)
    }

    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$spec.Name)) ('方案有名字：' + $label) ''
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$spec.Hint)) ('方案有说明：' + $label) ''

    # 表面类型只支持三种
    $surfaceType = [string]$spec.Surface.Type
    Assert-True (@('solid', 'gradient', 'radial') -contains $surfaceType) ('底色类型合法：' + $label) $surfaceType
}

# ---------- 查询函数 ----------
$fallback = Get-SchemeSpec -Key '不存在的键'
Assert-True ($fallback.Key -eq 'default') '未知键回落到默认界面' ([string]$fallback.Key)

Assert-True (Test-SchemeKey -Key 'c6') 'Test-SchemeKey 认得 c6' ''
Assert-True (-not (Test-SchemeKey -Key 'zz')) 'Test-SchemeKey 拒绝未知键' ''

# 循环切换：正着走一圈回到原点，倒着走一圈也回到原点
$walk = 'default'
for ($i = 0; $i -lt $schemes.Count; $i++) { $walk = Get-SchemeNeighbor -Key $walk -Step 1 }
Assert-True ($walk -eq 'default') '下一个方案走满一圈回到默认界面' $walk

$walk = 'default'
for ($i = 0; $i -lt $schemes.Count; $i++) { $walk = Get-SchemeNeighbor -Key $walk -Step -1 }
Assert-True ($walk -eq 'default') '上一个方案走满一圈回到默认界面' $walk

Assert-True ((Get-SchemeNeighbor -Key 'default' -Step 1) -eq 'a1') '默认界面的下一个是 A1' ([string](Get-SchemeNeighbor -Key 'default' -Step 1))
Assert-True ((Get-SchemeNeighbor -Key 'default' -Step -1) -eq 'f1') '默认界面的上一个是 F1' ([string](Get-SchemeNeighbor -Key 'default' -Step -1))

# ---------- 状态配色 ----------
$peakStatus = [pscustomobject]@{ IsPeak = $true; IsPeakDay = $true; IsWeekend = $false; IsHoliday = $false; DayFraction = 0.6; PeakWindows = @() }
$idleStatus = [pscustomobject]@{ IsPeak = $false; IsPeakDay = $true; IsWeekend = $false; IsHoliday = $false; DayFraction = 0.9; PeakWindows = @() }

$colorKeys = @('Accent', 'AccentSoft', 'BadgeBg', 'Track', 'Segment', 'Clock', 'Week', 'Date', 'Hint', 'Marker', 'Badge', 'Status')

foreach ($spec in $schemes) {
    foreach ($status in @($peakStatus, $idleStatus)) {
        $colors = Get-SchemeColors -Spec $spec -Status $status
        foreach ($name in $colorKeys) {
            Assert-True ($colors.ContainsKey($name) -and -not [string]::IsNullOrWhiteSpace([string]$colors[$name])) `
                ('配色齐全：' + [string]$spec.Key + ' / ' + $name) ''
        }
        # 满版色块的方案里，卡片底色就是 Accent，状态标题必须换成对比色，
        # 否则「高峰时段」四个字会印在同色底上，等于看不见。
        if ([bool]$spec.SurfaceByState) {
            Assert-True ([string]$colors.Status -ne [string]$colors.Accent) `
                ('满版色块方案的状态标题需用对比色：' + [string]$spec.Key) ([string]$colors.Status)
        }
    }
}

# ---------- 汇总 ----------
Write-Host ''
Write-Host ('测试完成：通过 ' + $script:Pass + ' 项，失败 ' + $script:Fail + ' 项。')
if ($script:Fail -gt 0) {
    Write-Host '存在失败项。' -ForegroundColor Red
    exit 1
}
Write-Host '全部通过。' -ForegroundColor Green
