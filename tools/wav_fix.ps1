# 16 bit mono PCM WAV: baştaki sessizliği kırpar (5 ms pay) ve tepe seviyesini hedef dBFS'e getirir.
# Kullanım: wav_fix.ps1 -Path dosya.wav [-TargetDb -4] [-ThresholdDb -40]
param(
    [Parameter(Mandatory = $true)][string]$Path,
    [double]$TargetDb = -4.0,
    [double]$ThresholdDb = -40.0
)
$bytes = [System.IO.File]::ReadAllBytes($Path)
# "data" parçasını bul
$dataOff = -1
for ($i = 12; $i -lt $bytes.Length - 8; ) {
    $id = [System.Text.Encoding]::ASCII.GetString($bytes, $i, 4)
    $size = [BitConverter]::ToInt32($bytes, $i + 4)
    if ($id -eq 'data') { $dataOff = $i; break }
    $i += 8 + $size + ($size % 2)
}
if ($dataOff -lt 0) { throw "data chunk yok: $Path" }
$fmtChannels = [BitConverter]::ToInt16($bytes, 22)
$bits = [BitConverter]::ToInt16($bytes, 34)
$rate = [BitConverter]::ToInt32($bytes, 24)
if ($bits -ne 16 -or $fmtChannels -lt 1 -or $fmtChannels -gt 2) { throw "16 bit mono/stereo degil: $Path" }

# Stereo ise kanalların ortalaması alınarak mono'ya çevrilir
$dataSize = [BitConverter]::ToInt32($bytes, $dataOff + 4)
$n = [int]($dataSize / (2 * $fmtChannels))
$samples = New-Object 'int[]' $n
$peak = 0
for ($k = 0; $k -lt $n; $k++) {
    $sum = 0
    for ($c = 0; $c -lt $fmtChannels; $c++) {
        $sum += [BitConverter]::ToInt16($bytes, $dataOff + 8 + 2 * ($k * $fmtChannels + $c))
    }
    $s = [int][Math]::Round($sum / $fmtChannels)
    $samples[$k] = $s
    $a = [Math]::Abs([int]$s)
    if ($a -gt $peak) { $peak = $a }
}
$thr = 32768 * [Math]::Pow(10, $ThresholdDb / 20)
$first = 0
for ($k = 0; $k -lt $n; $k++) { if ([Math]::Abs($samples[$k]) -gt $thr) { $first = $k; break } }
$start = [Math]::Max(0, $first - [int]($rate * 0.005))
$gain = (32767 * [Math]::Pow(10, $TargetDb / 20)) / $peak

$outN = $n - $start
$out = New-Object 'byte[]' (44 + 2 * $outN)
[System.Text.Encoding]::ASCII.GetBytes('RIFF').CopyTo($out, 0)
[BitConverter]::GetBytes([int](36 + 2 * $outN)).CopyTo($out, 4)
[System.Text.Encoding]::ASCII.GetBytes('WAVEfmt ').CopyTo($out, 8)
[BitConverter]::GetBytes([int]16).CopyTo($out, 16)
[BitConverter]::GetBytes([int16]1).CopyTo($out, 20)
[BitConverter]::GetBytes([int16]1).CopyTo($out, 22)
[BitConverter]::GetBytes([int]$rate).CopyTo($out, 24)
[BitConverter]::GetBytes([int]($rate * 2)).CopyTo($out, 28)
[BitConverter]::GetBytes([int16]2).CopyTo($out, 32)
[BitConverter]::GetBytes([int16]16).CopyTo($out, 34)
[System.Text.Encoding]::ASCII.GetBytes('data').CopyTo($out, 36)
[BitConverter]::GetBytes([int](2 * $outN)).CopyTo($out, 40)
for ($k = 0; $k -lt $outN; $k++) {
    $v = [Math]::Round($samples[$start + $k] * $gain)
    if ($v -gt 32767) { $v = 32767 } elseif ($v -lt -32768) { $v = -32768 }
    [BitConverter]::GetBytes([int16]$v).CopyTo($out, 44 + 2 * $k)
}
[System.IO.File]::WriteAllBytes($Path, $out)
"{0}: {1:N0} ms kirpildi, kazanc {2:N1} dB" -f (Split-Path $Path -Leaf), ($start / $rate * 1000), (20 * [Math]::Log10($gain))
