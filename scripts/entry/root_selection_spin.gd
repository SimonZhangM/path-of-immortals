extends Node
## Presentation only. The future random button supplies a result, not probabilities.
signal finished(element_ids: Array[String])

const DURATION := 1.0
const FPS := 30
const STEPS := int(DURATION * FPS)
var active := false
var frame := 0
var _core: TextureRect
var _effects: Control
var _pending: Array[String] = []
var _previous: Array[String] = []
var _started_usec := 0
var _pivot_uv := Vector2.ZERO

func _ready() -> void:
	set_process(false)

func configure(core: TextureRect, effects: Control, pivot_uv: Vector2) -> void:
	_core = core
	_effects = effects
	_pivot_uv = pivot_uv
	if not _core.resized.is_connected(_update_pivot):
		_core.resized.connect(_update_pivot)
	_update_pivot()

func _update_pivot() -> void:
	_core.pivot_offset = _core.size * _pivot_uv

func start(element_ids: Array) -> bool:
	if active or _effects == null or element_ids.is_empty(): return false
	if not _effects.accepts_roots(element_ids): return false
	_pending.clear()
	for id: String in element_ids:
		if not _pending.has(id): _pending.append(id)
	_previous = _effects.get_selected_roots()
	_effects.clear_selection()
	frame = 0
	_core.rotation = 0.0
	active = true
	_started_usec = Time.get_ticks_usec()
	set_process(true)
	return true

func _process(_delta: float) -> void:
	_advance_elapsed(float(Time.get_ticks_usec() - _started_usec) / 1000000.0)

func _advance_elapsed(seconds: float) -> void:
	if not active: return
	# Quantized 30 Hz pose, with elapsed time preventing slow frames from extending the turn.
	frame = clampi(int(floor(seconds * FPS)), 0, STEPS)
	_core.rotation = TAU * float(frame) / STEPS
	if seconds < DURATION: return
	active = false
	set_process(false)
	_core.rotation = 0.0
	_effects.set_selected_roots(_pending)
	finished.emit(_effects.get_selected_roots())

func cancel() -> void:
	if not active: return
	active = false
	set_process(false)
	_core.rotation = 0.0
	_effects.set_selected_roots(_previous)
	_pending.clear()
