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
	# Keine Etage trägt Schienen (Spieler-Wunsch 2026-10-27): die Karte hängt im Mund.
	for i in 6:
		assert_null(tower.get_node_or_null("Floor%d/RailA" % (i + 1)))
		assert_null(tower.get_node_or_null("Floor%d/RailB" % (i + 1)))

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

## Die RÜCKWAND steht am Bild-RECHTEN Rand - das ist WELT +Z - und IM gemeldeten
## Rechteck, nicht daneben.
func test_the_contact_bar_stands_right_inside_the_footprint() -> void:
	tower.seat(SEAT, SPAN, 6)
	var bar: MeshInstance3D = tower.get_node("Chamber/ContactBar")
	assert_gt(bar.position.z, SEAT.z, "sie steht auf der +Z-Seite (Bild-rechts)")
	assert_lte(bar.position.z + tower.backplane_depth() * 0.5, SEAT.z + SPAN.y * 0.5 + 0.001,
		"und bleibt im Fußabdruck")
	assert_lte(tower.backplane_depth(), tower.bar_depth(), "nie tiefer als ihr Platz")
	for i in TowerView.BUS_LINES:
		assert_not_null(tower.get_node_or_null("Chamber/Bus%d" % i), "eine Busbahn je Stift")
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

## Die STUMMEL (Welle 29): unten ragt die Karte am weitesten aus der Tasche, oben am
## wenigsten; eingerastet bleibt ein kürzerer stehen, und der HOVER zieht jede Etage
## an DENSELBEN Platz ganz in die Auswurf-Bahn.
func test_the_stubs_peek_the_lower_floors_furthest_out() -> void:
	for i in range(1, 6):
		assert_lt(TowerView.pull_share(i, 6), TowerView.pull_share(i - 1, 6),
			"Etage %d steckt tiefer in der Tasche als die darunter" % i)
	assert_almost_eq(TowerView.pull_share(5, 6) - TowerView.HOME_INSET,
		TowerView.STUB_SHARE, 0.001, "die oberste zeigt genau ihren Stummel")
	assert_lt(TowerView.latched_share(), TowerView.pull_share(5, 6),
		"eingerastet steckt sie tiefer ...")
	assert_gt(TowerView.latched_share(), TowerView.HOME_INSET,
		"... aber nicht ganz - am Stummel sieht man das Licht")
	for i in 6:
		assert_almost_eq(TowerView.pull_share(i, 6) + TowerView.hover_slide_for(i, 6),
			TowerView.HOME_INSET + TowerView.EJECT_PULL, 0.001,
			"Etage %d landet am selben Platz in der Bahn" % i)
	assert_almost_eq(TowerView.eject_share(6), TowerView.EJECT_PULL, 0.001)
	assert_gte(TowerView.EJECT_PULL, 1.0, "der Hover zieht die Karte ganz heraus")

## Mit gemeldeter Tischkante steht der Turm in seiner geschlossenen TASCHE: die Decke
## unter dem Filz, offen nur zur Auswurf-Bahn (Bild-links).
func test_the_pocket_closes_the_tower_under_the_felt() -> void:
	tower.seat(SEAT, SPAN, 6, SEAT.y + 3.0, SPAN.x * 1.5)
	var ceiling := tower.get_node_or_null("Tasche/Decke") as MeshInstance3D
	assert_not_null(ceiling, "die Tasche hat eine Decke")
	assert_almost_eq(ceiling.position.y + TowerView.POCKET_WALL * 0.5,
		SEAT.y + 3.0 - PackPitView.WALL_SINK, 0.001, "knapp unter der Tischkante")
	assert_not_null(tower.get_node_or_null("Tasche/Rueckwand"))
	assert_null(tower.get_node_or_null("Tasche/Vorderwand"), "zur Bahn hin offen")
	var back := tower.get_node("Tasche/Rueckwand") as MeshInstance3D
	assert_gt(back.position.z, SEAT.z + SPAN.y * 0.5, "hinter der Kontaktleiste")
	tower.seat(SEAT, SPAN, 6)
	assert_null(tower.get_node_or_null("Tasche"), "ohne Tischkante keine Tasche")

## Und zur MAGAZIN-Grube (Welt -X) steht sie OFFEN, sobald es bestellt ist
## (Spieler-Wunsch 2026-10-27): deren Oberwand hat dort ihren Durchbruch, und erst
## beide zusammen geben den Blick auf die Etagen frei.
func test_the_pocket_opens_to_the_magazine_when_ordered() -> void:
	tower.seat(SEAT, SPAN, 6, SEAT.y + 3.0, SPAN.x * 1.5)
	assert_not_null(tower.get_node_or_null("Tasche/Flanke0"),
		"unbestellt steht die Flanke zur Grube")
	assert_not_null(tower.get_node_or_null("Tasche/Flanke1"))
	tower.pit_open = true
	tower.seat(SEAT, SPAN * 1.01, 6, SEAT.y + 3.0, SPAN.x * 1.5)
	assert_null(tower.get_node_or_null("Tasche/Flanke0"),
		"bestellt fehlt sie - man sieht aus der Grube hinein")
	assert_not_null(tower.get_node_or_null("Tasche/Flanke1"),
		"die andere Flanke bleibt, dahinter liegt kein Loch")
	assert_not_null(tower.get_node_or_null("Tasche/Decke"), "Decke und Boden bleiben")
	assert_not_null(tower.get_node_or_null("Tasche/Boden"))

