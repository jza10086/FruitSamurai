extends Node3D
## Fruit simulation and local presentation. The entry owns networking and round lifetime.
signal failed(code: String, message: String)
const Hud = preload("res://games/minigame/gp_fruit_samurai/scripts/hud_skin.gd")
const Effects = preload("res://games/minigame/gp_fruit_samurai/scripts/slice_effects.gd")
const DEFAULT_TEXT: Translation = preload("res://games/minigame/gp_fruit_samurai/i18n/zh_Hans.po")
@export var hud: Hud
@export var audio: PartyGameAudio
@export var slice_sound: PartyAudioCue
@export var miss_sound: PartyAudioCue
@export var bomb_sound: PartyAudioCue
@export var combo_sound: PartyAudioCue
@export var decor_spin: Vector3 = Vector3(0.06, 0.15, 0.04)
var translate: Callable
var party_input: PartyInput

const Fruit = preload("res://games/minigame/gp_fruit_samurai/scripts/fruit.gd")
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
var shake: float = 0.0
var hit_stop: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
@onready var camera: Camera3D = %Camera
@onready var fruits: Node3D = %Fruits
@onready var fragments: Node3D = %Fragments
@onready var fx: Effects = %FX
@export var menu: Control
@export var menu_play: Button
@export var reduced_motion_button: CheckButton
@export var title_label: Label
@export var subtitle_label: Label
@export var eyebrow: Label
@export var instructions: Label
@export var version_label: Label
@onready var decor: Node3D = %Decor
var simulation_active: bool = true

func _ready() -> void:
	assert(hud != null and audio != null, "Fruit Samurai requires HUD and scoped audio.")
	assert(menu != null and menu_play != null and reduced_motion_button != null, "Fruit Samurai requires its preview menu.")
	assert(title_label != null and subtitle_label != null and eyebrow != null and instructions != null and version_label != null, "Fruit Samurai requires its menu labels.")
	assert(slice_sound != null and miss_sound != null and bomb_sound != null and combo_sound != null, "Fruit Samurai requires its sound cues.")
	rng.randomize()
	menu_play.pressed.connect(_play_pressed)
	reduced_motion_button.toggled.connect(_set_reduced_motion)
	hud.pause_button.pressed.connect(pause_game)
	hud.apply_translation(_text)
	fx.translate = _text
	reduced_motion_button.set_pressed_no_signal(fx.reduced_motion)
	hud.pause_button.visible = party_input == null
	instructions.text = _text(&"preview.instructions")
	version_label.text = _text(&"preview.rules")
	reduced_motion_button.text = _text(&"减弱动态效果")
	_show_preview_menu(&"preview.title", &"preview.subtitle", &"preview.play")
	if party_input != null:
		menu.hide()
	_update_hud()

func _text(key: StringName, values: Dictionary = {}) -> String:
	if translate.is_valid():
		return translate.call(key, values)
	return String(DEFAULT_TEXT.get_message(key)).format(values)

func _set_reduced_motion(value: bool) -> void:
	fx.reduced_motion = value

func start_game() -> void:
	_clear_round()
	score = 0
	misses = 0
	elapsed = 0
	wave = 0
	spawn_timer = 0.45
	state = State.PLAYING
	simulation_active = true
	menu.hide()
	hud.show()
	decor.hide()
	fx.set_process(true)
	_update_hud()

func _clear_round() -> void:
	for container: Node3D in [fruits, fragments]:
		for child: Node3D in container.get_children():
			container.remove_child(child)
			child.queue_free()
	slicing = false
	stroke_hits = 0
	combo_window = 0.0
	hit_stop = 0
	shake = 0
	camera.position.x = 0
	camera.position.y = 0
	fx.clear_effects()
	audio.stop_all()

func _play_pressed() -> void:
	if state == State.PAUSED:
		resume_game()
	else:
		start_game()

func pause_game() -> void:
	finish_stroke()
	if party_input != null or state != State.PLAYING:
		return
	state = State.PAUSED
	fx.set_process(false)
	audio.set_gameplay_paused(true)
	_show_preview_menu(&"preview.paused", &"preview.pause_hint", &"preview.resume")

