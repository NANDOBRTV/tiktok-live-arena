extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_verify")


func _verify() -> void:
	_check(ProjectSettings.get_setting("application/config/name") == "TikTok LIVE Arena", "identidade exportada")
	for path: String in [
		"assets/livearena/environment/arena_futurista.png",
		"assets/livearena/characters/capitao_brasa.png",
		"assets/livearena/characters/raio_azul.png",
		"assets/livearena/characters/sombra_negra.png",
		"assets/livearena/characters/guardiao_dourado.png",
	]:
		_check(ResourceLoader.exists("res://" + path), "recurso exportado: " + path)
	_check(not ResourceLoader.exists("res://test/test_suite.tscn"), "cena de teste excluída")
	_check(not ResourceLoader.exists("res://tools/capture_native.gd"), "ferramenta nativa excluída")
	_check(not ResourceLoader.exists("res://scripts/ui/tuning_panel.gd"), "painel de tuning não deve ir para release")
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "cena principal exportada")
	if packed != null:
		var main := packed.instantiate()
		root.add_child(main)
		await process_frame
		await process_frame
		_check(bool(main.get("title_root").visible), "o pacote inicia na tela principal")
		main.call("_start_demo_battle")
		await process_frame
		_check(bool(main.get("battle_active")), "o pacote inicia uma batalha")
		main.queue_free()
		await process_frame
	if failures.is_empty():
		print("[exported-pack] PASS: identidade, recursos, boot, arena e gameplay")
		quit(0)
	else:
		for failure: String in failures:
			push_error("[exported-pack] " + failure)
		quit(1)


func _check(condition: bool, context: String) -> void:
	if not condition and context not in failures:
		failures.append(context)