## Die LICHT-EBENE liegt nur über den Stummeln, links vor der offenen Turmkante.
func test_the_light_plane_lies_over_the_stubs() -> void:
	tower.seat(SEAT, SPAN, 6)
	var plane := tower.get_node("Light/Plane") as MeshInstance3D
	var reach := tower.card_length() * (TowerView.pull_share(0, 6) - TowerView.HOME_INSET)
	assert_almost_eq(tower.light_plane_size().y, reach, 0.001, "so tief wie der längste Stummel")
	assert_almost_eq(plane.position.z, -SPAN.y * 0.5 - reach * 0.5, 0.001,
		"links vor der offenen Seite")

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

## Und ihr DECKEL faellt, sobald es bestellt ist (Spieler-Wunsch 2026-10-27): die
## TISCHSEKTION darueber ist GLAS, also steht dort der Turm und keine Blechdecke.
func test_the_pocket_lid_opens_when_ordered() -> void:
	tower.seat(SEAT, SPAN, 6, SEAT.y + 3.0, SPAN.x * 1.5)
	assert_not_null(tower.get_node_or_null("Tasche/Decke"), "unbestellt steht sie")
	tower.lid_open = true
	tower.seat(SEAT, SPAN * 1.01, 6, SEAT.y + 3.0, SPAN.x * 1.5)
	assert_null(tower.get_node_or_null("Tasche/Decke"), "bestellt faellt sie")
	assert_not_null(tower.get_node_or_null("Tasche/Boden"), "der Boden bleibt")
	assert_not_null(tower.get_node_or_null("Tasche/Rueckwand"))

## Je Etage eine BUCHSE (2026-10-27): ihr Mund ist der Fuß der EINGERASTETEN Karte -
## eingerastet stecken die Stifte darin, in Ruhe stehen sie frei davor.
func test_every_floor_has_its_socket_at_the_latched_foot() -> void:
	tower.seat(SEAT, SPAN, 6)
	var length := tower.card_length()
	var latched_foot := tower.floor_point(0).z - TowerView.latched_share() * length 		+ length * 0.5
	assert_almost_eq(tower.socket_mouth_z(), latched_foot, 0.0001)
	var rest_foot := tower.floor_point(0).z - TowerView.pull_share(0, 6) * length 		+ length * 0.5
	var pins := DataCellView.PIN_LENGTH * PackDrawerView.CASSETTE_SCALE
	assert_lt(rest_foot + pins, tower.socket_mouth_z(), "in Ruhe steckt keine Karte")
	for i in 6:
		var socket := tower.get_node_or_null("Floor%d/Buchse" % (i + 1)) as Node3D
		assert_not_null(socket, "Etage %d hat ihre Buchse" % (i + 1))
		assert_almost_eq(socket.position.z, tower.socket_mouth_z(), 0.0001)
		assert_almost_eq(socket.position.y,
			SEAT.y + TowerView.floor_seat(i) + TowerView.CARD_THICKNESS * 0.5, 0.0001,
			"auf Stifthöhe der Karte")
		assert_not_null(tower.get_node_or_null("Floor%d/Steg" % (i + 1)),
			"ein Steg trägt sie bis an die Rückwand")

## Das GESTELL: vier Pfosten außerhalb der Kartenbreite, und ab Etage 2 je zwei
## Winkel, deren Auflage genau unter der Kartenebene endet.
func test_the_rack_carries_every_upper_card_by_its_edges() -> void:
	tower.seat(SEAT, SPAN, 6)
	var posts := 0
	for child in tower.get_node("Gestell").get_children():
		if String(child.name).begins_with("Pfosten"):
			posts += 1
			assert_gt(absf((child as Node3D).position.x - SEAT.x),
				tower.card_width() * 0.5, "ein Pfosten steht neben der Karte, nie in ihrer Bahn")
	assert_eq(posts, 4)
	assert_null(tower.get_node_or_null("Floor1/AuflageA"), "Etage 1 liegt auf der Kammer")
	for i in range(1, 6):
		var ledge := tower.get_node("Floor%d/AuflageA" % (i + 1)) as MeshInstance3D
		var size := (ledge.mesh as BoxMesh).size
		assert_almost_eq(ledge.position.y + size.y * 0.5, SEAT.y + TowerView.floor_top(i),
			0.0001, "die Auflage trägt die Karte von Etage %d" % (i + 1))
		assert_lt(absf(ledge.position.x - SEAT.x) - size.x * 0.5, tower.card_width() * 0.5,
			"und greift unter ihre Kante")
		assert_lt(TowerView.RACK_RAIL, TowerView.FLOOR_PLATE,
			"und paßt zwischen zwei Karten")
