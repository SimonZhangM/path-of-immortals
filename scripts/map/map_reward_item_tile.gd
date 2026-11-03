extends VBoxContainer
## Receipt presentation only: shop thumbnail, name below, task-style +quantity.
const HARMONY = preload("res://assets/fonts/HarmonyOS_Sans_SC_Regular.ttf")
var entry: Dictionary
var loadout: MapLoadoutState
var square: PanelContainer
var quantity_label: Label
var name_label: Label

func configure(record: Dictionary, edge := 152.0) -> void:
	entry = record.duplicate(true)
	name = "RewardItem"
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size.x = edge
	add_theme_constant_override("separation",17)
	square = MapItemThumbnail.create(self,entry,edge,-1,0.85)
	square.name = "RewardSquare"
	# A separate overlay keeps the badge from taking part in thumbnail layout.
	var layer := Node2D.new()
	square.add_child(layer)
	quantity_label = Label.new()
	quantity_label.name = "RewardQuantity"
	quantity_label.text = "+%d" % int(entry.get("quantity",1))
	quantity_label.mouse_filter = MOUSE_FILTER_IGNORE
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quantity_label.add_theme_font_override("font",HARMONY)
	quantity_label.add_theme_font_size_override("font_size",25)
	quantity_label.add_theme_color_override("font_color",Color.WHITE)
	var badge := StyleBoxFlat.new()
	badge.bg_color = Color(0,0,0,0.42)
	badge.set_corner_radius_all(6)
	quantity_label.add_theme_stylebox_override("normal",badge)
	var width := maxf(35,HARMONY.get_string_size(quantity_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,25).x+12)
	quantity_label.size = Vector2(width,30)
	layer.add_child(quantity_label)
	square.resized.connect(_place_quantity.bind(width))
	_place_quantity.call_deferred(width)
	name_label = Label.new()
	name_label.name = "ItemName"
	name_label.text = str(entry.get("name",""))
	name_label.mouse_filter = MOUSE_FILTER_IGNORE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var song := SystemFont.new()
	song.font_names = PackedStringArray(["SimSun","宋体","serif"])
	name_label.add_theme_font_override("font",song)
	name_label.add_theme_font_size_override("font_size",27)
	name_label.add_theme_color_override("font_color",Color("e0e3df"))
	add_child(name_label)

func _place_quantity(width: float) -> void:
	quantity_label.position = square.size-Vector2(width+5,35)

func _ready() -> void:
	ItemTooltipHost.bind(self,func(_point: Vector2): return entry.get("id",""),build_item_tooltip)

func build_item_tooltip(_for_text: String) -> Object:
	if loadout==null: return null
	var item := loadout.registry.get_item(entry.id)
	var tooltip := ItemTooltip.new()
	tooltip.configure(item,CultivationDescription.tooltip_context(loadout.knowledge,entry.id,item),-1,0,loadout.can_use_item(entry.id))
	return tooltip

func _gui_input(_event: InputEvent) -> void: accept_event()
