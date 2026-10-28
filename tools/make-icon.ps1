#Requires -Version 5.1
<#
  生成挂件图标：assets\deepseek-clock.ico（256x256 PNG 压缩 ICO）与 assets\icon-preview.png。
  用法：powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tools\make-icon.ps1
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$assets = Join-Path $root 'assets'
if (-not (Test-Path -LiteralPath $assets)) {
    New-Item -ItemType Directory -Path $assets -Force | Out-Null
}

$size = 256
$bitmap = New-Object -TypeName System.Drawing.Bitmap -ArgumentList @($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.Clear([System.Drawing.Color]::Transparent)

$rect = New-Object -TypeName System.Drawing.RectangleF -ArgumentList @(10.0, 10.0, 236.0, 236.0)
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$radius = 58.0
$path.AddArc($rect.X, $rect.Y, $radius, $radius, 180, 90)
$path.AddArc(($rect.Right - $radius), $rect.Y, $radius, $radius, 270, 90)
$path.AddArc(($rect.Right - $radius), ($rect.Bottom - $radius), $radius, $radius, 0, 90)
$path.AddArc($rect.X, ($rect.Bottom - $radius), $radius, $radius, 90, 90)
$path.CloseFigure()

$darkTop = [System.Drawing.Color]::FromArgb(255, 17, 24, 39)
$darkBottom = [System.Drawing.Color]::FromArgb(255, 30, 41, 59)
$backgroundBrush = New-Object -TypeName System.Drawing.Drawing2D.LinearGradientBrush -ArgumentList @($rect, $darkTop, $darkBottom, 45.0)
$graphics.FillPath($backgroundBrush, $path)

$borderPen = New-Object -TypeName System.Drawing.Pen -ArgumentList @([System.Drawing.Color]::FromArgb(70, 255, 255, 255), 3.0)
$graphics.DrawPath($borderPen, $path)

$centerX = 128.0
$centerY = 128.0
$ringRadius = 62.0
$ringRect = New-Object -TypeName System.Drawing.RectangleF -ArgumentList @(($centerX - $ringRadius), ($centerY - $ringRadius), ($ringRadius * 2), ($ringRadius * 2))
$amber = [System.Drawing.Color]::FromArgb(255, 245, 158, 11)
$green = [System.Drawing.Color]::FromArgb(255, 52, 211, 153)
$amberPen = New-Object -TypeName System.Drawing.Pen -ArgumentList @($amber, 14.0)
$greenPen = New-Object -TypeName System.Drawing.Pen -ArgumentList @($green, 14.0)
$amberPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$amberPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$greenPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$greenPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$graphics.DrawArc($amberPen, $ringRect, 180.0, 180.0)
$graphics.DrawArc($greenPen, $ringRect, 0.0, 180.0)

$handPen = New-Object -TypeName System.Drawing.Pen -ArgumentList @([System.Drawing.Color]::White, 9.0)
$handPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$handPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$graphics.DrawLine($handPen, $centerX, $centerY, $centerX, ($centerY - 38.0))
$graphics.DrawLine($handPen, $centerX, $centerY, ($centerX + 26.0), ($centerY - 22.0))
$centerBrush = New-Object -TypeName System.Drawing.SolidBrush -ArgumentList @([System.Drawing.Color]::White)
$graphics.FillEllipse($centerBrush, ($centerX - 7.0), ($centerY - 7.0), 14.0, 14.0)

$previewPath = Join-Path $assets 'icon-preview.png'
$bitmap.Save($previewPath, [System.Drawing.Imaging.ImageFormat]::Png)

$pngStream = New-Object System.IO.MemoryStream
$bitmap.Save($pngStream, [System.Drawing.Imaging.ImageFormat]::Png)
$pngBytes = $pngStream.ToArray()
$pngStream.Dispose()

$iconPath = Join-Path $assets 'deepseek-clock.ico'
$fileStream = [System.IO.File]::Create($iconPath)
$writer = New-Object System.IO.BinaryWriter -ArgumentList $fileStream
$writer.Write([UInt16]0)
$writer.Write([UInt16]1)
$writer.Write([UInt16]1)
$writer.Write([Byte]0)
$writer.Write([Byte]0)
$writer.Write([Byte]0)
$writer.Write([Byte]0)
$writer.Write([UInt16]1)
$writer.Write([UInt16]32)
$writer.Write([UInt32]$pngBytes.Length)
$writer.Write([UInt32]22)
$writer.Write($pngBytes)
$writer.Flush()
$writer.Close()

$graphics.Dispose()
$bitmap.Dispose()

Get-Item -LiteralPath $iconPath | Select-Object FullName, Length | Format-List
Get-Item -LiteralPath $previewPath | Select-Object FullName, Length | Format-List
