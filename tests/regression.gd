extends SceneTree

const Game = preload("res://scripts/main.gd")
var game: Node3D
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)

func _initialize() -> void:
	call_deferred("run")

func fresh() -> void:
	game.start_game()
	game.fx.set_process(false)
	game.rng.seed = 42
	game.spawn_timer = 100

func run() -> void:
	root.size = Vector2i(1600, 900)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.fx.reduced_motion = false
	game.fx.set_process(false)
	await process_frame
	check(game.state == Game.State.MENU and game.menu.visible and not game.hud.visible, "initial menu")
	check(game.get_node("Decor").get_child_count() == 4, "four imported decorative models")
	check(Game.segment_hits_circle(Vector2(-1000,-1000), Vector2(1000,1000), Vector2.ZERO, 1), "fast diagonal swept hit")
	check(not Game.segment_hits_circle(Vector2(-1000,-1000), Vector2(1000,1000), Vector2(0,30), 1), "diagonal miss")
	check(Game.segment_hits_circle(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, 1), "degenerate inside")
	check(not Game.segment_hits_circle(Vector2.ZERO, Vector2.ZERO, Vector2(3,0), 1), "degenerate outside")
	check(Game.segment_hits_circle(Vector2(-10,1), Vector2(10,1), Vector2.ZERO, 1), "tangent collision")
	game.menu.get_node("Play").pressed.emit()
	check(game.state == Game.State.PLAYING and not game.menu.visible and game.hud.visible, "play button starts")
	fresh()
	var fruit = game.spawn_fruit(0, Vector3.ZERO)
	var center: Vector2 = game.camera.unproject_position(fruit.global_position)
	game.begin_stroke(center - Vector2(500,500))
	game.continue_stroke(center + Vector2(500,500))
	check(game.score == 10 and fruit.cut, "actual projected fast diagonal scores")
	game.continue_stroke(center - Vector2(500,500))
	game.cut_fruit(fruit, center, Vector2.RIGHT)
	check(game.score == 10, "repeat crossing and explicit repeated cut no double score")
	check(game.fragments.get_child_count() == 2, "apple creates two authored halves")
	game.finish_stroke()
	check(game.score == 10, "one fruit no combo")
	fresh()
	game.begin_stroke(Vector2.ZERO)
	for kind in range(3):
		var f = game.spawn_fruit(kind, Vector3.ZERO)
		game.cut_fruit(f, Vector2(800,450), Vector2.RIGHT)
	check(game.score == 30, "three fruits base payout")
	game.finish_stroke()
	check(game.score == 45 and game.fx._combos.size() == 1, "three fruit combo plus fifteen")
	game.finish_stroke()
	check(game.score == 45, "combo paid once")
	fresh()
	game.begin_stroke(Vector2.ZERO)
	for i in range(3):
		game.cut_fruit(game.spawn_fruit(0, Vector3.ZERO), Vector2.ZERO, Vector2.RIGHT)
	game.hit_stop = 0
	for i in range(12):
		game._process(0.033)
	check(game.score == 45 and game.stroke_hits == 0 and game.slicing, "idle held stroke settles combo without release")
	for i in range(2):
		game.cut_fruit(game.spawn_fruit(1, Vector3.ZERO), Vector2.ZERO, Vector2.RIGHT)
	game.finish_stroke()
	check(game.score == 65, "held stroke cannot combine separated waves")
	fresh()
	var melon = game.spawn_fruit(3, Vector3.ZERO)
	game.cut_fruit(melon, Vector2.ZERO, Vector2.RIGHT)
	check(game.fragments.get_child_count() == 8, "melon creates eight imported wedges")
	fresh()
	var bomb = game.spawn_fruit(4, Vector3.ZERO)
	game.begin_stroke(Vector2.ZERO)
	game.cut_fruit(bomb, Vector2(800,450), Vector2.RIGHT)
	check(game.state == Game.State.OVER and game.score == 0 and game.menu.visible and not game.hud.visible, "bomb ends round without scoring")
	game.cut_fruit(game.spawn_fruit(0, Vector3.ZERO), Vector2.ZERO, Vector2.RIGHT)
	check(game.score == 0, "no scoring after end")
	fresh()
	var falling_bomb = game.spawn_fruit(4, Vector3(0,-8,0))
	falling_bomb.velocity = Vector3(0,-1,0)
	game._process(0.016)
	check(game.misses == 0 and game.state == Game.State.PLAYING, "missed bomb does not cost life")
	for i in range(3):
		var falling = game.spawn_fruit(0, Vector3(0,-8,0))
		falling.velocity = Vector3(0,-1,0)
		game._process(0.016)
	check(game.misses == 3 and game.state == Game.State.OVER, "third missed fruit ends round")
	fresh()
	var piece_source = game.spawn_fruit(0, Vector3(-3,0,0))
	game.cut_fruit(piece_source, Vector2.ZERO, Vector2.RIGHT)
	game.hit_stop = 0
	var paused_piece = game.fragments.get_child(0)
	var piece_pos: Vector3 = paused_piece.position
	var paused_fruit = game.spawn_fruit(1, Vector3.ZERO)
	game.fx.burst(Vector2.ZERO, Color.RED, Vector2.RIGHT)
	game.hud.get_node("Pause").pressed.emit()
	var pos: Vector3 = paused_fruit.position
	var timer: float = game.spawn_timer
	var elapsed: float = game.elapsed
	for i in range(100):
		game._process(0.033)
	check(game.state == Game.State.PAUSED and game.menu.visible, "pause button opens pause menu")
	check(paused_piece.position == piece_pos, "pause freezes cut fragments")
	check(paused_fruit.position == pos and game.spawn_timer == timer and game.elapsed == elapsed and not game.fx.is_processing(), "pause freezes fruit spawn time and effects")
	game.menu.get_node("Play").pressed.emit()
	game.fx.set_process(false)
	game._process(20)
	check(game.state == Game.State.PLAYING and is_equal_approx(game.elapsed - elapsed, 0.033), "continue resumes with clamped large delta")
	game.pause_game()
	game.menu.get_node("Secondary").pressed.emit()
	game.fx.set_process(false)
	check(game.state == Game.State.PLAYING and game.score == 0 and game.misses == 0 and game.fruits.get_child_count() == 0 and game.fragments.get_child_count() == 0 and game.fx._droplets.is_empty(), "new round clears entities counters and effects")
	fresh()
	var ui_touch := InputEventScreenTouch.new()
	ui_touch.index = 1
	ui_touch.pressed = true
	ui_touch.position = game.hud.get_node("Pause").get_global_rect().get_center()
	game._input(ui_touch)
	check(game.state == Game.State.PAUSED and not game.slicing and game.touch_id == -1, "touch pause button pauses without cutting")
	ui_touch.position = game.menu.get_node("Play").get_global_rect().get_center()
	game._input(ui_touch)
	check(game.state == Game.State.PLAYING and not game.slicing, "touch continue button resumes without cutting")
	game.fx.set_process(false)
	game.pause_game()
	ui_touch.position = game.menu.get_node("Secondary").get_global_rect().get_center()
	game._input(ui_touch)
	check(game.state == Game.State.PLAYING and game.score == 0 and not game.slicing, "touch new-round button restarts without cutting")
	fresh()
	var touch := InputEventScreenTouch.new()
	touch.index = 2
	touch.pressed = true
	touch.position = Vector2(200,200)
	game._input(touch)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = Vector2(900,900)
	game.stroke_hits = 2
	game._unhandled_input(mouse)
	check(game.touch_id == 2 and game.last_point == Vector2(200,200) and game.stroke_hits == 2, "synthetic mouse ignored during touch")
	var other := InputEventScreenTouch.new()
	other.index = 3
	other.pressed = true
	other.position = Vector2(600,600)
	game._input(other)
	check(game.touch_id == 2 and game.last_point == Vector2(200,200), "second finger does not steal stroke")
	touch.pressed = false
	game._input(touch)
	game._unhandled_input(mouse)
	check(not game.slicing and game.touch_id == -1, "post-touch synthetic mouse cooldown")
	game._process(0.033)
	for i in range(16):
		game._process(0.033)
	game._unhandled_input(mouse)
	check(game.slicing and game.last_point == mouse.position, "mouse works after touch cooldown")
	fresh()
	game.begin_stroke(Vector2.ZERO)
	for i in range(3):
		game.cut_fruit(game.spawn_fruit(0, Vector3.ZERO), Vector2.ZERO, Vector2.RIGHT)
	var release_over_ui := InputEventMouseButton.new()
	release_over_ui.button_index = MOUSE_BUTTON_LEFT
	release_over_ui.pressed = false
	release_over_ui.position = game.hud.get_node("Pause").get_global_rect().get_center()
	game._input(release_over_ui)
	check(not game.slicing and game.score == 45, "release over UI ends stroke before GUI consumption and pays combo")
	game._unhandled_input(release_over_ui)
	check(game.score == 45, "release handled twice cannot pay combo twice")
	fresh()
	var hover_fruit = game.spawn_fruit(0, Vector3.ZERO)
	var hover_center: Vector2 = game.camera.unproject_position(hover_fruit.global_position)
	game.begin_stroke(hover_center - Vector2(200,0))
	var motion := InputEventMouseMotion.new()
	motion.position = hover_center + Vector2(200,0)
	motion.button_mask = 0
	game._unhandled_input(motion)
	check(not game.slicing and not hover_fruit.cut and game.score == 0, "motion without held left button settles stale stroke without slicing")
	game._unhandled_input(motion)
	check(not hover_fruit.cut and game.score == 0, "hovering cannot start a slice")
	game.begin_stroke(hover_center - Vector2(200,0))
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	game._unhandled_input(motion)
	check(hover_fruit.cut and game.score == 10, "held left-button motion still cuts fruit")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._input(escape)
	check(game.state == Game.State.PAUSED, "escape pauses")
	game._input(escape)
	check(game.state == Game.State.PLAYING, "escape resumes")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.state == Game.State.PAUSED, "focus loss pauses")
	fresh()
	game._set_reduced_motion(true)
	game.cut_fruit(game.spawn_fruit(0, Vector3.ZERO), Vector2.ZERO, Vector2.RIGHT)
	check(game.hit_stop == 0 and game.fx._droplets.size() == 5, "reduced motion removes hit stop and reduces particles")
	game.score = 1234
	game.end_game("QA")
	var saved := ConfigFile.new()
	check(saved.load("user://progress.cfg") == OK and int(saved.get_value("game", "best", 0)) >= 1234 and saved.get_value("game", "reduced_motion", false), "best score and reduced motion persist")
	game.menu.get_node("Play").pressed.emit()
	check(game.state == Game.State.PLAYING and game.score == 0 and game.best >= 1234, "game-over replay resets score and keeps best")
	game.fx.set_process(false)
	game._set_reduced_motion(false)
	for effect in ["slice", "combo", "bomb", "miss"]:
		check(load("res://assets/audio/%s.wav" % effect) is AudioStreamWAV, "audio import " + effect)
	for filename in ["apple", "apple-half", "pear", "pear-half", "lemon", "lemon-half", "watermelon", "orange", "banana", "pineapple"]:
		var asset = load("res://assets/models/%s.glb" % filename)
		check(asset is PackedScene and asset.can_instantiate(), "asset import " + filename)
	check(load("res://assets/Display.ttf") is FontFile, "display font imports")
	var chinese_font: FontFile = load("res://assets/Chinese.ttc")
	check(chinese_font != null and chinese_font.has_char("水".unicode_at(0)), "Chinese font imports and includes CJK glyphs")
	for resolution in [Vector2i(1600,900), Vector2i(1280,720)]:
		root.size = resolution
		await process_frame
		var transform := root.get_final_transform()
		var physical := Rect2(Vector2.ZERO, Vector2(resolution))
		for path in ["Canvas/UI/Menu/Play", "Canvas/UI/Menu/Secondary", "Canvas/UI/Menu/ReducedMotion", "Canvas/UI/HUD/Pause"]:
			var control: Control = game.get_node(path)
			var rect := transform * control.get_global_rect()
			check(physical.encloses(rect), "%s fits %s" % [path, resolution])
	print("REGRESSION RESULT: %d checks, %d failures" % [checks, failures])
	game._clear_round()
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit(1 if failures else 0)
