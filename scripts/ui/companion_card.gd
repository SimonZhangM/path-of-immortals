class_name CompanionCard
extends HBoxContainer

# Source is 1254x1314; cover the circular aperture with a small overlap under the rim.
const FRAME_STYLE := {
	"portrait_frame": "res://assets/pt000.webp",
	"portrait_window": [137.0 / 1254, 176.0 / 1314, 978.0 / 1254, 978.0 / 1314],
}
var portrait_card: PartyMemberCard
var slots: Array[TraitSlot] = []
var companion: CompanionState

func configure(manager: GameManager, member: CompanionState, side: int, index: int) -> void:
	companion = member
	add_theme_constant_override("separation", 6)
	portrait_card = PartyMemberCard.new()
	add_child(portrait_card)
	portrait_card.configure(index, member, FRAME_STYLE)
	# Trim the layout-only right padding of pt000; circle-to-circle gaps then
	# match the 14px visible gap between the two 76px skill slots.
	portrait_card.custom_minimum_size.x = 147
	for slot in 2:
		var view := TraitSlot.new()
		add_child(view)
		view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# Align visible circles, accounting for the portrait frame's asymmetric source padding.
		view.circle_offset_y = portrait_card.custom_minimum_size.y * (665.0 / 1314.0 - 0.5)
		view.icon_texture = load("res://assets/skill%02d.webp" % (index * 2 + slot + 1))
		view.configure(manager, member.traits[slot] if slot < member.traits.size() else {}, BattleSimulation.trait_key(side, index, slot))
		slots.append(view)

func _process(_delta: float) -> void:
	portrait_card.refresh(companion)
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(preload("res://scripts/ui/portrait_backdrop.tres"), Rect2(70, 4, size.x - 46, size.y - 8), false)
