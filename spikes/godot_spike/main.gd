# Spike Godot 4 : « Compte les pommes » (voir ../README.md).
extends Node2D

# Positions normalisées communes aux trois spikes, et suite des N.
const POSITIONS = [
	Vector2(0.20, 0.20), Vector2(0.50, 0.15), Vector2(0.80, 0.22), Vector2(0.30, 0.42),
	Vector2(0.70, 0.40), Vector2(0.15, 0.60), Vector2(0.55, 0.62),
]
const ROUNDS = [5, 3, 7, 4, 6]
const RADIUS = 40.0
const BAR = 140.0
const RED = Color("#d6362b")
const GREEN = Color("#1d7a33")
const BG = Color("#f7f8f6")

var round_i := 0
var numbers := {}
var t := 0.0
var frames := 0
var window := 0.0
var voice := ""
var bar: HBoxContainer
var ding: AudioStreamPlayer
var font: Font


func n() -> int:
	return ROUNDS[round_i % ROUNDS.size()]


func _ready() -> void:
	RenderingServer.set_default_clear_color(BG)
	font = ThemeDB.fallback_font
	ding = AudioStreamPlayer.new()
	ding.stream = load("res://ding.wav")
	add_child(ding)
	var layer := CanvasLayer.new()
	add_child(layer)
	bar = HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 48)
	layer.add_child(bar)
	var voices := DisplayServer.tts_get_voices_for_language("fr")
	if voices.size() > 0:
		voice = voices[0]
	say("Touche chaque pomme pour la compter.")
	await RenderingServer.frame_post_draw
	print("SPIKE first_frame")


func say(text: String) -> void:
	if voice != "":
		DisplayServer.tts_speak(text, voice)


func area() -> Vector2:
	var s := get_viewport_rect().size
	return Vector2(s.x, s.y - BAR)


func centers() -> Array:
	var a := area()
	var out := []
	for i in n():
		var p: Vector2 = POSITIONS[i]
		out.append(Vector2(p.x * a.x, p.y / 0.75 * a.y + sin(t * 2 + i) * 8))
	return out


func _process(delta: float) -> void:
	t += delta
	frames += 1
	window += delta
	if window >= 5.0:
		print("SPIKE fps %.1f" % (frames / window))
		frames = 0
		window = 0.0
	var s := get_viewport_rect().size
	bar.position = Vector2(0, s.y - BAR)
	bar.size = Vector2(s.x, BAR)
	queue_redraw()


func _draw() -> void:
	var cs := centers()
	for i in cs.size():
		var c: Vector2 = cs[i]
		draw_circle(c, RADIUS * 0.85, RED)
		draw_set_transform(c + Vector2(RADIUS * 0.3, -RADIUS + RADIUS * 0.175), 0, Vector2(1, 0.58))
		draw_circle(Vector2.ZERO, RADIUS * 0.3, GREEN)
		draw_set_transform(Vector2.ZERO)
		if numbers.has(i):
			draw_arc(c, RADIUS, 0, TAU, 48, GREEN, 6, true)
			var txt := str(numbers[i])
			var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 34)
			draw_string(font, c + Vector2(-sz.x / 2, sz.y / 3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	var cs := centers()
	for i in cs.size():
		if not numbers.has(i) and event.position.distance_to(cs[i]) <= RADIUS:
			numbers[i] = numbers.size() + 1
			say(str(numbers.size()))
			if numbers.size() == n():
				say("Combien de pommes ?")
				show_buttons()
			return


func show_buttons() -> void:
	for v in [n() - 1, n(), n() + 1]:
		var b := Button.new()
		b.text = str(v)
		b.custom_minimum_size = Vector2(96, 96)
		b.add_theme_font_size_override("font_size", 40)
		var st := StyleBoxFlat.new()
		st.bg_color = GREEN
		st.set_corner_radius_all(24)
		for state in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(state, st)
		b.pressed.connect(answer.bind(v))
		bar.add_child(b)


func answer(v: int) -> void:
	if v != n():
		say("Compte encore.")
		return
	ding.play()
	say("Oui, il y a %d pommes. Bravo !" % n())
	for b in bar.get_children():
		b.queue_free()
	numbers.clear()
	round_i += 1
