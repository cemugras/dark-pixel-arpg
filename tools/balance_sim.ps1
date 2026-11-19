# Zorluk dengesi hesap tablosu (oyuna girmez). Oyundaki formüllerle dalga dalga kaba bir tahmin yapar:
# toplanan altın, o altınla alınan tipik yapı (2 AK47 + gümüş mermi + silah geliştirmeleri, kalan savunmaya),
# oyuncunun saniyedeki hasarı, sahneye saniyede gelen yaratık canı, boss'u öldürme süresi, ölmeden kaç pençe yenir.
# Kullanım: tools/balance_sim.ps1 [-HealthPerWave 0.12] [-DamagePerWave 0.1] [-IntervalMin 0.25] ... (aşağıdaki param'lar)
# Değerler oyundakiyle aynı varsayılanlarla başlar; denemek için parametre verilir, oyun dosyaları değişmez.
param(
    [double]$HealthPerWave = 0.10,     # enemy.gd HEALTH_PER_WAVE (HealthLateFrom dalgasına kadar)
    [double]$HealthLate = 0.18,        # enemy.gd HEALTH_PER_WAVE_LATE: HealthLateFrom dalgasından sonra can artışı (-1 = HealthPerWave ile aynı, tek eğri)
    [int]$HealthLateFrom = 20,         # enemy.gd HEALTH_LATE_FROM
    [double]$BossHealthPerWave = -1,   # boss için ayrı eğri (-1 = HealthPerWave ile aynı, şu anki durum)
    [double]$DamagePerWave = 0.07,     # enemy.gd setup: hasar çarpanı 1 + bu x (dalga-1)
    [double]$IntervalStart = 1.0,      # wave_manager _spawn_interval
    [double]$IntervalStep = 0.02,
    [double]$IntervalMin = 0.25,
    [double]$RateGrowth = 0.04,           # >0 ise doğma HIZI doğrusal artar: saniyede 1 + bu x (dalga-1) yaratık (aralık = 1/hız, en az IntervalMin)
    [double]$BossHpMult = 1.0,         # tüm boss canlarına çarpan (deneme)
    [double]$BossSpawnMult = 3.0,      # boss dalgasında doğma aralığı çarpanı
    [int]$CoinStepWaves = 0,           # sikke değeri her bu kadar dalgada +1 (0 = kapalı, şu anki durum)
    [int]$AkUnlockWave = 20,           # ak47.tres unlock_wave: AK47 bu dalga bitince mağazada alınabilir (öncesi Glock)
    [int]$SilverCost = 150,            # game_state.gd SILVER_COST
    [switch]$KeepUpgradesOnSwap,       # değiştirmede Damage/Fire Rate/gümüş yuvada kalır, sadece eski silahın fiyatının yarısı düşer (açık değilse silahla gider)
    [int]$SmgUnlockWave = 10,          # smg.tres unlock_wave (101 = SMG yokmuş gibi)
    [double]$SmgDps = 22.5, [int]$SmgPrice = 45,   # smg.tres: 5 x 4.5
    [double]$AkDps = 23.8,             # AK47 taban hasar/sn (7 x 3.4)
    [double]$OffenseShare = 0.7,       # altının saldırıya giden payı (kalanı can/zırh/yenilenme)
    [double]$Efficiency = 0.7,         # isabet/boşa giden hasar payı (kaçan mermi, fazla vuruş)
    [int[]]$Waves = @(1, 5, 10, 15, 20, 30, 40, 50, 60, 70, 80, 90, 100)
)
if ($HealthLate -lt 0) { $HealthLate = $HealthPerWave }
$useBossCurve = ($BossHealthPerWave -ge 0)
# İki parçalı can eğrisi: HealthLateFrom dalgasına kadar HealthPerWave, sonrası HealthLate (enemy.gd ile aynı tutulmalı)
function HpMult($w) { $e = [math]::Min($w, $HealthLateFrom) - 1; $l = [math]::Max(0, $w - $HealthLateFrom); 1 + $HealthPerWave * $e + $HealthLate * $l }

