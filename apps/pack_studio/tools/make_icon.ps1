# Regenerates the Android launcher icons (legacy + adaptive + themed).
# Original art: cream folder with "30" on d30mode's orange. Windows PowerShell 5.1.
#   powershell -File tools\make_icon.ps1 [-FolderScale 0.78]
param([double]$FolderScale = 0.78)   # 1.0 = folder spans 2/3 of the canvas; lower leaves more orange around it
Add-Type -AssemblyName System.Drawing
$app = Split-Path $PSScriptRoot
$res = "$app\android\app\src\main\res"
$orange = [System.Drawing.ColorTranslator]::FromHtml('#FF8B55')
$cream  = [System.Drawing.ColorTranslator]::FromHtml('#FFF7E8')
$back   = [System.Drawing.ColorTranslator]::FromHtml('#F7D3B4')

function RoundRect($x, $y, $w, $h, $r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = 2 * $r
  $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $p.CloseFigure(); $p
}

# Folder + "30" on a 432-unit canvas scaled to $size. mono = one opaque colour with the 30 knocked out.
function DrawFolder($g, $size, $mono) {
  $s = $size / 432.0
  $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAlias'
  $g.ScaleTransform($s, $s)
  # shrink about the folder's visual centre (216, 221)
  $g.TranslateTransform(216, 221); $g.ScaleTransform($FolderScale, $FolderScale); $g.TranslateTransform(-216, -221)
  $c1 = if ($mono) { [System.Drawing.Color]::Black } else { $back }
  $c2 = if ($mono) { [System.Drawing.Color]::Black } else { $cream }
  $b1 = New-Object System.Drawing.SolidBrush $c1; $b2 = New-Object System.Drawing.SolidBrush $c2
  $g.FillPath($b1, (RoundRect 78 112 140 70 18))
  $g.FillPath($b1, (RoundRect 72 146 288 118 20))
  $g.FillPath($b2, (RoundRect 72 178 288 152 22))
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $ff = New-Object System.Drawing.FontFamily 'Segoe UI'
  $path.AddString('30', $ff, [int][System.Drawing.FontStyle]::Bold, 112, (New-Object System.Drawing.PointF 0, 0), [System.Drawing.StringFormat]::GenericTypographic)
  $bb = $path.GetBounds()
  $m = New-Object System.Drawing.Drawing2D.Matrix
  $m.Translate((216 - ($bb.X + $bb.Width / 2)), (254 - ($bb.Y + $bb.Height / 2)))
  $path.Transform($m)
  if ($mono) { $g.CompositingMode = 'SourceCopy'; $g.FillPath([System.Drawing.Brushes]::Transparent, $path); $g.CompositingMode = 'SourceOver' }
  else { $g.FillPath((New-Object System.Drawing.SolidBrush $orange), $path) }
}

function Render($size, $mode, $file) {
  $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp); $g.Clear([System.Drawing.Color]::Transparent)
  if ($mode -eq 'legacy') {
    $g.SmoothingMode = 'AntiAlias'
    $g.FillPath((New-Object System.Drawing.SolidBrush $orange), (RoundRect 0 0 $size $size ($size * 0.22)))
    DrawFolder $g $size $false
  } else { DrawFolder $g $size ($mode -eq 'mono') }
  $g.Dispose()
  New-Item -ItemType Directory -Force (Split-Path $file) | Out-Null
  $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
}

$dens = @{ mdpi = @(48, 108); hdpi = @(72, 162); xhdpi = @(96, 216); xxhdpi = @(144, 324); xxxhdpi = @(192, 432) }
foreach ($k in $dens.Keys) {
  Render $dens[$k][0] 'legacy' "$res\mipmap-$k\ic_launcher.png"
  Render $dens[$k][1] 'fg'     "$res\mipmap-$k\ic_launcher_foreground.png"
  Render $dens[$k][1] 'mono'   "$res\mipmap-$k\ic_launcher_monochrome.png"
}

New-Item -ItemType Directory -Force "$res\mipmap-anydpi-v26", "$res\values" | Out-Null
@'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
'@ | Set-Content "$res\mipmap-anydpi-v26\ic_launcher.xml" -Encoding utf8
@'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#FF8B55</color>
</resources>
'@ | Set-Content "$res\values\ic_launcher_background.xml" -Encoding utf8

Write-Host "icons written; preview: $tmp"
