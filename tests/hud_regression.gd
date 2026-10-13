extends SceneTree
## Additional HUD skin coverage. The original gameplay regression suite is unchanged.
## Run with an isolated HOME/XDG tree, as in tests/run_regression.sh.

const Game = preload("res://scripts/main.gd")
const STYLES := ["original", "wenrexa5", "mobile", "hypercasual"]
const RESOLUTIONS := [Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1920, 1080)]
const LEGACY_NODES := ["ScoreCaption", "Score", "Best", "Lives", "Pause"]

var game: Node3D
var checks := 0
var failures := 0
var original_node_ids: Dictionary = {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func fresh() -> void:
	game.start_game()
	game.set_process(false)
	game.fx.set_process(false)
	game.spawn_timer = 100.0
	game.rng.seed = 42

func descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(descendants(child))
	return result

func send_mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = point
	event.global_position = point
	event.pressed = pressed
	# Exercise _input -> actual GUI routing -> _unhandled_input, rather than
	# manually invoking a button signal or the unhandled input handler.
	root.push_input(event, true)

func send_touch(point: Vector2, pressed: bool, finger: int = 2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = point
	event.pressed = pressed
	root.push_input(event, true)

func check_label_fits(label: Label, prefix: String) -> void:
	var font := label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var text_size := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	check(text_size.x <= label.size.x + 0.5, "%s %s text fits without clipping: %s" % [prefix, label.name, label.text])

func check_assets(style: String) -> void:
	if style == "original":
		check(game.hud.asset_paths.is_empty(), "original HUD has no borrowed raster assets")
		return
	check(not game.hud.asset_paths.is_empty(), "%s declares original pack image paths" % style)
	for path in game.hud.asset_paths:
		check(path.begins_with("res://assets/"), "%s pack path is project-local: %s" % [style, path])
		check(ResourceLoader.exists(path) and load(path) is Texture2D, "%s image imports: %s" % [style, path])
	var textures := 0
	for node in descendants(game.hud.decorations):
		if node is TextureRect or node is NinePatchRect:
			textures += 1
			check(node.texture != null and node.texture.get_width() > 0 and node.texture.get_height() > 0, "%s decoration has nonempty texture" % style)
			check(node.texture.resource_path in game.hud.asset_paths, "%s rendered decoration appears in asset list" % style)
	var pause: Button = game.hud.get_node("Pause")
	for mode in ["normal", "hover", "pressed", "focus"]:
		var box := pause.get_theme_stylebox(mode)
		check(box is StyleBoxTexture and box.texture != null, "%s Pause %s uses pack artwork" % [style, mode])
		if box is StyleBoxTexture and box.texture != null:
			check(box.texture.resource_path in game.hud.asset_paths, "%s Pause %s texture appears in asset list" % [style, mode])
	check(textures + 1 == game.hud.asset_paths.size(), "%s every declared asset is a rendered panel, icon or Pause background" % style)
	check(game.hud.life_icons.size() == 3, "%s has three independently updated life icons" % style)
	check(ResourceLoader.exists("res://assets/ui/%s/miss.png" % style), "%s alternate missed-fruit texture imports" % style)

func check_structure(style: String) -> void:
	check(game.hud.style_id == style, "%s selected" % style)
	check(game.hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s HUD root passes pointer input" % style)
	check(not game.hud.get_node("Lives").visible, "%s legacy Lives row remains hidden" % style)
	var pause := game.hud.get_node("Pause") as Button
	check(pause.visible and not pause.disabled and pause.mouse_filter == Control.MOUSE_FILTER_STOP, "%s Pause is the sole active HUD control" % style)
	for node_name in LEGACY_NODES:
		check(game.hud.get_node(node_name).get_instance_id() == original_node_ids[node_name], "%s retains %s node identity" % [style, node_name])
	var consumers: Array[String] = []
	for node in descendants(game.hud):
		if node is Control and node.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			consumers.append(String(node.name))
	check(consumers == ["Pause"], "%s all labels and pack decorations ignore mouse input" % style)
	check(game.hud.get_child_count() == LEGACY_NODES.size() + 1, "%s has exactly one decoration tree and five legacy controls" % style)
	check(game.hud.get_child(0) == game.hud.decorations, "%s decorative textures sit behind labels and Pause" % style)

func check_layout(style: String, resolution: Vector2i) -> void:
	var transform := root.get_final_transform()
	var physical := Rect2(Vector2.ZERO, Vector2(resolution))
	var prefix := "%s at %s" % [style, resolution]
	for node in descendants(game.hud):
		if node is Control and node.is_visible_in_tree() and node.size.x > 0 and node.size.y > 0:
			var rect: Rect2 = transform * node.get_global_rect()
			check(physical.encloses(rect), "%s %s remains within physical viewport: %s" % [prefix, node.name, rect])
	var score_rect: Rect2 = game.hud.get_node("Score").get_global_rect()
	var best_rect: Rect2 = game.hud.get_node("Best").get_global_rect()
	var pause_rect: Rect2 = game.hud.get_node("Pause").get_global_rect()
	check(not score_rect.intersects(best_rect), "%s score and best have separate bounds" % prefix)
	check(not score_rect.intersects(pause_rect) and not best_rect.intersects(pause_rect), "%s Pause does not overlap score labels" % prefix)
	var physical_pause := transform * pause_rect
	check(physical_pause.size.x >= 44.0 and physical_pause.size.y >= 44.0, "%s Pause retains a 44px minimum target" % prefix)
	check_label_fits(game.hud.get_node("Score"), prefix)
	check_label_fits(game.hud.get_node("Best"), prefix)

func check_values(style: String) -> void:
	for value in [0, 1, 42, 245, 99999, 100000, 999999, 123456789]:
		game.score = value
		game.best = 980
		game._update_hud()
		check(game.hud.get_node("Score").text == "%03d" % value, "%s updates score %d" % [style, value])
		check(game.hud.get_node("Best").text == "最高  %d" % maxi(value, 980), "%s displays maximum of saved best and current score %d" % [style, value])
		check(game.score == value and game.best == 980, "%s HUD rendering does not mutate gameplay scores %d" % [style, value])
		check_label_fits(game.hud.get_node("Score"), style)
		check_label_fits(game.hud.get_node("Best"), style)
	for missed in range(4):
		game.misses = missed
		game._update_hud()
		check(game.hud.current_misses == missed, "%s renders %d missed-fruit marks" % [style, missed])
		check(game.misses == missed, "%s HUD does not mutate misses %d" % [style, missed])
		if style != "original":
			for index in range(game.hud.life_icons.size()):
				var icon: TextureRect = game.hud.life_icons[index]
				var expected := "res://assets/ui/%s/%s.png" % [style, "miss" if index < missed else "life"]
				check(icon.texture != null and icon.texture.resource_path == expected, "%s misses=%d icon %d has correct artwork" % [style, missed, index])
	game.hud.update_values(0, 0, -4)
	check(game.hud.current_misses == 0, "%s clamps negative display misses" % style)
	game.hud.update_values(0, 0, 9)
	check(game.hud.current_misses == 3, "%s clamps display misses to three" % style)
	game.score = 245
	game.best = 980
	game.misses = 1
	game._update_hud()

func check_interactions(style: String) -> void:
	fresh()
	game.score = 245
	game.best = 980
	game.misses = 1
	game._update_hud()
	game.hud.get_node("Pause").pressed.emit()
	check(game.state == Game.State.PAUSED and game.menu.visible and not game.slicing, "%s Pause signal opens pause menu" % style)
	game.menu.get_node("Play").pressed.emit()
	game.fx.set_process(false)
	check(game.state == Game.State.PLAYING and not game.menu.visible and game.score == 245 and game.misses == 1, "%s Continue signal keeps round values" % style)
	game.pause_game()
	game.menu.get_node("Secondary").pressed.emit()
	game.fx.set_process(false)
	check(game.state == Game.State.PLAYING and game.score == 0 and game.misses == 0 and game.hud.current_misses == 0, "%s Restart signal resets HUD and game values" % style)
	check(game.hud.get_node("Score").text == "000" and game.hud.get_node("Best").text == "最高  980", "%s restart refreshes text and preserves best" % style)

	fresh()
	var pause_point: Vector2 = game.hud.get_node("Pause").get_global_rect().get_center()
	send_touch(pause_point, true)
	check(game.state == Game.State.PAUSED and not game.slicing and game.touch_id == -1, "%s routed touch Pause never starts a blade" % style)
	send_touch(pause_point, false)
	var play_point: Vector2 = game.menu.get_node("Play").get_global_rect().get_center()
	send_touch(play_point, true)
	check(game.state == Game.State.PLAYING and not game.slicing, "%s routed touch Continue resumes" % style)
	send_touch(play_point, false)
	game.fx.set_process(false)
	game.score = 77
	game.misses = 2
	game._update_hud()
	game.pause_game()
	var restart_point: Vector2 = game.menu.get_node("Secondary").get_global_rect().get_center()
	send_touch(restart_point, true)
	check(game.state == Game.State.PLAYING and game.score == 0 and game.misses == 0 and not game.slicing, "%s routed touch Restart resets without cutting" % style)
	send_touch(restart_point, false)
	game.fx.set_process(false)

	fresh()
	send_mouse(pause_point, true)
	check(not game.slicing, "%s GUI consumes mouse-down on Pause" % style)
	send_mouse(pause_point, false)
	check(game.state == Game.State.PAUSED and not game.slicing, "%s routed mouse Pause opens menu" % style)
	send_mouse(play_point, true)
	send_mouse(play_point, false)
	game.fx.set_process(false)
	check(game.state == Game.State.PLAYING and not game.menu.visible and not game.slicing, "%s routed mouse Continue resumes without cutting" % style)
	game.score = 77
	game.misses = 2
	game._update_hud()
	send_mouse(pause_point, true)
	send_mouse(pause_point, false)
	send_mouse(restart_point, true)
	send_mouse(restart_point, false)
	game.fx.set_process(false)
	check(game.state == Game.State.PLAYING and game.score == 0 and game.misses == 0 and not game.slicing, "%s routed mouse Restart resets without cutting" % style)

	# Both the open playfield and decoration-covered HUD areas must pass input.
	for point in [Vector2(800, 450), Vector2(120, 90), Vector2(1272, 91)]:
		fresh()
		check(not game._touch_ui(point), "%s point %s is not classified as a UI button" % [style, point])
		send_mouse(point, true)
		check(game.slicing and game.last_point == point and game.state == Game.State.PLAYING, "%s mouse reaches playfield through point %s" % [style, point])
		send_mouse(point, false)
		check(not game.slicing, "%s mouse release clears stroke at %s" % [style, point])
		send_touch(point, true)
		check(game.slicing and game.touch_id == 2 and game.last_point == point, "%s touch reaches playfield through point %s" % [style, point])
		send_touch(point, false)
		check(not game.slicing and game.touch_id == -1, "%s touch release clears stroke at %s" % [style, point])

func run() -> void:
	root.size = Vector2i(1600, 900)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.fx.set_process(false)
	await process_frame
	for node_name in LEGACY_NODES:
		original_node_ids[node_name] = game.hud.get_node(node_name).get_instance_id()
	for style in STYLES:
		fresh()
		var previous_decorations: Control = game.hud.decorations
		game.hud.configure(style)
		game._update_hud()
		await process_frame
		check(not is_instance_valid(previous_decorations), "%s switching skins frees the previous decoration tree" % style)
		check_structure(style)
		check_assets(style)
		var decoration_count: int = descendants(game.hud.decorations).size()
		for iteration in range(3):
			var old_decorations: Control = game.hud.decorations
			game.hud.configure(style)
			game._update_hud()
			await process_frame
			check(not is_instance_valid(old_decorations), "%s reconfigure %d frees old decorations" % [style, iteration])
			check(game.hud.get_child_count() == LEGACY_NODES.size() + 1 and descendants(game.hud.decorations).size() == decoration_count, "%s reconfigure %d does not duplicate nodes" % [style, iteration])
		check_values(style)
		for resolution in RESOLUTIONS:
			root.size = resolution
			await process_frame
			check_layout(style, resolution)
		root.size = Vector2i(1600, 900)
		await process_frame
		check_interactions(style)
	game.hud.configure("unknown-skin")
	check(game.hud.style_id == "original" and game.hud.asset_paths.is_empty(), "unknown style safely falls back to the original HUD")
	game._clear_round()
	await create_timer(0.15).timeout
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("HUD REGRESSION RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
