extends Control
## Skin scenes own all fixed art and layout; this script only presents live values.
@export_range(18, 64) var score_font_size: int = 48
@export var show_pause_caption: bool = true
@export var pause_symbol: String = ""
@onready var score_label: Label = %Score
@onready var best_label: Label = %Best
@onready var pause_button: Button = %Pause
@onready var available_marks: Array[CanvasItem] = [%Available0, %Available1, %Available2]
@onready var missing_marks: Array[CanvasItem] = [%Missing0, %Missing1, %Missing2]
var translate: Callable

func apply_translation(value: Callable) -> void:
	translate = value
	%ScoreCaption.text = translate.call(&"hud.score", {})
	%MissCaption.text = translate.call(&"hud.misses", {})
	pause_button.text = (translate.call(&"hud.pause", {}) if pause_symbol.is_empty() else pause_symbol) if show_pause_caption else ""
	pause_button.tooltip_text = translate.call(&"hud.pause", {})

func update_values(score: int, best: int, misses: int) -> void:
	score_label.text = "%03d" % score
	var font_size: int = score_font_size
	var font: Font = score_label.get_theme_font("font")
	while font_size > 18 and font.get_string_size(score_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > score_label.size.x:
		font_size -= 1
	score_label.add_theme_font_size_override("font_size", font_size)
	best_label.text = translate.call(&"hud.best", {"score": maxi(best, score)})
	for index: int in range(3):
		available_marks[index].visible = index >= misses
		missing_marks[index].visible = index < misses
