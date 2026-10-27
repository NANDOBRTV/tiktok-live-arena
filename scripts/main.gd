extends Control

const CombatEngineType = preload("res://scripts/game/combat_engine.gd")
const GiftManagerType = preload("res://scripts/integration/gift_manager.gd")
const TikTokAdapterType = preload("res://scripts/integration/tiktok_live_adapter.gd")
const FxType = preload("res://scripts/effects/arena_fx.gd")

const ARENA_ART = preload("res://assets/livearena/environment/arena_futurista.png")
const CAPITAO_ART = preload("res://assets/livearena/characters/capitao_brasa.png")
const RAIO_ART = preload("res://assets/livearena/characters/raio_azul.png")
const SOMBRA_ART = preload("res://assets/livearena/characters/sombra_negra.png")
const GUARDIAO_ART = preload("res://assets/livearena/characters/guardiao_dourado.png")

const BG := Color("070b18")
const PANEL := Color("111a2d")
const PANEL_2 := Color("17233b")
const TEXT := Color("f4f7ff")
const MUTED := Color("a5b3ce")
const CYAN := Color("55dcff")
const MAGENTA := Color("ee67ce")
const GOLD := Color("ffc857")
const FIRE := Color("ff653d")
const VIOLET := Color("ae7bff")

var engine: ArenaCombatEngine
var gifts: ArenaGiftManager
var tiktok: TikTokLiveAdapter
var match_duration := 45.0
var auto_restart := false
var demo_mode := true
var transmission_mode := false
var battle_active := false
var admin_visible := false
var history: Array[Dictionary] = []
var event_lines: Array[String] = []
var status_text := "MODO DEMONSTRAÇÃO • eventos simulados"

var background: TextureRect
var tint: ColorRect
var title_root: Control
var battle_root: Control
var admin_panel: PanelContainer
var result_panel: PanelContainer
var result_title: Label
var result_detail: Label
var live_status_label: Label
var battle_mode_label: Label
var round_label: Label
var timer_label: Label
var score_label: Label
var left_name: Label
var right_name: Label
var left_stats: Label
var right_stats: Label
var left_hp: ProgressBar
var right_hp: ProgressBar
var left_energy: ProgressBar
var right_energy: ProgressBar
var event_feed: RichTextLabel
var connection_label: Label
var special_label: Label
var transmission_label: Label
var fighter_nodes: Array[TextureRect] = []
var fighter_ids: Array[String] = ["capitao-brasa", "raio-azul"]
var left_select: OptionButton
var right_select: OptionButton
var target_select: OptionButton
var duration_slider: HSlider
var duration_value: Label
var auto_restart_check: CheckButton
var fx: ArenaFxOverlay
var gift_controls: Control
var battle_controls: Control
var title_status: Label
var paused_label: Label
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = 7281
	engine = CombatEngineType.new()
	gifts = GiftManagerType.new()
	tiktok = TikTokAdapterType.new()
	tiktok.state_changed.connect(_on_live_state)
	tiktok.authorized_event_received.connect(_on_authorized_event)
	_load_config()
	_load_history()
	_build_background()
	_build_title()
	_build_battle()
	_build_admin()
	_apply_layout()
	resized.connect(_apply_layout)
	_show_title()


func _process(delta: float) -> void:
	if battle_active and not transmission_mode:
		var events := engine.tick(delta)
		for event: Dictionary in events:
			_handle_engine_event(event)
		_sync_battle()
	elif battle_active and transmission_mode:
		var transmission_events := engine.tick(delta)
		for event: Dictionary in transmission_events:
			_handle_engine_event(event)
		_sync_battle()
	if paused_label != null:
		paused_label.visible = battle_active and engine.paused


func _build_background() -> void:
	background = TextureRect.new()
	background.texture = ARENA_ART
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	move_child(background, 0)
	tint = ColorRect.new()
	tint.color = Color(0.02, 0.04, 0.10, 0.54)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tint)


