extends Node3D
## Local cutting stays responsive; this entry owns bounded host scoring and round lifetime.
const Gameplay = preload("res://games/minigame/godot_party_default_fruit_samurai/scripts/main.gd")
const Pages = preload("res://games/protocols/godot_party_default_protocol/round_pages.gd")
const STANDING_ROW: PackedScene = preload("res://games/protocols/godot_party_default_protocol/standing_row.tscn")
@export var game: Gameplay
@export var challenge_hud: CanvasLayer
@export var summary: VBoxContainer
@export var round_label: Label
@export var world: WorldEnvironment
@export var sun: DirectionalLight3D
var pages: Pages
var api: PartyAPI
var request: Dictionary
var players: Array[Dictionary] = []
var local_id: String = ""
var running: bool = false
var stopped: bool = false
var submitted: bool = false
var elapsed: float = 0.0
var deadline: float
var report_clock: float = 0.0
var _end_msec: int = 0
var _sent_score: int = -1
var _sent_won: bool = false
var _published_records: Dictionary = {}
var _display_records: Dictionary = {}
var records: Dictionary[String, Dictionary] = {}
var score_rows: Dictionary[String, Label] = {}
var sequence: int = 0

func party_setup(value: PartyAPI, config: Dictionary) -> void:
	api = value
	request = config.duplicate(true)
	players = api.get_players()
	deadline = float(api.get_settings()["duration"])
	game.party_input = api.input
	game.translate = api.i18n.text
	game.audio.prepare_scope()
	game.simulation_active = false
	for player: Dictionary in players:
		var id: String = player.player_id
		if player.is_local:
			local_id = id
		records[id] = {"score": 0, "done": false, "won": false, "elapsed": 0.0, "seq": -1, "withdrawn": not player.connected}
	api.net.message_received.connect(_message)
	api.players_changed.connect(_players_changed)
	game.failed.connect(_fail)

func _ready() -> void:
	assert(game != null and challenge_hud != null and summary != null and round_label != null, "Fruit Samurai requires its gameplay and ranking HUD.")
	assert(world != null and sun != null, "Fruit Samurai requires its graphics targets.")
	if api == null:
		push_error("请从 GodotParty 大厅启动小游戏；F6 预览使用 scenes/main.tscn。")
		game.stop_gameplay()
		return
	if request.get("mode") != "standard":
		_fail("unsupported_request", "此小游戏仅支持 standard 普通局")
		return
	game.fx.reduced_motion = bool(api.config.get_own(&"reduced_motion"))
	for player: Dictionary in players:
		var row: Label = STANDING_ROW.instantiate()
		summary.add_child(row)
		score_rows[player.player_id] = row
		row.text = player.name
	round_label.text = api.i18n.text(&"hud.ready")
	pages = Pages.new()
	var error: Error = pages.prepare(self, api, request, _start_gameplay)
	if error != OK:
		_fail("load_failed", error_string(error))

func party_start() -> void:
	pages.transport_started()

func _start_gameplay() -> void:
	running = true
	if api.is_host():
		_end_msec = api.net.host_time_msec() + roundi(deadline * 1000.0)
	game.process_mode = Node.PROCESS_MODE_INHERIT
	if not local_id.is_empty():
		game.rng.seed = api.get_seed()
		game.start_game()
	var error: Error = _publish()
	if error != OK:
		_fail("standings_failed", error_string(error))

## Cleanup is synchronous and idempotent, including cancellation before ready.
func party_stop(_reason: StringName) -> void:
	if stopped:
		return
	stopped = true
	running = false
	if game.is_node_ready():
		game.stop_gameplay()
		game.get_node("Canvas").hide()
	challenge_hud.hide()
	game.audio.close_scope()
	if api != null:
		api.net.message_received.disconnect(_message)
		api.players_changed.disconnect(_players_changed)
		game.failed.disconnect(_fail)
	if pages != null:
		pages.stop()
		pages.hide()

func _process(delta: float) -> void:
	if not running:
		return
	elapsed = maxf(0.0, deadline - float(_end_msec - api.net.host_time_msec()) / 1000.0) if _end_msec > 0 else elapsed + delta
	round_label.text = api.i18n.text(&"hud.time", {"time": maxi(0, ceili(deadline - elapsed)),
		"spectator": api.i18n.text(&"hud.spectator") if local_id.is_empty() else ""})
	if not submitted and not local_id.is_empty() and (game.state == Gameplay.State.OVER or elapsed >= deadline):
		game.stop_gameplay(true)
		if stopped:
			return
		submitted = true
		var error: Error = _send_progress(true)
		if error != OK:
			_fail("progress_failed", error_string(error))
			return
	report_clock += delta
	if report_clock >= 0.25:
		report_clock = 0.0
		if not submitted and not local_id.is_empty():
			var error: Error = _send_progress(false)
			if error != OK:
				_fail("progress_failed", error_string(error))
				return
		var error: Error = _publish()
		if error != OK:
			_fail("standings_failed", error_string(error))
			return
	if api.is_host():
		var all_done: bool = true
		for row: Dictionary in records.values():
			if not row.done and not row.withdrawn:
				all_done = false
		if all_done or elapsed >= deadline + 2.0:
			_finish()

