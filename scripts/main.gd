extends Node3D
var party_input: PartyInput

const Fruit: Script = preload("res://games/minigame/godot_party_default_fruit_samurai/scripts/fruit.gd")
enum State { MENU, PLAYING, PAUSED, OVER }
var state: State = State.MENU
var score: int = 0
var best: int = 0
var misses: int = 0
var elapsed: float = 0.0
var spawn_timer: float = 0.5
var wave: int = 0
var slicing: bool = false
var last_point: Vector2 = Vector2.ZERO
var stroke_hits: int = 0
var combo_window: float = 0.0
var stroke_last: Vector2 = Vector2.ZERO
var touch_id: int = -1
var touch_cooldown: float = 0.0
var shake: float = 0.0
var hit_stop: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var audio_players: Array[AudioStreamPlayer] = []
var audio_index: int = 0
@onready var camera: Camera3D = $Camera
@onready var fruits: Node3D = $Fruits
@onready var fragments: Node3D = $Fragments
@onready var fx: Node2D = $Canvas/FX
@onready var menu: Control = $Canvas/UI/Menu
@onready var hud: Control = $Canvas/UI/HUD

func _ready() -> void:
	rng.randomize()
	for i: Variant in range(8):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(player)
		audio_players.append(player)
	menu.get_node("ReducedMotion").button_pressed = fx.reduced_motion
	menu.get_node("Play").pressed.connect(_play_pressed)
	menu.get_node("Secondary").hide()
	menu.get_node("ReducedMotion").toggled.connect(_set_reduced_motion)
	hud.get_node("Pause").pressed.connect(pause_game)
	_style_ui()
	var hud_style: String = "original"
	for argument: Variant in OS.get_cmdline_user_args():
		if argument.begins_with("--hud-style="):
			hud_style = argument.trim_prefix("--hud-style=")
	hud.configure(hud_style)
	_create_decor()
	_update_hud()

func _style_ui() -> void:
	for button: Variant in [menu.get_node("Play"), menu.get_node("Secondary"), hud.get_node("Pause")]:
		var normal: StyleBoxFlat = StyleBoxFlat.new()
		normal.bg_color = Color("e9cc87") if button.name == "Play" else Color("1c3931")
		normal.corner_radius_top_left = 6
		normal.corner_radius_top_right = 6
		normal.corner_radius_bottom_left = 6
		normal.corner_radius_bottom_right = 6
		normal.border_color = Color("607967")
		normal.set_border_width_all(1)
		button.add_theme_stylebox_override("normal", normal)
		var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
		hover.bg_color = normal.bg_color.lightened(0.16)
		button.add_theme_stylebox_override("hover", hover)
		var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
		pressed.bg_color = normal.bg_color.darkened(0.15)
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_stylebox_override("focus", hover)
		button.add_theme_color_override("font_color", Color("19372c") if button.name == "Play" else Color("f3edda"))
		button.add_theme_color_override("font_hover_color", Color("19372c") if button.name == "Play" else Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color("19372c") if button.name == "Play" else Color.WHITE)
		button.add_theme_color_override("font_focus_color", Color("19372c") if button.name == "Play" else Color.WHITE)

func _create_decor() -> void:
	for i: Variant in range(4):
		var fruit: Variant = Fruit.new()
		$Decor.add_child(fruit)
		fruit.setup(i)
		fruit.decorative = true
		fruit.position = [Vector3(4.3,0.2,0), Vector3(6.5,2.0,-0.5), Vector3(3.0,2.7,0), Vector3(6.0,-2.5,0)][i]
		fruit.scale = Vector3.ONE * [1.9,1.6,1.5,1.9][i]
		fruit.rotation = Vector3(0.25,-0.4,0.25 if i % 2 == 0 else -0.3)
		fruit.spin = Vector3(0.06,0.15,0.04)

func _set_reduced_motion(value: bool) -> void:
	fx.reduced_motion = value
	_save()

func _save() -> void:
	pass

func start_game() -> void:
	_clear_round()
	score = 0
	misses = 0
	elapsed = 0
	wave = 0
	spawn_timer = 0.45
	state = State.PLAYING
	menu.hide()
	hud.show()
	$Decor.hide()
	fx.set_process(true)
	_update_hud()

