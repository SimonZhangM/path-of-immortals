extends Control
## Committed gains only. The shared battle flight never changes authoritative values.
const Flight = preload("res://scripts/ui/restore_flight.gd")
const CULTIVATION_ICON = preload("res://assets/player-status-level.webp")
var session: RefCounted
var board: Control
var progress: Control
var header: Control
var flights: Array[Control] = []

func configure(value: RefCounted, source: Control, target: Control, status_header: Control) -> void:
	session=value; board=source; progress=target; header=status_header
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	# Match the battle's 36px icon and arc at 1080p on this 1440p design canvas.
	scale=Vector2.ONE*(2560.0/1920.0)
	z_index=50
	visibility_changed.connect(_visibility_changed)
	session.reset_requested.connect(clear)
	if session.runtime!=null: session.runtime.presentation_events.connect(present)

func present(events: Array[Dictionary]) -> void:
	if not is_visible_in_tree() or session.phase!="running": return
	for event: Dictionary in events:
		if float(event.get("value",0))<=0: continue
		if event.get("target_id","")!=session.runtime.player.character_id: continue
		var target: Control
		var icon: Texture2D
		if event.get("kind","")=="cultivation_gained":
			target=progress; icon=CULTIVATION_ICON
		elif event.get("kind","")=="restore":
			var resource := str(event.get("resource",""))
			if resource not in Flight.RESOURCE_ICONS: continue
			target=header.bars.get(resource); icon=Flight.RESOURCE_ICONS[resource]
		else: continue
		if target==null or not target.is_visible_in_tree(): continue
		var origin: Vector2=board.recovery_origin(event)
		if not origin.is_finite(): continue
		var flight := Flight.new()
		add_child(flight)
		flight.configure(icon,get_global_transform_with_canvas().affine_inverse()*origin,target)
		flights.append(flight)

func _process(delta: float) -> void:
	# Like battle recovery feedback, committed flights finish in presentation time.
	for flight: Control in flights.duplicate():
		flight.advance(delta)
		if flight.elapsed>=Flight.DURATION:
			flights.erase(flight)
			flight.queue_free()

func _visibility_changed() -> void:
	if not is_visible_in_tree(): clear()

func clear() -> void:
	for flight: Control in flights:
		flight.hide()
		flight.queue_free()
	flights.clear()