func _build_title() -> void:
	title_root = Control.new()
	title_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(title_root)
	var content := VBoxContainer.new()
	content.name = "TitleContent"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	content.set_anchors_preset(Control.PRESET_CENTER)
	content.position = Vector2(-300.0, -285.0)
	content.size = Vector2(600.0, 570.0)
	title_root.add_child(content)
	var eyebrow := _label("ARENA DE BATALHA • LIVE INTERACTIVE", 14, CYAN)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(eyebrow)
	var title := _label("TIKTOK LIVE\nARENA", 52, TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("101a36"))
	title.add_theme_constant_override("outline_size", 7)
	content.add_child(title)
	var subtitle := _label("A torcida decide o próximo golpe.", 18, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)
	content.add_child(_rule(MAGENTA))
	var select_title := _label("ESCOLHA OS LUTADORES", 13, GOLD)
	select_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(select_title)
	var selects := HBoxContainer.new()
	selects.alignment = BoxContainer.ALIGNMENT_CENTER
	selects.add_theme_constant_override("separation", 12)
	content.add_child(selects)
	left_select = _fighter_option("ESQUERDA", 0)
	right_select = _fighter_option("DIREITA", 1)
	selects.add_child(left_select)
	selects.add_child(right_select)
	var primary := _button("INICIAR JOGO", CYAN)
	primary.pressed.connect(_start_demo_battle)
	content.add_child(primary)
	var row_one := HBoxContainer.new()
	row_one.alignment = BoxContainer.ALIGNMENT_CENTER
	row_one.add_theme_constant_override("separation", 8)
	content.add_child(row_one)
	var choose := _button("ESCOLHER PERSONAGENS", Color("2c436d"), 210.0)
	choose.pressed.connect(_focus_selection)
	row_one.add_child(choose)
	var arena := _button("CONFIGURAR ARENA", Color("2c436d"), 210.0)
	arena.pressed.connect(func() -> void: _toggle_admin(true))
	row_one.add_child(arena)
	var row_two := HBoxContainer.new()
	row_two.alignment = BoxContainer.ALIGNMENT_CENTER
	row_two.add_theme_constant_override("separation", 8)
	content.add_child(row_two)
	var connect := _button("CONECTAR TIKTOK LIVE", Color("613864"), 210.0)
	connect.pressed.connect(_connect_live)
	row_two.add_child(connect)
	var transmit := _button("ABRIR MODO TRANSMISSÃO", Color("613864"), 210.0)
	transmit.pressed.connect(_open_transmission)
	row_two.add_child(transmit)
	var demo := _button("MODO DEMONSTRAÇÃO", Color("244d49"), 210.0)
	demo.pressed.connect(_start_demo_battle)
	row_two.add_child(demo)
	live_status_label = _label("TikTok LIVE: não configurado • eventos reais bloqueados", 13, MUTED)
	live_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(live_status_label)
	title_status = _label(status_text, 14, CYAN)
	title_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title_status)
	var footer := _label("MODO LOCAL SEGURO  •  integração real exige backend autorizado  •  OBS pronto via modo transmissão", 11, Color("8190ae"))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(footer)


func _fighter_option(caption: String, selected: int) -> OptionButton:
	var option := OptionButton.new()
	option.tooltip_text = caption
	option.custom_minimum_size = Vector2(220.0, 42.0)
	option.add_theme_font_size_override("font_size", 14)
	option.add_theme_color_override("font_color", TEXT)
	option.add_theme_stylebox_override("normal", _style(PANEL_2, Color(0.4, 0.7, 1.0, 0.38), 10))
	var index := 0
	for id: String in CombatEngineType.catalog().keys():
		var fighter: Dictionary = CombatEngineType.catalog()[id]
		option.add_item(str(fighter["name"]))
		option.set_item_metadata(index, id)
		if index == selected:
			option.select(index)
		index += 1
	return option


