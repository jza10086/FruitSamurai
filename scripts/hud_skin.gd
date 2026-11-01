extends Control
## Runtime skins reuse the same score/lives/pause nodes and input contract.
## Only Pause consumes input; decorative textures never obscure swipe routing.
const STYLES: Array = ["wenrexa5", "mobile", "hypercasual", "original"]
var style_id: String = "original"
var accent: Color = Color("dfb568")
var ink: Color = Color("f5e9c9")
var muted: Color = Color("c9b58d")
var current_misses: int = 0
var decorations: Control
var asset_paths: Array[String] = []
var life_icons: Array[TextureRect] = []

func configure(requested: String = "original") -> void:
	style_id = requested if requested in STYLES else "original"
	if is_instance_valid(decorations):
		remove_child(decorations)
		decorations.queue_free()
	decorations = Control.new()
	decorations.name = "SkinDecorations"
	decorations.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(decorations)
	move_child(decorations, 0)
	asset_paths.clear()
	life_icons.clear()
	accent = Color("dfb568")
	ink = Color("312d27")
	muted = Color("5d4b31")
	match style_id:
		"wenrexa5":
			accent = Color("ffd480")
			ink = Color("fff4dc")
			muted = Color("e7cea8")
		"mobile":
			accent = Color("93e3ea")
			ink = Color("efffff")
			muted = Color("b5e2e4")
		"hypercasual":
			accent = Color("ffe481")
			ink = Color("ffffff")
			muted = Color("d4eaff")
	_layout_label("ScoreCaption", Rect2(66, 36, 90, 28), 18, muted)
	_layout_label("Score", Rect2(62, 55, 222, 64), 48, ink)
	_layout_label("Best", Rect2(286, 81, 216, 30), 19, muted)
	_layout_label("Lives", Rect2(1208, 64, 172, 44), 30, accent)
	$Lives.hide() # Individual marks replace a spacing-sensitive text row.
	var caption: Label = Label.new()
	caption.name = "MissCaption"
	caption.text = "漏果"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	decorations.add_child(caption)
	caption.position = Vector2(1207, 38)
	caption.size = Vector2(160, 25)
	caption.add_theme_font_size_override("font_size", 17)
	caption.add_theme_color_override("font_color", Color("c9b58d") if style_id == "original" else muted)
	$Pause.position = Vector2(1440, 40)
	$Pause.size = Vector2(104, 72)
	$Pause.text = "暂停"
	$Pause.add_theme_font_size_override("font_size", 19)
	for mode: Variant in ["normal", "hover", "pressed", "focus"]:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Color("843c32") if mode == "normal" else Color("a65142")
		box.border_color = accent
		box.set_border_width_all(1 if mode == "normal" else 2)
		box.set_corner_radius_all(5)
		$Pause.add_theme_stylebox_override(mode, box)
	for mode: Variant in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		$Pause.add_theme_color_override(mode, Color("f5e9c9") if style_id == "original" else ink)
	if style_id == "original":
		_layout_label("ScoreCaption", Rect2(56,35,108,27), 17, muted)
		_layout_label("Score", Rect2(53,58,190,64), 48, ink)
		_layout_label("Best", Rect2(49,138,230,29), 17, Color("d2bd94"))
	_add_pack_art()
	_update_life_icons()
	queue_redraw()

func _layout_label(node_name: String, rect: Rect2, font_size: int, color: Color) -> void:
	var label: Label = get_node(node_name)
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func update_values(score: int, best: int, misses: int) -> void:
	$Score.text = "%03d" % score
	var score_font_size: int = 48 if style_id in ["original", "wenrexa5"] else (40 if style_id == "mobile" else 43)
	var score_font: Font = $Score.get_theme_font("font")
	while score_font_size > 18 and score_font.get_string_size($Score.text, HORIZONTAL_ALIGNMENT_LEFT, -1, score_font_size).x > $Score.size.x:
		score_font_size -= 1
	$Score.add_theme_font_size_override("font_size", score_font_size)
	$Best.text = "最高  %d" % maxi(best, score)
	current_misses = clampi(misses, 0, 3)
	_update_life_icons()
	queue_redraw()

func _add_pack_art() -> void:
	if style_id == "original":
		return
	var base: Variant = "res://games/minigame/godot_party_default_fruit_samurai/assets/ui/" + style_id + "/"
	if style_id == "wenrexa5":
		_panel(base + "score.png", Rect2(36,27,477,108), 12)
		_pause_texture(base + "pause.png", 10)
		$Pause.text = "Ⅱ"
		$Pause.add_theme_font_size_override("font_size", 32)
	elif style_id == "mobile":
		_panel(base + "score.png", Rect2(36,26,484,115), 23)
		_layout_label("ScoreCaption", Rect2(67,38,120,26), 16, Color("183f4b"))
		_layout_label("Score", Rect2(65,62,216,59), 40, ink)
		_layout_label("Best", Rect2(284,82,215,30), 18, muted)
		_pause_texture(base + "pause.png", 0)
		$Pause.text = ""
		$Pause.size = Vector2(91,79)
	else:
		_panel(base + "score.png", Rect2(39,30,217,104), 22)
		_panel(base + "best.png", Rect2(274,55,225,64), 18)
		_texture(base + "trophy.png", Rect2(289,73,30,30), Color("725321"))
		_layout_label("ScoreCaption", Rect2(62,35,130,27), 17, Color("e9faff"))
		_layout_label("Score", Rect2(60,60,180,60), 43, ink)
		_layout_label("Best", Rect2(328,70,158,32), 18, Color("503d1b"))
		_pause_texture(base + "pause_bg.png", 16)
		$Pause.text = ""
		var pause_icon: Variant = _texture(base + "pause.png", Rect2(1478,60,28,34))
		pause_icon.z_index = 1
	$Pause.tooltip_text = "暂停"
	for i: Variant in range(3):
		var icon: Variant = _texture(base + "life.png", Rect2(1201+i*52,72,38,38))
		life_icons.append(icon)
	# Make texture-based controls distinct but keep their entire hit rectangle clickable.

