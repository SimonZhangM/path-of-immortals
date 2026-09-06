class_name DebugLogger
extends RefCounted

static var simulation_enabled: bool = false

static func info(message: String) -> void:
	print("[INFO] " + message)

static func content(message: String) -> void:
	print("[CONTENT] " + message)

static func warning(message: String) -> void:
	push_warning("[WARNING] " + message)

static func error(message: String) -> void:
	push_error("[ERROR] " + message)

static func simulation(message: String) -> void:
	if simulation_enabled:
		print("[SIMULATION] " + message)
