param(
    [string[]]$Schemes = @('default'),
    [string]$OutDir = 'C:\Users\11853\Desktop\deepseek-time-widget-main\design\previews',
    [string]$PreviewTime = '2026-10-28T16:20:00+08:00'
)

$ErrorActionPreference = 'Stop'
$root = 'C:\Users\11853\Desktop\deepseek-time-widget-main'
$settingsDir = Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'DeepSeekClock'
$settingsPath = Join-Path $settingsDir 'settings.json'

# 截图进程走独立互斥体（-CapturePath 分支），不会和正在运行的挂件抢单实例锁

if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$original = $null
if (Test-Path -LiteralPath $settingsPath) { $original = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 }

foreach ($scheme in $Schemes) {
    $payload = [ordered]@{ Left = 1180; Top = 140; Topmost = $true; LaunchCount = 9; UiScheme = $scheme }
    $json = $payload | ConvertTo-Json
    [System.IO.File]::WriteAllText($settingsPath, $json, (New-Object System.Text.UTF8Encoding($false)))

    $out = Join-Path $OutDir ("scheme-" + $scheme + ".png")
    & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $root 'DeepSeekClock.ps1') -PreviewTime $PreviewTime -CapturePath $out
    if (Test-Path -LiteralPath $out) {
        Write-Output ("OK   " + $scheme + "  ->  " + $out)
    } else {
        Write-Output ("FAIL " + $scheme)
    }
    Start-Sleep -Milliseconds 250
}

if ($null -ne $original) {
    [System.IO.File]::WriteAllText($settingsPath, $original, (New-Object System.Text.UTF8Encoding($false)))
}