# Normal yaratıklar: can, sikke, ağırlık (min_wave, taban, dalga başına), pençe hasarı
$enemies = @(
    @{ name = 'soul';  hp = 20; coin = 1; min = 1;  w = 1.5; wpw = 0.0 },
    @{ name = 'harpy'; hp = 10; coin = 1; min = 3;  w = 1.0; wpw = 0.05 },
    @{ name = 'hound'; hp = 30; coin = 2; min = 5;  w = 0.5; wpw = 0.08 },
    @{ name = 'fly';   hp = 5;  coin = 1; min = 41; w = 0.6; wpw = 0.05; n = 3 },   # n = swarm_size (bir doğmada kaç tane)
    @{ name = 'lilim'; hp = 25; coin = 2; min = 51; w = 0.4; wpw = 0.04 },
    @{ name = 'locust'; hp = 30; coin = 2; min = 81; w = 0.4; wpw = 0.04 },  # Abyss Locust
    @{ name = 'grigori'; hp = 30; coin = 2; min = 91; w = 0.4; wpw = 0.04 }   # Grigori
)
$bosses = @{ 10 = 540; 20 = 1950; 30 = 1800; 40 = 1860; 50 = 2100; 60 = 2280; 70 = 2460; 80 = 2640; 90 = 2820; 100 = 3000 }  # 100 henüz yok: tahmini taban
$bossCoin = @{ 10 = 100; 20 = 150; 30 = 200; 40 = 250; 50 = 300; 60 = 350; 70 = 400; 80 = 450; 90 = 500; 100 = 0 }

function Cost($base, $step, $ratio, $level) { [math]::Ceiling(($base + $step * $level) * $ratio) }

$gold = 0.0; $bank = 0.0; $offGold = 0.0; $defGold = 0.0
# Yuvalar: 'g' = Glock (10 x 1.5), 'a' = AK47 (6 x 3). Başlangıç: tek Glock (bedava)
$type = @('g'); $spent = @(0, 0); $sil = @(0, 0)
$gunDps = @{ g = 15; s = $SmgDps; a = $AkDps }; $gunPrice = @{ g = 30; s = $SmgPrice; a = 60 }
$gunTier = @{ g = 0; s = 1; a = 2 }
$dmgLv = @(0, 0); $frLv = @(0, 0)
$hpLv = 0; $armorLv = 0; $regenLv = 0
$rows = @()

