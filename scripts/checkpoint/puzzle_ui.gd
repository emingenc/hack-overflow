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
var _pool_buttons: Array[Button] = []
# Firewall integrity: wrong answer -30%, hint -15%; at 0 the terminal locks
# (level_index 0 never locks — forgiving first sector).
var _integrity: float = 1.0
var _level_index: int = 0
var _integrity_bar: ProgressBar
var _assisted: bool = false  # true if solved via integrity-exhaustion reveal
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

	# Centered panel — sized responsively to the viewport so it never overflows
	# on phones (landscape or portrait).
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	var vp := get_viewport().get_visible_rect().size
	var pw := minf(760.0, vp.x * 0.92)
	var ph := minf(560.0, vp.y * 0.90)
	_panel.custom_minimum_size = Vector2(pw, ph)
	_panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 28)
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
	integ_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
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
	integ_style.border_color = Color(0.2, 0.6, 0.3, 0.5)
	integ_style.set_border_width_all(1)
	integ_style.set_corner_radius_all(4)
	_integrity_bar.add_theme_stylebox_override("background", integ_style)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 1.0, 0.4)
	fill_style.set_corner_radius_all(4)
	_integrity_bar.add_theme_stylebox_override("fill", fill_style)
	integ_row.add_child(_integrity_bar)

	var hline := HSeparator.new()
	vbox.add_child(hline)

	# Problem description — a plain RichTextLabel. (A ScrollContainer wrapper
	# collapses the label to zero size and hides the question entirely.)
	_desc_label = RichTextLabel.new()
	# BBCode OFF — DSA text is full of square brackets ([i], [start_i, end_i],
	# [0,1], [lo,hi]) which BBCode would parse as tags and silently drop.
	_desc_label.bbcode_enabled = false
	_desc_label.scroll_active = true
	_desc_label.custom_minimum_size = Vector2(0, 220)
	_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# CRITICAL: wrap the problem text or it clips past the panel edge on phones.
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("normal_font_size", 21)
	_desc_label.add_theme_color_override("default_color", Color(0.85, 1.0, 0.7))
	vbox.add_child(_desc_label)

	# Options — wrapped in a scroll area so tall ORDER layouts don't push the
	# panel (and the submit/exit buttons) below the fold on short screens.
	var options_scroll := ScrollContainer.new()
	options_scroll.custom_minimum_size = Vector2(0, 200)
	options_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	options_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(options_scroll)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 8)
	_options_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_scroll.add_child(_options_box)

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
	_feedback_label.add_theme_font_size_override("font_size", 16)
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
	sb.bg_color = Color(0.04, 0.09, 0.05, 0.97)
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

## Strip markdown backticks (code quotes) — meaningless in a plain text label.
func _clean_text(s: String) -> String:
	return s.replace("`", "")

## Record mastery on solve: 3 first-try, 2 with hint, 1 assisted.
func _record_solved() -> void:
	var stars := 3
	if _assisted:
		stars = 1
	elif _show_hint:
		stars = 2
	var pid: String = str(puzzle.get("id", ""))
	if pid != "":
		GameManager.record_solve(pid, stars)

func show_puzzle(data: Dictionary, level_index: int = 0) -> void:
	puzzle = data
	_level_index = level_index
	_integrity = 1.0
	_integrity_bar.value = _integrity
	_assisted = false
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
	_update_egg_active = false
	_update_egg_bar = null
	_kill_button = null
	_title_label.text = "> " + puzzle.title
	_difficulty_label.text = puzzle.difficulty
	_difficulty_label.add_theme_color_override("font_color",
		Color(0.6, 1.0, 0.6) if puzzle.difficulty == "EASY" else Color(1.0, 0.8, 0.4))
	_attempts_label.text = ""
	_desc_label.text = _clean_text(puzzle.description)
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
	_submit_button.disabled = true
	match _task_type:
		"trace":
			_build_trace_step()
		"order":
			_build_order()
		"restart":
			_build_restart()
		"windows_update":
			_build_windows_update()
		_:
			_build_mcq()

## ── EASTER EGG: "have you tried turning it off and on again?" ────────
func _build_restart() -> void:
	# No answer options. The ONLY correct move is the REBOOT button.
	_submit_button.text = "REBOOT SYSTEM"
	_submit_button.disabled = false
	_submit_button.pressed.connect(_on_reboot_pressed, CONNECT_ONE_SHOT)
	_hint_button.disabled = true
	_back_button.text = "ABANDON"
	_feedback_label.text = "It's not a bug — it's a feature. Probably."

func _on_reboot_pressed() -> void:
	# Restart literally IS the solution: reload the level, preserve progress
	# (GameManager already persisted mastery), and mark this puzzle solved.
	_assisted = false
	_last_correct = true
	_record_solved()
	_feedback_label.text = "✓ REBOOTING…\n\n…and it worked. Of course it worked."
	_feedback_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	AudioManager.play("correct")
	_submit_button.disabled = true
	_back_button.text = "CONTINUE →"
	_back_button.disabled = false

