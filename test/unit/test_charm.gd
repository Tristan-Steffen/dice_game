extends GutTest
## Tier-1-Tests des Charm-Datensatzes und der Registrierung (Charm.all).
## "Meta"-Tests, die die Registrierung selbst absichern: vollständige Anzahl,
## eindeutige ids, gefüllte Anzeigefelder und Konsistenz zwischen id-Konstante
## und Fabrikmethode.

func test_all_returns_twenty_charms():
	assert_eq(Charm.all().size(), 20)

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
	# Jeder Charm mit gesetztem model_path (aus Charm.MODEL_FILE) muss auf eine
	# real vorhandene GLB-Datei zeigen - fängt Tippfehler im Dateinamen ab.
	for charm in Charm.all():
		if charm.model_path != "":
			assert_true(FileAccess.file_exists(charm.model_path),
				"Modell fehlt: %s (%s)" % [charm.model_path, charm.id])

func test_most_charms_have_a_model():
	# Aktuell haben 19 der 20 Charms ein eigenes Modell; nur der Glücksgroschen
	# (OLD_PENNY) fällt noch auf das Platzhaltermodell zurück (siehe CharmRowView).
	var without: Array[String] = []
	for charm in Charm.all():
		if charm.model_path == "":
			without.append(charm.id)
	assert_eq(without, [Charm.OLD_PENNY],
		"nur der Glücksgroschen sollte (noch) ohne Modell sein")

func test_instantiate_is_independent_copy():
	# DieDefinition ist eine geteilte Resource - hier stellvertretend der Vertrag,
	# dass ein Charm ein reiner Datencontainer mit stabiler id bleibt.
	var a := Charm.rabbits_foot()
	var b := Charm.rabbits_foot()
	assert_eq(a.id, b.id)
	assert_ne(a.get_instance_id(), b.get_instance_id(), "jede Fabrik liefert eine neue Instanz")
