# Bir PNG karesindeki gövdeden kopuk küçük piksel kümelerini (ör. yere düşmüş sikkeler, uçuşan kırıntılar) siler.
# 8 komşulukla bağlı görünür pikseller bir küme sayılır; MinSize'dan küçük kümeler saydam yapılır.
# Kullanım: powershell -File tools/strip_loose_pixels.ps1 -MinSize 40 kare1.png kare2.png ...
#           -KeepLargest: en büyük küme dışındaki her şey silinir (gövdeye yakın kalan sikkeler için)
# Mammon'un throw animasyonunda bırakma sonrası karelerde yerde kalan sikkeleri temizlemek için yazıldı
# (paket yeniden indirilirse tekrar çalıştırılmalı).
param(
	[int]$MinSize = 40,
	[switch]$KeepLargest,   # boyuttan bağımsız: sadece en büyük küme (gövde) kalır
	[Parameter(ValueFromRemainingArguments = $true)][string[]]$Files
)
Add-Type -AssemblyName System.Drawing

foreach ($file in $Files) {
	$path = (Resolve-Path $file).Path
	$src = [System.Drawing.Bitmap]::FromFile($path)
	$bmp = New-Object System.Drawing.Bitmap $src
	$src.Dispose()
	$w = $bmp.Width; $h = $bmp.Height
	$label = New-Object 'int[]' ($w * $h)
	$removed = 0
	$next = 1
	$groups = @()
	for ($y = 0; $y -lt $h; $y++) {
		for ($x = 0; $x -lt $w; $x++) {
			$i = $y * $w + $x
			if ($label[$i] -ne 0 -or $bmp.GetPixel($x, $y).A -eq 0) { continue }
			# Kümeyi taşma ile bul
			$stack = New-Object System.Collections.Generic.Stack[int]
			$members = New-Object System.Collections.Generic.List[int]
			$stack.Push($i); $label[$i] = $next
			while ($stack.Count -gt 0) {
				$c = $stack.Pop(); $members.Add($c)
				$cx = $c % $w; $cy = [math]::Floor($c / $w)
				for ($dy = -1; $dy -le 1; $dy++) {
					for ($dx = -1; $dx -le 1; $dx++) {
						$nx = $cx + $dx; $ny = $cy + $dy
						if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $w -or $ny -ge $h) { continue }
						$n = $ny * $w + $nx
						if ($label[$n] -ne 0 -or $bmp.GetPixel($nx, $ny).A -eq 0) { continue }
						$label[$n] = $next; $stack.Push($n)
					}
				}
			}
			$groups += ,$members
			$next++
		}
	}
	$largest = ($groups | Measure-Object -Property Count -Maximum).Maximum
	foreach ($members in $groups) {
		$drop = if ($KeepLargest) { $members.Count -lt $largest } else { $members.Count -lt $MinSize }
		if ($drop) {
			foreach ($m in $members) { $bmp.SetPixel($m % $w, [math]::Floor($m / $w), [System.Drawing.Color]::Transparent) }
			$removed += $members.Count
		}
	}
	$bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
	$bmp.Dispose()
	Write-Output "$file : $removed piksel silindi"
}
