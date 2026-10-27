extends SceneTree

var main: Control
var capture_path := ""
var game_mode := false
var new_characters := false


func _initialize() -> void:
	capture_path = OS.get_environment("ARENA_CAPTURE_PATH")
	game_mode = OS.get_environment("ARENA_CAPTURE_GAME") == "1"
	new_characters = OS.get_environment("ARENA_NEW_CHARACTERS") == "1"
	if capture_path.is_empty():
		push_error("ARENA_CAPTURE_PATH ausente")
		quit(2)
		return
	call_deferred("_capture")


func _capture() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	if game_mode:
		if new_characters:
			(main.get("left_select") as OptionButton).select(0)
			(main.get("right_select") as OptionButton).select(1)
		main.call("_start_demo_battle")
		await process_frame
		await process_frame
		await process_frame
		await create_timer(1.2).timeout
	var image: Image = get_root().get_texture().get_image()
	image.save_png(capture_path)
	main.queue_free()
	await process_frame
	print("[arena-capture] saved %s" % capture_path)
	quit(0)
