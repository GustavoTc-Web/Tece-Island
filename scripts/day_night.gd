class_name DayNightCycle
extends CanvasModulate

signal time_changed(day: int, phase: String)
signal clock_changed(day: int, phase: String, remaining: int)

@export_range(1.0, 3600.0) var day_duration: float = 300.0
@export_range(1.0, 3600.0) var night_duration: float = 300.0
@export var transition_duration: float = 30.0
@export_range(0.1, 120.0) var time_scale: float = 1.0
@export var night_color := Color(0.45, 0.52, 0.68)
var elapsed: float = 0.0
var day_number: int = 1
var phase: String = "Dia"
var remaining_seconds := -1
var local_darkness := false


func _ready() -> void:
	refresh()


func _physics_process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if get_tree().paused:
		return
	elapsed += delta * time_scale
	refresh()


func is_night() -> bool:
	return fmod(elapsed, day_duration + night_duration) >= day_duration


func sleep_until_dawn() -> void:
	if not is_night() or get_tree().paused:
		return
	elapsed = (floorf(elapsed / (day_duration + night_duration)) + 1) * (day_duration + night_duration)
	refresh()


func refresh() -> void:
	var position := fmod(elapsed, day_duration + night_duration)
	var next_day := floori(elapsed / (day_duration + night_duration)) + 1
	var transition := maxf(0.01, minf(transition_duration, minf(day_duration, night_duration) * 0.5))
	var darkness: float = 0.0
	var next_phase := "Dia"
	if position < day_duration:
		if position >= day_duration - transition:
			next_phase = "Anoitecer"
			darkness = smoothstep(day_duration - transition, day_duration, position)
	else:
		next_phase = "Noite"
		darkness = 1.0
		if position >= day_duration + night_duration - transition:
			next_phase = "Amanhecer"
			darkness = 1.0 - smoothstep(day_duration + night_duration - transition, day_duration + night_duration, position)
	color = Color.WHITE.lerp(night_color, 1.0 if local_darkness else darkness)
	var remaining := ceili((day_duration if position < day_duration else day_duration + night_duration) - position)
	var clock_modified := remaining != remaining_seconds or next_phase != phase or next_day != day_number
	var phase_modified := next_day != day_number or next_phase != phase
	# Publish a consistent clock, including a restored day with the same phase
	# and remaining seconds. HUD callbacks may inspect the cycle immediately.
	day_number = next_day
	phase = next_phase
	remaining_seconds = remaining
	if clock_modified: clock_changed.emit(day_number, phase, remaining)
	if phase_modified: time_changed.emit(day_number, phase)
