extends Node2D
## Asset-free juice, slice trail and score callouts. Coordinates are local to this node.

var reduced_motion: bool = false

class BladePoint:
	var position: Vector2
	var age: float = 0.0
	var stroke: int
	func _init(at: Vector2, stroke_id: int) -> void:
		position = at
		stroke = stroke_id

class Droplet:
	var position: Vector2
	var velocity: Vector2
	var color: Color
	var radius: float
	var life: float
	var age: float = 0.0
	var spark: bool = false
	func _init(at: Vector2, speed: Vector2, tint: Color, size: float, duration: float, is_spark: bool) -> void:
		position = at
		velocity = speed
		color = tint
		radius = size
		life = duration
		spark = is_spark

class Ripple:
	var position: Vector2
	var color: Color
	var age: float = 0.0
	var life: float
	var radius: float
	var explosive: bool
	func _init(at: Vector2, tint: Color, size: float, duration: float, is_bomb: bool) -> void:
		position = at
		color = tint
		radius = size
		life = duration
		explosive = is_bomb

class ComboLabel:
	var position: Vector2
	var count: int
	var bonus: int
	var age: float = 0.0
	func _init(at: Vector2, amount: int, extra: int) -> void:
		position = at
		count = amount
		bonus = extra

const TRAIL_LIFE: float = 0.19
const COMBO_LIFE: float = 1.1
const MAX_DROPLETS: int = 320
var _blade: Array[BladePoint] = []
var _droplets: Array[Droplet] = []
var _ripples: Array[Ripple] = []
var _combos: Array[ComboLabel] = []
var _stroke: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func add_blade_point(point: Vector2) -> void:
	if not _blade.is_empty():
		var previous: BladePoint = _blade[_blade.size() - 1]
		if previous.stroke == _stroke and previous.position.distance_squared_to(point) < 5.0:
			previous.age = 0.0
			return
	_blade.append(BladePoint.new(point, _stroke))
	if _blade.size() > 60:
		_blade.pop_front()
	queue_redraw()

func end_blade() -> void:
	_stroke += 1

func burst(point: Vector2, color: Color, direction: Vector2, bomb: bool = false) -> void:
	var axis: Vector2 = direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	var count: int = 24 if bomb else 18
	if reduced_motion:
		count = 7 if bomb else 5
	for index: int in range(count):
		var angle: float = _rng.randf_range(-PI, PI)
		var outward: Vector2 = Vector2.from_angle(angle)
		var speed: float = _rng.randf_range(90.0, 390.0) if bomb else _rng.randf_range(60.0, 260.0)
		var velocity: Vector2 = outward * speed + axis * _rng.randf_range(20.0, 110.0)
		if reduced_motion:
			velocity *= 0.35
		var is_spark: bool = index % 4 == 0 or bomb
		var tint: Color = color.lerp(Color.WHITE, _rng.randf_range(0.0, 0.36))
		if bomb:
			tint = Color("ffcf71").lerp(Color("ff634a"), _rng.randf())
		var radius: float = _rng.randf_range(2.4, 6.8)
		if is_spark:
			radius *= 0.57
		var duration: float = _rng.randf_range(0.35, 0.76)
		_droplets.append(Droplet.new(point + outward * _rng.randf_range(2.0, 10.0), velocity, tint, radius, duration, is_spark))
	while _droplets.size() > MAX_DROPLETS:
		_droplets.pop_front()
	_ripples.append(Ripple.new(point, Color("ffbd74") if bomb else color, 105.0 if bomb else 46.0, 0.42 if bomb else 0.30, bomb))
	if _ripples.size() > 30:
		_ripples.pop_front()
	queue_redraw()

func show_combo(point: Vector2, count: int, bonus: int) -> void:
	_combos.append(ComboLabel.new(point, count, bonus))
	if _combos.size() > 6:
		_combos.pop_front()
	queue_redraw()

func clear_effects() -> void:
	_blade.clear()
	_droplets.clear()
	_ripples.clear()
	_combos.clear()
	_stroke += 1
	queue_redraw()

func _process(delta: float) -> void:
	var was_active: bool = not _blade.is_empty() or not _droplets.is_empty() or not _ripples.is_empty() or not _combos.is_empty()
	for index: int in range(_blade.size() - 1, -1, -1):
		_blade[index].age += delta
		if _blade[index].age >= TRAIL_LIFE:
			_blade.remove_at(index)
	for index: int in range(_droplets.size() - 1, -1, -1):
		var drop: Droplet = _droplets[index]
		drop.age += delta
		drop.position += drop.velocity * delta
		drop.velocity *= exp(-2.2 * delta)
		drop.velocity.y += (120.0 if reduced_motion else 290.0) * delta
		if drop.age >= drop.life:
			_droplets.remove_at(index)
	for index: int in range(_ripples.size() - 1, -1, -1):
		_ripples[index].age += delta
		if _ripples[index].age >= _ripples[index].life:
			_ripples.remove_at(index)
	for index: int in range(_combos.size() - 1, -1, -1):
		_combos[index].age += delta
		if _combos[index].age >= COMBO_LIFE:
			_combos.remove_at(index)
	if was_active:
		queue_redraw()

func _draw() -> void:
	_draw_ripples()
	_draw_droplets()
	_draw_blade()
	_draw_combos()

