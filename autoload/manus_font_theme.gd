extends Node
## Bind the imported UI composites (Latin body face + Noto Sans SC) at runtime, after the editor's first import pass.
const GameFonts = preload("res://scripts/manus/game_fonts.gd")
var _regular: Font
var _theme: Theme

func _enter_tree() -> void:
	_regular = load("res://assets/template/fonts/ui_regular.tres") as Font
	var bundled_fonts_available := _regular != null
	if not bundled_fonts_available:
		# The web export and headless CI must remain bootable when optional bundled webfonts are absent.
		_regular = ThemeDB.fallback_font
	var medium: Font = null
	var bold: Font = null
	if bundled_fonts_available:
		medium = load("res://assets/template/fonts/ui_medium.tres") as Font
		bold = load("res://assets/template/fonts/ui_bold.tres") as Font
	_theme = GameFonts.create_theme(_regular, medium, bold)
	get_tree().node_added.connect(_bind_node)
	_bind_tree(get_tree().root)

func _bind_tree(node: Node) -> void:
	_bind_node(node)
	for child in node.get_children():
		_bind_tree(child)

func _bind_node(node: Node) -> void:
	if node is Control:
		if node.theme != null:
			if node.theme.default_font == null:
				node.theme = node.theme.duplicate()
				node.theme.default_font = _regular
		elif node.get_parent_control() == null:
			node.theme = _theme
	elif node is Label3D and node.font == null:
		GameFonts.apply_world_label(node, _regular)
