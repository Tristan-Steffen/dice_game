extends GutTest
## Geister-Aufrufe aus scene_root: ruft der Koordinator eine Methode, die es an
## der Ansicht gar nicht (mehr) gibt, merkt das SONST NIEMAND - die Suite parst
## scene_root nie, und der Boot-Smoke klickt nicht. Genau so überlebte
## `die_inspector.edges_targeted()` den Kanten-Purge und stürzte erst beim
## Spielen ab.
## Geprüft wird gegen die ECHTE Methodenliste (Skript + geerbte Klasse), nicht
## gegen den Text - sonst gälte jedes add_child als Fehler.

## Handle in scene_root -> Skript der Ansicht dahinter.
const HANDLES := {
	"die_inspector": "res://scripts/ui/die_inspector_view.gd",
	"table_screen": "res://scripts/table/table_screen.gd",
	"pool_tray_view": "res://scripts/dice/dice_tray_view.gd",
	"discard_tray_view": "res://scripts/dice/dice_tray_view.gd",
	"queue_tray_view": "res://scripts/dice/dice_tray_view.gd",
	"camera_rig": "res://scripts/table/camera_rig.gd",
	"dice": "res://scripts/dice/dice_controller.gd",
	"charm_shop": "res://scripts/ui/shop_controller.gd",
	"dice_pit": "res://scripts/table/dice_tray.gd",
}

func test_scene_root_ruft_keine_geister_methoden() -> void:
	var source: String = load("res://scripts/scene_root.gd").source_code
	assert_gt(source.length(), 1000, "scene_root.gd ist lesbar")
	var missing: Array[String] = []
	for handle: String in HANDLES:
		var script: Script = load(HANDLES[handle])
		var known := _known_methods(script)
		for method in _called_methods(source, handle):
			if not known.has(method):
				missing.append("%s.%s()" % [handle, method])
	assert_eq(missing, [] as Array[String],
		"scene_root ruft Methoden, die es an der Ansicht nicht gibt")

## Alle Methodennamen, die ein Aufrufer an diesem Skript verwenden darf:
## eigene, geerbte Skript-Methoden und die der zugrunde liegenden Engine-Klasse.
func _known_methods(script: Script) -> Dictionary:
	var names := {}
	var walk := script
	while walk != null:
		for entry in walk.get_script_method_list():
			names[String(entry["name"])] = true
		walk = walk.get_base_script()
	var native := script.get_instance_base_type()
	if ClassDB.class_exists(native):
		for entry in ClassDB.class_get_method_list(native):
			names[String(entry["name"])] = true
	return names

## Methodennamen, die scene_root auf diesem Handle aufruft. Bewusst simpel:
## "handle.name(" - Zuweisungen und Property-Zugriffe interessieren hier nicht.
func _called_methods(source: String, handle: String) -> Array[String]:
	var found: Array[String] = []
	var re := RegEx.new()
	re.compile("\\b%s\\.([A-Za-z_][A-Za-z0-9_]*)\\s*\\(" % handle)
	for hit in re.search_all(source):
		var name := hit.get_string(1)
		if not found.has(name):
			found.append(name)
	return found
