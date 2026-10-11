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