func _build_battle() -> void:
	battle_root = Control.new()
	battle_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle_root.visible = false
	add_child(battle_root)
	battle_mode_label = _label("MODO DEMONSTRAÇÃO", 12, CYAN)
	_anchored(battle_mode_label, 0.03, 0.02, 0.34, 0.07)
	battle_root.add_child(battle_mode_label)
	transmission_label = _label("", 12, GOLD)
	transmission_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_anchored(transmission_label, 0.58, 0.02, 0.97, 0.07)
	battle_root.add_child(transmission_label)
	round_label = _label("RODADA 1", 18, TEXT)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchored(round_label, 0.39, 0.025, 0.61, 0.07)
	battle_root.add_child(round_label)
	timer_label = _label("00:45", 34, GOLD)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchored(timer_label, 0.40, 0.065, 0.60, 0.13)
	battle_root.add_child(timer_label)
	score_label = _label("0  —  0", 16, MUTED)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchored(score_label, 0.40, 0.13, 0.60, 0.17)
	battle_root.add_child(score_label)
	left_name = _label("Capitão Brasa", 22, FIRE)
	_anchored(left_name, 0.04, 0.115, 0.34, 0.16)
	battle_root.add_child(left_name)
	right_name = _label("Raio Azul", 22, CYAN)
	right_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_anchored(right_name, 0.66, 0.115, 0.96, 0.16)
	battle_root.add_child(right_name)
	left_stats = _label("", 11, MUTED)
	_anchored(left_stats, 0.04, 0.16, 0.34, 0.185)
	battle_root.add_child(left_stats)
	right_stats = _label("", 11, MUTED)
	right_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_anchored(right_stats, 0.66, 0.16, 0.96, 0.185)
	battle_root.add_child(right_stats)
	left_hp = _bar(FIRE)
	_anchored(left_hp, 0.04, 0.19, 0.34, 0.22)
	battle_root.add_child(left_hp)
	right_hp = _bar(CYAN)
	_anchored(right_hp, 0.66, 0.19, 0.96, 0.22)
	battle_root.add_child(right_hp)
	left_energy = _bar(GOLD)
	_anchored(left_energy, 0.04, 0.225, 0.34, 0.242)
	battle_root.add_child(left_energy)
	right_energy = _bar(VIOLET)
	_anchored(right_energy, 0.66, 0.225, 0.96, 0.242)
	battle_root.add_child(right_energy)
	for entry: Dictionary in [
		{"texture": CAPITAO_ART, "side": 0},
		{"texture": RAIO_ART, "side": 1},
	]:
		var fighter := TextureRect.new()
		fighter.texture = entry["texture"]
		fighter.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fighter.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fighter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fighter.pivot_offset = Vector2(180.0, 210.0)
		fighter.z_index = 4
		battle_root.add_child(fighter)
		fighter_nodes.append(fighter)
	fx = FxType.new()
	fx.z_index = 20
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battle_root.add_child(fx)
	special_label = _label("", 18, TEXT)
	special_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	special_label.add_theme_color_override("font_outline_color", Color("080d1c"))
	special_label.add_theme_constant_override("outline_size", 5)
	_anchored(special_label, 0.22, 0.27, 0.78, 0.34)
	battle_root.add_child(special_label)
	paused_label = _label("PAUSADO", 28, GOLD)
	paused_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	paused_label.visible = false
	_anchored(paused_label, 0.35, 0.43, 0.65, 0.50)
	battle_root.add_child(paused_label)
	_build_event_feed()
	_build_battle_controls()
	_build_result_panel()


func _build_event_feed() -> void:
	var panel := _panel(PANEL, Color(0.35, 0.55, 0.9, 0.35))
	panel.name = "EventHistory"
	panel.z_index = 8
	_anchored(panel, 0.03, 0.68, 0.36, 0.95)
	battle_root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var heading := _label("HISTÓRICO DA TORCIDA", 12, GOLD)
	column.add_child(heading)
	event_feed = RichTextLabel.new()
	event_feed.bbcode_enabled = true
	event_feed.fit_content = false
	event_feed.scroll_active = false
	event_feed.custom_minimum_size = Vector2(0.0, 130.0)
	event_feed.add_theme_font_size_override("normal_font_size", 12)
	event_feed.add_theme_color_override("default_color", MUTED)
	column.add_child(event_feed)


