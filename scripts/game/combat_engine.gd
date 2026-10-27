class_name ArenaCombatEngine
extends RefCounted

## Motor autoritativo local da demonstração. Um backend autorizado poderá reutilizar o mesmo contrato.

const MAX_ROUNDS := 3
const START_HP := 100.0
const START_ENERGY := 18.0

var fighters: Array[Dictionary] = []
var round_number := 1
var score := [0, 0]
var state := "idle"
var paused := false
var round_duration := 45.0
var elapsed := 0.0
var break_timer := 0.0
var decision_timer := 0.0
var rng := RandomNumberGenerator.new()
var winner_index := -1
var last_event := {}


func _init() -> void:
	rng.seed = 93217


func setup(left_id: String, right_id: String, duration: float = 45.0) -> void:
	round_duration = clampf(duration, 20.0, 120.0)
	round_number = 1
	score = [0, 0]
	winner_index = -1
	elapsed = 0.0
	break_timer = 0.0
	decision_timer = 0.5
	paused = false
	state = "active"
	fighters = [_make_fighter(left_id, 0), _make_fighter(right_id, 1)]
	last_event = {"kind": "round_start", "round": 1, "text": "RODADA 1 — LUTEM!"}


func _make_fighter(id: String, side: int) -> Dictionary:
	var data := _catalog().get(id, _catalog().get("capitao-brasa")) as Dictionary
	return {
		"id": id,
		"name": data.get("name", id),
		"special": data.get("special", "Habilidade especial"),
		"hp": START_HP,
		"max_hp": START_HP,
		"energy": START_ENERGY,
		"attack": float(data.get("attack", 20.0)),
		"defense": float(data.get("defense", 10.0)),
		"speed": float(data.get("speed", 10.0)),
		"special_power": float(data.get("special_power", 32.0)),
		"dodge": float(data.get("dodge", 0.12)),
		"side": side,
		"x": 0.22 if side == 0 else 0.78,
		"action": "idle",
		"action_time": 0.0,
		"attack_cooldown": 0.0,
		"special_cooldown": 0.0,
		"guard_timer": 0.0,
		"invulnerable": 0.0,
		"combo": 0,
	}


