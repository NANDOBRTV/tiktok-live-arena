extends Node

const EngineType = preload("res://scripts/game/combat_engine.gd")
const GiftsType = preload("res://scripts/integration/gift_manager.gd")
const LiveType = preload("res://scripts/integration/tiktok_live_connector.gd")

var failures: Array[String] = []
var checks := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog()
	_test_combat_loop()
	_test_gifts()
	_test_live_guard()
	_test_assets()
	if failures.is_empty():
		print("[game-generic-tests] PASS: %d checks" % checks)
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("[game-generic-tests] " + failure)
		print("[game-generic-tests] FAIL: %d failures across %d checks" % [failures.size(), checks])
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _test_catalog() -> void:
	var catalog := EngineType.catalog()
	_check(catalog.size() == 2, "somente Lula e Flávio Bolsonaro devem existir")
	for id: String in ["lula", "flavio-bolsonaro"]:
		_check(catalog.has(id), "lutador ausente: " + id)
		_check(str(catalog[id]["special"]).length() > 4, "especial ausente: " + id)


func _test_combat_loop() -> void:
	var combat := EngineType.new()
	combat.setup("lula", "flavio-bolsonaro", 30.0)
	_check(combat.state == "active", "partida deve iniciar ativa")
	_check(combat.fighters.size() == 2, "partida deve criar dois lutadores")
	var saw_action := false
	for index: int in 360:
		var events: Array[Dictionary] = combat.tick(0.5)
		if not events.is_empty():
			saw_action = true
		if combat.state == "finished":
			break
	_check(saw_action, "motor deve emitir eventos de combate")
	_check(combat.state == "finished", "combate deve chegar a um resultado")
	_check(combat.score[0] + combat.score[1] >= 1, "resultado deve pontuar uma rodada")
	combat.reset()
	_check(combat.state == "idle", "reinício deve voltar ao estado idle")


func _test_gifts() -> void:
	var combat := EngineType.new()
	combat.setup("lula", "flavio-bolsonaro", 40.0)
	var manager := GiftsType.new()
	var first := manager.process_event({"id": "t-flor", "gift_type": "flor-rosa", "quantity": 1, "target": 1, "user": "Teste"}, combat, true)
	_check(bool(first.get("ok", false)) and int(first.get("target", -1)) == 0, "flor rosa deve apoiar Lula")
	var duplicate := manager.process_event({"id": "t-flor", "gift_type": "flor-rosa", "quantity": 1, "target": 0}, combat, true)
	_check(not bool(duplicate.get("ok", false)) and duplicate.get("reason") == "duplicado", "duplicata deve ser rejeitada")
	var white_rose := manager.process_event({"id": "t-white", "gift_type": "rosa-branca", "quantity": 1, "target": 0, "user": "Teste"}, combat, true)
	_check(bool(white_rose.get("ok", false)) and int(white_rose.get("target", -1)) == 1, "rosa branca deve apoiar Flávio Bolsonaro")
	var crown := manager.process_event({"id": "t-coroa", "gift_type": "coroa", "quantity": 1, "target": 1, "user": "Teste"}, combat, true)
	_check(bool(crown.get("ok", false)), "coroa deve aplicar impacto")
	_check(float(combat.fighters[0]["energy"]) > 18.0, "flor rosa deve alterar energia de forma observável")
	_check(manager.get_configuration().has("foguete"), "configuração deve expor foguete")


func _test_live_guard() -> void:
	var adapter := LiveType.new()
	var result := adapter.connect_authorized()
	_check(not bool(result.get("ok", true)), "conexão não configurada não pode alegar sucesso")
	_check(str(result.get("state", "")) == "indisponivel", "estado da integração deve ser honesto")
	_check(not adapter.receive_authorized_event({"id": "real-1"}), "evento real deve ser bloqueado sem conexão autorizada")
	var command := adapter.handle_chat_command("Teste", "!força Lula", 0)
	_check(bool(command.get("ok", false)) and command["command"]["command"] == "forca", "connector deve reconhecer !força")


func _test_assets() -> void:
	for path: String in [
		"res://assets/livearena/environment/arena_futurista.png",
			"res://assets/livearena/characters/lula.png",
			"res://assets/livearena/characters/flavio_bolsonaro.png",
	]:
		_check(ResourceLoader.exists(path), "ativo original ausente: " + path)
	_check(ResourceLoader.exists("res://scenes/main.tscn"), "cena principal deve existir")