func _build_battle_controls() -> void:
	battle_controls = Control.new()
	battle_controls.z_index = 8
	_anchored(battle_controls, 0.40, 0.68, 0.97, 0.95)
	battle_root.add_child(battle_controls)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	top.add_theme_constant_override("separation", 6)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	battle_controls.add_child(top)
	var target_label := _label("TORCIDA:", 12, MUTED)
	top.add_child(target_label)
	target_select = OptionButton.new()
	target_select.custom_minimum_size = Vector2(150.0, 34.0)
	target_select.add_item("LUTADOR ESQUERDO")
	target_select.add_item("LUTADOR DIREITO")
	top.add_child(target_select)
	var pause := _button("PAUSAR", Color("3e5278"), 92.0)
	pause.pressed.connect(_toggle_pause)
	top.add_child(pause)
	var restart := _button("REINICIAR", Color("5a3a58"), 108.0)
	restart.pressed.connect(_restart_battle)
	top.add_child(restart)
	var exit := _button("SAIR", Color("26324d"), 74.0)
	exit.pressed.connect(_return_to_title)
	top.add_child(exit)
	gift_controls = HBoxContainer.new()
	gift_controls.alignment = BoxContainer.ALIGNMENT_END
	gift_controls.add_theme_constant_override("separation", 6)
	gift_controls.position = Vector2(0.0, 48.0)
	gift_controls.set_anchors_preset(Control.PRESET_TOP_WIDE)
	battle_controls.add_child(gift_controls)
	for config: Array in [["ROSA", "rosa", Color("e86aaf")], ["CORAÇÃO", "coracao", Color("ed6684")], ["FOGUETE", "foguete", Color("ff814c")], ["COROA", "coroa", GOLD]]:
		var gift_button := _button(config[0], config[2], 90.0)
		gift_button.pressed.connect(_send_demo_gift.bind(config[1]))
		gift_controls.add_child(gift_button)
	var hint := _label("Presentes acima são simulados e aparecem no histórico com identificação DEMO.", 10, Color("8291ae"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.position = Vector2(0.0, 86.0)
	hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	battle_controls.add_child(hint)


func _build_result_panel() -> void:
	result_panel = _panel(Color(0.04, 0.07, 0.15, 0.97), Color(1.0, 0.78, 0.35, 0.65))
	result_panel.visible = false
	result_panel.z_index = 40
	_anchored(result_panel, 0.28, 0.30, 0.72, 0.72)
	battle_root.add_child(result_panel)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	result_panel.add_child(content)
	result_title = _label("VITÓRIA", 34, GOLD)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(result_title)
	result_detail = _label("", 15, TEXT)
	result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(result_detail)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	var again := _button("NOVA PARTIDA", CYAN, 150.0)
	again.pressed.connect(_restart_battle)
	row.add_child(again)
	var back := _button("VOLTAR", Color("3e5278"), 120.0)
	back.pressed.connect(_return_to_title)
	row.add_child(back)


func _build_admin() -> void:
	admin_panel = _panel(Color(0.03, 0.06, 0.13, 0.98), Color(0.35, 0.83, 1.0, 0.8))
	admin_panel.visible = false
	admin_panel.z_index = 50
	_anchored(admin_panel, 0.24, 0.13, 0.76, 0.87)
	add_child(admin_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	admin_panel.add_child(content)
	var title := _label("CONFIGURAÇÃO DA ARENA", 26, CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var warning := _label("PAINEL LOCAL DE DEMONSTRAÇÃO • autenticação server-side deve ser adicionada antes de operar em produção", 11, GOLD)
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(warning)
	content.add_child(_rule(CYAN))
	var duration_row := HBoxContainer.new()
	content.add_child(duration_row)
	duration_row.add_child(_label("Duração da rodada", 14, TEXT))
	duration_slider = HSlider.new()
	duration_slider.min_value = 20.0
	duration_slider.max_value = 120.0
	duration_slider.step = 5.0
	duration_slider.value = match_duration
	duration_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duration_slider.value_changed.connect(func(value: float) -> void:
		match_duration = value
		duration_value.text = "%d s" % int(value)
	)
	duration_row.add_child(duration_slider)
	duration_value = _label("%d s" % int(match_duration), 14, GOLD)
	duration_row.add_child(duration_value)
	auto_restart_check = CheckButton.new()
	auto_restart_check.text = "Reiniciar automaticamente após o resultado"
	auto_restart_check.button_pressed = auto_restart
	auto_restart_check.add_theme_color_override("font_color", TEXT)
	content.add_child(auto_restart_check)
	var sound := CheckButton.new()
	sound.text = "Sons opcionais (rota silenciosa até configuração de áudio)"
	sound.button_pressed = false
	sound.disabled = true
	sound.add_theme_color_override("font_color", MUTED)
	content.add_child(sound)
	var info := _label("Presentes: Rosa = energia • Coração = vida + energia • Foguete = golpe poderoso • Coroa = impacto máximo. Repetições em janela de 4 s geram multiplicador validado.", 12, MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(info)
	var close := _button("SALVAR E FECHAR", CYAN, 220.0)
	close.pressed.connect(_save_admin)
	content.add_child(close)


func _start_demo_battle() -> void:
	demo_mode = true
	transmission_mode = false
	battle_active = true
	admin_visible = false
	admin_panel.visible = false
	result_panel.visible = false
	fighter_ids = [_selected_id(left_select, "capitao-brasa"), _selected_id(right_select, "raio-azul")]
	engine.setup(fighter_ids[0], fighter_ids[1], match_duration)
	gifts.reset()
	battle_root.visible = true
	title_root.visible = false
	battle_mode_label.text = "MODO DEMONSTRAÇÃO  •  EVENTOS SIMULADOS"
	transmission_label.text = ""
	event_lines.clear()
	_push_event("[color=#55dcff]DEMO[/color] arena iniciada • presentes simulados ativos")
	_sync_battle()


func _open_transmission() -> void:
	if not battle_active:
		_start_demo_battle()
	transmission_mode = true
	demo_mode = true
	title_root.visible = false
	battle_root.visible = true
	battle_controls.visible = false
	transmission_label.text = "MODO TRANSMISSÃO  •  1920×1080 / 1080×1920  •  DEMO LOCAL"
	battle_mode_label.text = "TIKTOK LIVE ARENA  •  CAPTURA OBS"
	_push_event("[color=#ffc857]OBS[/color] controles ocultos • conexão TikTok LIVE ainda não configurada")
	_apply_layout()


func _connect_live() -> void:
	var result := tiktok.connect_authorized()
	status_text = str(result.get("detail", "TikTok LIVE indisponível."))
	if title_status != null:
		title_status.text = status_text
	if live_status_label != null:
		live_status_label.text = "TikTok LIVE: %s" % status_text


func _on_live_state(state: String, detail: String) -> void:
	if live_status_label != null:
		live_status_label.text = "TikTok LIVE [%s]: %s" % [state.to_upper(), detail]
	if battle_active:
		_push_event("[color=#ee67ce]LIVE[/color] %s" % detail)


func _on_authorized_event(event: Dictionary) -> void:
	if not battle_active:
		return
	var result := gifts.process_event(event, engine, false)
	if bool(result.get("ok", false)):
		_push_event("[color=#ee67ce]LIVE REAL[/color] %s — %s" % [result["user"], result["text"]])
		_emit_gift_fx(result)
	else:
		_push_event("[color=#ff7d7d]LIVE BLOQUEADO[/color] %s" % result.get("text", "Evento rejeitado"))


func _send_demo_gift(gift_type: String) -> void:
	if not demo_mode or not battle_active:
		return
	var result := gifts.process_event({
		"id": "demo-%d-%s" % [Time.get_ticks_msec(), gift_type],
		"gift_type": gift_type,
		"quantity": 1,
		"target": target_select.selected,
		"user": "Torcedor DEMO",
	}, engine, true)
	if bool(result.get("ok", false)):
		_push_event("[color=#55dcff]DEMO[/color] %s enviou %s → %s" % [result["user"], result["label"], result["text"]])
		_emit_gift_fx(result)
	else:
		_push_event("[color=#ff7d7d]DEMO[/color] %s" % result.get("text", "Presente rejeitado"))
	_sync_battle()


func _emit_gift_fx(result: Dictionary) -> void:
	var target := int(result.get("target", 0))
	var color := MAGENTA if str(result.get("gift_type", "")) == "coracao" else GOLD
	if str(result.get("gift_type", "")) == "foguete":
		color = FIRE
	elif str(result.get("gift_type", "")) == "rosa":
		color = Color("ff94c8")
	fx.emit_burst(_fighter_center(target), color, "special" if str(result.get("gift_type", "")) in ["foguete", "coroa"] else "impact")
	special_label.text = "%s • %s" % [str(result.get("label", "PRESENTE")).to_upper(), str(result.get("text", ""))]
	var tween := create_tween()
	tween.tween_property(special_label, "modulate:a", 1.0, 0.08)
	tween.tween_interval(1.45)
	tween.tween_property(special_label, "modulate:a", 0.0, 0.3)


func _handle_engine_event(event: Dictionary) -> void:
	var kind := str(event.get("kind", ""))
	if kind == "round_start":
		_push_event("[color=#ffc857]%s[/color]" % event.get("text", "Nova rodada"))
		special_label.text = str(event.get("text", ""))
		_emit_center_fx(GOLD, "special")
	elif kind in ["attack", "critical", "special"]:
		var attacker := int(event.get("attacker", 0))
		var defender := int(event.get("defender", 1))
		var damage := float(event.get("damage", 0.0))
		var label := "[color=#ff8b72]IMPACTO[/color]"
		var color := FIRE
		if kind == "critical":
			label = "[color=#ffc857]CRÍTICO[/color]"
			color = GOLD
		elif kind == "special":
			label = "[color=#ae7bff]ESPECIAL[/color]"
			color = VIOLET
		_push_event("%s %s • %.0f dano" % [label, event.get("text", ""), damage])
		_animate_fighter(attacker, kind)
		_animate_fighter(defender, "damage")
		fx.emit_burst(_fighter_center(defender), color, "special" if kind == "special" else "impact")
		if kind == "special":
			special_label.text = str(event.get("text", ""))
			var tween := create_tween()
			tween.tween_property(special_label, "modulate:a", 1.0, 0.06)
			tween.tween_interval(0.75)
			tween.tween_property(special_label, "modulate:a", 0.0, 0.28)
	elif kind == "round_end":
		_push_event("[color=#ffc857]%s[/color]" % event.get("text", ""))
		_emit_center_fx(GOLD, "special")
	elif kind == "match_end":
		_push_event("[color=#ffc857]%s[/color]" % event.get("text", ""))
		_show_result(event)


func _sync_battle() -> void:
	if not battle_active or engine == null:
		return
	var state := engine.get_state()
	var fighters: Array = state.get("fighters", [])
	if fighters.size() < 2:
		return
	var left: Dictionary = fighters[0]
	var right: Dictionary = fighters[1]
	left_name.text = str(left["name"])
	right_name.text = str(right["name"])
	left_hp.value = float(left["hp"])
	right_hp.value = float(right["hp"])
	left_energy.value = float(left["energy"])
	right_energy.value = float(right["energy"])
	left_stats.text = "ATQ %d  DEF %d  VEL %d  • %s" % [int(left["attack"]), int(left["defense"]), int(left["speed"]), str(left["special"])]
	right_stats.text = "ATQ %d  DEF %d  VEL %d  • %s" % [int(right["attack"]), int(right["defense"]), int(right["speed"]), str(right["special"])]
	round_label.text = "RODADA %d" % int(state["round"])
	score_label.text = "%d  —  %d" % [int(state["score"][0]), int(state["score"][1])]
	var remaining := maxf(0.0, float(state["duration"]) - float(state["elapsed"]))
	timer_label.text = "%02d:%02d" % [int(remaining) / 60, int(remaining) % 60]
	fighter_nodes[0].texture = _texture_for(str(left["id"]))
	fighter_nodes[1].texture = _texture_for(str(right["id"]))
	if state["state"] == "finished" and not result_panel.visible:
		_show_result({"winner": int(state["winner"]), "score": state["score"], "text": "Partida encerrada"})
	_apply_layout()


func _animate_fighter(index: int, action: String) -> void:
	if index < 0 or index >= fighter_nodes.size():
		return
	var node := fighter_nodes[index]
	node.pivot_offset = node.size * 0.5
	var base := node.position
	var direction := 1.0 if index == 0 else -1.0
	var tween := create_tween()
	tween.set_parallel(true)
	match action:
		"attack", "critical":
			tween.tween_property(node, "position", base + Vector2(28.0 * direction, -8.0), 0.15)
			tween.tween_property(node, "scale", Vector2(1.08, 0.94), 0.15)
			if not action == "critical":
				tween.tween_property(node, "rotation", 0.035 * direction, 0.15)
		"special":
			tween.tween_property(node, "position", base + Vector2(20.0 * direction, -20.0), 0.18)
			tween.tween_property(node, "scale", Vector2(1.18, 1.18), 0.18)
			tween.tween_property(node, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.12)
		"damage":
			tween.tween_property(node, "position", base + Vector2(-16.0 * direction, 5.0), 0.10)
			tween.tween_property(node, "modulate", Color(1.4, 0.55, 0.55, 1.0), 0.10)
		"dodge":
			tween.tween_property(node, "position", base + Vector2(-34.0 * direction, -12.0), 0.16)
			tween.tween_property(node, "modulate", Color(0.7, 0.85, 1.25, 1.0), 0.16)
		_:
			tween.tween_property(node, "position", base + Vector2(0.0, -7.0), 0.16)
	tween.chain().set_parallel(true)
	tween.tween_property(node, "position", base, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "rotation", 0.0, 0.24)
	tween.tween_property(node, "modulate", Color.WHITE, 0.24)


func _show_result(event: Dictionary) -> void:
	if result_panel == null:
		return
	result_panel.visible = true
	var winner := int(event.get("winner", -1))
	result_title.text = "EMPATE" if winner < 0 else "VITÓRIA DE %s" % str(engine.fighters[winner]["name"])
	result_detail.text = "%s\nPlacar final: %d — %d\n%s" % [str(event.get("text", "Arena encerrada")), int(engine.score[0]), int(engine.score[1]), "Modo DEMO — nenhuma conexão TikTok foi simulada."]
	_save_history(winner)
	if auto_restart and not transmission_mode:
		var tween := create_tween()
		tween.tween_interval(3.0)
		tween.tween_callback(_restart_battle)


func _restart_battle() -> void:
	if fighter_ids.size() < 2:
		_start_demo_battle()
		return
	result_panel.visible = false
	battle_active = true
	engine.setup(fighter_ids[0], fighter_ids[1], match_duration)
	gifts.reset()
	event_lines.clear()
	_push_event("[color=#55dcff]DEMO[/color] partida reiniciada")
	_sync_battle()


func _return_to_title() -> void:
	battle_active = false
	transmission_mode = false
	battle_root.visible = false
	title_root.visible = true
	admin_panel.visible = false
	result_panel.visible = false
	title_status.text = status_text


func _toggle_pause() -> void:
	if not battle_active:
		return
	if engine.paused:
		engine.resume()
		_push_event("[color=#ffc857]SISTEMA[/color] partida retomada")
	else:
		engine.pause()
		_push_event("[color=#ffc857]SISTEMA[/color] partida pausada")


func _toggle_admin(should_show: bool) -> void:
	admin_visible = should_show
	admin_panel.visible = should_show
	if should_show:
		admin_panel.move_to_front()


func _save_admin() -> void:
	auto_restart = auto_restart_check.button_pressed
	_save_config()
	_toggle_admin(false)
	status_text = "Configuração salva localmente • pronta para nova partida"
	title_status.text = status_text


func _focus_selection() -> void:
	left_select.grab_focus()
	title_status.text = "Selecione dois lutadores originais e inicie a arena."


func _show_title() -> void:
	title_root.visible = true
	battle_root.visible = false
	admin_panel.visible = false
	result_panel.visible = false
	battle_active = false
	transmission_mode = false


func _push_event(text: String) -> void:
	event_lines.push_front(text)
	if event_lines.size() > 8:
		event_lines.resize(8)
	if event_feed != null:
		event_feed.text = "\n".join(event_lines)


func _emit_center_fx(color: Color, kind: String) -> void:
	if fx != null:
		fx.emit_burst(Vector2(size.x * 0.5, size.y * 0.47), color, kind)


func _fighter_center(index: int) -> Vector2:
	if index < 0 or index >= fighter_nodes.size():
		return Vector2(size.x * 0.5, size.y * 0.5)
	return fighter_nodes[index].position + fighter_nodes[index].size * 0.5


func _layout_fighters() -> void:
	if fighter_nodes.size() < 2:
		return
	var portrait := size.y > size.x * 1.12
	var sprite_size := Vector2(size.x * (0.25 if not portrait else 0.42), size.y * (0.58 if not portrait else 0.25))
	sprite_size.x = clampf(sprite_size.x, 190.0, 390.0)
	sprite_size.y = clampf(sprite_size.y, 190.0, 430.0)
	if portrait:
		fighter_nodes[0].size = sprite_size
		fighter_nodes[1].size = sprite_size
		fighter_nodes[0].position = Vector2(size.x * 0.27 - sprite_size.x * 0.5, size.y * 0.53)
		fighter_nodes[1].position = Vector2(size.x * 0.73 - sprite_size.x * 0.5, size.y * 0.33)
	else:
		fighter_nodes[0].size = sprite_size
		fighter_nodes[1].size = sprite_size
		fighter_nodes[0].position = Vector2(size.x * 0.16 - sprite_size.x * 0.5, size.y * 0.34)
		fighter_nodes[1].position = Vector2(size.x * 0.84 - sprite_size.x * 0.5, size.y * 0.34)
	for node: TextureRect in fighter_nodes:
		node.pivot_offset = node.size * 0.5


func _apply_layout() -> void:
	if is_instance_valid(background):
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if is_instance_valid(tint):
		tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout_fighters()
	if is_instance_valid(admin_panel):
		admin_panel.offset_left = -minf(420.0, size.x * 0.35)
		admin_panel.offset_right = minf(420.0, size.x * 0.35)


func _selected_id(option: OptionButton, fallback: String) -> String:
	if option == null or option.selected < 0:
		return fallback
	return str(option.get_item_metadata(option.selected))


func _texture_for(id: String) -> Texture2D:
	match id:
		"capitao-brasa": return CAPITAO_ART
		"raio-azul": return RAIO_ART
		"sombra-negra": return SOMBRA_ART
		"guardiao-dourado": return GUARDIAO_ART
	return CAPITAO_ART


func _anchored(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _button(text: String, accent: Color, width: float = 300.0) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 42.0)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _style(Color(0.08, 0.12, 0.22, 0.94), Color(accent, 0.5), 8))
	button.add_theme_stylebox_override("hover", _style(Color(0.12, 0.18, 0.31, 0.98), accent, 8))
	button.add_theme_stylebox_override("pressed", _style(Color(accent, 0.32), accent, 8))
	return button


func _style(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style


func _panel(color: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(color, border, 12))
	return panel


func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _style(Color(0.03, 0.05, 0.11, 0.92), Color(1.0, 1.0, 1.0, 0.12), 4))
	bar.add_theme_stylebox_override("fill", _style(color, Color(color, 0.8), 4))
	return bar


func _rule(color: Color) -> ColorRect:
	var line := ColorRect.new()
	line.color = color
	line.custom_minimum_size = Vector2(120.0, 2.0)
	return line


func _load_config() -> void:
	var config := ConfigFile.new()
	if config.load("user://livearena.cfg") == OK:
		match_duration = float(config.get_value("arena", "duration", 45.0))
		auto_restart = bool(config.get_value("arena", "auto_restart", false))


func _save_config() -> void:
	var config := ConfigFile.new()
	config.set_value("arena", "duration", match_duration)
	config.set_value("arena", "auto_restart", auto_restart)
	config.save("user://livearena.cfg")


func _load_history() -> void:
	if not FileAccess.file_exists("user://livearena_history.json"):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("user://livearena_history.json"))
	if parsed is Array:
		history = parsed


func _save_history(winner: int) -> void:
	var record := {"winner": winner, "score": engine.score.duplicate(), "round": engine.round_number, "mode": "demo" if demo_mode else "tiktok-live", "timestamp": Time.get_datetime_string_from_system()}
	history.push_front(record)
	if history.size() > 20:
		history.resize(20)
	var file := FileAccess.open("user://livearena_history.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(history))
		file.close()
