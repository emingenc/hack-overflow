extends Node
## AudioManager — procedural 8-bit SFX generated at runtime (no external files).

var _buses: Dictionary = {}

## Master volume for SFX.
var sfx_volume: float = 0.8

var _music_player: AudioStreamPlayer

func _ready() -> void:
	# Create buses: SFX and Music
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx == -1:
		AudioServer.add_bus()
		sfx_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(sfx_idx, "SFX")
	var music_idx := AudioServer.get_bus_index("Music")
	if music_idx == -1:
		AudioServer.add_bus()
		music_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_idx, "Music")

	# Cache a few synthesized samples.
	_buses["jump"] = _synth_square(0.25, 320.0, 660.0)
	_buses["double_jump"] = _synth_square(0.3, 500.0, 900.0)
	_buses["dash"] = _synth_sweep(0.22, 900.0, 240.0)
	_buses["land"] = _synth_noise(0.08, 0.4)
	_buses["hurt"] = _synth_square(0.35, 200.0, 90.0)
	_buses["death"] = _synth_square(0.6, 400.0, 60.0)
	_buses["chip"] = _synth_square(0.12, 880.0, 1320.0)
	_buses["checkpoint"] = _synth_square(0.45, 523.0, 1046.0)
	_buses["correct"] = _synth_square(0.3, 660.0, 990.0)
	_buses["wrong"] = _synth_square(0.4, 220.0, 140.0)
	_buses["unlock"] = _synth_square(0.6, 392.0, 784.0)
	_buses["ui"] = _synth_square(0.08, 700.0, 700.0)

	# Looping cyberpunk chiptune.
	_start_music()

## Simple looping 8-bit arpeggio bassline on the Music bus.
func _start_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.volume_db = -10.0
	_music_player.stream = _make_loop()
	add_child(_music_player)
	_music_player.play()

func _exit_tree() -> void:
	# Free the looping music player to avoid ObjectDB leak warnings at exit.
	if _music_player and is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.stream = null
		_music_player.free()
		_music_player = null
	# Release cached SFX samples.
	_buses.clear()

func _make_loop() -> AudioStreamWAV:
	var rate := 22050
	var loop_seconds := 3.2
	var frames := int(loop_seconds * rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	# Bass arpeggio: A2, C3, E3, A3 (minor), at 8th-note pace.
	var notes: Array[float] = [110.0, 130.81, 164.81, 220.0, 164.81, 130.81, 110.0, 98.0]
	var step := 0.2  # seconds per note
	for i in range(frames):
		var t := float(i) / float(rate)
		var note_idx := int(t / step) % notes.size()
		var freq: float = notes[note_idx]
		var phase := fmod(t * freq, 1.0)
		var sample := 1.0 if phase < 0.5 else -1.0
		# Simple decay envelope within each note.
		var in_note := fmod(t, step) / step
		var env := 1.0 - in_note * 0.7
		var amp := int((sample * env) * 0.18 * 32767)
		data[i * 2] = amp & 0xFF
		data[i * 2 + 1] = (amp >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frames
	return wav

func play(sound_name: String, volume_db: float = 0.0) -> void:
	if not _buses.has(sound_name):
		return
	var ap := AudioStreamPlayer.new()
	ap.stream = _buses[sound_name]
	ap.bus = "SFX"
	ap.volume_db = volume_db
	add_child(ap)
	ap.play()
	ap.finished.connect(func() -> void: ap.queue_free())

## Square wave from f_start to f_end (linear glide).
func _synth_square(duration: float, f_start: float, f_end: float) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(duration * rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var phase := 0.0
	for i in range(frames):
		var t := float(i) / float(frames)
		var freq := lerpf(f_start, f_end, t)
		phase += freq / float(rate)
		var sample := 1.0 if (fmod(phase, 1.0) < 0.5) else -1.0
		var envelope := 1.0 - (float(i) / float(frames)) * 0.85
		var amp := int((sample * envelope) * 0.35 * 32767)
		data[i * 2] = amp & 0xFF
		data[i * 2 + 1] = (amp >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

## Frequency sweep (no square) for whooshy effects.
func _synth_sweep(duration: float, f_start: float, f_end: float) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(duration * rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var phase := 0.0
	for i in range(frames):
		var t := float(i) / float(frames)
		var freq := lerpf(f_start, f_end, t)
		phase += freq / float(rate)
		var sample := sin(phase * TAU)
		var envelope := 1.0 - float(i) / float(frames)
		var amp := int((sample * envelope) * 0.3 * 32767)
		data[i * 2] = amp & 0xFF
		data[i * 2 + 1] = (amp >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav

## Short noise burst (impact).
func _synth_noise(duration: float, amp_scale: float = 1.0) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(duration * rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var sample := randf_range(-1.0, 1.0)
		var envelope := 1.0 - float(i) / float(frames)
		var amp := int((sample * envelope) * 0.4 * amp_scale * 32767)
		data[i * 2] = amp & 0xFF
		data[i * 2 + 1] = (amp >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