func _clear_round() -> void:
	for container: Variant in [fruits, fragments]:
		for child: Variant in container.get_children():
			container.remove_child(child)
			child.queue_free()
	slicing = false
	touch_id = -1
	touch_cooldown = 0
	stroke_hits = 0
	hit_stop = 0
	shake = 0
	camera.position.x = 0
	camera.position.y = 0
	fx.clear_effects()
	for player: Variant in audio_players:
		player.stop()

func _play_pressed() -> void:
	if state == State.PAUSED:
		resume_game()
	else:
		start_game()

func pause_game() -> void:
	finish_stroke()

func resume_game() -> void:
	state = State.PLAYING
	menu.hide()
	fx.set_process(true)
	slicing = false
	touch_id = -1

func end_game(reason: String) -> void:
	if state != State.PLAYING:
		return
	finish_stroke()
	state = State.OVER
	best = maxi(best, score)
	_save()
	_show_menu("本局\\n结束", "%s\\n得分  %d · 等待其他玩家完成" % [reason, score], "")
	menu.get_node("Play").hide()
	menu.get_node("ReducedMotion").hide()
	hud.hide()
	$Decor.show()
	for child: Variant in fruits.get_children():
		child.hide()

func _show_menu(title: String, subtitle: String, button: String) -> void:
	menu.get_node("Title").add_theme_font_override("font", load("res://games/minigame/godot_party_default_fruit_samurai/assets/Chinese.ttc"))
	menu.get_node("Title").text = title.replace("\\n", "\n")
	menu.get_node("Subtitle").text = subtitle.replace("\\n", "\n")
	menu.get_node("Play").text = button
	menu.get_node("Secondary").visible = state == State.PAUSED
	menu.get_node("Eyebrow").text = "出刀如风 · 果香四溢" if state != State.PAUSED else "暂停中"
	menu.show()

func _update_hud() -> void:
	hud.update_values(score, best, misses)

func _setup_hud_preview() -> void:
	# Capture renders a 1920x1080 viewport even when the desktop caps window dimensions.
	# HUD's authored 1600x900 coordinate system scales once; 3D and FX use viewport pixels.
	for argument: Variant in OS.get_cmdline_user_args():
		if argument.begins_with("--hud-capture="):
			var window: Variant = get_window()
			window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
			window.content_scale_size = Vector2i(1920,1080)
			$Canvas/UI.scale = Vector2(1.2,1.2)
			await get_tree().process_frame
	# Explicit, deterministic illustration for fair skin comparisons, not a recorded score.
	start_game()
	rng.seed = 1729
	fx._rng.seed = 1729
	score = 245
	best = 980
	misses = 1
	_update_hud()
	var positions: Array = [Vector3(-4.8,-0.5,0), Vector3(-1.9,1.3,0), Vector3(1.6,-0.7,0), Vector3(4.7,0.8,0)]
	for i: Variant in range(4):
		var fruit: Variant = spawn_fruit(i, positions[i])
		fruit.rotation = Vector3(0.24, -0.35, -0.22 + i * 0.19)
	var source: Variant = spawn_fruit(2, Vector3(0.2,0.4,0))
	_split(source, Vector2(0.8,-0.6))
	fruits.remove_child(source)
	source.queue_free()
	for piece: Variant in fragments.get_children():
		piece.step(0.12)
	var at: Variant = camera.unproject_position(Vector3(0.2,0.4,0))
	fx.burst(at, Color("ffdf5c"), Vector2(0.8,-0.6))
	fx.show_combo(at + Vector2(12,-70), 3, 15)
	fx._process(0.2)
	for p: Variant in [Vector2(-105,74),Vector2(-54,42),Vector2(-5,10),Vector2(45,-22),Vector2(82,-54)]:
		fx.add_blade_point(at + p)
	fx.set_process(false)
	set_process(false)
	for argument: Variant in OS.get_cmdline_user_args():
		if argument.begins_with("--hud-capture="):
			_capture_hud_preview(argument.trim_prefix("--hud-capture="))

func _capture_hud_preview(path: String) -> void:
	# A real rendered viewport; never available in the headless dummy renderer.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Variant = get_viewport().get_texture().get_image()
	var result: Variant = image.save_png(path)
	print("HUD_CAPTURE: ", path, " result=", result)

