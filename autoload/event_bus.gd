extends Node

signal enemy_died(position: Vector2, coin_value: int)
signal coins_spilled(position: Vector2, coin_value: int)  # yaratık ölmeden sikke saçar (Mammon vuruldukça); sikkeler etrafa savrulur
signal coin_collected(value: int)
signal player_damaged(current_hp: int, max_hp: int)
signal player_died
signal wave_started(wave: int)
signal wave_ended(wave: int)
signal player_health_changed(current: int, maximum: int)
signal shop_requested(wave: int)
signal next_wave_requested
signal shop_closed  # mağazada Next Wave basıldı; tüccar varsa havalanır, gidince next_wave_requested yayınlar
signal boss_spawned(boss: Node)
signal boss_defeated(boss_id: String)  # boss ölünce (EnemyData.id); ileride Steam başarımları bunu dinleyecek
