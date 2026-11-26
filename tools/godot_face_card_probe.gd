extends SceneTree
## Sichtprobe der SEITEN-AUSKUNFT (FaceCardView): sechs Seiten nebeneinander - Material
## normal und veredelt, keine, eine, zwei und drei Runen. Aufruf:
##   Godot --path . --resolution 1300x860 --position 4000,2400 --quit-after 300 \
##     --script tools/godot_face_card_probe.gd
## Bild: E:/Generated Images/Fumble/seiten_auskunft/spiel_karte.png

const OUT := "E:/Generated Images/Fumble/seiten_auskunft/"
const CARD := Vector2(614, 250)

var frames := 0

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

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 30:
		root.get_texture().get_image().save_png(OUT + "spiel_karte.png")
		return true
	return false