## ── EASTER EGG: "Windows Update" (never finishes) ─────────────────────
func _build_windows_update() -> void:
	# A fake progress bar that crawls toward 99% and hangs forever.
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 0
	bar.show_percentage = true
	bar.custom_minimum_size = Vector2(0, 28)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options_box.add_child(bar)
	_update_egg_bar = bar
	_update_egg_t = 0.0
	_update_egg_active = true

	# The real solve: a hidden "force stop" (Ctrl+C) button disguised as terminal text.
	_submit_button.text = "DON'T TURN OFF YOUR PC"
	_submit_button.disabled = true

	# A subtle kill switch appears as a tiny terminal prompt button.
	var kill := Button.new()
	kill.text = "> _  (press to force-quit wuauserv.exe)"
	kill.alignment = HORIZONTAL_ALIGNMENT_LEFT
	kill.custom_minimum_size = Vector2(0, 40)
	kill.add_theme_font_size_override("font_size", 14)
	kill.pressed.connect(_on_kill_update, CONNECT_ONE_SHOT)
	_options_box.add_child(kill)
	_kill_button = kill
	_back_button.text = "EXIT TERMINAL"
	_hint_button.disabled = true

var _update_egg_bar: ProgressBar = null
var _update_egg_t: float = 0.0
var _update_egg_active: bool = false
var _kill_button: Button = null

func _process(delta: float) -> void:
	# Drive the Windows Update fake progress bar toward an eternal 99%.
	if _update_egg_active and _update_egg_bar:
		_update_egg_t += delta
		var v: float = minf(99.0, _update_egg_bar.value + delta * 6.0)
		if v >= 99.0:
			# Hang at 99%: occasionally tick to 99%, never 100%.
			v = 99.0
			_update_egg_active = false
			_feedback_label.text = "Still working on updates…"
		_update_egg_bar.value = v

func _on_kill_update() -> void:
	_assisted = false
	_last_correct = true
	_record_solved()
	_update_egg_active = false
	if _update_egg_bar:
		_update_egg_bar.value = 100
	_feedback_label.text = "✓ wuauserv.exe terminated.\n\nUpdate cancelled. Freedom."
	_feedback_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	AudioManager.play("correct")
	_submit_button.disabled = true
	if _kill_button:
		_kill_button.disabled = true
	_back_button.text = "CONTINUE →"
	_back_button.disabled = false

func _build_mcq() -> void:
	for i in range(puzzle.options.size()):
		var btn := _make_option_button(puzzle.options[i], i)
		btn.pressed.connect(_on_option_pressed.bind(i))
		_options_box.add_child(btn)

func _make_option_button(text: String, i: int) -> Button:
	var btn := Button.new()
	btn.text = "  [%s]  %s" % [String.chr(65 + i), text]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 44)
	btn.add_theme_font_size_override("font_size", 18)
	# No per-button style overrides — inherit the global theme's Kenney 9-slice
	# buttons for a consistent professional look.
	return btn

## ── TRACE: dry-run a sequence of steps ───────────────────────────────
func _build_trace_step() -> void:
	var steps: Array = puzzle.get("steps", [])
	if _step_index >= steps.size():
		# All steps done → optional synthesis capstone question.
		var syn: Dictionary = puzzle.get("synthesis", {})
		if not syn.is_empty():
			_desc_label.text = _clean_text(syn.get("question", ""))
			_submit_button.text = "SUBMIT ANSWER"
			for i in range(syn.get("options", []).size()):
				var btn := _make_option_button(syn["options"][i], i)
				btn.pressed.connect(_on_option_pressed.bind(i))
				_options_box.add_child(btn)
			_submit_button.disabled = true
		return
	var step: Dictionary = steps[_step_index]
	# State readout + question — KEEP the original problem/input visible so the
	# learner can reason about the dry-run without holding it all in memory.
	_desc_label.text = _clean_text(puzzle.description) + "\n\nSTATE: " + step.get("state", "") + "\n\n" + _clean_text(step.get("question", ""))
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
	# Single column: SCRAMBLED pool on top, numbered slots below.
	var pool_label := Label.new()
	pool_label.text = "TAP A SCRAMBLED STEP TO PLACE IT IN THE NEXT SLOT:"
	pool_label.add_theme_font_size_override("font_size", 14)
	pool_label.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5))
	pool_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_options_box.add_child(pool_label)

	_pool_buttons = []
	for i in range(shuffled.size()):
		var btn := _make_order_step_button(shuffled[i])
		btn.pressed.connect(_on_order_pool_pressed.bind(i))
		_options_box.add_child(btn)
		_pool_buttons.append(btn)

	var slot_label := Label.new()
	slot_label.text = "SEQUENCE:"
	slot_label.add_theme_font_size_override("font_size", 14)
	slot_label.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5))
	_options_box.add_child(slot_label)

	_slot_buttons = []
	for s in range(correct.size()):
		var btn := Button.new()
		btn.text = "%d.  [ empty ]" % (s + 1)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 52)
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_stylebox_override("normal", _make_button_style(Color(0.08, 0.1, 0.2)))
		btn.add_theme_stylebox_override("hover", _make_button_style(Color(0.12, 0.16, 0.3)))
		btn.pressed.connect(_on_order_slot_pressed.bind(s))
		_options_box.add_child(btn)
		_slot_buttons.append(btn)
	_submit_button.text = "CHECK SEQUENCE"