func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.033)
	touch_cooldown = maxf(0, touch_cooldown - dt)
	for decor: Variant in $Decor.get_children():
		if not fx.reduced_motion:
			decor.step(dt)
	if state != State.PLAYING:
		return
	if hit_stop > 0:
		hit_stop -= dt
		return
	if stroke_hits > 0:
		combo_window -= dt
		if combo_window <= 0:
			_settle_combo()
	elapsed += dt
	shake = maxf(0, shake - dt * 4)
	camera.position.x = rng.randf_range(-shake, shake) * 0.12 if not fx.reduced_motion else 0.0
	camera.position.y = rng.randf_range(-shake, shake) * 0.09 if not fx.reduced_motion else 0.0
	spawn_timer -= dt
	if spawn_timer <= 0:
		_spawn_wave()
		spawn_timer = maxf(1.3, 2.1 - elapsed * 0.006)
	for fruit: Variant in fruits.get_children():
		fruit.step(dt)
		if fruit.position.y < -7.6 and fruit.velocity.y < 0:
			if not fruit.cut and fruit.kind != 4:
				misses += 1
				_sound("miss")
				_update_hud()
				if misses >= 3:
					end_game("漏掉了三个水果，下次一定更快。")
			fruit.cut = true
			fruit.queue_free()
			if state != State.PLAYING:
				break
	for piece: Variant in fragments.get_children():
		piece.step(dt)
		if piece.position.y < -9 or piece.age > 3:
			piece.queue_free()

func _spawn_wave() -> void:
	wave += 1
	var count: int = mini(5, 2 + int(elapsed / 22.0))
	var center: float = rng.randf_range(-3.8, 3.8)
	for i: Variant in range(count):
		spawn_fruit(rng.randi_range(0, 3), Vector3(center + (float(i) - float(count - 1) * 0.5) * 1.65, -6.6 - rng.randf_range(0, 0.4), rng.randf_range(-0.4, 0.4)))
	if wave > 2 and rng.randf() < 0.52:
		spawn_fruit(4, Vector3(rng.randf_range(-6.5,6.5), -7.1, 0.4))

func spawn_fruit(kind: int, at: Vector3) -> Node3D:
	var fruit: Variant = Fruit.new()
	fruits.add_child(fruit)
	fruit.setup(kind)
	fruit.position = at
	fruit.velocity = Vector3(-at.x * rng.randf_range(0.12,0.24), rng.randf_range(12.8,14.1), 0)
	fruit.spin = Vector3(rng.randf_range(-2,2), rng.randf_range(-2,2), rng.randf_range(-1.7,1.7))
	return fruit

