extends "res://scripts/map/map_quest_story_controller.gd"
## Idle startup resumes only persisted dialogue; a new chapter needs a click/arrival.
var arrival_pending := false

func _ready() -> void:
	super._ready()
	if not map.startup_error.is_empty(): return
	signs = preload("res://scripts/map/map_quest_signs.gd").new()
	signs.configure(map.content.get_node("Points"),map.sign_motion)
	refresh_signs()

func refresh_signs() -> void:
	if signs!=null: signs.show_task_at(QinglanDepartureQuest.marker_points(map.loadout,map.definition.id),"main")

func record_arrival(point_id: String) -> void:
	arrival_pending = not QinglanDepartureQuest.arrival(map.loadout,map.definition.id,point_id).is_empty()
	if arrival_pending: set_process(true)

func _process(delta: float) -> void:
	# Completing main three at home merely exposes the red sign. It never chains
	# into this chapter, including a reload on the same untouched node.
	if QinglanDepartureQuest.story(map.loadout).active.is_empty() and not arrival_pending:
		set_process(false)
		return
	super._process(delta)

func try_arrival(point_id: String, _clicked := false) -> bool:
	if map.event_state.is_active(): return owns_dialogue()
	var scene := QinglanDepartureQuest.arrival(map.loadout,map.definition.id,point_id)
	if scene.is_empty(): return false
	arrival_pending = false
	begin(scene)
	return true

func present() -> void:
	var saved := QinglanDepartureQuest.story(map.loadout)
	if saved.active.is_empty(): return
	occupy(saved.active)
	map.event_state.line_index = int(saved.line)
	map._saved_loadout_revision = map.loadout.revision
	var event := QinglanDepartureQuest.event(saved.active,map.loadout)
	map.dialogue.present(event,DialogueJournal.render_text(event.lines[saved.line],map.loadout.narrative),event.line_speakers[saved.line],"dialogue",int(saved.line))

func finish() -> void:
	arrival_pending = false
	set_process(false)
	super.finish()
