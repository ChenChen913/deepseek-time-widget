#Requires -Version 5.1
<#
  test/Test-Render.ps1 —— 23 套界面离屏渲染冒烟测试

  只验证「界面能不能真的渲染出来」：
  启动一个 STA 子进程，用 -CycleCapture 依次切完 23 套方案并截图，
  再校验截图数量、文件大小、图片尺寸和子进程输出。

  运行时会短暂弹出挂件窗口，约 15 秒。

  跑法：
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\test\Test-Render.ps1
  退出码 0 = 全部通过；非 0 = 存在失败。
#>
[CmdletBinding()]
param(
    [switch]$KeepArtifacts
)

$ErrorActionPreference = 'Stop'

$script:Root = Split-Path -Parent $PSScriptRoot
$script:AppPath = Join-Path $script:Root 'DeepSeekClock.ps1'
$script:SchemesPath = Join-Path $script:Root 'lib\Schemes.ps1'
foreach ($path in @($script:AppPath, $script:SchemesPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw ('找不到文件：' + $path)
    }
}

# 方案清单直接来自方案引擎，避免测试里再维护一份硬编码的 23 个键
. $script:SchemesPath
$script:ExpectedKeys = @($script:UiSchemes | ForEach-Object { [string]$_.Key })

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

$script:OutDir = Join-Path ([System.IO.Path]::GetTempPath()) ('deepseek-clock-render-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $script:OutDir -Force | Out-Null
$stdoutPath = Join-Path $script:OutDir 'render.stdout.txt'
$stderrPath = Join-Path $script:OutDir 'render.stderr.txt'

Write-Host ('渲染目录：' + $script:OutDir)
Write-Host ('方案数量：' + $script:ExpectedKeys.Count)

$previewTime = '2026-10-28T10:30:24+08:00'
$exe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $exe)) { $exe = 'powershell.exe' }
$arguments = '-NoProfile -STA -ExecutionPolicy Bypass -File "' + $script:AppPath + '" -PreviewTime ' + $previewTime + ' -CycleCapture "' + $script:OutDir + '"'

$process = Start-Process -FilePath $exe -ArgumentList $arguments -PassThru -WindowStyle Hidden `
    -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
$finished = $process.WaitForExit(120000)
if (-not $finished) {
    try { $process.Kill() } catch { }
    throw ('界面渲染超时（120 秒），目录：' + $script:OutDir)
}
$process.WaitForExit()
$exitCode = [int]$process.ExitCode
Write-Host ('子进程退出码：' + $exitCode)

$stdoutText = ''
$stderrText = ''
if (Test-Path -LiteralPath $stdoutPath) {
    $stdoutText = (Get-Content -LiteralPath $stdoutPath -Raw) -replace "`r`n", "`n"
}
if (Test-Path -LiteralPath $stderrPath) {
    $stderrText = Get-Content -LiteralPath $stderrPath -Raw
    if (-not [string]::IsNullOrWhiteSpace($stderrText)) {
        Write-Host '子进程 stderr：' -ForegroundColor Yellow
        Write-Host $stderrText.Trim()
    }
}

if ($exitCode -ne 0) {
    Assert-True $false '渲染子进程正常退出' ('退出码 ' + $exitCode)
}

$captured = @(Get-ChildItem -LiteralPath $script:OutDir -Filter 'cycle-*.png' -File)
Assert-True ($captured.Count -eq $script:ExpectedKeys.Count) '截图数量与方案数量一致' ('期望 ' + $script:ExpectedKeys.Count + '，实际 ' + $captured.Count)

Add-Type -AssemblyName System.Drawing

foreach ($key in $script:ExpectedKeys) {
    $path = Join-Path $script:OutDir ('cycle-' + $key + '.png')
    Assert-True (Test-Path -LiteralPath $path) ('截图存在：' + $key) $path
    if (-not (Test-Path -LiteralPath $path)) { continue }

    $size = (Get-Item -LiteralPath $path).Length
    Assert-True ($size -gt 2000) ('截图不是空图：' + $key) ([string]$size + ' 字节')

    try {
        $image = [System.Drawing.Image]::FromFile($path)
        try {
            $width = $image.Width
            $height = $image.Height
        } finally {
            $image.Dispose()
        }
        Assert-True (($width -ge 200) -and ($height -ge 50)) ('截图尺寸合理：' + $key) ($width.ToString() + 'x' + $height.ToString())
    } catch {
        Assert-True $false ('截图可正常解码：' + $key) $_.Exception.Message
    }

    Assert-True ($stdoutText -match ('(?m)^OK\s+' + [regex]::Escape($key) + '$')) ('渲染日志标记 OK：' + $key) ''
}

Write-Host ''
Write-Host ('测试完成：通过 ' + $script:Pass + ' 项，失败 ' + $script:Fail + ' 项。')
if ($script:Fail -gt 0) {
    Write-Host ('截图目录已保留：' + $script:OutDir) -ForegroundColor Yellow
    Write-Host '存在失败项。' -ForegroundColor Red
    exit 1
}
if (-not $KeepArtifacts) {
    try { Remove-Item -LiteralPath $script:OutDir -Recurse -Force } catch { }
}
Write-Host '全部通过。' -ForegroundColor Green
exit 0
