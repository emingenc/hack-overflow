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
var _attempts_label: Label
var _desc_label: RichTextLabel
var _options_box: VBoxContainer
var _feedback_label: Label
var _hint_label: Label
var _hint_button: Button
var _submit_button: Button
var _back_button: Button
var _panel: PanelContainer
var _locked_options: Array[int] = []
# Task-type state (trace/order/mcq)
var _task_type: String = "mcq"
var _step_index: int = 0
var _order_placed: Array[int] = []  # index into shuffled_steps per slot, -1 = empty
var _steps_correct: int = 0
var _steps_total: int = 0
var _slot_buttons: Array[Button] = []
# Firewall integrity: wrong answer -30%, hint -15%; at 0 the terminal locks
# (level_index 0 never locks — forgiving first sector).
var _integrity: float = 1.0
var _level_index: int = 0
var _integrity_bar: ProgressBar
signal puzzle_locked

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
	_title_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_difficulty_label = Label.new()
	_difficulty_label.add_theme_font_size_override("font_size", 16)
	_difficulty_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	header.add_child(_difficulty_label)

	_attempts_label = Label.new()
	_attempts_label.add_theme_font_size_override("font_size", 16)
	_attempts_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	header.add_child(_attempts_label)

	# Firewall integrity bar (diegetic consequence: wrong answers drain it).
	var integ_row := HBoxContainer.new()
	integ_row.add_theme_constant_override("separation", 10)
	vbox.add_child(integ_row)
	var integ_label := Label.new()
	integ_label.text = "FIREWALL INTEGRITY"
	integ_label.add_theme_font_size_override("font_size", 12)
	integ_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	integ_row.add_child(integ_label)
	_integrity_bar = ProgressBar.new()
	_integrity_bar.min_value = 0.0
	_integrity_bar.max_value = 1.0
	_integrity_bar.value = 1.0
	_integrity_bar.show_percentage = false
	_integrity_bar.custom_minimum_size = Vector2(0, 18)
	_integrity_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var integ_style := StyleBoxFlat.new()
	integ_style.bg_color = Color(0.04, 0.08, 0.05)
	integ_style.border_color = Color(0.3, 0.5, 0.8, 0.5)
	integ_style.set_border_width_all(1)
	integ_style.set_corner_radius_all(4)
	_integrity_bar.add_theme_stylebox_override("background", integ_style)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.9, 1.0)
	fill_style.set_corner_radius_all(4)
	_integrity_bar.add_theme_stylebox_override("fill", fill_style)
	integ_row.add_child(_integrity_bar)

	var hline := HSeparator.new()
	vbox.add_child(hline)

	# Problem description (scrollable)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 180)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_desc_label = RichTextLabel.new()
	_desc_label.bbcode_enabled = true
	_desc_label.fit_content = true
	_desc_label.scroll_active = false
	# CRITICAL: wrap the problem text or it clips past the panel edge on phones.
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("normal_font_size", 17)
	_desc_label.add_theme_color_override("default_color", Color(0.85, 1.0, 0.7))
	scroll.add_child(_desc_label)

	# Options
	var options_label := Label.new()
	options_label.text = "CHOOSE YOUR APPROACH:"
	options_label.add_theme_font_size_override("font_size", 13)
	options_label.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5))
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
	_submit_button.add_theme_color_override("font_color", Color(0.08, 0.12, 0.08))
	_submit_button.add_theme_stylebox_override("normal", _make_button_style(Color(0.4, 1.0, 0.6)))
	btn_row.add_child(_submit_button)

func _make_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.1, 0.22, 0.97)
	sb.border_color = Color(0.0, 1.0, 0.25, 0.5)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0.0, 1.0, 0.25, 0.25)
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

func show_puzzle(data: Dictionary, level_index: int = 0) -> void:
	puzzle = data
	_level_index = level_index
	_integrity = 1.0
	_integrity_bar.value = _integrity
	_selected = -1
	_answered = false
	_attempts = 0
	_show_hint = false
	_last_correct = false
	_locked_options.clear()
	_task_type = str(puzzle.get("type", "mcq"))
	_step_index = 0
	_steps_correct = 0
	_steps_total = 0
	_order_placed = []
	_title_label.text = "> " + puzzle.title
	_difficulty_label.text = puzzle.difficulty
	_difficulty_label.add_theme_color_override("font_color",
		Color(0.6, 1.0, 0.6) if puzzle.difficulty == "EASY" else Color(1.0, 0.8, 0.4))
	_attempts_label.text = ""
	_desc_label.text = puzzle.description
	_feedback_label.text = ""
	_feedback_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.7))
	_hint_label.text = ""
	_hint_button.text = "GET HINT"
	_hint_button.disabled = false
	_back_button.text = "EXIT TERMINAL"
	_submit_button.text = "SUBMIT ANSWER"
	_build_options()
	show()
	get_tree().paused = true  # freeze enemies + timer while reading
	AudioManager.play("ui")