func tick(delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if state == "idle" or state == "finished" or paused:
		return events
	if state == "round_break":
		break_timer -= delta
		if break_timer <= 0.0:
			_start_next_round(events)
		return events

	elapsed += delta
	decision_timer -= delta
	for fighter: Dictionary in fighters:
		fighter["attack_cooldown"] = maxf(0.0, float(fighter["attack_cooldown"]) - delta)
		fighter["special_cooldown"] = maxf(0.0, float(fighter["special_cooldown"]) - delta)
		fighter["guard_timer"] = maxf(0.0, float(fighter["guard_timer"]) - delta)
		fighter["invulnerable"] = maxf(0.0, float(fighter["invulnerable"]) - delta)
		fighter["action_time"] = maxf(0.0, float(fighter["action_time"]) - delta)
		if fighter["action_time"] <= 0.0 and fighter["action"] not in ["idle", "defeat", "victory"]:
			fighter["action"] = "idle"

	if elapsed >= round_duration:
		_end_round(-1, "TEMPO ESGOTADO", events)
		return events
	if decision_timer <= 0.0:
		decision_timer = 0.48
		_decide_action(events)
	return events


func _decide_action(events: Array[Dictionary]) -> void:
	if fighters.size() != 2:
		return
	var left: Dictionary = fighters[0]
	var right: Dictionary = fighters[1]
	var distance := absf(float(right["x"]) - float(left["x"]))
	if distance > 0.30:
		var step := 0.018
		left["x"] = move_toward(float(left["x"]), 0.46, step * (0.8 + float(left["speed"]) / 30.0))
		right["x"] = move_toward(float(right["x"]), 0.54, step * (0.8 + float(right["speed"]) / 30.0))
		left["action"] = "approach"
		right["action"] = "approach"
		left["action_time"] = 0.48
		right["action_time"] = 0.48
		return
	var attacker_index := 0 if rng.randf() < 0.5 else 1
	var defender_index := 1 - attacker_index
	var attacker: Dictionary = fighters[attacker_index]
	var defender: Dictionary = fighters[defender_index]
	if float(attacker["attack_cooldown"]) > 0.0:
		attacker_index = defender_index
		defender_index = 1 - attacker_index
		attacker = fighters[attacker_index]
		defender = fighters[defender_index]
	if float(attacker["attack_cooldown"]) > 0.0:
		_set_defense(attacker)
		return
	if float(defender["hp"]) < 30.0 and rng.randf() < 0.32:
		_set_defense(defender)
		return
	_resolve_attack(attacker_index, defender_index, events)


func _set_defense(fighter: Dictionary) -> void:
	fighter["action"] = "defend"
	fighter["guard_timer"] = 0.72
	fighter["action_time"] = 0.72


func _resolve_attack(attacker_index: int, defender_index: int, events: Array[Dictionary]) -> void:
	var attacker: Dictionary = fighters[attacker_index]
	var defender: Dictionary = fighters[defender_index]
	var special := float(attacker["energy"]) >= 100.0 and float(attacker["special_cooldown"]) <= 0.0
	var critical := rng.randf() < (0.12 + float(attacker["speed"]) / 500.0)
	var damage := 0.0
	if special:
		damage = float(attacker["special_power"])
		attacker["energy"] = 0.0
		attacker["special_cooldown"] = 4.0
		attacker["action"] = "special"
		attacker["action_time"] = 1.1
	else:
		damage = maxf(5.0, float(attacker["attack"]) - float(defender["defense"]) * 0.32)
		if critical:
			damage *= 1.55
		attacker["energy"] = minf(100.0, float(attacker["energy"]) + 11.0)
		attacker["action"] = "attack"
		attacker["action_time"] = 0.64
	attacker["attack_cooldown"] = maxf(0.35, 1.2 - float(attacker["speed"]) / 40.0)
	if float(defender["invulnerable"]) > 0.0:
		damage = 0.0
		defender["action"] = "dodge"
		defender["action_time"] = 0.5
	elif float(defender["guard_timer"]) > 0.0:
		damage *= 0.38
		defender["action"] = "defend"
		defender["action_time"] = 0.52
	elif rng.randf() < float(defender["dodge"]):
		damage = 0.0
		defender["action"] = "dodge"
		defender["invulnerable"] = 0.42
		defender["action_time"] = 0.52
	else:
		defender["action"] = "damage"
		defender["action_time"] = 0.58
	defender["hp"] = maxf(0.0, float(defender["hp"]) - damage)
	attacker["combo"] = int(attacker["combo"]) + 1
	defender["combo"] = 0
	var kind := "special" if special else ("critical" if critical else "attack")
	var text := "%s" % attacker["name"]
	if special:
		text += " • %s" % attacker["special"]
	elif critical:
		text += " • GOLPE CRÍTICO"
	else:
		text += " acerta"
	var event := {
		"kind": kind,
		"attacker": attacker_index,
		"defender": defender_index,
		"damage": damage,
		"critical": critical,
		"special": special,
		"text": text,
	}
	events.append(event)
	last_event = event
	if float(defender["hp"]) <= 0.0:
		_end_round(attacker_index, "%s vence a rodada" % attacker["name"], events)


func _end_round(round_winner: int, reason: String, events: Array[Dictionary]) -> void:
	if state != "active":
		return
	if round_winner >= 0:
		score[round_winner] = int(score[round_winner]) + 1
	for fighter: Dictionary in fighters:
		fighter["action"] = "victory" if fighter["side"] == round_winner else "defeat"
		fighter["action_time"] = 999.0
	var round_event := {"kind": "round_end", "winner": round_winner, "reason": reason, "score": score.duplicate(), "text": reason}
	events.append(round_event)
	last_event = round_event
	if int(score[0]) >= 2 or int(score[1]) >= 2 or round_number >= MAX_ROUNDS:
		winner_index = 0 if int(score[0]) > int(score[1]) else (1 if int(score[1]) > int(score[0]) else -1)
		state = "finished"
		var finish := {"kind": "match_end", "winner": winner_index, "score": score.duplicate(), "text": "EMPATE" if winner_index < 0 else "%s É O CAMPEÃO" % fighters[winner_index]["name"]}
		events.append(finish)
		last_event = finish
	else:
		state = "round_break"
		break_timer = 1.35


func _start_next_round(events: Array[Dictionary]) -> void:
	round_number += 1
	elapsed = 0.0
	decision_timer = 0.4
	state = "active"
	for fighter: Dictionary in fighters:
		fighter["hp"] = START_HP
		fighter["energy"] = START_ENERGY
		fighter["attack_cooldown"] = 0.0
		fighter["special_cooldown"] = 0.0
		fighter["guard_timer"] = 0.0
		fighter["invulnerable"] = 0.0
		fighter["combo"] = 0
		fighter["action"] = "idle"
		fighter["action_time"] = 0.0
		fighter["x"] = 0.22 if fighter["side"] == 0 else 0.78
	var event := {"kind": "round_start", "round": round_number, "text": "RODADA %d — NOVO ASSALTO" % round_number}
	events.append(event)
	last_event = event


func apply_gift(gift_type: String, target_index: int, quantity: int, multiplier: float = 1.0) -> Dictionary:
	if state == "idle" or state == "finished" or target_index < 0 or target_index >= fighters.size():
		return {"ok": false, "text": "A partida não está ativa."}
	var target: Dictionary = fighters[target_index]
	var amount := float(quantity) * multiplier
	var text := ""
	match gift_type:
		"rosa":
			target["energy"] = minf(100.0, float(target["energy"]) + 8.0 * amount)
			text = "+%d energia para %s" % [int(8.0 * amount), target["name"]]
		"coracao":
			target["hp"] = minf(START_HP, float(target["hp"]) + 10.0 * amount)
			target["energy"] = minf(100.0, float(target["energy"]) + 5.0 * amount)
			text = "+%d vida e torcida para %s" % [int(10.0 * amount), target["name"]]
		"foguete":
			var enemy: Dictionary = fighters[1 - target_index]
			enemy["hp"] = maxf(0.0, float(enemy["hp"]) - 22.0 * amount)
			target["energy"] = minf(100.0, float(target["energy"]) + 25.0 * amount)
			target["action"] = "special"
			target["action_time"] = 0.9
			text = "Foguete: %s desfere golpe de torcida" % target["name"]
		"coroa":
			var rival: Dictionary = fighters[1 - target_index]
			rival["hp"] = maxf(0.0, float(rival["hp"]) - 36.0 * amount)
			target["energy"] = minf(100.0, float(target["energy"]) + 42.0 * amount)
			target["action"] = "special"
			target["action_time"] = 1.2
			text = "Coroa: impacto máximo para %s" % target["name"]
		_:
			return {"ok": false, "text": "Presente não configurado."}
	return {"ok": true, "text": text, "target": target_index, "gift_type": gift_type, "quantity": quantity}


func pause() -> void:
	paused = true


func resume() -> void:
	if state == "active":
		paused = false


func reset() -> void:
	fighters.clear()
	state = "idle"
	paused = false
	score = [0, 0]
	round_number = 1
	winner_index = -1


func get_state() -> Dictionary:
	return {
		"state": state,
		"paused": paused,
		"round": round_number,
		"score": score.duplicate(),
		"elapsed": elapsed,
		"duration": round_duration,
		"winner": winner_index,
		"fighters": fighters.duplicate(true),
	}


static func catalog() -> Dictionary:
	return _catalog()


static func _catalog() -> Dictionary:
	return {
		"capitao-brasa": {"name": "Capitão Brasa", "special": "Explosão de Fogo", "attack": 25.0, "defense": 11.0, "speed": 14.0, "special_power": 38.0, "dodge": 0.10},
		"raio-azul": {"name": "Raio Azul", "special": "Tempestade Elétrica", "attack": 21.0, "defense": 9.0, "speed": 22.0, "special_power": 34.0, "dodge": 0.19},
		"sombra-negra": {"name": "Sombra Negra", "special": "Corte das Sombras", "attack": 23.0, "defense": 10.0, "speed": 20.0, "special_power": 36.0, "dodge": 0.24},
		"guardiao-dourado": {"name": "Guardião Dourado", "special": "Impacto Titânico", "attack": 30.0, "defense": 18.0, "speed": 9.0, "special_power": 43.0, "dodge": 0.07},
	}
