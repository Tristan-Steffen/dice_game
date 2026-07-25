extends GutTest
## Tier-1-Tests des Charm-Datensatzes und der Registrierung (Charm.all).
## "Meta"-Tests, die die Registrierung selbst absichern: vollständige Anzahl,
## eindeutige ids, gefüllte Anzeigefelder und Konsistenz zwischen id-Konstante
## und Fabrikmethode.

func test_all_returns_all_charms():
	# 72 Charms: die 86 des Obsidian-Katalogs minus die fünf Menü-Charms
	# (Stammgast/Feinschmecker/Mitternachtssnack/Restaurantkritiker/Hausrezept),
	# die mit den Menü-Deals entfielen, minus Wechselgeld, Ausziehtisch,
	# Doppelte Perforation, Doppelte Sechs, Glücksknoten, Großformat,
	# Hausmarke, Legierung und Nachzügler.
	# +11 außerhalb des Katalogs: Beherit, Hochstapler, Prime Time, Vorreiter,
	# Hausjoker, Gratis Getränk, Rampenlicht, Midashandschuh, Goldader,
	# Blood Diamond, Knochenmark.
	assert_eq(Charm.all().size(), 83)

func test_all_ids_are_unique():
	var seen := {}
	for charm in Charm.all():
		assert_false(seen.has(charm.id), "doppelte id: %s" % charm.id)
		seen[charm.id] = true

func test_every_charm_has_filled_metadata():
	for charm in Charm.all():
		assert_ne(charm.id, "", "id fehlt")
		assert_ne(charm.display_name, "", "display_name fehlt bei %s" % charm.id)
		assert_ne(charm.description, "", "description fehlt bei %s" % charm.id)

func test_factory_id_matches_constant():
	# Stichproben: die Fabrikmethode setzt genau die zugehörige id-Konstante.
	assert_eq(Charm.rabbits_foot().id, Charm.RABBITS_FOOT)
	assert_eq(Charm.collectors_amulet().id, Charm.COLLECTORS_AMULET)
	assert_eq(Charm.con_artist_cuff().id, Charm.CON_ARTIST_CUFF)

func test_mapped_models_exist_on_disk():
	# Jeder Charm mit gesetztem model_path (Konvention: MODEL_DIR + id + ".glb",
	# siehe Charm._make) muss auf eine real vorhandene GLB-Datei zeigen.
	for charm in Charm.all():
		if charm.model_path != "":
			assert_true(FileAccess.file_exists(charm.model_path),
				"Modell fehlt: %s (%s)" % [charm.model_path, charm.id])

func test_original_charms_have_models():
	# Die 19 ursprünglichen Modelle bleiben verdrahtet; alle Effektkatalog-Charms
	# (und der Glücksgroschen) fallen bewusst auf die Platzhalter-Karte zurück
	# (siehe CharmRowView.placeholder_model).
	assert_ne(Charm.rabbits_foot().model_path, "", "Hasenpfote hat ihr Modell")
	assert_ne(Charm.horseshoe().model_path, "", "Hufeisen hat sein Modell")
	assert_eq(Charm.old_penny().model_path, "", "Glücksgroschen nutzt den Platzhalter")

func test_placeholder_model_is_a_colored_card():
	var model: Node3D = autofree(CharmRowView.placeholder_model(Charm.PENDULUM))
	var mesh_instance: MeshInstance3D = model.get_child(0)
	assert_true(mesh_instance.mesh is BoxMesh, "Platzhalter ist ein flacher Kasten")
	var other: Node3D = autofree(CharmRowView.placeholder_model(Charm.BLACKJACK))
	var color_a: Color = mesh_instance.material_override.albedo_color
	var color_b: Color = (other.get_child(0) as MeshInstance3D).material_override.albedo_color
	assert_ne(color_a, color_b, "verschiedene Charms bekommen verschiedene Kartenfarben")

func test_instantiate_is_independent_copy():
	# DieDefinition ist eine geteilte Resource - hier stellvertretend der Vertrag,
	# dass ein Charm ein reiner Datencontainer mit stabiler id bleibt.
	var a := Charm.rabbits_foot()
	var b := Charm.rabbits_foot()
	assert_eq(a.id, b.id)
	assert_ne(a.get_instance_id(), b.get_instance_id(), "jede Fabrik liefert eine neue Instanz")
