class_name PuzzleUI
extends Control
## Terminal-style DSA problem screen. Builds its UI in code (no .tscn needed).
## Player reads the LeetCode-style problem, selects an answer, gets feedback.
## Correct answer grants access to the next level.

signal puzzle_completed(success: bool)

var puzzle: Dictionary = {}
var _selected: int = -1
var _answered: bool = false
var _attempts: int = 0
var _show_hint: bool = false
var _last_correct: bool = false

var _title_label: Label
var _difficulty_label: Label
var _desc_label: RichTextLabel
var _options_box: VBoxContainer
var _feedback_label: Label
var _hint_label: Label
var _hint_button: Button
var _submit_button: Button
var _back_button: Button
var _panel: PanelContainer

func _ready() -> void:
	_build_ui()
	hide()
	# Must keep running while the rest of the game is paused.
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

func _notification(what: int) -> void:
	# Defensive: if we're freed without _on_back, unpause (guard against teardown).
	if what == NOTIFICATION_PREDELETE and is_inside_tree() and get_tree() and get_tree().paused:
		get_tree().paused = false

func _build_ui() -> void:
	# Full-screen dim
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# Centered panel
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(760, 560)
	_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_difficulty_label = Label.new()
	_difficulty_label.add_theme_font_size_override("font_size", 14)
	_difficulty_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	header.add_child(_difficulty_label)

	var hline := HSeparator.new()
	vbox.add_child(hline)

	# Problem description (scrollable)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 180)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_desc_label = RichTextLabel.new()
	_desc_label.bbcode_enabled = true
	_desc_label.fit_content = true
	_desc_label.scroll_active = false
	_desc_label.add_theme_font_size_override("normal_font_size", 15)
	_desc_label.add_theme_color_override("default_color", Color(0.9, 0.95, 1.0))
	scroll.add_child(_desc_label)

	# Options
	var options_label := Label.new()
	options_label.text = "CHOOSE YOUR APPROACH:"
	options_label.add_theme_font_size_override("font_size", 13)
	options_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	vbox.add_child(options_label)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 8)
	vbox.add_child(_options_box)

	# Hint area
	_hint_label = Label.new()
	_hint_label.text = ""
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vbox.add_child(_hint_label)

	# Feedback area
	_feedback_label = Label.new()
	_feedback_label.text = ""
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(_feedback_label)

	# Button row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_row)

	_hint_button = Button.new()
	_hint_button.text = "GET HINT"
	_hint_button.pressed.connect(_on_hint)
	btn_row.add_child(_hint_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(spacer)

	_back_button = Button.new()
	_back_button.text = "EXIT TERMINAL"
	_back_button.pressed.connect(_on_back)
	btn_row.add_child(_back_button)

	_submit_button = Button.new()
	_submit_button.text = "SUBMIT ANSWER"
	_submit_button.pressed.connect(_on_submit)
	_submit_button.disabled = true
	_submit_button.add_theme_color_override("font_color", Color(0.1, 0.1, 0.15))
	_submit_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.4, 1.0, 0.6)))
	btn_row.add_child(_submit_button)

func _make_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.1, 0.22, 0.97)
	sb.border_color = Color(0.0, 0.9, 1.0, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0.0, 0.9, 1.0, 0.3)
	sb.shadow_size = 24
	return sb

func _make_button_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

func show_puzzle(data: Dictionary) -> void:
	puzzle = data
	_selected = -1
	_answered = false
	_attempts = 0
	_show_hint = false
	_last_correct = false
	_title_label.text = "> " + puzzle.title
	_difficulty_label.text = puzzle.difficulty
	_difficulty_label.add_theme_color_override("font_color",
		Color(0.6, 1.0, 0.6) if puzzle.difficulty == "EASY" else Color(1.0, 0.8, 0.4))
	_desc_label.text = "[code]" + puzzle.description + "[/code]"
	_feedback_label.text = ""
	_feedback_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_hint_label.text = ""
	_hint_button.text = "GET HINT"
	_hint_button.disabled = false
	_back_button.text = "EXIT TERMINAL"
	_build_options()
	show()
	get_tree().paused = true  # freeze enemies + timer while reading
	AudioManager.play("ui")

func _build_options() -> void:
	for child in _options_box.get_children():
		child.queue_free()
	for i in range(puzzle.options.size()):
		var btn := Button.new()
		btn.text = "  [%s]  %s" % [String.chr(65 + i), puzzle.options[i]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 44)
		btn.add_theme_font_size_override("font_size", 15)
		btn.add_theme_stylebox_override("normal", _make_button_style(Color(0.12, 0.16, 0.35)))
		btn.add_theme_stylebox_override("hover", _make_button_style(Color(0.16, 0.22, 0.45)))
		btn.add_theme_stylebox_override("pressed", _make_button_style(Color(0.1, 0.13, 0.3)))
		btn.pressed.connect(_on_option_pressed.bind(i))
		_options_box.add_child(btn)
	_submit_button.disabled = true

func _on_option_pressed(index: int) -> void:
	if _answered:
		return
	_selected = index
	_submit_button.disabled = false
	for i in range(_options_box.get_child_count()):
		var btn := _options_box.get_child(i) as Button
		var selected := i == index
		btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.7) if selected else Color(0.85, 0.9, 1.0))
		btn.add_theme_stylebox_override("normal", _make_button_style(Color(0.14, 0.2, 0.4) if selected else Color(0.12, 0.16, 0.35)))

func _on_submit() -> void:
	if _selected < 0 or _answered:
		return
	_answered = true
	_attempts += 1
	GameManager.puzzles_attempted += 1
	var correct: bool = (_selected == int(puzzle.correct_index))
	_last_correct = correct
	if correct:
		_feedback_label.text = "✓ ACCESS GRANTED\n\n" + puzzle.explanation
		_feedback_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
		AudioManager.play("correct")
		for i in range(_options_box.get_child_count()):
			var btn := _options_box.get_child(i) as Button
			var is_correct: bool = (i == int(puzzle.correct_index))
			btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6) if is_correct else Color(0.5, 0.5, 0.55))
			btn.add_theme_stylebox_override("normal", _make_button_style(Color(0.1, 0.2, 0.15) if is_correct else Color(0.1, 0.12, 0.25)))
		_submit_button.disabled = true
		_hint_button.disabled = true
		_back_button.text = "ENTER NEXT SECTOR →"
		await get_tree().create_timer(1.8).timeout
		hide()
		get_tree().paused = false
		puzzle_completed.emit(true)
	else:
		_feedback_label.text = "✗ ACCESS DENIED\n\n" + puzzle.explanation
		_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		AudioManager.play("wrong")
		for i in range(_options_box.get_child_count()):
			var btn := _options_box.get_child(i) as Button
			var is_wrong := i == _selected
			btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55) if is_wrong else Color(0.85, 0.9, 1.0))
			btn.add_theme_stylebox_override("normal", _make_button_style(Color(0.2, 0.12, 0.12) if is_wrong else Color(0.12, 0.16, 0.35)))
		_submit_button.disabled = true
		await get_tree().create_timer(2.0).timeout
		_answered = false
		_submit_button.disabled = _selected < 0

func _on_hint() -> void:
	_show_hint = not _show_hint
	if _show_hint:
		_hint_label.text = ">> " + puzzle.hint
		_hint_button.text = "HIDE HINT"
		AudioManager.play("ui")
	else:
		_hint_label.text = ""
		_hint_button.text = "GET HINT"

func _on_back() -> void:
	hide()
	get_tree().paused = false
	# If the puzzle was solved, the (relabeled) button means "continue to exit".
	puzzle_completed.emit(_last_correct)
