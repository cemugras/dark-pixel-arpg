class_name UpgradeData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var base_cost: int = 10
@export var cost_step: int = 10      # her alımda eklenen fiyat
@export var stat: String = ""        # PlayerStats'taki değişken adı
@export var amount: float = 1.0
@export var sort_order: int = 0      # mağazadaki sıra
@export var requires: String = ""    # "gun": menzilli silah yoksa mağazada kilitli görünür
# Mağazada nerede görünür: "" = genel geliştirmeler ızgarası (oyuncuya),
# "gun" = her silah yuvasının altında ayrı ayrı (seviye ve harcama o yuvaya ait, GameState.gun_upgrades);
# başka değer (ör. "grenade") = sadece WeaponData.upgrade_scope'u aynı olan silahın yuvasında
@export var scope: String = ""
@export var price_ratio: float = 1.0 # fiyat çarpanı (silah başına geliştirmeler yarı fiyat: 0.5)
