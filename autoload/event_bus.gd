extends Node

signal enemy_died(position: Vector2, coin_value: int)
signal coin_collected(value: int)
signal player_damaged(current_hp: int, max_hp: int)
signal player_died
signal wave_started(wave: int)
signal wave_ended(wave: int)
signal player_health_changed(current: int, maximum: int)
signal shop_requested(wave: int)
signal next_wave_requested