for ($wave = 1; $wave -le 100; $wave++) {
    $isBoss = ($wave % 10 -eq 0)
    $interval = if ($RateGrowth -gt 0) { [math]::Max($IntervalMin, 1 / (1 + $RateGrowth * ($wave - 1))) } else { [math]::Max($IntervalMin, $IntervalStart - $IntervalStep * ($wave - 1)) }
    $duration = [math]::Min(20 + 2 * ($wave - 1), 60)
    $hpMult = HpMult $wave
    $dmgMult = 1 + $DamagePerWave * ($wave - 1)
    $coinBonus = if ($CoinStepWaves -gt 0) { [math]::Floor(($wave - 1) / $CoinStepWaves) } else { 0 }

    # Bu dalgadaki ortalama yaratık
    $tw = 0.0; $hpSum = 0.0; $coinSum = 0.0
    foreach ($e in $enemies) {
        if ($wave -lt $e.min) { continue }
        $wt = $e.w + $e.wpw * ($wave - $e.min)
        $n = if ($e.n) { $e.n } else { 1 }
        $tw += $wt; $hpSum += $wt * $e.hp * $n; $coinSum += $wt * ($e.coin + $coinBonus) * $n
    }
    $avgHp = $hpSum / $tw * $hpMult
    $avgCoin = $coinSum / $tw

    # Oyuncunun bu dalgadaki gücü (mağazada önceki dalgaların altınıyla alındı)
    $dps = 0.0
    for ($s = 0; $s -lt $type.Count; $s++) {
        $sv = if ($sil[$s]) { 2 } else { 1 }
        $base = $gunDps[$type[$s]]
        $dps += $base * (1 + 0.15 * $dmgLv[$s]) * $sv * (1 + 0.1 * $frLv[$s])
    }
    $effDps = $dps * $Efficiency
    $spawnInterval = if ($isBoss) { $interval * $BossSpawnMult } else { $interval }
    $incoming = $avgHp / $spawnInterval   # saniyede gelen can
    $ratio = $effDps / $incoming

    $maxHp = 100 + 10 * $hpLv
    $armor = $armorLv
    $reduction = $armor / ($armor + 15)
    $claw = [math]::Max(1, [math]::Round(6 * $dmgMult * (1 - $reduction)))   # Damned Soul pençesi
    $hitsToDie = [math]::Floor($maxHp / $claw)

    $bossTtk = ''
    $earn = 0.0
    if ($isBoss) {
        $bossHp = $bosses[$wave] * $BossHpMult * $(if ($useBossCurve) { 1 + $BossHealthPerWave * ($wave - 1) } else { HpMult $wave })
        $surplus = $effDps - $incoming
        if ($surplus -gt 0) {
            $t = $bossHp / $surplus
            $bossTtk = if ($t -gt 999) { '>999' } else { [math]::Round($t) }
            $earn = $t / $spawnInterval * $avgCoin + $bossCoin[$wave]
        } else {
            $bossTtk = 'never'
            $earn = 60 / $spawnInterval * $avgCoin   # boss ölmüyor: 60 sn dayanıp ölür varsayımı
        }
    } else {
        $earn = $duration / $interval * $avgCoin
    }
    $gold += $earn   # dalgada kalan yaratıklar da öldürülmek zorunda: doğan her yaratığın altını gelir

    if ($Waves -contains $wave) {
        $rows += [pscustomobject]@{
            Dalga = $wave; ToplamAltin = [math]::Round($gold); Silah = (($type | ForEach-Object { @{ g = 'Gl'; s = 'SMG'; a = 'AK' }[$_] }) -join '+') + $(if ($sil[0] + $sil[1]) { ' gm' + ($sil[0] + $sil[1]) } else { '' })
            DmgLv = ($dmgLv -join '/'); FrLv = ($frLv -join '/'); Hasar_sn = [math]::Round($effDps)
            GelenCan_sn = [math]::Round($incoming); Oran = [math]::Round($ratio, 2)
            BossSure_sn = $bossTtk; Can = $maxHp; Zirh = $armor; Pence = $claw; KacPence = $hitsToDie
        }
    }

    # Mağaza: önce ikinci silah (kilidi açık en iyi silah), sonra pay oranında saldırı/savunma.
    # Daha iyi silahın kilidi açılınca yuvalar ona değiştirilir. KeepUpgradesOnSwap yoksa geliştirmeler ve gümüş silahla gider,
    # harcamanın yarısı fiyattan düşer; varsa yuvada kalır, sadece eski silahın fiyatının yarısı düşer.
    # Gümüş: geliştirmeler kalıyorsa her silaha, gitmiyorsa sadece son silaha (AK47) alınır. Silah geliştirmesinde en ucuzu önce.
    $best = 'g'
    if ($wave -ge $SmgUnlockWave) { $best = 's' }
    if ($wave -ge $AkUnlockWave) { $best = 'a' }
    $bank += $earn   # ikinci silahın parası birikir
    if ($type.Count -lt 2) {
        $price = $gunPrice[$best]
        if ($bank -ge $price) { $type += $best; $spent[1] = $price; $bank -= $price }
    }
    if ($type.Count -ge 2) {
        $offGold += $bank * $OffenseShare; $defGold += $bank * (1 - $OffenseShare); $bank = 0
    }
    for ($s = 0; $s -lt $type.Count; $s++) {
        if ($gunTier[$type[$s]] -ge $gunTier[$best]) { continue }
        $refund = if ($KeepUpgradesOnSwap) { [math]::Floor($gunPrice[$type[$s]] * 0.5) } else { [math]::Floor($spent[$s] * 0.5) }
        $c = $gunPrice[$best] - $refund
        if ($offGold -lt $c) { continue }
        $offGold -= $c; $type[$s] = $best
        if ($KeepUpgradesOnSwap) { $spent[$s] += $c } else { $spent[$s] = $gunPrice[$best]; $dmgLv[$s] = 0; $frLv[$s] = 0; $sil[$s] = 0 }
    }
    for ($s = 0; $s -lt $type.Count; $s++) {
        $canSilver = $KeepUpgradesOnSwap -or $type[$s] -eq 'a'
        if ($canSilver -and -not $sil[$s] -and $offGold -ge $SilverCost) { $sil[$s] = 1; $offGold -= $SilverCost; $spent[$s] += $SilverCost }
    }
    while ($true) {
        $best = $null; $bestCost = [double]::MaxValue
        for ($s = 0; $s -lt $type.Count; $s++) {
            $c = Cost 20 15 0.5 $dmgLv[$s]; if ($c -lt $bestCost) { $bestCost = $c; $best = @('d', $s) }
            $c = Cost 20 15 0.5 $frLv[$s];  if ($c -lt $bestCost) { $bestCost = $c; $best = @('f', $s) }
        }
        if ($offGold -lt $bestCost) { break }
        $offGold -= $bestCost; $spent[$best[1]] += $bestCost
        if ($best[0] -eq 'd') { $dmgLv[$best[1]]++ } else { $frLv[$best[1]]++ }
    }
    while ($true) {
        $opts = @(@('h', (Cost 15 10 1 $hpLv)), @('a', (Cost 20 15 1 $armorLv)), @('r', (Cost 20 15 1 $regenLv))) | Sort-Object { $_[1] }
        if ($defGold -lt $opts[0][1]) { break }
        $defGold -= $opts[0][1]
        switch ($opts[0][0]) { 'h' { $hpLv++ } 'a' { $armorLv++ } 'r' { $regenLv++ } }
    }
}