func _update_life_icons() -> void:
	for i: Variant in range(life_icons.size()):
		var path: Variant = "res://games/minigame/godot_party_default_fruit_samurai/assets/ui/" + style_id + ("/miss.png" if i < current_misses else "/life.png")
		life_icons[i].texture = load(path) as Texture2D
		life_icons[i].modulate = Color("ed7468") if i < current_misses else accent
		if style_id != "hypercasual":
			life_icons[i].modulate = Color.WHITE

func _panel(path: String, rect: Rect2, margin: int) -> void:
	var panel: NinePatchRect = NinePatchRect.new()
	panel.texture = load(path) as Texture2D
	panel.position = rect.position
	panel.size = rect.size
	panel.patch_margin_left = margin
	panel.patch_margin_right = margin
	panel.patch_margin_top = margin
	panel.patch_margin_bottom = margin
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	decorations.add_child(panel)
	decorations.move_child(panel, 0)
	asset_paths.append(path)

func _pause_texture(path: String, margin: int) -> void:
	asset_paths.append(path)
	for mode: Variant in ["normal", "hover", "pressed", "focus"]:
		var box: StyleBoxTexture = StyleBoxTexture.new()
		box.texture = load(path) as Texture2D
		for side: Variant in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			box.set_texture_margin(side, margin)
		box.modulate_color = Color.WHITE if mode == "normal" else (Color("b6cbd4") if mode == "pressed" else Color("fff3d2"))
		$Pause.add_theme_stylebox_override(mode, box)

func _texture(path: String, rect: Rect2, tint: Color = Color.WHITE) -> TextureRect:
	var image: TextureRect = TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.texture = load(path) as Texture2D
	image.position = rect.position
	image.size = rect.size
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.modulate = tint
	decorations.add_child(image)
	asset_paths.append(path)
	return image

func _draw() -> void:
	if style_id == "original":
		# Irregular ink wash, fine gilt edge and vermilion seal. No raster dependency.
		var poly: Variant = PackedVector2Array([Vector2(39,27),Vector2(243,29),Vector2(258,40),Vector2(250,126),Vector2(159,130),Vector2(37,126),Vector2(31,72)])
		draw_colored_polygon(poly, Color("e9d9b6f5"))
		draw_line(Vector2(48,28), Vector2(242,30), Color("d1ac64"), 1.5, true)
		draw_line(Vector2(47,126),Vector2(244,125),Color("bba16d"),2,true)
		for i: Variant in range(6):
			draw_line(Vector2(32+i*2,37), Vector2(28+i*2,119), Color(0.16,0.13,0.1,0.17), 2, true)
		for i: Variant in range(8):
			draw_line(Vector2(42+i*21,43+i%3*19),Vector2(65+i*20,42+i%3*19),Color(0.5,0.36,0.17,0.07),1,true)
		draw_rect(Rect2(198,40,30,27), Color("973f36"))
		var font: Font = load("res://games/minigame/godot_party_default_fruit_samurai/assets/Chinese.ttc") as Font
		draw_string(font, Vector2(204,61), "斩", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f3ddad"))
		draw_line(Vector2(1188,35),Vector2(1188,109),Color("846c45"),1,true)
	elif style_id == "wenrexa5":
		draw_line(Vector2(278,55),Vector2(278,112),Color("d1a56c80"),1,true)
	if style_id != "original":
		return
	# Consistent life semantics in every skin: one red crossed mark per missed fruit.
	for i: Variant in range(3):
		var p: Vector2 = Vector2(1220 + i * 52, 91)
		var lost: bool = i < current_misses
		var c: Color = Color("ed7468") if lost else accent
		if style_id == "original":
			var diamond: Variant = PackedVector2Array([p+Vector2(0,-11),p+Vector2(11,0),p+Vector2(0,11),p+Vector2(-11,0)])
			draw_colored_polygon(diamond, Color("493b2c") if lost else Color("af8c4c"))
			draw_polyline(PackedVector2Array([diamond[0],diamond[1],diamond[2],diamond[3],diamond[0]]),c,1.5,true)
		else:
			draw_circle(p, 12, Color(c,0.15) if lost else Color(c,0.22))
			draw_arc(p,12,0,TAU,32,c,2,true)
			if not lost:
				draw_circle(p,6,c)
		if lost:
			draw_line(p-Vector2(6,6),p+Vector2(6,6),c,2.5,true)
			draw_line(p+Vector2(-6,6),p+Vector2(6,-6),c,2.5,true)
