#Requires -Version 5.1
<#
  构建可发布的安装包与便携版。

  默认流程：
    1. 运行核心、方案、渲染三套测试
    2. 编译 DeepSeekClock.exe 启动器
    3. 生成运行目录
    4. 编译 Inno Setup 安装包
    5. 生成便携 zip 和 SHA256SUMS.txt

  用法：
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\build-release.ps1 -Version 1.2.0

  可选：
    -SkipTests
    -InnoSetupPath C:\Program Files (x86)\Inno Setup 6\ISCC.exe
    -PfxPath .\cert.pfx -PfxPassword <密码> -TimestampUrl http://timestamp.digicert.com

  未提供 PfxPath 时构建仍然继续，但产物不会签名。
#>
[CmdletBinding()]
param(
    [string]$Version = '1.2.0',
    [switch]$SkipTests,
    [string]$InnoSetupPath = '',
    [string]$PfxPath = '',
    [string]$PfxPassword = '',
    [string]$TimestampUrl = 'http://timestamp.digicert.com'
)

$ErrorActionPreference = 'Stop'

$script:Root = Split-Path -Parent $PSScriptRoot
$script:DistDir = Join-Path $script:Root 'dist'
$script:AppDir = Join-Path $script:DistDir 'app'
$script:LibDir = Join-Path $script:Root 'lib'
$script:AssetsDir = Join-Path $script:Root 'assets'
$script:LauncherSource = Join-Path $script:Root 'launcher\DeepSeekClock.Launcher.cs'
$script:InstallerScript = Join-Path $script:Root 'installer\DeepSeekClock.iss'

$Version = $Version.Trim()
if ($Version.StartsWith('v')) { $Version = $Version.Substring(1) }
if ($Version -notmatch '^\d+\.\d+\.\d+(\d+)?$') {
    throw ('版本号格式应类似 1.2.0：' + $Version)
}
$versionParts = @($Version -split '\.')
$numericVersion = $Version
if ($versionParts.Count -eq 3) { $numericVersion = $Version + '.0' }
if ($versionParts.Count -eq 4) { $Version = ($versionParts[0..2] -join '.') }

if (-not $PfxPath -and -not [string]::IsNullOrWhiteSpace($env:DEEPSEEKCLOCK_PFX_PATH)) {
    $PfxPath = $env:DEEPSEEKCLOCK_PFX_PATH
}
if (-not $PfxPassword -and -not [string]::IsNullOrWhiteSpace($env:DEEPSEEKCLOCK_PFX_PASSWORD)) {
    $PfxPassword = $env:DEEPSEEKCLOCK_PFX_PASSWORD
}
if ($PfxPath -and -not (Test-Path -LiteralPath $PfxPath)) {
    Write-Warning ('签名证书不存在，跳过签名：' + $PfxPath)
    $PfxPath = ''
}

Write-Host ('构建版本：' + $Version)
Write-Host ('输出目录：' + $script:DistDir)

if (-not $SkipTests) {
    $tests = @('Test-Core.ps1', 'Test-Schemes.ps1', 'Test-Render.ps1')
    foreach ($test in $tests) {
        $testPath = Join-Path $script:Root ('test\' + $test)
        Write-Host ('运行测试：' + $test)
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $testPath
        if ($LASTEXITCODE -ne 0) {
            throw ('测试失败：' + $test + '，退出码 ' + $LASTEXITCODE)
        }
    }
}

if (Test-Path -LiteralPath $script:DistDir) {
    Remove-Item -LiteralPath $script:DistDir -Recurse -Force
}
New-Item -ItemType Directory -Path $script:AppDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $script:AppDir 'lib') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $script:AppDir 'assets') -Force | Out-Null

$filesToCopy = @(
    @{ From = (Join-Path $script:Root 'DeepSeekClock.ps1'); To = (Join-Path $script:AppDir 'DeepSeekClock.ps1') },
    @{ From = (Join-Path $script:Root 'holidays.json'); To = (Join-Path $script:AppDir 'holidays.json') },
    @{ From = (Join-Path $script:Root 'LICENSE'); To = (Join-Path $script:AppDir 'LICENSE') },
    @{ From = (Join-Path $script:Root '启动挂件.cmd'); To = (Join-Path $script:AppDir '启动挂件.cmd') },
    @{ From = (Join-Path $script:AssetsDir 'deepseek-clock.ico'); To = (Join-Path $script:AppDir 'assets\deepseek-clock.ico') }
)
foreach ($item in $filesToCopy) {
    if (-not (Test-Path -LiteralPath $item.From)) { throw ('缺少文件：' + $item.From) }
    Copy-Item -LiteralPath $item.From -Destination $item.To -Force
}
Get-ChildItem -LiteralPath $script:LibDir -Filter '*.ps1' -File | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $script:AppDir ('lib\' + $_.Name)) -Force
}

