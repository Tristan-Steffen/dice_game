class_name ComboRowView
extends Node3D
## Eine Zeile der Tisch-Kombinationsliste als PIKTOGRAMM statt Text: die
## Beispiel-Würfel der Kombination (siehe DiceScoring.EXAMPLE_DICE - Full House
## z.B. als 6 6 6 1 1) als kleine weiße Würfelplättchen mit Augenzahl, dahinter
## der Multiplikator "×N". Ersetzt zur Laufzeit die Text-Label3D der Szene
## (siehe scene_root._collect_combo_labels; die Szenen-Labels bleiben als
## unsichtbare Autoren-Anker für Position/Größe/Ebene bestehen).
##
## modulate bündelt die Ruhe-/Glüh-Farbe der ganzen Zeile (alle Plättchen
## teilen EIN unshaded-Material, der Multiplikator sein Label3D-modulate; die
## Ziffern bleiben dunkel lesbar) - dieselben Tweens wie früher auf
## Label3D.modulate funktionieren dadurch unverändert (siehe
## scene_root._tween_combo_label; Überhell-Farben > 1 lassen die Zeile glühen).

const DIE_SIZE := 0.72       # Kantenlänge eines Würfelplättchens (Zeilen-lokal)
const DIE_STEP := 0.8        # Abstand der Plättchen-Mitten
const DIGIT_FONT_SIZE := 46
const MULT_FONT_SIZE := 60   # wie die alten Text-Zeilen (siehe Szene)
const MULT_GAP := 0.4        # Abstand letztes Plättchen -> "×N"
const INK := Color(0.13, 0.12, 0.1)  # Ziffern-"Druckfarbe" auf den Plättchen
## Die Plättchen-FLÄCHE übernimmt die Zeilenfarbe gedimmt: volle Überhelligkeit
## (siehe scene_root.PAYOUT_LABEL_BASE_COLOR) lässt solide Quads viel stärker
## blühen als Textglyphen und überstrahlt die Ziffern. Ruhe ≈ neutralweiß,
## das Gold-Highlight glüht trotzdem noch deutlich.
const BODY_DIM := 0.74

var body_material: StandardMaterial3D
var mult_label: Label3D
## Szenen-Scale des ersetzten Anker-Labels - Bezugsgröße fürs Highlight-Wachsen
## (siehe scene_root._tween_combo_label: base_scale × Faktor statt absolut).
var base_scale := Vector3.ONE

var modulate: Color = Color.WHITE:
	set(value):
		modulate = value
		if body_material != null:
			body_material.albedo_color = Color(value.r * BODY_DIM, value.g * BODY_DIM, value.b * BODY_DIM, value.a)
		if mult_label != null:
			mult_label.modulate = value

## Baut die Zeile: je Beispiel-Wert ein Plättchen mit Ziffer, dahinter "×mult".
func setup(values: Array, mult: int) -> void:
	body_material = StandardMaterial3D.new()
	body_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body_material.albedo_color = modulate
	var quad_mesh := QuadMesh.new()
	quad_mesh.size = Vector2.ONE * DIE_SIZE

	for i in values.size():
		var quad := MeshInstance3D.new()
		quad.mesh = quad_mesh
		quad.material_override = body_material
		quad.position = Vector3(DIE_SIZE * 0.5 + i * DIE_STEP, 0, 0)
		add_child(quad)

		var digit := Label3D.new()
		digit.text = str(values[i])
		digit.font_size = DIGIT_FONT_SIZE
		digit.modulate = INK
		digit.position = Vector3(0, 0, 0.01)  # knapp vor dem Plättchen (kein z-fighting)
		digit.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
		quad.add_child(digit)

	mult_label = Label3D.new()
	mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	mult_label.font_size = MULT_FONT_SIZE
	mult_label.outline_size = 10
	mult_label.modulate = modulate
	mult_label.position = Vector3(values.size() * DIE_STEP - (DIE_STEP - DIE_SIZE) * 0.5 + MULT_GAP, 0, 0)
	add_child(mult_label)
	set_mult(mult)

## Schreibt den Multiplikator neu (Menü-Stufen, siehe DiceScoring.mult_for).
func set_mult(mult: int) -> void:
	mult_label.text = "×%d" % mult
