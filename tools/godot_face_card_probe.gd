extends SceneTree
## Sichtprobe der SEITEN-AUSKUNFT (FaceCardView): sechs Seiten nebeneinander - Material
## normal und veredelt, keine, eine, zwei und drei Runen - und die WÜRFEL-AUSKUNFT (DieCardView)
## für sechs Würfel. Aufruf:
##   Godot --path . --resolution 1300x860 --position 4000,2400 --quit-after 300 \
##     --script tools/godot_face_card_probe.gd
## Bilder: E:/Generated Images/Fumble/seiten_auskunft/spiel_karte.png und spiel_wuerfel.png

const OUT := "E:/Generated Images/Fumble/seiten_auskunft/"
const CARD := Vector2(614, 250)

var frames := 0
var dice_layer: ColorRect

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.06, 0.08)
	back.size = Vector2(1300, 860)
	root.add_child(back)
	var cases := [
		[560, DieMaterial.AMBER, 2, [Rune.STRAY_LIGHT]],
		[7, DieMaterial.RUBY, 1, [Rune.REVERSE]],
		[3, "", 0, []],
		[7, DieMaterial.GLASS, 2, [Rune.SPARK_FLIGHT, Rune.AFTERGLOW]],
		[12, DieMaterial.COPPER, 1, [Rune.BURN_IN, Rune.SPARK_FLIGHT, Rune.STRAY_LIGHT]],
		[1450, DieMaterial.GOLD, 2, []],
	]
	for i in cases.size():
		var spec: Array = cases[i]
		var def := DieDefinition.standard()
		def.faces[0] = int(spec[0])
		if String(spec[1]) != "":
			def.set_face_material(0, spec[1])
			def.levels[0] = int(spec[2])
		if (spec[3] as Array).size() > 1:
			def.essence_id = Essence.VACUUM
		var slot := 0
		for rune_id: String in spec[3]:
			def.set_rune(0, rune_id, slot, 2)
			slot += 1
		var frame := Panel.new()
		frame.add_theme_stylebox_override("panel", TableScreen.window_style())
		frame.position = Vector2(20 + (i % 2) * (CARD.x + 30), 20 + (i / 2) * (CARD.y + 25))
		frame.size = CARD + Vector2(24, 24)
		back.add_child(frame)
		var card := FaceCardView.new()
		card.position = Vector2(12, 12)
		card.size = CARD
		frame.add_child(card)
		card.show_face(def, 0)
	_build_dice()

## Sechs ganze Würfel auf einer zweiten Ebene (wird nach dem ersten Bild gezeigt).
func _build_dice() -> void:
	dice_layer = ColorRect.new()
	dice_layer.color = Color(0.05, 0.06, 0.08)
	dice_layer.size = Vector2(1300, 860)
	dice_layer.visible = false
	root.add_child(dice_layer)
	var specs := [
		[Essence.SODIUM_VAPOR, [2, 2, 3, 5, 5, 5], {0: DieMaterial.RUBY, 3: DieMaterial.GOLD}],
		["", [1, 2, 3, 4, 5, 6], {}],
		[Essence.OZONE, [4, 4, 4, 4, 9, 9], {4: DieMaterial.GLASS, 5: DieMaterial.GLASS}],
		[Essence.VACUUM, [3, 3, 3, 3, 3, 3], {1: DieMaterial.COPPER}],
		[Essence.GAMMA_BURST, [12, 40, 75, 120, 560, 1450], {2: DieMaterial.AMBER, 5: DieMaterial.BONE}],
		[Essence.PHOTON_GAS, [1, 1, 6, 6, 6, 6], {0: DieMaterial.GOLD, 2: DieMaterial.RUBY}],
	]
	for i in specs.size():
		var spec: Array = specs[i]
		var def := DieDefinition.standard()
		def.essence_id = spec[0]
		for face in 6:
			def.faces[face] = int(spec[1][face])
		for face: int in spec[2]:
			def.set_face_material(face, spec[2][face])
		if spec[2].has(3):
			def.levels[3] = DieMaterial.MAX_LEVEL
		var frame := Panel.new()
		frame.add_theme_stylebox_override("panel", TableScreen.window_style())
		frame.position = Vector2(20 + (i % 2) * (CARD.x + 30), 20 + (i / 2) * (CARD.y + 25))
		frame.size = CARD + Vector2(24, 24)
		dice_layer.add_child(frame)
		var card := DieCardView.new()
		card.position = Vector2(12, 12)
		card.size = CARD
		frame.add_child(card)
		card.show_die(def)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 30:
		root.get_texture().get_image().save_png(OUT + "spiel_karte.png")
		dice_layer.visible = true
	if frames == 45:
		root.get_texture().get_image().save_png(OUT + "spiel_wuerfel.png")
		return true
	return false