"Ayarlar: can/dalga $HealthPerWave ($HealthLateFrom. dalgadan sonra $HealthLate), boss can/dalga $(if ($useBossCurve) { $BossHealthPerWave } else { 'normal eğri' }), hasar/dalga $DamagePerWave, aralık $IntervalStart-$IntervalStep/dalga (en az $IntervalMin), boss aralık x$BossSpawnMult, sikke +1/$CoinStepWaves dalga, saldırı payı $OffenseShare, verim $Efficiency"
"{0,5} {1,7} {2,-9} {3,-7} {4,-7} {5,7} {6,8} {7,5} {8,6} {9,4} {10,4} {11,5} {12,8}" -f 'Wave','Gold','Guns','DmgLv','FrLv','DPS','HPin/s','Ratio','BossT','HP','Arm','Claw','ClawsToDie'
foreach ($r in $rows) { "{0,5} {1,7} {2,-9} {3,-7} {4,-7} {5,7} {6,8} {7,5} {8,6} {9,4} {10,4} {11,5} {12,8}" -f $r.Dalga,$r.ToplamAltin,$r.Silah,$r.DmgLv,$r.FrLv,$r.Hasar_sn,$r.GelenCan_sn,$r.Oran,$r.BossSure_sn,$r.Can,$r.Zirh,$r.Pence,$r.KacPence }
"Oran = oyuncunun etkili hasarı / saniyede gelen yaratık canı (1'in altı: kalabalık birikir). BossSure: boss'a kalan hasarla öldürme süresi ('yok' = kalabalığa bile yetmiyor). KacPence: Damned Soul pençesinden ölmeden kaç tane yenir."
