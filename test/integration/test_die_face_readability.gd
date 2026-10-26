extends GutTest
## Lesbarkeit der Seiten auf Essenz-Würfeln. Das Urteil über das Aussehen fällt
## der Playtest; hier steht die Struktur. Die dunkle Fassung am Flächenrand ist
## am 2026-10-25 gestrichen - das Material füllt seither die ganze Seite.

# --- Kein additives Licht über den Flächen -------------------------------------------

func test_no_additive_layer_floats_over_the_faces() -> void:
	# Die Fresnel-Hülle ist gestrichen und darf nicht zurückkommen: eine
	# Leuchtfolie knapp über dem Körper hat nur zwei Fehler zur Wahl -
	# deckungsgleich flimmert ihr Tiefentest, abgehoben steht ihr Rand in der
	# Luft und liest sich als abgelöste Seite. Licht nur auf echter Geometrie.
	var die: Node3D = autofree(DieBuilder.build())
	var faces: DieFaceDisplay = die.get_node("RigidBody3D/Faces")
	assert_null(faces.get_node_or_null("FresnelShell"), "keine Hülle über dem Körper")
	for visual in faces.find_children("*", "MeshInstance3D", true, false):
		var material: Material = (visual as MeshInstance3D).material_override
		if material is BaseMaterial3D:
			assert_ne((material as BaseMaterial3D).blend_mode, BaseMaterial3D.BLEND_MODE_ADD,
				"%s liegt nicht additiv über dem Würfel" % visual.name)