func _send_progress(done: bool) -> Error:
	if not done and game.score == _sent_score:
		return OK
	sequence += 1
	var error: Error = api.net.send_to_host(&"progress", {"seq": sequence, "score": game.score, "won": false,
		"done": done, "elapsed": minf(elapsed, deadline)})
	if error == OK:
		_sent_score = game.score
	return error

func _message(sender: Dictionary, topic: StringName, payload: Variant) -> void:
	# G01 still owns page visibility. Stop local effects before its result handler
	# disables the root; the page remains responsible for validating the result.
	if topic == Pages.RESULT_TOPIC and sender.peer_id == 1 and not api.is_host():
		running = false
		game.stop_gameplay()
		return
	if not running or not payload is Dictionary:
		return
	if topic == &"standings" and sender.peer_id == 1:
		_show_standings(payload)
	elif topic == &"progress" and api.is_host():
		var id: String = ""
		for player: Dictionary in api.get_players():
			if player.connected and player.player_id in sender.player_ids:
				id = player.player_id
				break
		if id.is_empty() or not _valid_progress(payload) or records[id].done or records[id].withdrawn:
			return
		if payload.seq <= records[id].seq or payload.score < records[id].score:
			return
		records[id] = {"score": payload.score, "won": payload.won, "done": payload.done,
			"elapsed": payload.elapsed, "seq": payload.seq, "withdrawn": false}

func _valid_progress(value: Dictionary) -> bool:
	return value.get("seq") is int and value.seq >= 0 and value.get("score") is int and value.score >= 0 and value.score <= 1000000 and value.get("won") is bool and not value.won and value.get("done") is bool and (value.get("elapsed") is float or value.get("elapsed") is int) and is_finite(float(value.elapsed)) and value.elapsed >= 0 and value.elapsed <= deadline

func _players_changed() -> void:
	if not api.is_host():
		return
	for player: Dictionary in api.get_players():
		if not player.connected and records.has(player.player_id):
			records[player.player_id].withdrawn = true

func _publish() -> Error:
	if not api.is_host():
		return OK
	var changed: Dictionary = {}
	for id: String in records:
		var row: Dictionary = records[id]
		var public: Dictionary = {"score": row.score, "won": row.won, "done": row.done, "withdrawn": row.withdrawn}
		if not _published_records.has(id) or _published_records[id] != public:
			changed[id] = public
	if changed.is_empty():
		return OK
	var message: Dictionary = {"records": changed}
	if _published_records.is_empty():
		message["end_msec"] = _end_msec
	var error: Error = api.net.broadcast(&"standings", message)
	if error == OK:
		_published_records.merge(changed, true)
	return error

func _show_standings(value: Dictionary) -> void:
	if not value.get("records") is Dictionary:
		return
	if value.has("end_msec"):
		if not value.end_msec is int:
			return
		_end_msec = value.end_msec
	for id: Variant in value.records:
		var row: Variant = value.records[id]
		if not id is String or not records.has(id) or not row is Dictionary or not row.get("score") is int or row.score < 0 or not row.get("won") is bool or not row.get("done") is bool or not row.get("withdrawn") is bool:
			return
		_display_records[id] = row
	for player: Dictionary in players:
		var row: Dictionary = _display_records.get(player.player_id, {})
		var state_key: StringName = &"hud.withdrawn" if row.get("withdrawn", false) else (&"hud.completed" if row.get("done", false) else &"hud.playing")
		score_rows[player.player_id].text = api.i18n.text(&"hud.player", {"player": player.name,
			"score": row.get("score", 0), "state": api.i18n.text(state_key)})

func _finish() -> void:
	running = false
	game.stop_gameplay()
	var rows: Array[Dictionary] = []
	for player: Dictionary in players:
		var row: Dictionary = records[player.player_id]
		rows.append({"player_id": player.player_id, "rank": 0, "status": "withdrawn" if row.withdrawn else "completed",
			"metrics": {"score": row.score, "time": roundi(row.elapsed * 1000.0), "clear": 0}})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.metrics.score > b.metrics.score)
	for row: Dictionary in rows:
		if row.status == "withdrawn":
			continue
		var rank_value: int = 1
		for other: Dictionary in rows:
			if other.status != "withdrawn" and other.metrics.score > row.metrics.score:
				rank_value += 1
		row.rank = rank_value
	var result: Dictionary = {"request_id": request.request_id, "reason": "completed", "rankings": rows,
		"columns": [{"key": "score", "title": api.i18n.text(&"hud.score"), "format": "integer"},
			{"key": "time", "title": api.i18n.text(&"hud.elapsed"), "format": "time"}]}
	var error: Error = pages.present(result)
	if error != OK:
		_fail("result_rejected", error_string(error))

func _fail(code: String, message: String) -> void:
	party_stop(&"failed")
	var error: Error = api.fail(code, message)
	if error != OK:
		push_error("Fruit Samurai cancellation failed (%s): %s; original %s: %s" % [error, error_string(error), code, message])

func godot_party_graphics_targets() -> Dictionary:
	return {"world": world, "sun": sun}

func godot_party_audio_target() -> PartyGameAudio:
	return game.audio