func _make_order_step_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = "  " + text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 52)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_stylebox_override("normal", _make_button_style(Color(0.12, 0.16, 0.35)))
	btn.add_theme_stylebox_override("hover", _make_button_style(Color(0.16, 0.22, 0.45)))
	return btn

func _on_order_pool_pressed(step_idx: int) -> void:
	# Prevent duplicate placement: a step already placed can't be re-placed.
	if _order_placed.has(step_idx):
		return
	# Place this step into the first empty slot.
	for s in range(_order_placed.size()):
		if _order_placed[s] == -1:
			_order_placed[s] = step_idx
			_refresh_order_slots()
			_refresh_order_pool()
			_submit_button.disabled = false
			return

func _on_order_slot_pressed(slot: int) -> void:
	if _order_placed[slot] != -1:
		_order_placed[slot] = -1  # pull back out
		_refresh_order_slots()
		_refresh_order_pool()

func _refresh_order_pool() -> void:
	# Dim (disable) pool steps that are already placed.
	for i in range(_pool_buttons.size()):
		var placed: bool = _order_placed.has(i)
		_pool_buttons[i].disabled = placed
		_pool_buttons[i].modulate = Color(0.5, 0.5, 0.5) if placed else Color(1, 1, 1)

func _refresh_order_slots() -> void:
	var shuffled: Array = puzzle.get("shuffled_steps", [])
	for s in range(_slot_buttons.size()):
		var idx: int = _order_placed[s]
		if idx == -1:
			_slot_buttons[s].text = "%d.  [ empty ]" % (s + 1)
			_slot_buttons[s].add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
		else:
			_slot_buttons[s].text = "%d.  %s" % [s + 1, shuffled[idx]]
			_slot_buttons[s].add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))

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
	if str(puzzle.get("id", "")) != "":
		GameManager.record_attempt(str(puzzle["id"]))
	_attempts_label.text = "ATTEMPT %d" % _attempts
	var correct: bool = (_selected == int(puzzle.correct_index))
	_last_correct = correct
	if correct:
		_record_solved()
		_feedback_label.text = "✓ ACCESS GRANTED\n\n" + puzzle.explanation
		_feedback_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
		AudioManager.play("correct")
		for i in range(_options_box.get_child_count()):
			var btn := _options_box.get_child(i) as Button
			var is_correct: bool = (i == int(puzzle.correct_index))
			btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6) if is_correct else Color(0.45, 0.55, 0.45))
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
		_record_solved()
		if correct:
			_feedback_label.text = "✓ Correct — " + syn.get("explanation", "")
			_feedback_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
			AudioManager.play("correct")
		else:
			_feedback_label.text = "✗ " + syn.get("explanation", "")
			_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
			AudioManager.play("wrong")
			_drain_integrity(0.30)
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
			_record_solved()
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
		_record_solved()
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

## Drain firewall integrity. At 0, convert the failure into a teaching moment:
## reveal the worked answer, mark the task "solved with assistance" (reduced
## reward), and let the player continue — never a dead-end softlock.
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
	if _integrity <= 0.0:
		_reveal_assisted()
		return true
	return false

## Teaching moment instead of a softlock: reveal the correct answer + worked
## explanation, mark assisted (reduced reward), emit completion as success.
func _reveal_assisted() -> void:
	_assisted = true
	_last_correct = true
	_record_solved()
	# Build a worked explanation: prefer a top-level explanation; for trace
	# tasks, show the current step's explanation (the moment they got stuck).
	var expl: String = str(puzzle.get("explanation", ""))
	if expl == "":
		var steps: Array = puzzle.get("steps", [])
		if _step_index < steps.size():
			expl = str(steps[_step_index].get("explanation", "Review the step and try again."))
	_feedback_label.text = "⚠ FIREWALL BREACHED — integrity exhausted.\n\n" + expl + "\n\n[solved with assistance — reduced reward]"
	_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	_submit_button.disabled = true
	_hint_button.disabled = true
	_back_button.text = "CONTINUE →"
	_back_button.disabled = false
	AudioManager.play("wrong")

func _lock_terminal() -> void:
	# Legacy path — kept for safety; new behavior is _reveal_assisted (no softlock).
	_feedback_label.text = "⚠ FIREWALL LOCKED — integrity exhausted.\nRe-approach the terminal and try again."
	_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_submit_button.disabled = true
	_hint_button.disabled = true
	AudioManager.play("wrong")
	puzzle_locked.emit()

func _on_hint() -> void:
	# Ignore hint taps during the brief correct-answer flash (answer in flight).
	if _answered:
		return
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
