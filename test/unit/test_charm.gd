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

func test_rabbits_foot_has_a_model():
	# Der einzige bereits modellierte Charm zeigt auf sein GLB; die anderen
	# fallen (in CharmRowView) auf das Platzhaltermodell zurück.
	assert_ne(Charm.rabbits_foot().model_path, "")

func test_instantiate_is_independent_copy():
	# DieDefinition ist eine geteilte Resource - hier stellvertretend der Vertrag,
	# dass ein Charm ein reiner Datencontainer mit stabiler id bleibt.
	var a := Charm.rabbits_foot()
	var b := Charm.rabbits_foot()
	assert_eq(a.id, b.id)
	assert_ne(a.get_instance_id(), b.get_instance_id(), "jede Fabrik liefert eine neue Instanz")