func resume_game() -> void:
	state = State.PLAYING
	menu.hide()
	fx.set_process(true)
	audio.set_gameplay_paused(false)

func end_game(reason: StringName) -> void:
	if state != State.PLAYING:
		return
	finish_stroke()
	state = State.OVER
	best = maxi(best, score)
	title_label.text = _text(&"game.over")
	subtitle_label.text = _text(&"game.over_detail", {"reason": _text(reason), "score": score,
		"next": _text(&"game.waiting") if party_input != null else _text(&"preview.retry")})
	menu_play.text = _text(&"preview.retry")
	menu_play.visible = party_input == null
	reduced_motion_button.visible = party_input == null
	menu.show()
	hud.hide()
	decor.show()
	for child: Node3D in fruits.get_children():
		child.hide()

func _show_preview_menu(title: StringName, subtitle: StringName, button: StringName) -> void:
	title_label.text = _text(title)
	subtitle_label.text = _text(subtitle)
	menu_play.text = _text(button)
	eyebrow.text = _text(&"preview.eyebrow")
	menu.show()

func _update_hud() -> void:
	hud.update_values(score, best, misses)

## Freeze local play without stopping the entry's coordination messages.
## Settle a final stroke before reporting, but never award a cancelled stroke.
func stop_gameplay(settle_stroke: bool = false) -> void:
	if settle_stroke:
		finish_stroke()
	else:
		slicing = false
		stroke_hits = 0
		combo_window = 0.0
		fx.end_blade()
	simulation_active = false
	fx.clear_effects()
	fx.set_process(false)
	audio.stop_all()

func _process(delta: float) -> void:
	if not simulation_active:
		return
	if slicing and not _slice_pressed():
		finish_stroke()
		if not simulation_active:
			return
	var dt: float = minf(delta, 0.033)
	for decoration: Node3D in decor.get_children():
		if not fx.reduced_motion:
			decoration.rotation += decor_spin * dt
	if state != State.PLAYING:
		return
	if hit_stop > 0:
		hit_stop -= dt
		return
	if stroke_hits > 0:
		combo_window -= dt
		if combo_window <= 0:
			_settle_combo()
			if not simulation_active:
				return
	elapsed += dt
	shake = maxf(0, shake - dt * 4)
	camera.position.x = rng.randf_range(-shake, shake) * 0.12 if not fx.reduced_motion else 0.0
	camera.position.y = rng.randf_range(-shake, shake) * 0.09 if not fx.reduced_motion else 0.0
	spawn_timer -= dt
	if spawn_timer <= 0:
		_spawn_wave()
		spawn_timer = maxf(1.3, 2.1 - elapsed * 0.006)
	for fruit: Fruit in fruits.get_children():
		fruit.step(dt)
		if fruit.position.y < -7.6 and fruit.velocity.y < 0:
			if not fruit.cut and fruit.kind != 4:
				misses += 1
				if _sound(miss_sound) != OK:
					return
				_update_hud()
				if misses >= 3:
					end_game(&"game.missed")
			fruit.cut = true
			fruit.queue_free()
			if state != State.PLAYING:
				break
	for piece: Fruit in fragments.get_children():
		piece.step(dt)
		if piece.position.y < -9 or piece.age > 3:
			piece.queue_free()

func _spawn_wave() -> void:
	wave += 1
	var count: int = mini(5, 2 + int(elapsed / 22.0))
	var center: float = rng.randf_range(-3.8, 3.8)
	for i: int in range(count):
		spawn_fruit(rng.randi_range(0, 3), Vector3(center + (float(i) - float(count - 1) * 0.5) * 1.65, -6.6 - rng.randf_range(0, 0.4), rng.randf_range(-0.4, 0.4)))
	if wave > 2 and rng.randf() < 0.52:
		spawn_fruit(4, Vector3(rng.randf_range(-6.5,6.5), -7.1, 0.4))

