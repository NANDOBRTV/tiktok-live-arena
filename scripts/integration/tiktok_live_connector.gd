class_name TikTokLiveConnector
extends RefCounted

## Ponte segura para uma futura integração oficial/autorizada.
## O jogo não inventa endpoints nem aceita eventos reais enquanto state != "conectado".

signal state_changed(state: String, detail: String)
signal authorized_event_received(event: Dictionary)
signal command_received(command: Dictionary)

const GIFT_RULES := {
	"flor-rosa": {"label": "Flor Rosa", "target": 0, "effect": "energia_lula"},
	"rosa-branca": {"label": "Rosa Branca", "target": 1, "effect": "energia_flavio"},
	"tiktok": {"label": "TikTok", "target": -1, "effect": "animo"},
	"leao": {"label": "Leão", "target": -1, "effect": "aliado"},
	"carro": {"label": "Carro", "target": -1, "effect": "velocidade"},
	"foguete": {"label": "Foguete", "target": -1, "effect": "ataque"},
	"arco-iris": {"label": "Arco-íris", "target": -1, "effect": "protecao"},
	"coroa": {"label": "Coroa", "target": -1, "effect": "virada"},
	"vaca": {"label": "Vaca", "target": -1, "effect": "zoeira"},
}

const COMMAND_RULES := {
	"!ataque": "ataque",
	"!defesa": "defesa",
	"!forca": "forca",
	"!força": "forca",
	"!zoeira": "zoeira",
}

var state := "desconectado"
var detail := "Nenhuma ponte oficial/autorizada configurada."
var processed_ids: Dictionary = {}
var ranking: Dictionary = {}
var reconnect_attempts := 0


func connect_authorized() -> Dictionary:
	state = "indisponivel"
	detail = "TikTok LIVE Connector aguardando backend oficial/autorizado; modo demonstração permanece ativo."
	state_changed.emit(state, detail)
	return {"ok": false, "state": state, "detail": detail}


func disconnect_live() -> void:
	state = "desconectado"
	detail = "Conexão encerrada; eventos reais bloqueados."
	state_changed.emit(state, detail)


func mark_authorized_connection(detail_text: String) -> void:
	## Somente uma ponte de servidor validada deve chamar este método.
	state = "conectado"
	detail = detail_text
	reconnect_attempts = 0
	state_changed.emit(state, detail)


func mark_disconnect(detail_text: String) -> void:
	state = "reconectando"
	detail = detail_text
	reconnect_attempts += 1
	state_changed.emit(state, detail)


func receive_authorized_event(event: Dictionary) -> bool:
	if state != "conectado":
		return false
	var event_id := str(event.get("id", ""))
	if event_id.is_empty() or processed_ids.has(event_id):
		return false
	var normalized := normalize_event(event)
	if normalized.is_empty():
		return false
	processed_ids[event_id] = Time.get_ticks_msec()
	var user := str(normalized.get("user", "Torcida"))
	ranking[user] = int(ranking.get(user, 0)) + int(normalized.get("quantity", 1))
	authorized_event_received.emit(normalized)
	return true


func normalize_event(event: Dictionary) -> Dictionary:
	var gift_type := str(event.get("gift_type", "")).to_lower().strip_edges()
	if not GIFT_RULES.has(gift_type):
		return {}
	var rule: Dictionary = GIFT_RULES[gift_type]
	var target := int(rule.get("target", -1))
	if target < 0:
		target = clampi(int(event.get("target", 0)), 0, 1)
	return {
		"id": str(event.get("id", "")),
		"gift_type": gift_type,
		"quantity": clampi(int(event.get("quantity", 1)), 1, 20),
		"target": target,
		"user": str(event.get("user", "Torcida")),
		"label": str(rule["label"]),
		"effect": str(rule["effect"]),
	}


func handle_chat_command(user: String, message: String, target: int = 0) -> Dictionary:
	var command_text := message.to_lower().strip_edges().split(" ")[0]
	if not COMMAND_RULES.has(command_text):
		return {"ok": false, "reason": "comando_desconhecido", "text": "Comando não reconhecido."}
	var command := {
		"id": "command-%d" % Time.get_ticks_msec(),
		"command": str(COMMAND_RULES[command_text]),
		"raw": command_text,
		"target": clampi(target, 0, 1),
		"user": user if not user.is_empty() else "Torcida",
	}
	command_received.emit(command)
	return {"ok": true, "command": command}


func get_gift_rules() -> Dictionary:
	return GIFT_RULES.duplicate(true)


func get_command_rules() -> Dictionary:
	return COMMAND_RULES.duplicate(true)


func get_ranking() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for user: String in ranking.keys():
		rows.append({"user": user, "points": int(ranking[user])})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["points"]) > int(b["points"]))
	return rows


func get_status() -> Dictionary:
	return {"state": state, "detail": detail, "reconnect_attempts": reconnect_attempts, "processed_events": processed_ids.size()}
