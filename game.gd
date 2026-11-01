extends Node3D
## Local responsive simulation; host accepts bounded progress and publishes one result.
const GAME: PackedScene = preload("res://games/minigame/godot_party_default_fruit_samurai/scenes/main.tscn")
const IS_PLATFORM: bool = false
var api: PartyAPI
var request: Dictionary
var players: Array[Dictionary] = []
var local_id: String = ""
var game: Node3D
var running: bool = false
var submitted: bool = false
var elapsed: float = 0.0
var deadline: float = 90.0
var report_clock: float = 0.0
var records: Dictionary = {}
var summary: Label
var round_label: Label
var sequence: int = 0

func party_setup(value: PartyAPI, config: Dictionary) -> void:
	api = value
	request = config.duplicate(true)
	players = api.get_players()
	deadline = float(api.get_settings().get("duration", 180 if IS_PLATFORM else 90))
	for player: Dictionary in players:
		var id: String = player.player_id
		if player.is_local:
			local_id = id
		records[id] = {"score": 0, "done": false, "won": false, "elapsed": 0.0, "seq": -1, "withdrawn": not player.connected}
	api.net.message_received.connect(_message)
	api.players_changed.connect(_players_changed)

func _ready() -> void:
	if api == null:
		push_error("请从 GodotParty 大厅启动小游戏")
		return
	if request.get("mode") != "standard":
		api.fail("unsupported_request", "此小游戏仅支持 standard 普通局")
		return
	game = GAME.instantiate()
	add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	if IS_PLATFORM:
		game.party_input = api.input
		game.player.party_input = api.input
		game.pause_button.hide()
		game.restart_button.hide()
	else:
		game.party_input = api.input
		game.menu.hide()
		game.hud.get_node("Pause").hide()
		game.fx.reduced_motion = bool(api.config.get_own(&"reduced_motion", false))
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	margin.offset_left = -430
	margin.offset_right = -30
	margin.offset_top = 180
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	round_label = Label.new()
	round_label.add_theme_font_size_override("font_size", 24)
	column.add_child(round_label)
	summary = Label.new()
	summary.add_theme_font_size_override("font_size", 20)
	column.add_child(summary)
	round_label.text = "等待所有玩家准备完成"
	api.mark_ready()

func party_start() -> void:
	running = true
	if game != null and not local_id.is_empty():
		game.process_mode = Node.PROCESS_MODE_INHERIT
		game.rng.seed = api.get_seed()
		if IS_PLATFORM:
			game.remaining_time = deadline
		else:
			game.start_game()
	_publish()

func party_stop(_reason: StringName) -> void:
	running = false
	if game != null:
		game.process_mode = Node.PROCESS_MODE_DISABLED

func _process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	round_label.text = "%s · 剩余 %d 秒%s" % ["云间跃行" if IS_PLATFORM else "水果武士", maxi(0, ceili(deadline - elapsed)), " · 观战中" if local_id.is_empty() else ""]
	if game != null and not submitted and not local_id.is_empty():
		var ended: bool = (game.won or game.lives <= 0) if IS_PLATFORM else game.state == game.State.OVER
		if ended or elapsed >= deadline:
			if not IS_PLATFORM:
				game.finish_stroke()
			submitted = true
			game.process_mode = Node.PROCESS_MODE_DISABLED
			_send_progress(true)
	report_clock += delta
	if report_clock >= 0.25:
		report_clock = 0.0
		if game != null and not submitted and not local_id.is_empty():
			_send_progress(false)
		if api.is_host():
			_publish()
	if api.is_host():
		var all_done: bool = true
		for id: String in records:
			if not records[id].done and not records[id].withdrawn:
				all_done = false
		if all_done or elapsed >= deadline + 2.0:
			_finish()

func _send_progress(done: bool) -> void:
	sequence += 1
	api.net.send_to_host(&"progress", {"seq": sequence, "score": int(game.score), "won": bool(game.won) if IS_PLATFORM else false, "done": done, "elapsed": minf(elapsed, deadline)})

func _message(sender: Dictionary, topic: StringName, payload: Variant) -> void:
	if not running or not payload is Dictionary:
		return
	if topic == &"standings" and int(sender.get("peer_id", 0)) == 1:
		_show_standings(payload)
	elif topic == &"progress" and api.is_host():
		var id: String = ""
		for player: Dictionary in api.get_players():
			if player.connected and player.player_id in sender.get("player_ids", []):
				id = player.player_id
				break
		if id.is_empty() or not _valid_progress(payload) or records[id].done or records[id].withdrawn:
			return
		if payload.seq <= records[id].seq or payload.score < records[id].score:
			return
		records[id] = {"score": payload.score, "won": payload.won, "done": payload.done, "elapsed": payload.elapsed, "seq": payload.seq, "withdrawn": false}

func _valid_progress(value: Dictionary) -> bool:
	return value.get("seq") is int and value.seq >= 0 and value.get("score") is int and value.score >= 0 and value.score <= 1000000 and value.get("won") is bool and value.get("done") is bool and (value.get("elapsed") is float or value.get("elapsed") is int) and is_finite(float(value.elapsed)) and value.elapsed >= 0 and value.elapsed <= deadline and (not value.won or IS_PLATFORM)

func _players_changed() -> void:
	if not api.is_host():
		return
	for player: Dictionary in api.get_players():
		if not player.connected and records.has(player.player_id):
			records[player.player_id].withdrawn = true

func _publish() -> void:
	if api.is_host():
		api.net.broadcast(&"standings", {"records": records.duplicate(true)})

func _show_standings(value: Dictionary) -> void:
	var lines: PackedStringArray = []
	for player: Dictionary in players:
		var row: Dictionary = value.get("records", {}).get(player.player_id, {})
		lines.append("%s  %d 分  %s" % [player.name, row.get("score", 0), "已退出" if row.get("withdrawn", false) else ("已完成" if row.get("done", false) else "挑战中")])
	summary.text = "\n".join(lines)

func _finish() -> void:
	running = false
	var rows: Array[Dictionary] = []
	for player: Dictionary in players:
		var row: Dictionary = records[player.player_id]
		rows.append({"player_id": player.player_id, "rank": 0, "status": "withdrawn" if row.withdrawn else "completed", "metrics": {"score": row.score, "time": roundi(row.elapsed * 1000.0), "clear": 1 if row.won else 0}})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.metrics.score > b.metrics.score)
	for index: int in rows.size():
		if rows[index].status == "withdrawn":
			continue
		var rank_value: int = 1
		for other: Dictionary in rows:
			if other.status != "withdrawn" and other.metrics.score > rows[index].metrics.score:
				rank_value += 1
		rows[index].rank = rank_value
	var result: Dictionary = {"request_id": request.request_id, "reason": "completed", "rankings": rows, "columns": [{"key": "score", "title": "得分", "format": "integer"}, {"key": "time", "title": "用时", "format": "time"}]}
	var error: Error = api.finish(result)
	if error != OK:
		api.fail("result_rejected", error_string(error))

func godot_party_graphics_targets() -> Dictionary:
	if game == null:
		return {}
	if IS_PLATFORM:
		return {"world": game.get_node("WorldEnvironment"), "sun": game.get_node("Sun")}
	return {"world": game.get_node("Environment"), "sun": game.get_node("KeyLight")}