func _build_options() -> void:
	for child in _options_box.get_children():
		child.queue_free()
	match _task_type:
		"trace":
			_build_trace_step()
		"order":
			_build_order()
		_:
			_build_mcq()
	_submit_button.disabled = true

func _build_mcq() -> void:
	for i in range(puzzle.options.size()):
		var btn := _make_option_button(puzzle.options[i], i)
		btn.pressed.connect(_on_option_pressed.bind(i))
		_options_box.add_child(btn)

func _make_option_button(text: String, i: int) -> Button:
	var btn := Button.new()
	btn.text = "  [%s]  %s" % [String.chr(65 + i), text]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 56)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_stylebox_override("normal", _make_button_style(Color(0.06, 0.16, 0.09)))
	btn.add_theme_stylebox_override("hover", _make_button_style(Color(0.08, 0.2, 0.1)))
	btn.add_theme_stylebox_override("pressed", _make_button_style(Color(0.05, 0.14, 0.08)))
	return btn

## ── TRACE: dry-run a sequence of steps ───────────────────────────────
func _build_trace_step() -> void:
	var steps: Array = puzzle.get("steps", [])
	if _step_index >= steps.size():
		# All steps done → optional synthesis capstone question.
		var syn: Dictionary = puzzle.get("synthesis", {})
		if not syn.is_empty():
			_desc_label.text = syn.get("question", "")
			_submit_button.text = "SUBMIT ANSWER"
			for i in range(syn.get("options", []).size()):
				var btn := _make_option_button(syn["options"][i], i)
				btn.pressed.connect(_on_option_pressed.bind(i))
				_options_box.add_child(btn)
			_submit_button.disabled = true
		return
	var step: Dictionary = steps[_step_index]
	# State readout + question
	_desc_label.text = "STATE: " + step.get("state", "") + "\n\n" + step.get("question", "")
	_attempts_label.text = "STEP %d / %d" % [_step_index + 1, steps.size()]
	_submit_button.text = "SUBMIT"
	for i in range(step.get("options", []).size()):
		var btn := _make_option_button(step["options"][i], i)
		btn.pressed.connect(_on_option_pressed.bind(i))
		_options_box.add_child(btn)

## ── ORDER: reconstruct shuffled algorithm steps ──────────────────────
func _build_order() -> void:
	var shuffled: Array = puzzle.get("shuffled_steps", [])
	var correct: Array = puzzle.get("correct_order", [])
	_order_placed.clear()
	for _i in range(correct.size()):
		_order_placed.append(-1)
	# Two columns: a pool of shuffled steps (left) + numbered slots (right).
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	_options_box.add_child(cols)

	var pool := VBoxContainer.new()
	pool.add_theme_constant_override("separation", 6)
	pool.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(pool)
	var pool_label := Label.new()
	pool_label.text = "SCRAMBLED:"
	pool_label.add_theme_font_size_override("font_size", 14)
	pool_label.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5))
	pool.add_child(pool_label)
	for i in range(shuffled.size()):
		var btn := _make_order_step_button(shuffled[i])
		btn.pressed.connect(_on_order_pool_pressed.bind(i))
		pool.add_child(btn)

	var slots := VBoxContainer.new()
	slots.add_theme_constant_override("separation", 6)
	slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(slots)
	var slot_label := Label.new()
	slot_label.text = "SEQUENCE:"
	slot_label.add_theme_font_size_override("font_size", 14)
	slot_label.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5))
	slots.add_child(slot_label)
	_slot_buttons = []
	for s in range(correct.size()):
		var btn := Button.new()
		btn.text = "%d.  [ empty ]" % (s + 1)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 52)
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_stylebox_override("normal", _make_button_style(Color(0.04, 0.1, 0.06)))
		btn.add_theme_stylebox_override("hover", _make_button_style(Color(0.06, 0.16, 0.09)))
		btn.pressed.connect(_on_order_slot_pressed.bind(s))
		slots.add_child(btn)
		_slot_buttons.append(btn)
	_submit_button.text = "CHECK SEQUENCE"

