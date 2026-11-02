#Requires -Version 5.1
<#
  逐方案离屏截图。

  默认截取全部界面方案并写入 design\previews；也可以只截指定方案：
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\capture-schemes.ps1
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\capture-schemes.ps1 -Schemes default,e2b -OutDir .\tmp

  截图进程使用独立互斥体，并直接把方案传给挂件，不会改动用户目录里的 settings.json。
#>
[CmdletBinding()]
param(
    [string[]]$Schemes = @(),
    [string]$OutDir = '',
    [string]$PreviewTime = '2026-10-28T10:30:24+08:00'
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$appPath = Join-Path $root 'DeepSeekClock.ps1'
$schemesPath = Join-Path $root 'lib\Schemes.ps1'
foreach ($path in @($appPath, $schemesPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw ('找不到文件：' + $path)
    }
}

# 方案清单来自方案引擎，新增方案后无需再来改这个脚本
. $schemesPath
if ($Schemes.Count -eq 0) {
    $Schemes = @($script:UiSchemes | ForEach-Object { [string]$_.Key })
} else {
    # powershell.exe -File 传进来的 -Schemes default,e2b 是单个字符串，这里统一拆开
    $Schemes = @($Schemes | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
}
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $root 'design\previews'
}
if (-not (Test-Path -LiteralPath $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

$powerShellExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $powerShellExe)) { $powerShellExe = 'powershell.exe' }

Write-Host ('输出目录：' + $OutDir)
Write-Host ('方案数量：' + $Schemes.Count)

$failed = 0
foreach ($scheme in $Schemes) {
    if (-not (Test-SchemeKey -Key $scheme)) {
        Write-Host ('未知方案：' + $scheme) -ForegroundColor Red
        $failed++
        continue
    }

    $out = Join-Path $OutDir ('scheme-' + $scheme + '.png')
    $arguments = '-NoProfile -STA -ExecutionPolicy Bypass -File "' + $appPath + '" -PreviewTime ' + $PreviewTime + ' -UiScheme ' + $scheme + ' -CapturePath "' + $out + '"'
    $process = Start-Process -FilePath $powerShellExe -ArgumentList $arguments -Wait -PassThru -NoNewWindow
    if (($process.ExitCode -eq 0) -and (Test-Path -LiteralPath $out)) {
        Write-Host ('OK   ' + $scheme + '  ->  ' + $out)
    } else {
        Write-Host ('FAIL ' + $scheme + '  退出码 ' + $process.ExitCode) -ForegroundColor Red
        $failed++
    }
    Start-Sleep -Milliseconds 200
}

Write-Host ''
if ($failed -gt 0) {
    Write-Host ('截图完成：失败 ' + $failed + ' 套。') -ForegroundColor Red
    exit 1
}
Write-Host ('截图完成：全部 ' + $Schemes.Count + ' 套成功。') -ForegroundColor Green
exit 0
