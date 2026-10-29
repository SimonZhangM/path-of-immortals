extends "res://scripts/map/map_chest_observation_dialog.gd"

signal accept_requested
const CARD_SCRIPT := preload("res://scripts/map/map_chest_choice_card.gd")
const CARD_RECTS := [Rect2(854,350,562,156),Rect2(854,525,562,156)]
var selected_index := -1
var cards: Array[Control] = []
var accept_button: TextureButton
var review_button: Button
var pick_sound: AudioStreamPlayer
var warning: RichTextLabel
var _model: MapLoadoutState

func _init() -> void:
	super(true)
	name="MapChestDialog"
	accept_button=open_button
	review_button=later_button
	_label("选择一件物品",Rect2(1030,304,205,39),24,true)
	warning=RichTextLabel.new()
	warning.bbcode_enabled=true
	warning.text="选择并收取后，另一格的物品将[color=#ffda69]永久[/color]无法获得。"
	warning.scroll_active=false
	warning.mouse_filter=MOUSE_FILTER_IGNORE
	warning.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	warning.add_theme_font_override("normal_font",_kai_font)
	warning.add_theme_color_override("default_color",INK)
	warning.set_meta("source_font_size",18)
	_place(warning,Rect2(941,685,471,32))
	pick_sound=AudioStreamPlayer.new()
	preload("res://scripts/settings/game_settings.gd").ensure_audio_buses()
	pick_sound.bus="Effects"
	pick_sound.stream=GameAudio.STREAMS.pick
	pick_sound.volume_db=-4
	add_child(pick_sound)
	set_busy(false)

func present_choices(event: Dictionary, records: Array[Dictionary], categories: Dictionary, model: MapLoadoutState, error := "") -> void:
	selected_index=-1
	_model=model
	for card in cards:
		_geometry.erase(card)
		canvas.remove_child(card)
		card.queue_free()
	cards.clear()
	var copy: Dictionary=event.get("observation",{})
	heading.text=copy.get("location_name","宝箱")
	location_description.text=copy.get("result_description","")
	var illustration: String=event.get("presentation",{}).get("result_illustration","")
	location_illustration.texture=load(illustration) if not illustration.is_empty() else null
	error_label.text=error
	for index in mini(2,records.size()):
		var card: Control=CARD_SCRIPT.new()
		card.configure(records[index],categories,model)
		_place(card,CARD_RECTS[index])
		card.chosen.connect(func():select_choice(index))
		cards.append(card)
	open_label.text="请选择物品"
	set_busy(false)
	show()
	_layout()

func select_choice(index: int) -> void:
	if _busy or index<0 or index>=cards.size(): return
	selected_index=index
	for slot in cards.size(): cards[slot].set_selected(slot==index)
	open_label.text="收取 "+str(cards[index].entry.name)
	set_busy(false)
	_layout()

func set_busy(value: bool) -> void:
	_busy=value
	open_button.disabled=value or selected_index<0
	later_button.disabled=value
	for card in cards: card.busy=value
	_set_hover(open_button.is_hovered())

func _set_hover(hovered: bool) -> void:
	open_label.add_theme_color_override("font_color",Color.BLACK if hovered and not open_button.disabled else Color.WHITE)

func request_open() -> void:
	if open_button.disabled or not visible: return
	# The controller validates selection, then disables UI during the atomic claim.
	accept_requested.emit()

func _layout() -> void:
	super()
	if open_label==null or open_button==null: return
	# Retain stage-one bold FangSong, fitting unusually long item names inside the art.
	var font: Font=open_label.get_theme_font("font")
	var font_size:=open_label.get_theme_font_size("font_size")
	var width:=minf(open_button.size.x,open_button.size.y*OPEN_IDLE.get_width()/OPEN_IDLE.get_height())*0.84
	while font_size>12 and font.get_string_size(open_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width:
		font_size-=1
	open_label.add_theme_font_size_override("font_size",font_size)