func _make_order_step_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = "  " + text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 52)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_stylebox_override("normal", _make_button_style(Color(0.06, 0.16, 0.09)))
	btn.add_theme_stylebox_override("hover", _make_button_style(Color(0.08, 0.2, 0.1)))
	return btn

func _on_order_pool_pressed(step_idx: int) -> void:
	# Place this step into the first empty slot.
	for s in range(_order_placed.size()):
		if _order_placed[s] == -1:
			_order_placed[s] = step_idx
			_refresh_order_slots()
			_submit_button.disabled = false
			return

func _on_order_slot_pressed(slot: int) -> void:
	if _order_placed[slot] != -1:
		_order_placed[slot] = -1  # pull back out
		_refresh_order_slots()

func _refresh_order_slots() -> void:
	var shuffled: Array = puzzle.get("shuffled_steps", [])
	for s in range(_slot_buttons.size()):
		var idx: int = _order_placed[s]
		if idx == -1:
			_slot_buttons[s].text = "%d.  [ empty ]" % (s + 1)
			_slot_buttons[s].add_theme_color_override("font_color", Color(0.55, 0.8, 0.55))
		else:
			_slot_buttons[s].text = "%d.  %s" % [s + 1, shuffled[idx]]
			_slot_buttons[s].add_theme_color_override("font_color", Color(0.85, 1.0, 0.7))

func _on_option_pressed(index: int) -> void:
	if _answered:
		return
	if _locked_options.has(index):
		return  # wrong pick already revealed — locked
	_selected = index
	_submit_button.disabled = false
	for i in range(_options_box.get_child_count()):
		var btn := _options_box.get_child(i) as Button
		var selected := i == index
		btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.7) if selected else Color(0.8, 1.0, 0.65))
		btn.add_theme_stylebox_override("normal", _make_button_style(Color(0.07, 0.18, 0.1) if selected else Color(0.06, 0.16, 0.09)))

func _on_submit() -> void:
	match _task_type:
		"trace":
			_on_submit_trace()
		"order":
			_on_submit_order()
		_:
			_on_submit_mcq()

## ── MCQ submit ────────────────────────────────────────────────────────
func _on_submit_mcq() -> void:
	if _selected < 0 or _answered:
		return
	_answered = true
	_attempts += 1
	GameManager.puzzles_attempted += 1
	_attempts_label.text = "ATTEMPT %d" % _attempts
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
			btn.add_theme_stylebox_override("normal", _make_button_style(Color(0.1, 0.2, 0.15) if is_correct else Color(0.05, 0.12, 0.07)))
		_submit_button.disabled = true
		_hint_button.disabled = true
		_back_button.text = "CONTINUE →"
		_back_button.disabled = false
	else:
		_feedback_label.text = "✗ ACCESS DENIED\n\n" + puzzle.explanation
		_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		AudioManager.play("wrong")
		_drain_integrity(0.30)
		_locked_options.append(_selected)
		for i in range(_options_box.get_child_count()):
			var btn := _options_box.get_child(i) as Button
			var is_wrong := i == _selected
			if is_wrong:
				btn.text = "  ✗  " + puzzle.options[i]
				btn.disabled = true
				btn.add_theme_color_override("font_color", Color(0.6, 0.35, 0.35))
				btn.add_theme_stylebox_override("normal", _make_button_style(Color(0.2, 0.1, 0.1)))
			else:
				btn.disabled = false
				btn.add_theme_color_override("font_color", Color(0.8, 1.0, 0.65))
				btn.add_theme_stylebox_override("normal", _make_button_style(Color(0.06, 0.16, 0.09)))
		_selected = -1
		_submit_button.disabled = true
		_answered = false

