class_name TikTokLiveAdapter
extends RefCounted

signal state_changed(state: String, detail: String)
signal authorized_event_received(event: Dictionary)

## Não inventa endpoints privados. A integração real só é habilitada quando um backend autorizado
## fornecer uma ponte testada e assinar os eventos antes de chamar receive_authorized_event().

var state := "desconectado"
var detail := "Nenhuma integração autorizada configurada."
var processed_ids: Dictionary = {}
var reconnect_attempts := 0


func connect_authorized() -> Dictionary:
	state = "indisponivel"
	detail = "TikTok LIVE não configurado: forneça uma ponte oficial/autorizada no servidor."
	state_changed.emit(state, detail)
	return {"ok": false, "state": state, "detail": detail}


func disconnect_live() -> void:
	state = "desconectado"
	detail = "Conexão encerrada; nenhum evento real será aceito."
	state_changed.emit(state, detail)


func receive_authorized_event(event: Dictionary) -> bool:
	if state != "conectado":
		return false
	var event_id := str(event.get("id", ""))
	if event_id.is_empty() or processed_ids.has(event_id):
		return false
	processed_ids[event_id] = Time.get_ticks_msec()
	authorized_event_received.emit(event)
	return true


func mark_authorized_connection(detail_text: String) -> void:
	## Chamado apenas por uma ponte de backend validada; não é usado pelo modo demonstração.
	state = "conectado"
	detail = detail_text
	reconnect_attempts = 0
	state_changed.emit(state, detail)


func mark_disconnect(detail_text: String) -> void:
	state = "reconectando"
	detail = detail_text
	reconnect_attempts += 1
	state_changed.emit(state, detail)


func get_status() -> Dictionary:
	return {"state": state, "detail": detail, "reconnect_attempts": reconnect_attempts}