$usagePath = Join-Path $script:AppDir '使用说明.txt'
$usageText = @"
DeepSeek 时段挂件 v$Version

启动：双击 DeepSeekClock.exe
要求：Windows 10 / 11，系统自带 Windows PowerShell 5.1，无需安装第三方运行库

安装版：快捷方式由安装程序创建；卸载请在“设置 > 应用 > 已安装的应用”中操作。
便携版：首次启动会创建桌面和开始菜单快捷方式，可在右键菜单中使用“界面方案”等功能。

设置与联网更新数据保存在：
%APPDATA%\DeepSeekClock

项目主页：
https://github.com/ChenChen913/deepseek-time-widget

本工具只做本地时间计算，不调用 DeepSeek 接口，也不代表官方计费结果。
"@
[System.IO.File]::WriteAllText($usagePath, $usageText, (New-Object System.Text.UTF8Encoding($true)))

$frameworkCsc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $frameworkCsc)) {
    $frameworkCsc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
}
if (-not (Test-Path -LiteralPath $frameworkCsc)) {
    throw '找不到 .NET Framework csc.exe，无法编译启动器。'
}

$versionSource = Join-Path $script:DistDir 'launcher-version.cs'
$versionText = @"
using System.Reflection;
[assembly: AssemblyTitle("DeepSeek 时段挂件启动器")]
[assembly: AssemblyDescription("DeepSeek 计费时段挂件启动器")]
[assembly: AssemblyCompany("ChenChen913")]
[assembly: AssemblyProduct("DeepSeek 时段挂件")]
[assembly: AssemblyCopyright("MIT License")]
[assembly: AssemblyVersion("$numericVersion")]
[assembly: AssemblyFileVersion("$numericVersion")]
[assembly: AssemblyInformationalVersion("$Version")]
"@
[System.IO.File]::WriteAllText($versionSource, $versionText, (New-Object System.Text.UTF8Encoding($true)))

$launcherExe = Join-Path $script:AppDir 'DeepSeekClock.exe'
$cscArguments = '/nologo /target:winexe /platform:anycpu /optimize+ /r:System.dll /r:System.Core.dll /r:System.Windows.Forms.dll' `
    + ' /win32icon:"' + (Join-Path $script:AssetsDir 'deepseek-clock.ico') + '"' `
    + ' /out:"' + $launcherExe + '" "' + $script:LauncherSource + '" "' + $versionSource + '"'
$cscProcess = Start-Process -FilePath $frameworkCsc -ArgumentList $cscArguments -Wait -PassThru -NoNewWindow
if (($cscProcess.ExitCode -ne 0) -or (-not (Test-Path -LiteralPath $launcherExe))) {
    throw ('编译启动器失败，退出码 ' + $cscProcess.ExitCode)
}
Write-Host ('已编译启动器：' + $launcherExe)

