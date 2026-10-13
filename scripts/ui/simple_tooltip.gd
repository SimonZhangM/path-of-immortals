extends RefCounted
## 简易悬浮效果：日期同款深色紧凑原生文字提示，不用于物品详情浮层。
## 显式指定 TooltipPanel / TooltipLabel，避免宿主主题的空面板和正文字体影响。
static func apply(control: Control) -> void:
	var local_theme: Theme = control.theme.duplicate() if control.theme != null else Theme.new()
	var reference := ThemeDB.get_default_theme()
	local_theme.set_stylebox("panel", "TooltipPanel", reference.get_stylebox("panel", "TooltipPanel"))
	local_theme.set_font("font", "TooltipLabel", reference.get_font("font", "TooltipLabel"))
	local_theme.set_font_size("font_size", "TooltipLabel", reference.get_font_size("font_size", "TooltipLabel"))
	for key in reference.get_color_list("TooltipLabel"):
		local_theme.set_color(key, "TooltipLabel", reference.get_color(key, "TooltipLabel"))
	for key in reference.get_constant_list("TooltipLabel"):
		local_theme.set_constant(key, "TooltipLabel", reference.get_constant(key, "TooltipLabel"))
	control.theme = local_theme