static func segment_hits_circle(a: Vector2, b: Vector2, center: Vector2, radius: float) -> bool:
	var ab: Vector2 = b - a
	var t: float = clampf((center - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return (a + ab * t).distance_squared_to(center) <= radius * radius

func begin_stroke(point: Vector2) -> void:
	if state != State.PLAYING:
		return
	slicing = true
	last_point = point
	stroke_last = point
	stroke_hits = 0
	fx.add_blade_point(point)

func continue_stroke(point: Vector2) -> void:
	if not slicing or state != State.PLAYING:
		return
	fx.add_blade_point(point)
	if point.distance_squared_to(last_point) < 4:
		return
	var direction: Vector2 = (point - last_point).normalized()
	for fruit: Variant in fruits.get_children():
		if fruit.cut or fruit.is_queued_for_deletion() or camera.is_position_behind(fruit.global_position):
			continue
		var center: Vector2 = camera.unproject_position(fruit.global_position)
		var edge: Vector2 = camera.unproject_position(fruit.global_position + Vector3.RIGHT * fruit.radius)
		if segment_hits_circle(last_point, point, center, center.distance_to(edge)):
			cut_fruit(fruit, center, direction)
			if state != State.PLAYING:
				break
	last_point = point
	stroke_last = point

func _settle_combo() -> void:
	if stroke_hits >= 3:
		var bonus: int = stroke_hits * 5
		score += bonus
		fx.show_combo(stroke_last, stroke_hits, bonus)
		_sound("combo")
		_update_hud()
	stroke_hits = 0
	combo_window = 0

func finish_stroke() -> void:
	_settle_combo()
	slicing = false
	fx.end_blade()

func cut_fruit(fruit: Node3D, point: Vector2, direction: Vector2) -> void:
	if fruit.cut or state != State.PLAYING:
		return
	fruit.cut = true
	_sound("bomb" if fruit.kind == 4 else "slice")
	fx.burst(point, fruit.juice_color(), direction, fruit.kind == 4)
	shake = 1.0 if fruit.kind == 4 else 0.2
	hit_stop = 0.045 if not fx.reduced_motion else 0.0
	if fruit.kind == 4:
		fruit.queue_free()
		end_game("切到了炸弹！调整节奏，再试一次。")
		return
	score += 10
	stroke_hits += 1
	combo_window = 0.30
	stroke_last = point
	_update_hud()
	_split(fruit, direction)
	fruit.queue_free()

func _split(fruit: Node3D, direction: Vector2) -> void:
	var normal: Vector3 = Vector3(-direction.y, -direction.x, 0).normalized()
	var angle: float = atan2(normal.y, normal.x)
	if fruit.kind < 3:
		for side: Variant in range(2):
			var piece: Variant = Fruit.new()
			fragments.add_child(piece)
			piece.setup(fruit.kind, true, side == 1)
			piece.fragment = true
			piece.position = fruit.position
			piece.rotation = Vector3(0.15,0.3,angle - (PI * 0.5 if fruit.kind == 2 else 0.0))
			var sign_value: float = -1.0 if side == 0 else 1.0
			piece.velocity = fruit.velocity * 0.32 + normal * sign_value * 2.8 + Vector3(0,1,0)
			piece.spin = Vector3(sign_value * 2.5, sign_value * 1.5, sign_value * 2)
	else:
		# Kenney's melon is composed of eight authored wedges. Preserve their transforms.
		for original: Variant in fruit.visual.get_child(0).get_children():
			if not original is MeshInstance3D:
				continue
			var piece: Variant = Fruit.new()
			fragments.add_child(piece)
			piece.kind = 3
			piece.fragment = true
			piece.transform = fruit.transform
			var mesh: MeshInstance3D = original.duplicate() as MeshInstance3D
			piece.add_child(mesh)
			mesh.transform = fruit.visual.transform * fruit.visual.get_child(0).transform * original.transform
			piece.velocity = fruit.velocity * 0.3 + Vector3(rng.randf_range(-3.5,3.5),rng.randf_range(-1,3),rng.randf_range(-1,1))
			piece.spin = Vector3(rng.randf_range(-3,3),rng.randf_range(-3,3),rng.randf_range(-3,3))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and slicing:
		finish_stroke()

func _unhandled_input(event: InputEvent) -> void:
	if party_input == null or not party_input.is_pressed(&"fruit_slice"):
		if slicing:
			finish_stroke()
		return
	if event is InputEventMouseButton and event.pressed:
		begin_stroke(get_viewport().get_mouse_position())
	elif event is InputEventMouseMotion:
		if not slicing:
			begin_stroke(event.position)
		continue_stroke(event.position)

func _notification(_what: int) -> void:
	pass

func _sound(effect: String) -> void:
	if audio_players.is_empty():
		return
	var player: AudioStreamPlayer = audio_players[audio_index % audio_players.size()]
	audio_index += 1
	player.stream = load("res://games/minigame/godot_party_default_fruit_samurai/assets/audio/" + effect + ".wav")
	player.pitch_scale = rng.randf_range(0.9, 1.15) if effect == "slice" else 1.0
	player.volume_db = -7.0
	player.play()

func _touch_ui(point: Vector2) -> bool:
	if menu.visible:
		for name_value: Variant in ["Play", "Secondary", "ReducedMotion"]:
			var button: BaseButton = menu.get_node(name_value) as BaseButton
			if button.visible and button.get_global_rect().has_point(point):
				if button is CheckButton:
					button.button_pressed = not button.button_pressed
				else:
					button.pressed.emit()
				return true
		return true
	if hud.visible and hud.get_node("Pause").get_global_rect().has_point(point):
		pause_game()
		return true
	return false