function Find-SignTool {
    $candidates = @()
    $sdkRoots = @()
    if (${env:ProgramFiles(x86)}) { $sdkRoots += (Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\bin') }
    if ($env:ProgramFiles) { $sdkRoots += (Join-Path $env:ProgramFiles 'Windows Kits\10\bin') }
    foreach ($root in $sdkRoots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $candidates += @(Get-ChildItem -LiteralPath $root -Recurse -Filter 'signtool.exe' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '\\x64\\signtool\.exe$' } | Sort-Object FullName -Descending | Select-Object -ExpandProperty FullName)
    }
    if ($candidates.Count -gt 0) { return $candidates[0] }
    return ''
}

function Invoke-SignFile {
    param([string]$FilePath)
    if ([string]::IsNullOrWhiteSpace($PfxPath)) { return }
    if (-not (Test-Path -LiteralPath $FilePath)) { throw ('待签名文件不存在：' + $FilePath) }
    $signTool = Find-SignTool
    if ([string]::IsNullOrWhiteSpace($signTool)) {
        throw '找不到 signtool.exe，请安装 Windows SDK 或先不提供签名证书。'
    }
    $signArguments = 'sign /f "' + $PfxPath + '" /p "' + $PfxPassword + '" /fd SHA256 /tr "' + $TimestampUrl + '" /td SHA256 /a "' + $FilePath + '"'
    $signProcess = Start-Process -FilePath $signTool -ArgumentList $signArguments -Wait -PassThru -NoNewWindow
    if ($signProcess.ExitCode -ne 0) {
        throw ('签名失败：' + $FilePath + '，退出码 ' + $signProcess.ExitCode)
    }
    $verifyProcess = Start-Process -FilePath $signTool -ArgumentList ('verify /pa /q "' + $FilePath + '"') -Wait -PassThru -NoNewWindow
    if ($verifyProcess.ExitCode -ne 0) {
        throw ('签名校验失败：' + $FilePath)
    }
    Write-Host ('已签名：' + $FilePath)
}

Invoke-SignFile -FilePath $launcherExe

if ([string]::IsNullOrWhiteSpace($InnoSetupPath) -and -not [string]::IsNullOrWhiteSpace($env:ISCC_PATH)) {
    $InnoSetupPath = $env:ISCC_PATH
}
if ([string]::IsNullOrWhiteSpace($InnoSetupPath)) {
    $candidates = @()
    if ($env:ProgramFiles) { $candidates += (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe') }
    if (${env:ProgramFiles(x86)}) { $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe') }
    if ($env:LOCALAPPDATA) { $candidates += (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe') }
    if ($env:TEMP) { $candidates += (Join-Path $env:TEMP 'InnoSetup6\ISCC.exe') }
    $isccCommand = Get-Command 'iscc.exe' -ErrorAction SilentlyContinue
    if ($null -ne $isccCommand) { $candidates += $isccCommand.Source }
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            $InnoSetupPath = $candidate
            break
        }
    }
}
if ([string]::IsNullOrWhiteSpace($InnoSetupPath) -or (-not (Test-Path -LiteralPath $InnoSetupPath))) {
    throw '找不到 ISCC.exe，请安装 Inno Setup 6，或用 -InnoSetupPath 指定。'
}
Write-Host ('使用 Inno Setup：' + $InnoSetupPath)

$markerPath = Join-Path $script:AppDir 'install.marker'
[System.IO.File]::WriteAllText($markerPath, ('installed ' + $Version), (New-Object System.Text.UTF8Encoding($false)))

$isccArguments = '/DMyAppVersion=' + $Version + ' /DMyAppVersionNumeric=' + $numericVersion + ' "' + $script:InstallerScript + '"'
$isccProcess = Start-Process -FilePath $InnoSetupPath -ArgumentList $isccArguments -WorkingDirectory (Split-Path -Parent $script:InstallerScript) -Wait -PassThru -NoNewWindow
if ($isccProcess.ExitCode -ne 0) {
    throw ('编译安装包失败，退出码 ' + $isccProcess.ExitCode)
}
$setupExe = Join-Path $script:DistDir ('DeepSeekClock-Setup-v' + $Version + '.exe')
if (-not (Test-Path -LiteralPath $setupExe)) {
    throw ('安装包未生成：' + $setupExe)
}
Write-Host ('已生成安装包：' + $setupExe)

Invoke-SignFile -FilePath $setupExe

# 便携版不包含安装标记，首次启动仍按原逻辑创建快捷方式
Remove-Item -LiteralPath $markerPath -Force -ErrorAction SilentlyContinue
$portableRoot = Join-Path $script:DistDir 'portable'
$portableApp = Join-Path $portableRoot 'DeepSeekClock'
New-Item -ItemType Directory -Path $portableApp -Force | Out-Null
Copy-Item -Path (Join-Path $script:AppDir '*') -Destination $portableApp -Recurse -Force
$portableZip = Join-Path $script:DistDir ('DeepSeekClock-Portable-v' + $Version + '.zip')
if (Test-Path -LiteralPath $portableZip) { Remove-Item -LiteralPath $portableZip -Force }
Compress-Archive -Path $portableApp -DestinationPath $portableZip -CompressionLevel Optimal
Remove-Item -LiteralPath $portableRoot -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ('已生成便携版：' + $portableZip)

$hashLines = @()
foreach ($file in @($setupExe, $portableZip)) {
    $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
    $hashLines += ($hash + '  ' + (Split-Path -Leaf $file))
}
$hashPath = Join-Path $script:DistDir 'SHA256SUMS.txt'
[System.IO.File]::WriteAllText($hashPath, ($hashLines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
Write-Host ('已生成校验文件：' + $hashPath)

if ([string]::IsNullOrWhiteSpace($PfxPath)) {
    Write-Warning '本次构建未签名。发布前建议配置代码签名证书，否则 Windows 可能提示未知发布者。'
}

Write-Host ''
Write-Host '构建完成：'
Get-ChildItem -LiteralPath $script:DistDir -File | Select-Object Name, Length | Format-Table -AutoSize
