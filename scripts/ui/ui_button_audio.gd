extends Node
## One presentation-only click sound for every native UI button, including
## dynamically created dialogs. It survives scene changes and paused gameplay.
signal click_played

var player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.stream = load("res://assets/click.ogg")
	player.volume_db = -4.0
	player.max_polyphony = 8
	add_child(player)
	get_tree().node_added.connect(_bind_button)
	_bind_tree(get_tree().root)

func _bind_tree(node: Node) -> void:
	_bind_button(node)
	for child in node.get_children(): _bind_tree(child)

func _bind_button(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(play_click):
		node.pressed.connect(play_click)

func play_click() -> void:
	# Native pressed excludes disabled controls and cancelled pointer presses.
	# Don't recheck disabled here: the action may already have disabled itself.
	player.play()
	click_played.emit()

func _exit_tree() -> void:
	if is_instance_valid(player): player.stop()
