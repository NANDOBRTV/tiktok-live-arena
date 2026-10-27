class_name ArenaFxOverlay
extends Control

var bursts: Array[Dictionary] = []
var ambient_time := 0.0
var reduced_motion := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)


func emit_burst(at: Vector2, color: Color, kind: String = "impact") -> void:
	bursts.append({"at": at, "color": color, "kind": kind, "life": 0.0, "duration": 0.82 if kind == "special" else 0.52})
	queue_redraw()


func _process(delta: float) -> void:
	ambient_time += delta
	for burst: Dictionary in bursts:
		burst["life"] = float(burst["life"]) + delta
	bursts = bursts.filter(func(item: Dictionary) -> bool: return float(item["life"]) < float(item["duration"]))
	queue_redraw()


func _draw() -> void:
	if not reduced_motion:
		for index: int in 5:
			var alpha := 0.05 + 0.025 * sin(ambient_time * 1.2 + index)
			var x := size.x * (0.12 + 0.19 * index)
			draw_line(Vector2(x, size.y * 0.24), Vector2(x + 90.0, size.y * 0.24), Color(0.23, 0.78, 1.0, alpha), 2.0)
	for burst: Dictionary in bursts:
		var life := float(burst["life"])
		var duration := float(burst["duration"])
		var p: Vector2 = burst["at"]
		var color: Color = burst["color"]
		var t := clampf(life / duration, 0.0, 1.0)
		var fade := 1.0 - t
		var radius := lerpf(18.0, 110.0 if burst["kind"] == "special" else 72.0, t)
		if burst["kind"] == "special":
			draw_arc(p, radius, 0.0, TAU, 36, Color(color, fade * 0.8), 7.0)
			draw_arc(p, radius * 0.62, 0.0, TAU, 30, Color.WHITE * Color(1.0, 1.0, 1.0, fade * 0.7), 3.0)
			for ray: int in 10:
				var a := TAU * float(ray) / 10.0
				draw_line(p + Vector2.from_angle(a) * radius * 0.58, p + Vector2.from_angle(a) * radius * 1.12, Color(color, fade * 0.65), 4.0)
		else:
			draw_circle(p, lerpf(5.0, 2.0, t), Color.WHITE * Color(1.0, 1.0, 1.0, fade))
			for ray: int in 8:
				var a := TAU * float(ray) / 8.0
				draw_line(p + Vector2.from_angle(a) * radius * 0.2, p + Vector2.from_angle(a) * radius, Color(color, fade * 0.8), 3.0)
