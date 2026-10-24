# Genera assets\zonely.ico (16, 24, 32, 48, 64 y 256 px) con el icono de tres bloques de Zonely.
# Uso:  powershell -ExecutionPolicy Bypass -File scripts\make-icon.ps1
Add-Type -AssemblyName System.Drawing

$out = Join-Path $PSScriptRoot '..\assets\zonely.ico'
$sizes = 16, 24, 32, 48, 64, 256

function RoundRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = New-Object Drawing.Drawing2D.GraphicsPath
    $d = 2 * $r
    $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure(); return $p
}

function Render([int]$s) {
    $bmp = New-Object Drawing.Bitmap $s, $s, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.Clear([Drawing.Color]::Transparent)
    # Icono 160x150 centrado con un margen del 6 %.
    $k = ($s * 0.88) / 160.0
    $ox = ($s - 160 * $k) / 2; $oy = ($s - 150 * $k) / 2
    $blocks = @(
        @(0, 0, 88, 72, '#38BDF8', '#3B82F6'),
        @(0, 78, 88, 72, '#5B7CF6', '#8B5CF6'),
        @(96, 0, 64, 150, '#9B6CF8', '#7C3AED'))
    foreach ($b in $blocks) {
        $x = $ox + $b[0] * $k; $y = $oy + $b[1] * $k; $w = $b[2] * $k; $h = $b[3] * $k
        $path = RoundRect $x $y $w $h (16 * $k)
        $rect = New-Object Drawing.RectangleF $x, $y, $w, $h
        $br = New-Object Drawing.Drawing2D.LinearGradientBrush $rect, ([Drawing.ColorTranslator]::FromHtml($b[4])), ([Drawing.ColorTranslator]::FromHtml($b[5])), 45.0
        $g.FillPath($br, $path)
    }
    $g.Dispose(); return $bmp
}

$png = @()
foreach ($s in $sizes) {
    $ms = New-Object IO.MemoryStream
    (Render $s).Save($ms, [Drawing.Imaging.ImageFormat]::Png)
    $png += , $ms.ToArray()
}

$fs = [IO.File]::Create($out); $bw = New-Object IO.BinaryWriter $fs
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $s = $sizes[$i]; $dim = if ($s -ge 256) { 0 } else { $s }
    $bw.Write([byte]$dim); $bw.Write([byte]$dim); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32)
    $bw.Write([uint32]$png[$i].Length); $bw.Write([uint32]$offset)
    $offset += $png[$i].Length
}
foreach ($d in $png) { $bw.Write($d) }
$bw.Close(); $fs.Close()
"Creado $out"

# PNG de 1024 px: electron-builder lo convierte en el .icns de macOS.
$big = Join-Path $PSScriptRoot '..\assets\zonely.png'
(Render 1024).Save($big, [Drawing.Imaging.ImageFormat]::Png)
"Creado $big"
