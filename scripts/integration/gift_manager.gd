class_name ArenaGiftManager
extends RefCounted

## Camada única para eventos simulados e eventos autorizados futuros.

const CONFIG := {
	"rosa": {"label": "Rosa", "cooldown": 0.25, "description": "Energia leve"},
	"coracao": {"label": "Coração", "cooldown": 0.4, "description": "Vida + energia"},
	"foguete": {"label": "Foguete", "cooldown": 1.5, "description": "Golpe poderoso"},
	"coroa": {"label": "Coroa", "cooldown": 2.5, "description": "Impacto máximo"},
}

var processed_ids: Dictionary = {}
var recent_by_gift: Dictionary = {}
var last_time := 0.0
var max_events_per_second := 8


func process_event(event: Dictionary, engine: Object, simulated: bool = false) -> Dictionary:
	var now := Time.get_ticks_msec() / 1000.0
	if not _valid_payload(event):
		return {"ok": false, "reason": "payload_invalido", "text": "Evento rejeitado: dados inválidos."}
	var event_id := str(event.get("id", ""))
	if processed_ids.has(event_id):
		return {"ok": false, "reason": "duplicado", "text": "Evento duplicado ignorado."}
	if now - last_time < 0.12 and processed_ids.size() > max_events_per_second:
		return {"ok": false, "reason": "limite", "text": "Limite temporário de eventos atingido."}
	var gift_type := str(event.get("gift_type", ""))
	var target := clampi(int(event.get("target", 0)), 0, 1)
	var quantity := clampi(int(event.get("quantity", 1)), 1, 20)
	var prior := recent_by_gift.get(gift_type, {"at": 0.0, "count": 0}) as Dictionary
	var multiplier := 1.0
	if now - float(prior.get("at", 0.0)) <= 4.0:
		multiplier = minf(2.5, 1.0 + float(prior.get("count", 0)) * 0.25)
	var applied: Dictionary = engine.apply_gift(gift_type, target, quantity, multiplier)
	if not bool(applied.get("ok", false)):
		return {"ok": false, "reason": "partida_inativa", "text": str(applied.get("text", "Evento não aplicado."))}
	processed_ids[event_id] = now
	recent_by_gift[gift_type] = {"at": now, "count": int(prior.get("count", 0)) + 1}
	last_time = now
	return {
		"ok": true,
		"id": event_id,
		"gift_type": gift_type,
		"label": str(CONFIG[gift_type]["label"]),
		"quantity": quantity,
		"target": target,
		"multiplier": multiplier,
		"user": str(event.get("user", "Torcida anônima")),
		"simulated": simulated,
		"text": str(applied.get("text", "Evento aplicado.")),
	}


func _valid_payload(event: Dictionary) -> bool:
	if str(event.get("id", "")).strip_edges().is_empty():
		return false
	if not CONFIG.has(str(event.get("gift_type", ""))):
		return false
	if int(event.get("quantity", 1)) < 1:
		return false
	return int(event.get("target", 0)) in [0, 1]


func reset() -> void:
	processed_ids.clear()
	recent_by_gift.clear()
	last_time = 0.0


func get_configuration() -> Dictionary:
	return CONFIG.duplicate(true)
