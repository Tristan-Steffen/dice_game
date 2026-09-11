extends GutTest
## DER TURM der Werkstatt: sechs Etagen übereinander, Etage 1 UNTEN, die Kontakte
## nach Bild-rechts in der KONTAKTLEISTE. Aus der KAMMER am Fuß steigt das
## DURCHLICHT. Reine Anzeige - die Maße kommen von außen, seat() ist idempotent.

const SEAT := Vector3(-4.0, 0.0, 9.0)
const SPAN := Vector2(2.6, 4.2)

var tower: TowerView

func before_each() -> void:
	tower = TowerView.new()
	add_child_autofree(tower)

func test_it_seats_one_floor_per_slot() -> void:
	tower.seat(SEAT, SPAN, 6)
	assert_eq(tower.floor_count(), 6, "sechs Etagen")
	assert_not_null(tower.get_node_or_null("Chamber/Base"), "die KAMMER am Fuß")
	assert_not_null(tower.get_node_or_null("Chamber/ContactBar"), "die KONTAKTLEISTE")
	for i in 6:
		assert_not_null(tower.get_node_or_null("Floor%d/Mouth" % (i + 1)),
			"Etage %d hat ihren Mund" % (i + 1))
	# Die unterste steht auf der Kammer, jede weitere auf zwei Schienen.
	assert_null(tower.get_node_or_null("Floor1/RailA"), "Etage 1 steht auf der Kammer")
	assert_not_null(tower.get_node_or_null("Floor2/RailA"))
	assert_not_null(tower.get_node_or_null("Floor2/RailB"))

## Jede Etage steigt um genau EINE Teilung - und Etage 1 ist die UNTERSTE, denn das
## Licht steigt von unten.
func test_every_floor_rises_by_one_pitch() -> void:
	assert_almost_eq(TowerView.CARD_THICKNESS,
		DataCellView.DEPTH * PackDrawerView.CASSETTE_SCALE, 0.001,
		"eine Kartendicke ist EINE Zahl")
	assert_almost_eq(TowerView.FLOOR_PITCH,
		TowerView.CARD_THICKNESS + TowerView.FLOOR_PLATE, 0.001,
		"eine Etage ist Karte plus Boden")
	for i in range(1, 6):
		assert_almost_eq(TowerView.floor_top(i) - TowerView.floor_top(i - 1),
			TowerView.FLOOR_PITCH, 0.001, "Etage %d liegt eine Teilung höher" % i)
	assert_lt(TowerView.floor_top(0), TowerView.floor_top(5), "Etage 1 ist die UNTERSTE")
	assert_almost_eq(TowerView.floor_top(0), TowerView.CHAMBER_HEIGHT, 0.001,
		"und sie steht auf der Kammer")

## floor_seat steigt MONOTON, und floor_point setzt sie in Welt - vor die Leiste,
## nicht in sie.
func test_floor_points_climb_and_lie_before_the_contact_bar() -> void:
	tower.seat(SEAT, SPAN, 6)
	var last := -1000.0
	for i in 6:
		var point := tower.floor_point(i)
		assert_gt(point.y, last, "Etage %d liegt höher als die vorige" % i)
		last = point.y
		assert_almost_eq(point.x, SEAT.x, 0.001)
		assert_almost_eq(point.z, SEAT.z - tower.bar_depth() * 0.5, 0.001,
			"die Karte liegt VOR der Leiste")
	assert_almost_eq(tower.floor_point(0).y,
		SEAT.y + TowerView.floor_seat(0), 0.001)
	assert_eq(tower.floor_point(6), Vector3.ZERO, "eine siebte gibt es nicht")

## Die KONTAKTLEISTE steht am Bild-RECHTEN Rand - das ist WELT +Z - und IM
## gemeldeten Rechteck, nicht daneben.
func test_the_contact_bar_stands_right_inside_the_footprint() -> void:
	tower.seat(SEAT, SPAN, 6)
	var bar: MeshInstance3D = tower.get_node("Chamber/ContactBar")
	assert_gt(bar.position.z, SEAT.z, "sie steht auf der +Z-Seite (Bild-rechts)")
	assert_lte(bar.position.z + tower.bar_depth() * 0.5, SEAT.z + SPAN.y * 0.5 + 0.001,
		"und bleibt im Fußabdruck")
	assert_almost_eq((bar.mesh as BoxMesh).size.y, TowerView.tower_height(6), 0.001,
		"sie geht über die ganze Höhe")

