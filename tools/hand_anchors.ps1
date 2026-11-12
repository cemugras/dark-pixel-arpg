# Walt nişan pozlarının her animasyon karesinde yumruk (ten rengi küme) konumlarını ölçer, JSON'a yazar.
# Konumlar sprite merkezine göre piksel (64 px karakter ölçeğinde). Yüz/kulak gibi kümeler, referans
# noktaya (bir önceki karedeki yumruk) en yakın küme seçilerek elenir.
# Kullanım: hand_anchors.ps1 -Root <proje> -Out <json> -Spec "aim_two=<klasör>" -Spec "aim_one=<klasör>"
#           -Ref "aim_two:south=3,-9;-7,-9" ...  (her durum/yön için referans yumruklar, ';' ile ayrılmış)
param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Out,
    [Parameter(Mandatory = $true)][string[]]$Spec,
    [Parameter(Mandatory = $true)][string[]]$Ref,
    [double]$MaxJump = 7.0
)
Add-Type -AssemblyName System.Drawing
$dirs = @('south', 'south-east', 'east', 'north-east', 'north')

function Get-Clusters([string]$path) {
    $bmp = [System.Drawing.Bitmap]::FromFile($path)
    $w = $bmp.Width; $h = $bmp.Height
    $skin = New-Object 'bool[,]' $w, $h
    for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) {
        $c = $bmp.GetPixel($x, $y)
        if ($c.A -gt 200 -and $c.R -gt 140 -and $c.R -gt $c.G -and $c.G -gt $c.B -and ($c.R - $c.B) -gt 40) { $skin[$x, $y] = $true }
    } }
    $bmp.Dispose()
    $seen = New-Object 'bool[,]' $w, $h
    $list = @()
    for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) {
        if (-not $skin[$x, $y] -or $seen[$x, $y]) { continue }
        $st = New-Object System.Collections.Stack; $st.Push(@($x, $y)); $seen[$x, $y] = $true
        $n = 0; $sx = 0; $sy = 0
        while ($st.Count -gt 0) {
            $p = $st.Pop(); $n++; $sx += $p[0]; $sy += $p[1]
            foreach ($d in @(@(1, 0), @(-1, 0), @(0, 1), @(0, -1), @(1, 1), @(-1, -1), @(1, -1), @(-1, 1))) {
                $nx = $p[0] + $d[0]; $ny = $p[1] + $d[1]
                if ($nx -ge 0 -and $ny -ge 0 -and $nx -lt $w -and $ny -lt $h -and $skin[$nx, $ny] -and -not $seen[$nx, $ny]) { $seen[$nx, $ny] = $true; $st.Push(@($nx, $ny)) }
            }
        }
        if ($n -ge 3) { $list += , @(($sx / $n - $w / 2), ($sy / $n - $h / 2), $n) }
    } }
    return , $list
}

# Referansları ayrıştır: "aim_two:south=3,-9;-7,-9"
$refs = @{}
foreach ($r in $Ref) {
    $k, $v = $r -split '=', 2
    $pts = @()
    foreach ($pt in ($v -split ';')) { $xy = $pt -split ','; $pts += , @([double]$xy[0], [double]$xy[1]) }
    $refs[$k] = $pts
}

$result = [ordered]@{}
$report = @()
foreach ($s in $Spec) {
    $state, $folder = $s -split '=', 2
    $result[$state] = [ordered]@{}
    foreach ($anim in @('run', 'idle')) {
        $result[$state][$anim] = [ordered]@{}
        foreach ($dir in $dirs) {
            $key = $dir -replace '-', '_'
            $prev = $refs["${state}:$key"]
            $frames = @()
            $files = Get-ChildItem (Join-Path $Root "$folder/animations/$anim/$dir") -Filter *.png | Sort-Object Name
            $misses = 0
            foreach ($f in $files) {
                $cl = Get-Clusters $f.FullName
                $pts = @()
                for ($i = 0; $i -lt $prev.Count; $i++) {
                    $best = $null; $bd = $MaxJump
                    foreach ($c in $cl) {
                        $dd = [Math]::Sqrt([Math]::Pow($c[0] - $prev[$i][0], 2) + [Math]::Pow($c[1] - $prev[$i][1], 2))
                        if ($dd -lt $bd) { $bd = $dd; $best = $c }
                    }
                    if ($best) { $pts += , @([Math]::Round($best[0], 1), [Math]::Round($best[1], 1)) }
                    else { $pts += , $prev[$i]; $misses++ }  # bulunamazsa önceki konum (el gövdenin arkasında)
                }
                $frames += , $pts
                $prev = $pts
            }
            $result[$state][$anim][$key] = $frames
            $report += "{0}/{1}/{2}: {3} kare, bulunamayan {4}" -f $state, $anim, $key, $files.Count, $misses
        }
    }
}
# BOM'suz UTF-8 (Godot JSON ayrıştırıcısı BOM'u sevmez)
$json = $result | ConvertTo-Json -Depth 8 -Compress
[System.IO.File]::WriteAllText((Join-Path $Root $Out), $json, (New-Object System.Text.UTF8Encoding $false))
$report