func spawn_fruit(kind: int, at: Vector3) -> Fruit:
	var fruit: Fruit = Fruit.new()
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
	if not simulation_active or state != State.PLAYING or not _slice_pressed():
		return
	slicing = true
	last_point = point
	stroke_last = point
	stroke_hits = 0
	fx.add_blade_point(point)

func continue_stroke(point: Vector2) -> void:
	if not simulation_active or not slicing or state != State.PLAYING or not _slice_pressed():
		return
	fx.add_blade_point(point)
	if point.distance_squared_to(last_point) < 4:
		return
	var direction: Vector2 = (point - last_point).normalized()
	for fruit: Fruit in fruits.get_children():
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
		if _sound(combo_sound) != OK:
			return
		_update_hud()
	stroke_hits = 0
	combo_window = 0

func finish_stroke() -> void:
	_settle_combo()
	slicing = false
	fx.end_blade()

func cut_fruit(fruit: Fruit, point: Vector2, direction: Vector2) -> void:
	if fruit.cut or state != State.PLAYING:
		return
	fruit.cut = true
	if _sound(bomb_sound if fruit.kind == 4 else slice_sound, fruit.kind != 4) != OK:
		return
	fx.burst(point, fruit.juice_color(), direction, fruit.kind == 4)
	shake = 1.0 if fruit.kind == 4 else 0.2
	hit_stop = 0.045 if not fx.reduced_motion else 0.0
	if fruit.kind == 4:
		fruit.queue_free()
		end_game(&"game.bomb")
		return
	score += 10
	stroke_hits += 1
	combo_window = 0.30
	stroke_last = point
	_update_hud()
	_split(fruit, direction)
	fruit.queue_free()

func _split(fruit: Fruit, direction: Vector2) -> void:
	var normal: Vector3 = Vector3(-direction.y, -direction.x, 0).normalized()
	var angle: float = atan2(normal.y, normal.x)
	if fruit.kind < 3:
		for side: int in range(2):
			var piece: Fruit = Fruit.new()
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
		for original: Node in fruit.visual.get_child(0).get_children():
			if not original is MeshInstance3D:
				continue
			var piece: Fruit = Fruit.new()
			fragments.add_child(piece)
			piece.kind = 3
			piece.fragment = true
			piece.transform = fruit.transform
			var mesh: MeshInstance3D = original.duplicate() as MeshInstance3D
			piece.add_child(mesh)
			mesh.transform = fruit.visual.transform * fruit.visual.get_child(0).transform * original.transform
			piece.velocity = fruit.velocity * 0.3 + Vector3(rng.randf_range(-3.5,3.5),rng.randf_range(-1,3),rng.randf_range(-1,1))
			piece.spin = Vector3(rng.randf_range(-3,3),rng.randf_range(-3,3),rng.randf_range(-3,3))

func _slice_pressed() -> bool:
	if party_input != null:
		return party_input.is_pressed(&"fruit_slice")
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func _input(_event: InputEvent) -> void:
	if slicing and not _slice_pressed():
		finish_stroke()

func _unhandled_input(event: InputEvent) -> void:
	# F6 has a local preview boundary; formal play only reads the scoped action.
	if party_input == null and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if state == State.PAUSED:
			resume_game()
		else:
			pause_game()
		get_viewport().set_input_as_handled()
		return
	if not simulation_active or not _slice_pressed():
		return
	if event is InputEventMouseButton and event.pressed:
		begin_stroke(get_viewport().get_mouse_position())
	elif event is InputEventMouseMotion:
		if not slicing:
			begin_stroke(event.position)
		continue_stroke(event.position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and slicing:
		finish_stroke()

func _sound(authored_cue: PartyAudioCue, vary_pitch: bool = false) -> Error:
	var cue: PartyAudioCue = authored_cue
	if vary_pitch:
		# Per-play pitch must not mutate the shared authored cue.
		cue = authored_cue.duplicate()
		cue.pitch_scale = rng.randf_range(0.9, 1.15)
	var handle: PartyAudioHandle = audio.play_sfx(cue)
	if handle.error != OK:
		stop_gameplay()
		failed.emit("audio_failed", error_string(handle.error))

	return handle.error