## Das LICHT fährt von der Kammer bis zum Kopf - und bei Zeit 0 steht es hart dort.
func test_the_light_climbs_from_the_chamber_to_the_head() -> void:
	tower.seat(SEAT, SPAN, 6)
	assert_false(tower.lighting(), "vor dem Griff brennt nichts")
	tower.light_on(PressNetView.VALUE_TINT)
	assert_true(tower.lighting())
	assert_almost_eq(tower.light_height(), SEAT.y + tower.chamber_top(), 0.001,
		"es zündet in der Kammer")
	tower.light_to(tower.top_point().y, 0.0)
	assert_almost_eq(tower.light_height(), tower.top_point().y, 0.001,
		"Zeit 0 setzt hart")
	tower.light_off()
	assert_false(tower.lighting(), "und der Aufräum-Pfad löscht es")

## Ein REITER hängt an der Licht-Ebene und fährt mit ihr.
func test_a_rider_travels_with_the_light() -> void:
	tower.seat(SEAT, SPAN, 6)
	var rider := Node3D.new()
	tower.attach_to_light(rider)
	tower.light_on(PressNetView.VALUE_TINT)
	tower.light_to(tower.top_point().y, 0.0)
	assert_almost_eq(rider.global_position.y, tower.top_point().y, 0.001,
		"das Licht-Netz reitet mit")

## Der KOPF steht über der obersten Etage, und die Turmhöhe ist eine reine Rechnung.
func test_the_head_stands_above_the_top_floor() -> void:
	tower.seat(SEAT, SPAN, 6)
	assert_almost_eq(tower.top_point().y,
		SEAT.y + TowerView.tower_height(6), 0.001)
	assert_gt(tower.top_point().y, tower.floor_point(5).y, "über der obersten Karte")
	assert_almost_eq(TowerView.tower_height(6),
		TowerView.floor_top(5) + TowerView.CARD_THICKNESS, 0.001)

## DER TURM STEHT IN DER FLACHEN BUCHT (2026-09-11): sie ist genau so tief, dass
## die OBERSTE KARTE gerade noch unter dem Glas liegt - flacher als die Hälfte der
## Magazin-Grube geht nicht, ohne dass ein Upgrade über den Tisch ragt.
func test_the_bay_is_just_deep_enough_for_the_top_card() -> void:
	# Dieselbe Tiefe, die scene_root schneidet: Turmhöhe plus TOWER_PIT_HEADROOM.
	var depth := TowerView.tower_height(6) + 0.06
	assert_lt(depth, DataCellView.STAND_HEIGHT * PackDrawerView.CASSETTE_SCALE * 1.3 * 0.6,
		"nicht tiefer als gut die Hälfte der Magazin-Grube")
	tower.seat(Vector3(SEAT.x, -depth, SEAT.z), SPAN, 6)
	assert_almost_eq(tower.top_point().y, -0.06, 0.001,
		"der Turmkopf liegt um die Luft unter dem Glas")
	assert_lt(tower.floor_point(5).y + TowerView.CARD_THICKNESS, 0.0,
		"und die oberste Karte mit ihm")

## Der ZUG einer Karte: unten am weitesten heraus, oben am wenigsten - und der
## HOVER legt seinen vollen Weg obendrauf.
func test_the_pull_peeks_the_lower_floors_furthest_out() -> void:
	for i in range(1, 6):
		assert_lt(TowerView.pull_share(i, 6), TowerView.pull_share(i - 1, 6),
			"Etage %d steckt tiefer im Turm als die darunter" % i)
	assert_almost_eq(TowerView.pull_share(5, 6), TowerView.UNLATCHED_PULL, 0.001,
		"die oberste hat nur den Grundzug")
	assert_almost_eq(TowerView.eject_share(6),
		TowerView.pull_share(0, 6) + TowerView.HOVER_SLIDE, 0.001,
		"die AUSWURF-BAHN mißt den vollen Zug der untersten")
	assert_gte(TowerView.eject_share(6), 1.0,
		"und der zieht die Karte ganz aus dem Turm")

## seat() ist IDEMPOTENT: dieselbe Liste baut denselben Turm, kein zweiter Leib.
func test_seat_is_idempotent() -> void:
	tower.seat(SEAT, SPAN, 6)
	var before := tower.floor_point(3)
	var children := tower.get_child_count()
	tower.seat(SEAT, SPAN, 6)
	assert_eq(tower.floor_count(), 6, "immer noch sechs Etagen")
	assert_eq(tower.get_child_count(), children, "und kein zweiter Satz Körper")
	assert_almost_eq(tower.floor_point(3).distance_to(before), 0.0, 0.001)

## Ein kürzerer Turm behält seine Kammer und wird nur niedriger.
func test_a_shorter_tower_keeps_its_chamber() -> void:
	tower.seat(SEAT, SPAN, 2)
	assert_eq(tower.floor_count(), 2)
	assert_almost_eq(TowerView.floor_top(0), TowerView.CHAMBER_HEIGHT, 0.001)
	assert_lt(TowerView.tower_height(2), TowerView.tower_height(6))