func _draw_ripples() -> void:
	for ripple: Ripple in _ripples:
		var progress: float = clampf(ripple.age / ripple.life, 0.0, 1.0)
		var opacity: float = pow(1.0 - progress, 2.0)
		var size: float = ripple.radius * (0.15 + 0.85 * (1.0 - pow(1.0 - progress, 3.0)))
		if reduced_motion:
			size *= 0.65
		var tint: Color = ripple.color
		tint.a = opacity * 0.11
		draw_circle(ripple.position, size * 0.8, tint)
		tint.a = opacity * 0.75
		draw_arc(ripple.position, size, 0.0, TAU, 48, tint, 1.5 + opacity * 1.5, true)
		if ripple.explosive:
			tint.a = opacity * 0.45
			draw_arc(ripple.position, size * 0.66, 0.0, TAU, 40, tint, 2.0, true)
			tint.a = opacity * 0.85
			for ray: int in range(10):
				var axis: Vector2 = Vector2.from_angle(float(ray) * TAU / 10.0 + 0.2)
				draw_line(ripple.position + axis * size * 0.75, ripple.position + axis * size * 1.18, tint, 2.0, true)

func _draw_droplets() -> void:
	for drop: Droplet in _droplets:
		var progress: float = clampf(drop.age / drop.life, 0.0, 1.0)
		var opacity: float = pow(1.0 - progress, 1.4)
		var tint: Color = drop.color
		tint.a = opacity
		var radius: float = drop.radius * (1.0 - progress * 0.45)
		if drop.spark:
			var tail: Vector2 = drop.velocity.normalized() * minf(17.0, drop.velocity.length() * 0.042)
			var glow: Color = tint
			glow.a *= 0.16
			draw_line(drop.position - tail, drop.position, glow, radius * 5.0, true)
			draw_line(drop.position - tail, drop.position, tint, maxf(1.0, radius), true)
		else:
			var shadow: Color = tint.darkened(0.4)
			shadow.a *= 0.35
			draw_circle(drop.position + Vector2(0.0, 1.8), radius * 1.05, shadow)
			draw_circle(drop.position, radius, tint)
			var highlight: Color = Color(1.0, 1.0, 1.0, opacity * 0.45)
			draw_circle(drop.position + Vector2(-radius * 0.28, -radius * 0.28), radius * 0.30, highlight)

func _draw_blade() -> void:
	for index: int in range(1, _blade.size()):
		var from: BladePoint = _blade[index - 1]
		var to: BladePoint = _blade[index]
		if from.stroke != to.stroke:
			continue
		var strength: float = clampf(1.0 - from.age / TRAIL_LIFE, 0.0, 1.0)
		var width: float = 1.0 + 6.0 * strength
		draw_line(from.position, to.position, Color(0.23, 0.91, 1.0, 0.075 * strength), width * 3.5, true)
		draw_line(from.position, to.position, Color(0.30, 0.94, 1.0, 0.24 * strength), width * 1.8, true)
		draw_line(from.position, to.position, Color(0.77, 1.0, 1.0, 0.77 * strength), width * 0.72, true)
		draw_line(from.position, to.position, Color(1.0, 1.0, 1.0, strength), maxf(1.0, width * 0.30), true)
	if not _blade.is_empty():
		var tip: BladePoint = _blade[_blade.size() - 1]
		var strength: float = clampf(1.0 - tip.age / TRAIL_LIFE, 0.0, 1.0)
		draw_circle(tip.position, 8.0 * strength, Color(0.45, 0.97, 1.0, strength * 0.15))
		draw_circle(tip.position, 2.5 * strength, Color(1.0, 1.0, 1.0, strength))

func _draw_combos() -> void:
	var font: Font = ThemeDB.fallback_font
	for combo: ComboLabel in _combos:
		var progress: float = clampf(combo.age / COMBO_LIFE, 0.0, 1.0)
		var opacity: float = clampf((1.0 - progress) / 0.32, 0.0, 1.0)
		var entrance: float = clampf(combo.age / 0.12, 0.0, 1.0)
		opacity *= entrance
		var lift: float = 8.0 if reduced_motion else 40.0
		var origin: Vector2 = combo.position + Vector2(0.0, -32.0 - progress * lift)
		var title: String = "%d FRUIT COMBO" % combo.count
		var bonus_text: String = "+%d BONUS" % combo.bonus
		var title_size: int = 24
		var title_width: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size).x
		var bonus_width: float = font.get_string_size(bonus_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17).x
		var title_position: Vector2 = origin - Vector2(title_width * 0.5, 0.0)
		var bonus_position: Vector2 = origin + Vector2(-bonus_width * 0.5, 25.0)
		draw_string_outline(font, title_position, title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size, 6, Color(0.02, 0.06, 0.10, opacity * 0.85))
		draw_string(font, title_position, title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size, Color(1.0, 0.94, 0.65, opacity))
		draw_string_outline(font, bonus_position, bonus_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, 5, Color(0.02, 0.06, 0.10, opacity * 0.8))
		draw_string(font, bonus_position, bonus_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17, Color(0.47, 1.0, 0.85, opacity))
		var line_color: Color = Color(0.47, 1.0, 0.85, opacity * 0.6)
		draw_line(origin + Vector2(-bonus_width * 0.5 - 22.0, 18.0), origin + Vector2(-bonus_width * 0.5 - 8.0, 18.0), line_color, 1.0, true)
		draw_line(origin + Vector2(bonus_width * 0.5 + 8.0, 18.0), origin + Vector2(bonus_width * 0.5 + 22.0, 18.0), line_color, 1.0, true)
