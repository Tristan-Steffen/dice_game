extends GutTest
## Der PROJEKTOR eines Charm-Platzes im Laden (2026-11-20): belegt projiziert er ein
## kleines Hologramm und nennt den Preis, verkauft ist er dunkel; die Diskette steckt.

var projector: CharmProjectorView

func before_each() -> void:
	projector = CharmProjectorView.new()
	add_child_autofree(projector)

func test_empty_projector_is_dark_and_silent() -> void:
	projector.set_price("$5")
	assert_eq(projector.glow_color(), CharmReaderView.DARK)
	assert_eq(projector.price_text(), "", "ohne Charm kein Preis")
	assert_null(projector.holo)

func test_loaded_projector_shows_a_small_hologram_and_the_price() -> void:
	projector.set_charm(Charm.broken_mirror())
	projector.set_price("$7")
	assert_not_null(projector.holo)
	assert_lt(projector.holo.scale.x, CharmRowView.MODEL_SCALE, "kleiner als in der Reihe")
	assert_eq(projector.price_text(), "$7")
	var rest := projector.glow_color()
	projector.set_hovered(true)
	assert_gt(projector.glow_color().r + projector.glow_color().g + projector.glow_color().b,
		rest.r + rest.g + rest.b, "der Zeiger hebt das Leuchten")

func test_sold_projector_drops_its_hologram() -> void:
	projector.set_charm(Charm.rabbits_foot())
	projector.set_charm(null)
	assert_null(projector.holo)
	assert_eq(projector.glow_color(), CharmReaderView.DARK)

func test_disk_and_bridge_fit_the_disk_seat() -> void:
	var center := Vector3(3.0, 0.0, -2.0)
	projector.global_position = CharmProjectorView.origin_for(center)
	var disk := projector.disk_global_transform().origin
	var front := disk.x - CharmDiskView.SIZE.x * 0.5
	var back := projector.global_position.x + CharmProjectorView.DEPTH * 0.5
	assert_almost_eq((front + back) * 0.5, center.x, 0.05, "mittig auf dem Stellplatz")
	assert_lt(back - front, CharmDiskView.SIZE.x * 1.03, "kaum länger als die Diskette")
	assert_almost_eq(back - (disk.x + CharmDiskView.SIZE.x * 0.5),
		CharmProjectorView.BACK + CharmProjectorView.AIR, 0.001, "nur der Schieber steckt")
	assert_lt(projector.mouth_global_transform().origin.x + CharmDiskView.SIZE.x * 0.5,
		projector.global_position.x - CharmProjectorView.DEPTH * 0.5 + 0.001, "vor dem Schlitz ist sie frei")