## ── TRACE submit: per-step validation ─────────────────────────────────
func _on_submit_trace() -> void:
	var steps: Array = puzzle.get("steps", [])
	var syn: Dictionary = puzzle.get("synthesis", {})
	# If past the steps, we're on the synthesis capstone.
	if _step_index >= steps.size():
		if _selected < 0 or _answered:
			return
		_answered = true
		_attempts += 1
		GameManager.puzzles_attempted += 1
		var correct: bool = (_selected == int(syn.get("correct_index", -1)))
		_last_correct = true  # the task's core steps were all solved; synthesis is graded but not gating
		if correct:
			_feedback_label.text = "✓ Correct — " + syn.get("explanation", "")
			_feedback_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
			AudioManager.play("correct")
		else:
			_feedback_label.text = "✗ " + syn.get("explanation", "")
			_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
			AudioManager.play("wrong")
		_submit_button.disabled = true
		_hint_button.disabled = true
		_back_button.text = "CONTINUE →"
		return
	if _selected < 0 or _answered:
		return
	_answered = true
	_attempts += 1
	GameManager.puzzles_attempted += 1
	var step: Dictionary = steps[_step_index]
	var correct: bool = (_selected == int(step.get("correct_index", -1)))
	if correct:
		_steps_correct += 1
		_feedback_label.text = "✓ " + step.get("explanation", "")
		_feedback_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
		AudioManager.play("correct")
		await get_tree().create_timer(0.9).timeout
		_step_index += 1
		_answered = false
		_selected = -1
		_feedback_label.text = ""
		# If this was the final step and there's no synthesis, the task is done.
		if _step_index >= steps.size() and syn.is_empty():
			_last_correct = true
			_submit_button.disabled = true
			_hint_button.disabled = true
			_back_button.text = "CONTINUE →"
		else:
			_build_options()
	else:
		# Targeted: show the ACTUAL state transition they misread.
		_feedback_label.text = "✗ " + step.get("explanation", "") + "\n\nTry again."
		_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		AudioManager.play("wrong")
		_drain_integrity(0.30)
		_selected = -1
		_submit_button.disabled = true
		_answered = false

## ── ORDER submit: per-slot validation ─────────────────────────────────
func _on_submit_order() -> void:
	var correct_order: Array = puzzle.get("correct_order", [])
	var slot_expl: Array = puzzle.get("slot_explanations", [])
	if _answered:
		return
	# All slots filled?
	for p in _order_placed:
		if p == -1:
			_feedback_label.text = "Fill every slot before checking."
			_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
			return
	_answered = true
	_attempts += 1
	GameManager.puzzles_attempted += 1
	_attempts_label.text = "ATTEMPT %d" % _attempts
	var all_correct := true
	for s in range(correct_order.size()):
		var ok: bool = (_order_placed[s] == int(correct_order[s]))
		if not ok:
			all_correct = false
			_slot_buttons[s].add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
			_slot_buttons[s].add_theme_stylebox_override("normal", _make_button_style(Color(0.2, 0.1, 0.1)))
		else:
			_slot_buttons[s].add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
			_slot_buttons[s].add_theme_stylebox_override("normal", _make_button_style(Color(0.1, 0.2, 0.15)))
	if all_correct:
		_last_correct = true
		_feedback_label.text = "✓ ACCESS GRANTED — sequence correct."
		_feedback_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
		AudioManager.play("correct")
		_submit_button.disabled = true
		_hint_button.disabled = true
		_back_button.text = "CONTINUE →"
	else:
		# Slot-level corrective feedback: explain what belongs in the first wrong slot.
		var first_wrong := -1
		for s in range(correct_order.size()):
			if _order_placed[s] != int(correct_order[s]):
				first_wrong = s
				break
		if first_wrong >= 0 and first_wrong < slot_expl.size():
			_feedback_label.text = "Slot %d is wrong — %s" % [first_wrong + 1, slot_expl[first_wrong]]
		else:
			_feedback_label.text = "Some slots are out of order — review and retry."
		_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		AudioManager.play("wrong")
		_drain_integrity(0.30)
		_answered = false
		_submit_button.disabled = false

## Drain firewall integrity. Returns true if the terminal locked (integrity 0).
func _drain_integrity(amount: float) -> bool:
	_integrity = maxf(0.0, _integrity - amount)
	_integrity_bar.value = _integrity
	# Color shift as it drains: cyan → amber → red.
	var c := Color(0.2, 0.9, 1.0)
	if _integrity < 0.5:
		c = Color(1.0, 0.6, 0.2)
	if _integrity <= 0.0:
		c = Color(1.0, 0.2, 0.2)
	var fill := _integrity_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		fill.bg_color = c
	if _integrity <= 0.0 and _level_index > 0:
		_lock_terminal()
		return true
	return false

func _lock_terminal() -> void:
	_feedback_label.text = "⚠ FIREWALL LOCKED — integrity exhausted.\nRe-approach the terminal and try again."
	_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_submit_button.disabled = true
	_hint_button.disabled = true
	AudioManager.play("wrong")
	puzzle_locked.emit()

func _on_hint() -> void:
	# Hints cost integrity — showing the nudge drains the firewall.
	if not _show_hint:
		_drain_integrity(0.15)
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
