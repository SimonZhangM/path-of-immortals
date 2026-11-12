extends SceneTree

const Catalog = preload("res://scripts/entry/save_catalog.gd")
const Files = preload("res://scripts/entry/save_file.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var directory := "res://artifacts/save-location-preview/run-%d/" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(directory)
	var catalog := Catalog.new()
	var world: Dictionary = Files.read("res://data/world/world_map_locations.json")
	var cases: Dictionary = {"base.map.diecuifeng":{"name":"叠翠峰","picture":"res://assets/map-worldmap-diecuifeng.webp"}}
	for location: Dictionary in world.locations.values():
		cases[location.map_id] = {"name":location.name,"picture":location.picture}
	var snapshot := {"version":2,"board_id":"base.board.bag","placements":[],"owned_units":{}}
	for map_id: String in cases:
		snapshot.map_location = {"map_id":map_id,"point_id":map_id+".point.n01"}
		var path := directory+map_id.get_slice(".",2)+".json"
		check(Files.write(path,snapshot)==OK,"write isolated preview fixture")
		var before := FileAccess.get_sha256(path)
		var row := catalog.describe(path,3)
		check(row.readable and row.location==cases[map_id].name,"location resolves for "+map_id)
		check(row.picture==cases[map_id].picture and ResourceLoader.exists(row.picture,"Texture2D"),"preview resolves for "+map_id)
		check(FileAccess.get_sha256(path)==before,"catalogue is read-only")
	snapshot.map_location = {"map_id":"base.map.unknown","point_id":"base.map.unknown.point.n01"}
	var unknown := directory+"unknown.json"
	check(Files.write(unknown,snapshot)==OK,"write unknown-map fixture")
	check(catalog.describe(unknown,3).picture.is_empty(),"unknown map does not borrow another map image")
	snapshot.erase("map_location")
	check(Files.write(unknown,snapshot)==OK,"write legacy missing-location fixture")
	check(catalog.describe(unknown,3).picture.is_empty(),"missing location remains explicit")
	snapshot.map_location = {"map_id":"base.map.diecuifeng","point_id":"base.map.diecuifeng.point.n19"}
	var backup := directory+"backup.json"
	check(Files.write(backup+".bak",snapshot)==OK,"write backup fixture")
	check(catalog.describe(backup,3).location=="叠翠峰" and catalog.describe(backup,3).picture==cases["base.map.diecuifeng"].picture,"backup preview uses same map mapping")
	print("SAVE_LOCATION_PREVIEW: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
