param(
    [string[]]$Schemes = @('default'),
    [string]$OutDir = 'C:\Users\11853\Desktop\deepseek-time-widget-main\design\previews',
    [string]$PreviewTime = '2026-10-28T10:30:24+08:00'
)

$ErrorActionPreference = 'Stop'
$root = 'C:\Users\11853\Desktop\deepseek-time-widget-main'

# 截图进程走独立互斥体（-CapturePath 分支），不会和正在运行的挂件抢单实例锁。
# 方案通过 -UiScheme 直接指定，不碰用户目录里的 settings.json
# （截图进程也不再回写设置，见 Save-Settings 里的拦截）。

if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

foreach ($scheme in $Schemes) {
    $out = Join-Path $OutDir ("scheme-" + $scheme + ".png")
    & powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $root 'DeepSeekClock.ps1') `
        -PreviewTime $PreviewTime -UiScheme $scheme -CapturePath $out
    if (Test-Path -LiteralPath $out) {
        Write-Output ("OK   " + $scheme + "  ->  " + $out)
    } else {
        Write-Output ("FAIL " + $scheme)
    }
    Start-Sleep -Milliseconds 200
}
